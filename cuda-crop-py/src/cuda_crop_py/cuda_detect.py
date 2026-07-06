from collections.abc import Iterator
from pathlib import Path
from tempfile import TemporaryDirectory
from time import perf_counter
from typing import Protocol, TypedDict

import cupy as cp
import PyNvVideoCodec as nvc

from cuda_crop_py.detect import (
    ActiveBounds,
    active_bounds,
    active_row_bounds,
    choose_crop,
    crop_from_bounds,
    first_stable_crop,
    stable_crop_markers,
)
from cuda_crop_py.ffmpeg_cropdetect import (
    CropdetectError,
)
from cuda_crop_py.ffmpeg_cropdetect import (
    analyze_timeline_events as analyze_cropdetect_timeline_events,
)
from cuda_crop_py.model import AnalyzerConfig, CropBox, CropMarker, CropVote
from cuda_crop_py.segment import remux_segment

REMUX_TIMESTAMP_CORRECTION_FRAMES = 2


class CudaArrayInterface(TypedDict):
    shape: list[int]
    strides: list[int]
    data: tuple[int, bool]


class CudaMemoryView(Protocol):
    @property
    def __cuda_array_interface__(self) -> CudaArrayInterface: ...


class DecodedRgbFrame(Protocol):
    def cuda(self) -> list[CudaMemoryView]: ...


def _cupy_rgb_frame(frame: DecodedRgbFrame) -> cp.ndarray:
    view = frame.cuda()[0]
    cai = view.__cuda_array_interface__
    shape = tuple(cai["shape"])
    strides = tuple(cai["strides"])
    pointer = int(cai["data"][0])
    size = shape[0] * strides[0]
    memory = cp.cuda.UnownedMemory(pointer, size, view)
    memory_pointer = cp.cuda.MemoryPointer(memory, 0)
    return cp.ndarray(shape=shape, dtype=cp.uint8, memptr=memory_pointer, strides=strides)


def _detect_frame_crop(frame: DecodedRgbFrame, threshold: float, round_to: int) -> CropBox | None:
    rgb = _cupy_rgb_frame(frame)
    luma = (
        rgb[:, :, 0].astype(cp.float32) * 0.2126
        + rgb[:, :, 1].astype(cp.float32) * 0.7152
        + rgb[:, :, 2].astype(cp.float32) * 0.0722
    )
    row_mean = cp.mean(luma, axis=1)
    col_mean = cp.mean(luma, axis=0)
    active_pixels = luma > threshold
    row_active_fraction = cp.mean(active_pixels, axis=1)
    col_active_fraction = cp.mean(active_pixels, axis=0)
    row_bounds = active_row_bounds(row_mean.get().tolist(), row_active_fraction.get().tolist(), threshold)
    col_bounds = active_bounds(col_mean.get().tolist(), col_active_fraction.get().tolist(), threshold)
    if row_bounds is None or col_bounds is None:
        return None
    top, bottom = row_bounds
    left, right = col_bounds
    width = int(rgb.shape[1])
    height = int(rgb.shape[0])
    return crop_from_bounds(
        source_width=width,
        source_height=height,
        bounds=ActiveBounds(left=left, right=right, top=top, bottom=bottom),
        round_to=round_to,
    )


def analyze_segment(segment_path: Path, config: AnalyzerConfig, remux_seconds: float) -> CropVote | None:
    started = perf_counter()
    decoder = nvc.SimpleDecoder(
        str(segment_path),
        gpu_id=config.gpu_id,
        use_device_memory=True,
        output_color_type=nvc.OutputColorType.RGB,
    )
    crops: list[CropBox] = []
    for index in range(0, len(decoder), config.sample_step):
        crop = _detect_frame_crop(decoder[index], config.threshold, config.round_to)
        if crop is not None:
            crops.append(crop)
    return choose_crop(crops, config.min_votes, remux_seconds, perf_counter() - started)


