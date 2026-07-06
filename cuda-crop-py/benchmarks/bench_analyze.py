from dataclasses import asdict, dataclass
from enum import StrEnum
from json import dumps
from pathlib import Path
from tempfile import TemporaryDirectory
from time import perf_counter
from typing import Annotated, assert_never

import PyNvVideoCodec as nvc
import typer

from cuda_crop_py.cuda_detect import _detect_frame_crop
from cuda_crop_py.detect import choose_crop, first_stable_crop
from cuda_crop_py.model import AnalyzerConfig, CropBox
from cuda_crop_py.segment import remux_segment


class BenchmarkMode(StrEnum):
    TIMELINE = "timeline"
    VOTE = "vote"


@dataclass(frozen=True, slots=True)
class BenchmarkTiming:
    remux_seconds: float
    decoder_init_seconds: float
    frame_fetch_seconds: float
    gpu_compute_seconds: float
    vote_seconds: float
    total_seconds: float


@dataclass(frozen=True, slots=True)
class BenchmarkResult:
    crop: str | None
    votes: int
    sampled_frames: int
    relative_seconds: float | None
    timing: BenchmarkTiming


def benchmark_segment(config: AnalyzerConfig, timeline: bool) -> BenchmarkResult:
    total_started = perf_counter()
    with TemporaryDirectory(prefix="cuda-crop-bench-") as directory:
        segment_path = Path(directory) / "segment.mkv"

        remux_started = perf_counter()
        remux_segment(config.source, segment_path, config.start_seconds, config.duration_seconds)
        remux_seconds = perf_counter() - remux_started

        decoder_started = perf_counter()
        decoder = nvc.SimpleDecoder(
            str(segment_path),
            gpu_id=config.gpu_id,
            use_device_memory=True,
            output_color_type=nvc.OutputColorType.RGB,
        )
        decoder_init_seconds = perf_counter() - decoder_started

        frame_rate = max(1.0, len(decoder) / config.duration_seconds)
        frame_fetch_seconds = 0.0
        gpu_compute_seconds = 0.0
        crops: list[CropBox] = []
        timeline_crops: list[tuple[float, CropBox]] = []

        for index in range(0, len(decoder), config.sample_step):
            frame_started = perf_counter()
            frame = decoder[index]
            frame_fetch_seconds += perf_counter() - frame_started

            compute_started = perf_counter()
            crop = _detect_frame_crop(frame, config.threshold, config.round_to)
            gpu_compute_seconds += perf_counter() - compute_started
            if crop is not None:
                crops.append(crop)
                timeline_crops.append((index / frame_rate, crop))

        vote_started = perf_counter()
        if timeline:
            marker = first_stable_crop(timeline_crops, config.min_votes)
            vote_seconds = perf_counter() - vote_started
            return BenchmarkResult(
                crop=marker.crop.ffmpeg_crop() if marker else None,
                votes=marker.votes if marker else 0,
                sampled_frames=marker.sampled_frames if marker else len(crops),
                relative_seconds=marker.relative_seconds if marker else None,
                timing=BenchmarkTiming(
                    remux_seconds=remux_seconds,
                    decoder_init_seconds=decoder_init_seconds,
                    frame_fetch_seconds=frame_fetch_seconds,
                    gpu_compute_seconds=gpu_compute_seconds,
                    vote_seconds=vote_seconds,
                    total_seconds=perf_counter() - total_started,
                ),
            )

        vote = choose_crop(crops, config.min_votes)
        vote_seconds = perf_counter() - vote_started
        return BenchmarkResult(
            crop=vote.crop.ffmpeg_crop() if vote else None,
            votes=vote.votes if vote else 0,
            sampled_frames=vote.sampled_frames if vote else len(crops),
            relative_seconds=None,
            timing=BenchmarkTiming(
                remux_seconds=remux_seconds,
                decoder_init_seconds=decoder_init_seconds,
                frame_fetch_seconds=frame_fetch_seconds,
                gpu_compute_seconds=gpu_compute_seconds,
                vote_seconds=vote_seconds,
                total_seconds=perf_counter() - total_started,
            ),
        )


def main(
    source: Annotated[Path, typer.Argument(exists=True, file_okay=True, dir_okay=False, readable=True)],
    start: Annotated[float, typer.Option(min=0.0)] = 0.0,
    duration: Annotated[float, typer.Option(min=0.1)] = 10.0,
    threshold: Annotated[float, typer.Option(min=0.0)] = 26.0,
    round_to: Annotated[int, typer.Option(min=1)] = 2,
    sample_step: Annotated[int, typer.Option(min=1)] = 6,
    min_votes: Annotated[int, typer.Option(min=1)] = 3,
    gpu_id: Annotated[int, typer.Option(min=0)] = 0,
    mode: Annotated[BenchmarkMode, typer.Option()] = BenchmarkMode.TIMELINE,
) -> None:
    config = AnalyzerConfig(
        source=source,
        start_seconds=start,
        duration_seconds=duration,
        threshold=threshold,
        round_to=round_to,
        sample_step=sample_step,
        min_votes=min_votes,
        gpu_id=gpu_id,
    )
    match mode:
        case BenchmarkMode.TIMELINE:
            timeline = True
        case BenchmarkMode.VOTE:
            timeline = False
        case unreachable:
            assert_never(unreachable)

    print(dumps(asdict(benchmark_segment(config, timeline)), indent=2))


if __name__ == "__main__":
    typer.run(main)
