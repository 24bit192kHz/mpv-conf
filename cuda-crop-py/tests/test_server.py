import subprocess
from json import dumps, loads
from pathlib import Path
from typing import ClassVar

import pytest

from cuda_crop_py import cpu_detect, cuda_detect
from cuda_crop_py import server as server_module
from cuda_crop_py.model import AnalyzerConfig, CropBox, CropMarker, DetectorBackend
from cuda_crop_py.server import (
    CropServerConfig,
    ProtocolError,
    UnixCropServer,
    handle_request,
    lower_process_priority,
)


class IdleSocket:
    last_socket: ClassVar["IdleSocket | None"] = None

    def __init__(self, _family: int, _socket_type: int) -> None:
        self.closed = False
        self.timeout_seconds = 0.0
        IdleSocket.last_socket = self

    def bind(self, _path: str) -> None:
        return

    def listen(self, _backlog: int) -> None:
        return

    def settimeout(self, timeout_seconds: float) -> None:
        self.timeout_seconds = timeout_seconds

    def accept(self) -> tuple["IdleSocket", None]:
        raise TimeoutError

    def close(self) -> None:
        self.closed = True


def test_unix_crop_server_exits_after_idle_timeout(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    socket_path = tmp_path / "crop.sock"
    config = CropServerConfig(socket_path=socket_path, idle_timeout_seconds=0.01)

    monkeypatch.setattr(server_module.socket, "socket", IdleSocket)
    with UnixCropServer(config) as server:
        server.serve_forever()

    assert IdleSocket.last_socket is not None
    assert IdleSocket.last_socket.closed
    assert IdleSocket.last_socket.timeout_seconds == 0.01


def test_unix_crop_server_rejects_second_owner_for_same_socket(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    socket_path = tmp_path / "crop.sock"
    config = CropServerConfig(socket_path=socket_path, idle_timeout_seconds=1.0)

    monkeypatch.setattr(server_module.socket, "socket", IdleSocket)
    with (
        UnixCropServer(config),
        pytest.raises(ProtocolError, match="server already active"),
        UnixCropServer(config),
    ):
        pass


def test_lower_process_priority_uses_idle_io_class(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[tuple[str, int | list[str]]] = []

    def nice(increment: int) -> int:
        calls.append(("nice", increment))
        return 19

    def run(
        args: list[str],
        check: bool,
        stdout: int,
        stderr: int,
    ) -> subprocess.CompletedProcess[str]:
        calls.append(("run", args))
        assert check is False
        assert stdout == subprocess.DEVNULL
        assert stderr == subprocess.DEVNULL
        return subprocess.CompletedProcess(args=args, returncode=0)

    monkeypatch.setattr(server_module.os, "nice", nice)
    monkeypatch.setattr(server_module.os, "getpid", lambda: 1234)
    monkeypatch.setattr(
        server_module,
        "which",
        lambda name: f"/usr/bin/{name}" if name in {"chrt", "ionice"} else None,
    )
    monkeypatch.setattr(server_module.subprocess, "run", run)

    lower_process_priority()

    assert calls == [
        ("nice", 19),
        ("run", ["/usr/bin/chrt", "-i", "-p", "0", "1234"]),
        ("run", ["/usr/bin/ionice", "-c", "3", "-p", "1234"]),
    ]


def test_handle_request_routes_timeline_to_cpu_backend(monkeypatch: pytest.MonkeyPatch) -> None:
    def analyze_cpu_timeline_events(config: AnalyzerConfig) -> list[CropMarker]:
        assert config.detector_backend == DetectorBackend.CPU
        return [
            CropMarker(
                crop=CropBox(width=1920, height=800, x=0, y=140),
                relative_seconds=0.5,
                votes=2,
                sampled_frames=2,
                remux_seconds=0.0,
                analyze_seconds=0.01,
            ),
        ]

    def analyze_cuda_timeline_events(_config: AnalyzerConfig) -> list[CropMarker]:
        msg = "cpu detector requests must not call the cuda analyzer"
        raise AssertionError(msg)

    monkeypatch.setattr(cpu_detect, "analyze_timeline_events", analyze_cpu_timeline_events)
    monkeypatch.setattr(cuda_detect, "analyze_timeline_events", analyze_cuda_timeline_events)

    response = loads(
        handle_request(
            dumps(
                {
                    "source": "/movie.mkv",
                    "start": 1,
                    "duration": 2,
                    "threshold": 2,
                    "round_to": 2,
                    "sample_step": 1,
                    "min_votes": 2,
                    "detector_backend": "cpu",
                    "timeline": True,
                },
            ),
        ),
    )

    assert response["ok"] is True
    assert response["crop"] == "1920:800:0:140"
    assert response["remux_seconds"] == 0.0