def analyze_timeline_segment(
    segment_path: Path,
    config: AnalyzerConfig,
    remux_seconds: float,
    segment_start_seconds: float | None = None,
    frame_duration_seconds: float | None = None,
) -> CropMarker | None:
    started = perf_counter()
    decoder = nvc.SimpleDecoder(
        str(segment_path),
        gpu_id=config.gpu_id,
        use_device_memory=True,
        output_color_type=nvc.OutputColorType.RGB,
    )
    frame_duration = frame_duration_seconds or (config.duration_seconds / max(1, len(decoder)))
    first_frame_seconds = segment_start_seconds or config.start_seconds
    if segment_start_seconds is not None:
        first_frame_seconds += REMUX_TIMESTAMP_CORRECTION_FRAMES * frame_duration

    def crop_samples() -> Iterator[tuple[float, CropBox]]:
        for index in range(0, len(decoder), config.sample_step):
            absolute_seconds = first_frame_seconds + (index * frame_duration)
            if absolute_seconds < config.start_seconds:
                continue
            crop = _detect_frame_crop(decoder[index], config.threshold, config.round_to)
            if crop is not None:
                yield absolute_seconds - config.start_seconds, crop

    marker = first_stable_crop(crop_samples(), config.min_votes, config.current_crop, remux_seconds)
    if marker is None:
        return None
    return CropMarker(
        crop=marker.crop,
        relative_seconds=marker.relative_seconds,
        votes=marker.votes,
        sampled_frames=marker.sampled_frames,
        remux_seconds=marker.remux_seconds,
        analyze_seconds=perf_counter() - started,
    )


def analyze_timeline_segment_events(
    segment_path: Path,
    config: AnalyzerConfig,
    remux_seconds: float,
    segment_start_seconds: float | None = None,
    frame_duration_seconds: float | None = None,
) -> list[CropMarker]:
    started = perf_counter()
    decoder = nvc.SimpleDecoder(
        str(segment_path),
        gpu_id=config.gpu_id,
        use_device_memory=True,
        output_color_type=nvc.OutputColorType.RGB,
    )
    frame_duration = frame_duration_seconds or (config.duration_seconds / max(1, len(decoder)))
    first_frame_seconds = segment_start_seconds or config.start_seconds
    if segment_start_seconds is not None:
        first_frame_seconds += REMUX_TIMESTAMP_CORRECTION_FRAMES * frame_duration

    def crop_samples() -> Iterator[tuple[float, CropBox]]:
        for index in range(0, len(decoder), config.sample_step):
            absolute_seconds = first_frame_seconds + (index * frame_duration)
            if absolute_seconds < config.start_seconds:
                continue
            crop = _detect_frame_crop(decoder[index], config.threshold, config.round_to)
            if crop is not None:
                yield absolute_seconds - config.start_seconds, crop

    markers = stable_crop_markers(crop_samples(), config.min_votes, config.current_crop, remux_seconds)
    analyze_seconds = perf_counter() - started
    return [
        CropMarker(
            crop=marker.crop,
            relative_seconds=marker.relative_seconds,
            votes=marker.votes,
            sampled_frames=marker.sampled_frames,
            remux_seconds=marker.remux_seconds,
            analyze_seconds=analyze_seconds,
        )
        for marker in markers
    ]


def analyze_source(config: AnalyzerConfig) -> CropVote | None:
    with TemporaryDirectory(prefix="cuda-crop-py-") as directory:
        segment_path = Path(directory) / "segment.mkv"
        started = perf_counter()
        remux_segment(config.source, segment_path, config.start_seconds, config.duration_seconds)
        return analyze_segment(segment_path, config, perf_counter() - started)


def analyze_timeline(config: AnalyzerConfig) -> CropMarker | None:
    markers = analyze_timeline_events(config)
    return markers[0] if markers else None


def analyze_timeline_events(config: AnalyzerConfig) -> list[CropMarker]:
    try:
        return analyze_cropdetect_timeline_events(config)
    except CropdetectError:
        pass

    with TemporaryDirectory(prefix="cuda-crop-py-") as directory:
        segment_path = Path(directory) / "segment.mkv"
        started = perf_counter()
        segment = remux_segment(config.source, segment_path, config.start_seconds, config.duration_seconds)
        return analyze_timeline_segment_events(
            segment_path,
            config,
            perf_counter() - started,
            segment.start_seconds,
            segment.frame_duration_seconds,
        )
