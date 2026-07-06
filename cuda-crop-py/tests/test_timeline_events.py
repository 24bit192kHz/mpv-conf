from pathlib import Path
from typing import ClassVar, NoReturn

import pytest

from cuda_crop_py import cuda_detect
from cuda_crop_py.detect import stable_crop_markers
from cuda_crop_py.ffmpeg_cropdetect import CropdetectError
from cuda_crop_py.model import AnalyzerConfig, CropBox, CropMarker
from cuda_crop_py.segment import SegmentInfo


class FakeFrame:
    def cuda(self) -> list[cuda_detect.CudaMemoryView]:
        return []


class FakeDecoder:
    requested_indexes: ClassVar[list[int]] = []

    def __init__(
        self,
        source: str,
        gpu_id: int,
        use_device_memory: bool,
        output_color_type: cuda_detect.nvc.OutputColorType,
    ) -> None:
        self.source = source
        self.gpu_id = gpu_id
        self.use_device_memory = use_device_memory
        self.output_color_type = output_color_type

    def __len__(self) -> int:
        return 120

    def __getitem__(self, index: int) -> FakeFrame:
        self.requested_indexes.append(index)
        return FakeFrame()

def test_stable_crop_markers_returns_all_timeline_transitions() -> None:
    full = CropBox(width=1920, height=1080, x=0, y=0)
    wide = CropBox(width=1920, height=752, x=0, y=164)
    academy = CropBox(width=1920, height=928, x=0, y=76)

    markers = stable_crop_markers(
        [
            (0.0, full),
            (0.5, wide),
            (0.542, wide),
            (1.0, academy),
            (1.042, academy),
            (1.5, wide),
            (1.542, wide),
        ],
        min_votes=2,
        current_crop=full,
    )

    assert [marker.crop for marker in markers] == [wide, academy, wide]
    assert [marker.relative_seconds for marker in markers] == [0.5, 1.0, 1.5]


def test_stable_crop_markers_ignores_letterbox_edge_jitter() -> None:
    wide = CropBox(width=3840, height=1604, x=0, y=280)
    jitter = CropBox(width=3840, height=1600, x=0, y=280)
    full = CropBox(width=3840, height=2160, x=0, y=0)

    markers = stable_crop_markers(
        [
            (0.0, jitter),
            (0.125, wide),
            (0.792, jitter),
            (0.959, wide),
            (1.752, jitter),
            (1.835, full),
            (1.877, full),
        ],
        min_votes=2,
        current_crop=wide,
    )

    assert [marker.crop for marker in markers] == [full]
    assert [marker.relative_seconds for marker in markers] == [1.835]


def test_stable_crop_markers_suppresses_sub_quarter_second_revert() -> None:
    wide = CropBox(width=3840, height=1604, x=0, y=280)
    full = CropBox(width=3840, height=2160, x=0, y=0)

    markers = stable_crop_markers(
        [
            (0.000, full),
            (0.042, full),
            (0.166, wide),
            (0.209, wide),
            (1.918, full),
            (1.960, full),
        ],
        min_votes=2,
        current_crop=wide,
    )

    assert [marker.crop for marker in markers] == [full]
    assert [marker.relative_seconds for marker in markers] == [1.918]


def test_analyze_timeline_segment_events_keeps_rapid_transitions(monkeypatch: pytest.MonkeyPatch) -> None:
    full = CropBox(width=1920, height=1080, x=0, y=0)
    wide = CropBox(width=1920, height=752, x=0, y=164)
    academy = CropBox(width=1920, height=928, x=0, y=76)
    crops = [full, wide, wide, academy, academy, wide, wide, wide, wide, wide]

    def detect_frame_crop(
        _frame: cuda_detect.DecodedRgbFrame,
        _threshold: float,
        _round_to: int,
    ) -> CropBox:
        return crops.pop(0)

    FakeDecoder.requested_indexes = []
    monkeypatch.setattr(cuda_detect.nvc, "SimpleDecoder", FakeDecoder)
    monkeypatch.setattr(cuda_detect, "_detect_frame_crop", detect_frame_crop)

    config = AnalyzerConfig(
        source=Path("/ratio.mp4"),
        start_seconds=0.0,
        duration_seconds=3.0,
        threshold=2.0,
        round_to=2,
        sample_step=12,
        min_votes=2,
        gpu_id=0,
        current_crop=full,
    )

    markers = cuda_detect.analyze_timeline_segment_events(
        Path("segment.mkv"),
        config,
        remux_seconds=0.1,
        segment_start_seconds=0.0,
        frame_duration_seconds=1 / 24,
    )

    assert [marker.crop for marker in markers] == [wide, academy, wide]
    assert [marker.relative_seconds for marker in markers] == [0.5 + (2 / 24), 1.5 + (2 / 24), 2.5 + (2 / 24)]
    assert FakeDecoder.requested_indexes == [0, 12, 24, 36, 48, 60, 72, 84, 96, 108]


