import subprocess
from pathlib import Path

import pytest

from cuda_crop_py import ffmpeg_cropdetect
from cuda_crop_py.ffmpeg_cropdetect import VideoSignal
from cuda_crop_py.model import AnalyzerConfig, CropBox


def test_analyze_timeline_events_parses_cropdetect_without_segment_remux(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    full = CropBox(width=3840, height=2160, x=0, y=0)
    wide = CropBox(width=3840, height=1604, x=0, y=280)
    commands: list[list[str]] = []

    def run(
        command: list[str],
        check: bool,
        capture_output: bool,
        text: bool,
    ) -> subprocess.CompletedProcess[str]:
        assert check is False
        assert capture_output is True
        assert text is True
        commands.append(command)
        return subprocess.CompletedProcess(
            args=command,
            returncode=0,
            stderr=(
                "t:0.000000 crop=3840:2160:0:0\n"
                "t:0.041000 crop=3840:1602:0:280\n"
                "t:0.083000 crop=3840:1602:0:280\n"
            ),
        )

    monkeypatch.setattr(
        ffmpeg_cropdetect,
        "probe_video_signal",
        lambda _source: VideoSignal(bit_depth=10, limited_range=True),
    )
    monkeypatch.setattr(ffmpeg_cropdetect.subprocess, "run", run)

    markers = ffmpeg_cropdetect.analyze_timeline_events(
        AnalyzerConfig(
            source=Path("/movie.mkv"),
            start_seconds=1069.277,
            duration_seconds=3.0,
            threshold=2.0,
            round_to=2,
            sample_step=1,
            min_votes=2,
            gpu_id=0,
            current_crop=full,
        ),
    )

    assert [marker.crop for marker in markers] == [wide]
    assert [marker.relative_seconds for marker in markers] == [0.041]
    assert markers[0].remux_seconds == 0.0
    assert "copy" not in commands[0]
    assert commands[0][-2:] == ["null", "-"]
    assert any("cropdetect=limit=64:round=2:skip=2:reset=1" in arg for arg in commands[0])


def test_build_cropdetect_command_uses_limited_range_black_code() -> None:
    config = AnalyzerConfig(
        source=Path("/movie.mkv"),
        start_seconds=1.0,
        duration_seconds=3.0,
        threshold=2.0,
        round_to=2,
        sample_step=1,
        min_votes=2,
        gpu_id=0,
    )

    command = ffmpeg_cropdetect.build_cropdetect_command(
        config,
        VideoSignal(bit_depth=10, limited_range=True),
    )

    assert "hwdownload,format=p010le,cropdetect=limit=64:round=2:skip=2:reset=1" in command


def test_probe_video_signal_accepts_ffprobe_trailing_empty_field(monkeypatch: pytest.MonkeyPatch) -> None:
    def run(
        command: list[str],
        check: bool,
        capture_output: bool,
        text: bool,
    ) -> subprocess.CompletedProcess[str]:
        assert command[0] == "ffprobe"
        assert check is False
        assert capture_output is True
        assert text is True
        return subprocess.CompletedProcess(
            args=command,
            returncode=0,
            stdout="yuv420p10le,tv,\n",
        )

    ffmpeg_cropdetect.probe_video_signal.cache_clear()
    monkeypatch.setattr(ffmpeg_cropdetect.subprocess, "run", run)

    signal = ffmpeg_cropdetect.probe_video_signal("/movie.mkv")

    assert signal == VideoSignal(bit_depth=10, limited_range=True)
