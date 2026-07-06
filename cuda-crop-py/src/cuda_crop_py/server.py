import fcntl
import os
import socket
import subprocess
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from json import JSONDecodeError, dumps, loads
from pathlib import Path
from shutil import which
from types import TracebackType
from typing import Self, TextIO

from cuda_crop_py.detect import crop_from_string
from cuda_crop_py.model import (
    AnalyzerConfig,
    CropMarker,
    CropResponse,
    CropVote,
    DetectorBackend,
    TimelineEventsResponse,
    TimelineResponse,
)

DETECTOR_VERSION = "active-box-cfr-v5"


class ProtocolError(Exception):
    def __init__(self, message: str) -> None:
        self.message = message
        super().__init__(message)

    @classmethod
    def invalid_json(cls) -> Self:
        return cls("request is not valid json")

    @classmethod
    def invalid_shape(cls) -> Self:
        return cls("request must be a json object")

    @classmethod
    def missing_key(cls, key: str) -> Self:
        return cls(f"missing request key: {key}")

    @classmethod
    def invalid_value_type(cls) -> Self:
        return cls("request has invalid value types")

    @classmethod
    def active_server(cls) -> Self:
        return cls("server already active")


def socket_is_active(socket_path: Path) -> bool:
    if not socket_path.exists():
        return False
    probe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    with probe:
        try:
            probe.connect(str(socket_path))
        except OSError:
            return False
    return True


@dataclass(frozen=True, slots=True)
class CropServerConfig:
    socket_path: Path
    idle_timeout_seconds: float


