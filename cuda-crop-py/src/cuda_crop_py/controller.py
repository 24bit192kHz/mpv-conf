import json
import socket
from dataclasses import dataclass
from json import JSONDecodeError
from pathlib import Path
from time import sleep
from types import TracebackType
from typing import Protocol, Self, TextIO, TypedDict

from cuda_crop_py.cuda_detect import analyze_timeline_events
from cuda_crop_py.model import AnalyzerConfig
from cuda_crop_py.server import response_from_markers

type JsonValue = str | int | float | bool | None | list["JsonValue"] | dict[str, "JsonValue"]


class IpcResponse(TypedDict, total=False):
    data: JsonValue
    error: str


class ControllerError(RuntimeError):
    def __init__(self, message: str) -> None:
        super().__init__(message)


class ControllerFinishedError(RuntimeError):
    pass


class MpvClient(Protocol):
    def command(self, command: list[JsonValue]) -> IpcResponse: ...


@dataclass(frozen=True, slots=True)
class ControllerConfig:
    mpv_socket: Path
    interval_seconds: float
    scan_ahead_seconds: float
    duration_seconds: float
    threshold: float
    round_to: int
    sample_step: int
    min_votes: int
    gpu_id: int


@dataclass(frozen=True, slots=True)
class PlaybackState:
    path: str
    time_pos: float
    eof_reached: bool
    idle_active: bool
    core_idle: bool
    paused: bool


class MpvIpcConnection:
    def __init__(self, socket_path: Path) -> None:
        self.socket_path = socket_path
        self.client: socket.socket | None = None
        self.reader: TextIO | None = None
        self.request_id = 0

    def __enter__(self) -> Self:
        self.client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.client.connect(str(self.socket_path))
        self.reader = self.client.makefile("r", encoding="utf-8")
        return self

    def __exit__(
        self,
        _exc_type: type[BaseException] | None,
        _exc_value: BaseException | None,
        _traceback: TracebackType | None,
    ) -> None:
        if self.reader is not None:
            self.reader.close()
        if self.client is not None:
            self.client.close()

    def command(self, command: list[JsonValue]) -> IpcResponse:
        if self.client is None or self.reader is None:
            message = "mpv IPC connection is not open"
            raise ControllerError(message)

        self.request_id += 1
        request_id = self.request_id
        payload = (
            json.dumps({"command": command, "request_id": request_id}, separators=(",", ":")).encode()
            + b"\n"
        )
        self.client.sendall(payload)
        while line := self.reader.readline():
            response = parse_ipc_response(line, request_id)
            if response is not None:
                return response
        message = "mpv IPC returned no response"
        raise ControllerError(message)


def parse_ipc_response(line: str, request_id: int) -> IpcResponse | None:
    try:
        raw = json.loads(line)
    except JSONDecodeError as exc:
        message = "mpv IPC returned invalid JSON"
        raise ControllerError(message) from exc
    if not isinstance(raw, dict):
        message = "mpv IPC returned invalid response"
        raise ControllerError(message)
    if raw.get("request_id") != request_id:
        return None

    error = raw.get("error")
    if not isinstance(error, str):
        message = "mpv IPC returned invalid response"
        raise ControllerError(message)
    response: IpcResponse = {"error": error}
    data = raw.get("data")
    if data is None or isinstance(data, str | int | float | bool | list | dict):
        response["data"] = data
    return response


def mpv_property(client: MpvClient, name: str) -> JsonValue:
    response = client.command(["get_property", name])
    if response.get("error") != "success":
        return None
    return response.get("data")


def send_timeline(client: MpvClient, response_json: str, scan_start: float) -> None:
    client.command(
        [
            "script-message-to",
            "dynamic_crop",
            "timeline-events",
            response_json,
            f"{scan_start:.3f}",
        ],
    )


def playback_state(client: MpvClient) -> PlaybackState | None:
    path = mpv_property(client, "path")
    time_pos = mpv_property(client, "time-pos")
    eof_reached = mpv_property(client, "eof-reached")
    idle_active = mpv_property(client, "idle-active")
    core_idle = mpv_property(client, "core-idle")
    paused = mpv_property(client, "pause")
    if not isinstance(path, str) or not isinstance(time_pos, int | float):
        return None
    return PlaybackState(
        path=path,
        time_pos=float(time_pos),
        eof_reached=eof_reached is True,
        idle_active=idle_active is True,
        core_idle=core_idle is True,
        paused=paused is True,
    )


def scan_once(config: ControllerConfig, client: MpvClient, *, allow_paused: bool) -> bool:
    state = playback_state(client)
    if state is None:
        return False
    if state.eof_reached or state.idle_active:
        raise ControllerFinishedError
    if (state.core_idle or state.paused) and not allow_paused:
        return False

    scan_start = state.time_pos + config.scan_ahead_seconds
    analyzer_config = AnalyzerConfig(
        source=Path(state.path),
        start_seconds=scan_start,
        duration_seconds=config.duration_seconds,
        threshold=config.threshold,
        round_to=config.round_to,
        sample_step=config.sample_step,
        min_votes=config.min_votes,
        gpu_id=config.gpu_id,
    )
    markers = analyze_timeline_events(analyzer_config)
    if markers:
        response_json = json.dumps({"ok": True, **response_from_markers(markers)}, separators=(",", ":"))
    else:
        response_json = json.dumps({"ok": False, "error": "no stable crop found"}, separators=(",", ":"))
    send_timeline(client, response_json, scan_start)
    return True


def run_controller(config: ControllerConfig) -> None:
    try:
        with MpvIpcConnection(config.mpv_socket) as client:
            first_scan_sent = False
            while True:
                scan_sent = scan_once(config, client, allow_paused=not first_scan_sent)
                first_scan_sent = first_scan_sent or scan_sent
                sleep(config.interval_seconds)
    except (ControllerFinishedError, ControllerError, FileNotFoundError, ConnectionError, OSError):
        return