def test_analyze_timeline_events_uses_cropdetect_without_remux(monkeypatch: pytest.MonkeyPatch) -> None:
    full = CropBox(width=1920, height=1080, x=0, y=0)
    wide = CropBox(width=1920, height=752, x=0, y=164)

    def fail_remux(_source: Path, _target: Path, _start: float, _duration: float) -> NoReturn:
        message = "timeline analysis must not remux source video"
        raise AssertionError(message)

    def analyze_cropdetect_timeline_events(_config: AnalyzerConfig) -> list[CropMarker]:
        return [
            CropMarker(
                crop=wide,
                relative_seconds=1.0,
                votes=2,
                sampled_frames=5,
                remux_seconds=0.0,
                analyze_seconds=0.2,
            ),
        ]

    monkeypatch.setattr(cuda_detect, "remux_segment", fail_remux)
    monkeypatch.setattr(cuda_detect, "analyze_cropdetect_timeline_events", analyze_cropdetect_timeline_events)

    config = AnalyzerConfig(
        source=Path("/ratio.mp4"),
        start_seconds=1.0,
        duration_seconds=2.0,
        threshold=2.0,
        round_to=2,
        sample_step=12,
        min_votes=2,
        gpu_id=0,
        current_crop=full,
    )

    markers = cuda_detect.analyze_timeline_events(config)

    assert [marker.crop for marker in markers] == [wide]
    assert [marker.relative_seconds for marker in markers] == [1.0]
    assert markers[0].remux_seconds == 0.0


def test_analyze_timeline_events_falls_back_to_remux_when_cropdetect_fails(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    source = tmp_path / "movie.mkv"
    source.write_bytes(b"movie")
    full = CropBox(width=1920, height=1080, x=0, y=0)
    wide = CropBox(width=1920, height=752, x=0, y=164)

    def analyze_cropdetect_timeline_events(_config: AnalyzerConfig) -> NoReturn:
        message = "cropdetect failed"
        raise CropdetectError(message)

    def remux_segment(source_path: Path, target_path: Path, start: float, duration: float) -> SegmentInfo:
        assert source_path == source
        assert target_path.name == "segment.mkv"
        assert start == 1.0
        assert duration == 2.0
        target_path.write_bytes(b"segment")
        return SegmentInfo(start_seconds=1.0, frame_duration_seconds=1 / 24)

    def analyze_timeline_segment_events(
        segment_path: Path,
        _config: AnalyzerConfig,
        remux_seconds: float,
        segment_start_seconds: float,
        frame_duration_seconds: float,
    ) -> list[CropMarker]:
        assert segment_path.name == "segment.mkv"
        assert remux_seconds >= 0.0
        assert segment_start_seconds == 1.0
        assert frame_duration_seconds == 1 / 24
        return [
            CropMarker(
                crop=wide,
                relative_seconds=0.5,
                votes=2,
                sampled_frames=2,
                remux_seconds=remux_seconds,
                analyze_seconds=0.01,
            ),
        ]

    monkeypatch.setattr(cuda_detect, "analyze_cropdetect_timeline_events", analyze_cropdetect_timeline_events)
    monkeypatch.setattr(cuda_detect, "remux_segment", remux_segment)
    monkeypatch.setattr(cuda_detect, "analyze_timeline_segment_events", analyze_timeline_segment_events)

    markers = cuda_detect.analyze_timeline_events(
        AnalyzerConfig(
            source=source,
            start_seconds=1.0,
            duration_seconds=2.0,
            threshold=2.0,
            round_to=2,
            sample_step=12,
            min_votes=2,
            gpu_id=0,
            current_crop=full,
        ),
    )

    assert [marker.crop for marker in markers] == [wide]
