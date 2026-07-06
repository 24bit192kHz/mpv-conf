from pathlib import Path
from typing import ClassVar

import pytest

from cuda_crop_py import cuda_detect
from cuda_crop_py.detect import (
    ActiveBounds,
    active_row_bounds,
    choose_crop,
    crop_from_bounds,
    crop_from_string,
    first_stable_crop,
    round_down,
)
from cuda_crop_py.model import AnalyzerConfig, CropBox, DetectorBackend
from cuda_crop_py.segment import build_remux_command
from cuda_crop_py.server import (
    DETECTOR_VERSION,
    parse_request,
    response_from_marker,
    response_from_vote,
)


def test_round_down_when_unit_is_even() -> None:
    assert round_down(1601, 2) == 1600


def test_crop_from_bounds_when_letterboxed() -> None:
    bounds = ActiveBounds(left=0, right=3839, top=280, bottom=1880)

    crop = crop_from_bounds(source_width=3840, source_height=2160, bounds=bounds, round_to=2)

    assert crop == CropBox(width=3840, height=1600, x=0, y=280)


def test_crop_from_string_when_valid() -> None:
    assert crop_from_string("3840:1600:0:280") == CropBox(width=3840, height=1600, x=0, y=280)


def test_active_row_bounds_keeps_dark_detailed_rows_active() -> None:
    row_means = [0.5, 0.7, 1.2, 5.0, 5.1]
    active_fractions = [0.004, 0.004, 0.004, 0.5, 0.5]

    assert active_row_bounds(row_means, active_fractions, threshold=2.0) == (0, 4)


def test_active_row_bounds_detects_true_black_bars() -> None:
    row_means = [0.0, 0.0, 5.0, 5.1, 0.0]
    active_fractions = [0.0, 0.0, 0.5, 0.5, 0.0]

    assert active_row_bounds(row_means, active_fractions, threshold=2.0) == (2, 3)


def test_choose_crop_when_enough_votes() -> None:
    crop = CropBox(width=3840, height=1600, x=0, y=280)
    vote = choose_crop([crop, crop], min_votes=2)

    assert vote is not None
    assert vote.crop == crop
    assert vote.votes == 2
    assert vote.remux_seconds == 0.0


def test_choose_crop_when_too_few_votes() -> None:
    crop = CropBox(width=3840, height=1600, x=0, y=280)

    assert choose_crop([crop], min_votes=2) is None


def test_parse_request_when_valid_json() -> None:
    config = parse_request(
        '{"source":"/movie.mkv","start":53,"duration":4,"threshold":26,'
        '"round_to":2,"sample_step":8,"min_votes":3}',
    )

    assert config.source == Path("/movie.mkv")
    assert config.start_seconds == 53.0
    assert config.duration_seconds == 4.0
    assert config.sample_step == 8


def test_response_from_vote_when_crop_found() -> None:
    crop = CropBox(width=3840, height=1600, x=0, y=280)
    vote = choose_crop([crop, crop, crop], min_votes=3, remux_seconds=0.1, analyze_seconds=0.2)

    assert vote is not None
    response = response_from_vote(vote)
    assert response["crop"] == "3840:1600:0:280"
    assert response["detector_version"] == DETECTOR_VERSION


def test_first_stable_crop_when_verified_by_two_samples() -> None:
    full = CropBox(width=3840, height=2160, x=0, y=0)
    cropped = CropBox(width=3840, height=1600, x=0, y=280)
    marker = first_stable_crop([(0.0, full), (1.0, cropped), (2.0, cropped)], min_votes=2)

    assert marker is not None
    assert marker.crop == cropped
    assert marker.relative_seconds == 1.0
    assert response_from_marker(marker)["relative_seconds"] == 1.0


def test_first_stable_crop_skips_current_crop_until_transition() -> None:
    full = CropBox(width=3840, height=2160, x=0, y=0)
    cropped = CropBox(width=3840, height=1600, x=0, y=280)
    marker = first_stable_crop(
        [(0.0, full), (0.5, full), (1.0, cropped), (1.042, cropped)],
        min_votes=2,
        current_crop=full,
    )

    assert marker is not None
    assert marker.crop == cropped
    assert marker.relative_seconds == 1.0