class UnixCropServer:
    def __init__(self, config: CropServerConfig) -> None:
        self.config = config
        self._socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._lock_file: TextIO | None = None

    def _release_lock(self) -> None:
        if self._lock_file is None:
            return
        fcntl.flock(self._lock_file.fileno(), fcntl.LOCK_UN)
        self._lock_file.close()
        self._lock_file = None

    def __enter__(self) -> Self:
        self._lock_file = self.config.socket_path.with_suffix(self.config.socket_path.suffix + ".lock").open(
            "w",
            encoding="utf-8",
        )
        try:
            fcntl.flock(self._lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            self._lock_file.close()
            self._lock_file = None
            raise ProtocolError.active_server() from exc

        try:
            if socket_is_active(self.config.socket_path):
                raise ProtocolError.active_server()
            self.config.socket_path.unlink(missing_ok=True)
            self._socket.bind(str(self.config.socket_path))
            self._socket.listen(4)
            self._socket.settimeout(self.config.idle_timeout_seconds)
        except OSError:
            self._release_lock()
            raise
        except ProtocolError:
            self._release_lock()
            raise
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        self._socket.close()
        self.config.socket_path.unlink(missing_ok=True)
        self._release_lock()

    def serve_forever(self) -> None:
        while True:
            try:
                connection, _address = self._socket.accept()
            except TimeoutError:
                return
            with connection:
                try:
                    line = connection.makefile("r", encoding="utf-8").readline()
                    connection.sendall(handle_request(line))
                except OSError:
                    continue


def parse_request(line: str) -> AnalyzerConfig:
    try:
        raw = loads(line)
    except JSONDecodeError as exc:
        raise ProtocolError.invalid_json() from exc

    if not isinstance(raw, dict):
        raise ProtocolError.invalid_shape()

    try:
        source = Path(str(raw["source"]))
        start = float(raw["start"])
        duration = float(raw["duration"])
        threshold = float(raw["threshold"])
        round_to = int(raw["round_to"])
        sample_step = int(raw["sample_step"])
        min_votes = int(raw["min_votes"])
        gpu_id = int(raw.get("gpu_id", 0))
        current_crop = raw.get("current_crop")
        detector_backend = DetectorBackend(str(raw.get("detector_backend", DetectorBackend.CUDA)))
    except KeyError as exc:
        raise ProtocolError.missing_key(str(exc.args[0])) from exc
    except (TypeError, ValueError) as exc:
        raise ProtocolError.invalid_value_type() from exc

    if current_crop is not None and not isinstance(current_crop, str):
        raise ProtocolError.invalid_value_type()
    try:
        parsed_current_crop = crop_from_string(current_crop) if current_crop is not None else None
    except ValueError as exc:
        raise ProtocolError.invalid_value_type() from exc

    return AnalyzerConfig(
        source=source,
        start_seconds=start,
        duration_seconds=duration,
        threshold=threshold,
        round_to=round_to,
        sample_step=sample_step,
        min_votes=min_votes,
        gpu_id=gpu_id,
        current_crop=parsed_current_crop,
        detector_backend=detector_backend,
    )


def response_from_vote(vote: CropVote) -> CropResponse:
    return {
        "detector_version": DETECTOR_VERSION,
        "crop": vote.crop.ffmpeg_crop(),
        "mpv_filter": vote.crop.mpv_filter(),
        "votes": vote.votes,
        "sampled_frames": vote.sampled_frames,
        "remux_seconds": vote.remux_seconds,
        "analyze_seconds": vote.analyze_seconds,
    }


def response_from_marker(marker: CropMarker) -> TimelineResponse:
    return {
        "detector_version": DETECTOR_VERSION,
        "crop": marker.crop.ffmpeg_crop(),
        "mpv_filter": marker.crop.mpv_filter(),
        "votes": marker.votes,
        "sampled_frames": marker.sampled_frames,
        "remux_seconds": marker.remux_seconds,
        "analyze_seconds": marker.analyze_seconds,
        "relative_seconds": marker.relative_seconds,
    }


def response_from_markers(markers: list[CropMarker]) -> TimelineEventsResponse:
    first = markers[0]
    return {
        **response_from_marker(first),
        "events": [response_from_marker(marker) for marker in markers],
    }


def request_wants_timeline(line: str) -> bool:
    try:
        raw = loads(line)
    except JSONDecodeError:
        return False
    return isinstance(raw, dict) and raw.get("timeline") is True


@contextmanager
def suppress_native_stderr() -> Iterator[None]:
    saved_stderr = os.dup(2)
    with Path(os.devnull).open("w", encoding="utf-8") as devnull:
        os.dup2(devnull.fileno(), 2)
        try:
            yield
        finally:
            os.dup2(saved_stderr, 2)
            os.close(saved_stderr)


def silence_process_output() -> None:
    with Path(os.devnull).open("w", encoding="utf-8") as devnull:
        os.dup2(devnull.fileno(), 1)
        os.dup2(devnull.fileno(), 2)


def lower_process_priority() -> None:
    try:
        os.nice(19)
    except OSError:
        return

    chrt = which("chrt")
    if chrt is not None:
        subprocess.run(
            [chrt, "-i", "-p", "0", str(os.getpid())],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    ionice = which("ionice")
    if ionice is None:
        return
    subprocess.run(
        [ionice, "-c", "3", "-p", str(os.getpid())],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def handle_request(line: str) -> bytes:
    from cuda_crop_py.cpu_detect import analyze_timeline_events as analyze_cpu_timeline_events
    from cuda_crop_py.cuda_detect import (
        analyze_source,
    )
    from cuda_crop_py.cuda_detect import (
        analyze_timeline_events as analyze_cuda_timeline_events,
    )

    try:
        config = parse_request(line)
        with suppress_native_stderr():
            if request_wants_timeline(line):
                match config.detector_backend:
                    case DetectorBackend.CPU:
                        markers = analyze_cpu_timeline_events(config)
                    case DetectorBackend.CUDA:
                        markers = analyze_cuda_timeline_events(config)
                if not markers:
                    return dumps({"ok": False, "error": "no stable crop found"}).encode() + b"\n"
                return dumps({"ok": True, **response_from_markers(markers)}).encode() + b"\n"
            vote = analyze_source(config)
    except ProtocolError as exc:
        return dumps({"ok": False, "error": exc.message}).encode() + b"\n"

    if vote is None:
        return dumps({"ok": False, "error": "no stable crop found"}).encode() + b"\n"

    return dumps({"ok": True, **response_from_vote(vote)}).encode() + b"\n"


def serve(socket_path: Path, idle_timeout_seconds: float) -> None:
    config = CropServerConfig(socket_path=socket_path, idle_timeout_seconds=idle_timeout_seconds)
    lower_process_priority()
    with UnixCropServer(config) as server:
        silence_process_output()
        server.serve_forever()
