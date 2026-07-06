from json import loads
from pathlib import Path

import pytest

from cuda_crop_py import controller
from cuda_crop_py.model import AnalyzerConfig, CropBox, CropMarker


class FakeMpvClient:
    def __init__(self, properties: dict[str, controller.JsonValue]) -> None:
        self.properties = properties
        self.messages: list[list[controller.JsonValue]] = []

    def command(self, command: list[controller.JsonValue]) -> controller.IpcResponse:
        name = command[0]
        if name == "get_property":
            property_name = command[1]
            assert isinstance(property_name, str)
            return {"error": "success", "data": self.properties.get(property_name)}
        if name == "script-message-to":
            self.messages.append(command)
            return {"error": "success"}
        msg = f"unexpected mpv command: {command}"
        raise AssertionError(msg)


def config_for(tmp_path: Path) -> controller.ControllerConfig:
    return controller.ControllerConfig(
        mpv_socket=tmp_path / "mpv.sock",
        interval_seconds=0.25,
        scan_ahead_seconds=0.0,
        duration_seconds=3.0,
        threshold=2.0,
        round_to=2,
        sample_step=1,
        min_votes=2,
        gpu_id=0,
    )


def test_scan_once_allows_startup_scan_while_mpv_is_paused(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    source = tmp_path / "movie.mkv"
    source.write_bytes(b"movie")
    client = FakeMpvClient(
        {
            "path": str(source),
            "time-pos": 10.0,
            "eof-reached": False,
            "idle-active": False,
            "core-idle": True,
            "pause": True,
        },
    )

    def analyze_timeline_events(config: AnalyzerConfig) -> list[CropMarker]:
        assert config.source == source
        assert config.start_seconds == 10.0
        return [
            CropMarker(
                crop=CropBox(width=3840, height=1604, x=0, y=280),
                relative_seconds=0.0,
                votes=2,
                sampled_frames=3,
                remux_seconds=0.0,
                analyze_seconds=0.1,
            ),
        ]

    monkeypatch.setattr(controller, "analyze_timeline_events", analyze_timeline_events)

    assert controller.scan_once(config_for(tmp_path), client, allow_paused=True)
    assert len(client.messages) == 1
    assert client.messages[0][:3] == ["script-message-to", "dynamic_crop", "timeline-events"]
    payload = loads(str(client.messages[0][3]))
    assert payload["ok"] is True
    assert payload["crop"] == "3840:1604:0:280"


def test_scan_once_skips_paused_playback_after_startup(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    source = tmp_path / "movie.mkv"
    source.write_bytes(b"movie")
    client = FakeMpvClient(
        {
            "path": str(source),
            "time-pos": 10.0,
            "eof-reached": False,
            "idle-active": False,
            "core-idle": False,
            "pause": True,
        },
    )

    def analyze_timeline_events(_config: AnalyzerConfig) -> list[CropMarker]:
        msg = "paused playback after startup must not scan"
        raise AssertionError(msg)

    monkeypatch.setattr(controller, "analyze_timeline_events", analyze_timeline_events)

    assert not controller.scan_once(config_for(tmp_path), client, allow_paused=False)
    assert client.messages == []


def test_scan_once_stops_controller_when_mpv_reaches_core_idle(tmp_path: Path) -> None:
    source = tmp_path / "movie.mkv"
    source.write_bytes(b"movie")
    client = FakeMpvClient(
        {
            "path": str(source),
            "time-pos": 10.0,
            "eof-reached": False,
            "idle-active": False,
            "core-idle": True,
            "pause": False,
        },
    )

    with pytest.raises(controller.ControllerFinishedError):
        controller.scan_once(config_for(tmp_path), client, allow_paused=False)