def test_parse_request_when_current_crop_is_present() -> None:
    config = parse_request(
        '{"source":"/movie.mkv","start":53,"duration":4,"threshold":26,'
        '"round_to":2,"sample_step":8,"min_votes":3,"current_crop":"3840:2160:0:0"}',
    )

    assert config.current_crop == CropBox(width=3840, height=2160, x=0, y=0)


def test_parse_request_when_cpu_detector_backend_is_present() -> None:
    config = parse_request(
        (
            '{"source":"/movie.mkv","start":1,"duration":2,"threshold":2,'
            '"round_to":2,"sample_step":1,"min_votes":2,"detector_backend":"cpu"}'
        ),
    )

    assert config.detector_backend == DetectorBackend.CPU


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


def test_analyze_timeline_segment_stops_after_first_stable_crop(monkeypatch: pytest.MonkeyPatch) -> None:
    crop = CropBox(width=3840, height=1600, x=0, y=280)

    def detect_frame_crop(
        _frame: cuda_detect.DecodedRgbFrame,
        _threshold: float,
        _round_to: int,
    ) -> CropBox:
        return crop

    FakeDecoder.requested_indexes = []
    monkeypatch.setattr(cuda_detect.nvc, "SimpleDecoder", FakeDecoder)
    monkeypatch.setattr(cuda_detect, "_detect_frame_crop", detect_frame_crop)

    config = AnalyzerConfig(
        source=Path("/movie.mkv"),
        start_seconds=0.0,
        duration_seconds=10.0,
        threshold=26.0,
        round_to=2,
        sample_step=6,
        min_votes=3,
        gpu_id=0,
    )

    marker = cuda_detect.analyze_timeline_segment(
        Path("segment.mkv"),
        config,
        remux_seconds=0.1,
        segment_start_seconds=0.0,
        frame_duration_seconds=1 / 12,
    )

    assert marker is not None
    assert marker.crop == crop
    assert marker.sampled_frames == 3
    assert FakeDecoder.requested_indexes == [0, 6, 12]


def test_analyze_timeline_segment_skips_preroll_frames(monkeypatch: pytest.MonkeyPatch) -> None:
    full = CropBox(width=3840, height=2160, x=0, y=0)
    cropped = CropBox(width=3840, height=1600, x=0, y=280)
    crops = [full, full, cropped, cropped]

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
        source=Path("/movie.mkv"),
        start_seconds=51.967,
        duration_seconds=4.0,
        threshold=26.0,
        round_to=2,
        sample_step=12,
        min_votes=2,
        gpu_id=0,
        current_crop=full,
    )

    marker = cuda_detect.analyze_timeline_segment(
        Path("segment.mkv"),
        config,
        remux_seconds=0.1,
        segment_start_seconds=50.968,
        frame_duration_seconds=1 / 30,
    )

    assert marker is not None
    assert marker.crop == cropped
    assert marker.relative_seconds == pytest.approx(1.001 + (2 / 30))
    assert FakeDecoder.requested_indexes == [36, 48, 60, 72]


def test_analyze_timeline_segment_uses_real_frame_duration(monkeypatch: pytest.MonkeyPatch) -> None:
    full = CropBox(width=1920, height=1080, x=0, y=0)
    cropped = CropBox(width=1920, height=816, x=0, y=132)
    crops = [full, full, full, full, full, full, full, full, cropped, cropped]

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
        source=Path("/anime.mkv"),
        start_seconds=170.0,
        duration_seconds=3.0,
        threshold=2.0,
        round_to=2,
        sample_step=12,
        min_votes=2,
        gpu_id=0,
        current_crop=full,
    )

    marker = cuda_detect.analyze_timeline_segment(
        Path("segment.mkv"),
        config,
        remux_seconds=0.1,
        segment_start_seconds=170.212,
        frame_duration_seconds=1 / 24,
    )

    assert marker is not None
    assert marker.crop == cropped
    assert marker.relative_seconds == pytest.approx(4.212 + (2 / 24))
    assert FakeDecoder.requested_indexes == [0, 12, 24, 36, 48, 60, 72, 84, 96, 108]


def test_build_remux_command_preserves_source_timestamps() -> None:
    command = build_remux_command(Path("/movie.mkv"), Path("segment.mkv"), 51.967, 3.0)

    assert "-copyts" in command
    assert "disabled" in command
    assert command[:3] == ["ionice", "-c", "3"]
    assert command[3:6] == ["nice", "-n", "19"]
    assert command[6:9] == ["chrt", "-i", "0"]
