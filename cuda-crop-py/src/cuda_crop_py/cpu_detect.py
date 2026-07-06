import subprocess
from collections.abc import Iterator
from dataclasses import dataclass
from fractions import Fraction
from math import ceil, floor
from pathlib import Path
from time import perf_counter

import numpy as np

from cuda_crop_py.detect import (
    ActiveBounds,
    active_bounds,
    active_row_bounds,
    crop_from_bounds,
    equivalent_crop,
)
from cuda_crop_py.model import AnalyzerConfig, CropBox, CropMarker
from cuda_crop_py.segment import build_idle_command

CPU_DETECT_SCALE = 4


class CpuDetectError(RuntimeError):
    def __init__(self, message: str) -> None:
        super().__init__(message)


@dataclass(frozen=True, slots=True)
class VideoStreamInfo:
    width: int
    height: int
    scaled_width: int
    scaled_height: int
    frame_duration_seconds: float


def _rate_duration(rate: str) -> float:
    fraction = Fraction(rate)
    if fraction.numerator <= 0:
        msg = f"invalid frame rate: {rate}"
        raise CpuDetectError(msg)
    return float(fraction.denominator / fraction.numerator)


def _probe_video_stream(source: Path) -> VideoStreamInfo:
    result = subprocess.run(
        [
            "ffprobe",
            "-hide_banner",
            "-loglevel",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height,avg_frame_rate,r_frame_rate",
            "-of",
            "csv=p=0",
            str(source),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise CpuDetectError(result.stderr)

    width, height, average_rate, fallback_rate = result.stdout.splitlines()[0].split(",", maxsplit=3)
    rate = average_rate if average_rate != "0/0" else fallback_rate
    return VideoStreamInfo(
        width=int(width),
        height=int(height),
        scaled_width=max(1, int(width) // CPU_DETECT_SCALE),
        scaled_height=max(1, int(height) // CPU_DETECT_SCALE),
        frame_duration_seconds=_rate_duration(rate),
    )


def _rawvideo_command(source: Path, config: AnalyzerConfig, info: VideoStreamInfo) -> list[str]:
    command = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-threads",
        "1",
        "-ss",
        f"{config.start_seconds:.3f}",
        "-t",
        f"{config.duration_seconds:.3f}",
        "-i",
        str(source),
        "-map",
        "0:v:0",
        "-an",
        "-sn",
        "-dn",
        "-vf",
        f"scale={info.scaled_width}:{info.scaled_height}:flags=fast_bilinear,format=gray",
        "-pix_fmt",
        "gray",
        "-f",
        "rawvideo",
        "pipe:1",
    ]
    return build_idle_command(command)


def _gray_frames(
    source: Path,
    config: AnalyzerConfig,
    info: VideoStreamInfo,
) -> Iterator[tuple[int, np.ndarray]]:
    frame_size = info.scaled_width * info.scaled_height
    process = subprocess.Popen(
        _rawvideo_command(source, config, info),
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if process.stdout is None:
        msg = "ffmpeg stdout pipe is unavailable"
        raise CpuDetectError(msg)

    index = 0
    completed = False
    try:
        while True:
            data = process.stdout.read(frame_size)
            if not data:
                completed = True
                break
            if len(data) != frame_size:
                msg = "ffmpeg returned a partial video frame"
                raise CpuDetectError(msg)
            if index % config.sample_step == 0:
                frame = np.frombuffer(data, dtype=np.uint8).reshape((info.scaled_height, info.scaled_width))
                yield index, frame
            index += 1
    finally:
        process.stdout.close()
        if not completed and process.poll() is None:
            process.terminate()
        returncode = process.wait()

    if completed and returncode != 0:
        msg = f"ffmpeg rawvideo decode failed with status {returncode}"
        raise CpuDetectError(msg)


def _source_bounds(bounds: ActiveBounds, frame: np.ndarray, info: VideoStreamInfo) -> ActiveBounds:
    scale_x = info.width / frame.shape[1]
    scale_y = info.height / frame.shape[0]
    return ActiveBounds(
        left=max(0, floor(bounds.left * scale_x)),
        right=min(info.width - 1, ceil((bounds.right + 1) * scale_x) - 1),
        top=max(0, floor(bounds.top * scale_y)),
        bottom=min(info.height - 1, ceil((bounds.bottom + 1) * scale_y) - 1),
    )


def _detect_luma_crop(
    frame: np.ndarray,
    threshold: float,
    round_to: int,
    info: VideoStreamInfo | None = None,
) -> CropBox | None:
    luma = frame.astype(np.float32, copy=False)
    row_mean = np.mean(luma, axis=1)
    col_mean = np.mean(luma, axis=0)
    active_pixels = luma > threshold
    row_active_fraction = np.mean(active_pixels, axis=1)
    col_active_fraction = np.mean(active_pixels, axis=0)
    row_bounds = active_row_bounds(row_mean.tolist(), row_active_fraction.tolist(), threshold)
    col_bounds = active_bounds(col_mean.tolist(), col_active_fraction.tolist(), threshold)
    if row_bounds is None or col_bounds is None:
        return None
    top, bottom = row_bounds
    left, right = col_bounds
    source_width = int(frame.shape[1])
    source_height = int(frame.shape[0])
    bounds = ActiveBounds(left=left, right=right, top=top, bottom=bottom)
    if info is not None:
        source_width = info.width
        source_height = info.height
        bounds = _source_bounds(bounds, frame, info)
    return crop_from_bounds(
        source_width=source_width,
        source_height=source_height,
        bounds=bounds,
        round_to=round_to,
    )


def _crop_samples(config: AnalyzerConfig) -> Iterator[tuple[float, CropBox]]:
    info = _probe_video_stream(config.source)
    for index, frame in _gray_frames(config.source, config, info):
        crop = _detect_luma_crop(frame, config.threshold, config.round_to, info)
        if crop is not None:
            yield index * info.frame_duration_seconds, crop


def _first_stable_change(config: AnalyzerConfig) -> CropMarker | None:
    run_crop: CropBox | None = None
    run_start = 0.0
    run_votes = 0

    for sampled_frames, (relative_seconds, crop) in enumerate(_crop_samples(config), start=1):
        if equivalent_crop(crop, run_crop):
            run_votes += 1
        else:
            run_crop = crop
            run_start = relative_seconds
            run_votes = 1

        if run_votes < config.min_votes:
            continue
        if equivalent_crop(crop, config.current_crop):
            return None
        return CropMarker(
            crop=crop,
            relative_seconds=run_start,
            votes=run_votes,
            sampled_frames=sampled_frames,
            remux_seconds=0.0,
            analyze_seconds=0.0,
        )

    return None


def analyze_timeline_events(config: AnalyzerConfig) -> list[CropMarker]:
    started = perf_counter()
    marker = _first_stable_change(config)
    analyze_seconds = perf_counter() - started
    if marker is None:
        return []
    return [
        CropMarker(
            crop=marker.crop,
            relative_seconds=marker.relative_seconds,
            votes=marker.votes,
            sampled_frames=marker.sampled_frames,
            remux_seconds=0.0,
            analyze_seconds=analyze_seconds,
        ),
    ]
