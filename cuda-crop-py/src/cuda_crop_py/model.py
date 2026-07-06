from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import TypedDict


class DetectorBackend(StrEnum):
    CUDA = "cuda"
    CPU = "cpu"


@dataclass(frozen=True, slots=True)
class CropBox:
    width: int
    height: int
    x: int
    y: int

    def mpv_filter(self) -> str:
        return f"w={self.width}:h={self.height}:x={self.x}:y={self.y}"

    def ffmpeg_crop(self) -> str:
        return f"{self.width}:{self.height}:{self.x}:{self.y}"


@dataclass(frozen=True, slots=True)
class AnalyzerConfig:
    source: Path
    start_seconds: float
    duration_seconds: float
    threshold: float
    round_to: int
    sample_step: int
    min_votes: int
    gpu_id: int
    current_crop: CropBox | None = None
    detector_backend: DetectorBackend = DetectorBackend.CUDA


@dataclass(frozen=True, slots=True)
class CropVote:
    crop: CropBox
    votes: int
    sampled_frames: int
    remux_seconds: float
    analyze_seconds: float


@dataclass(frozen=True, slots=True)
class CropMarker:
    crop: CropBox
    relative_seconds: float
    votes: int
    sampled_frames: int
    remux_seconds: float
    analyze_seconds: float


class CropResponse(TypedDict):
    detector_version: str
    crop: str
    mpv_filter: str
    votes: int
    sampled_frames: int
    remux_seconds: float | None
    analyze_seconds: float | None


class TimelineResponse(CropResponse):
    relative_seconds: float


class TimelineEventsResponse(TimelineResponse):
    events: list[TimelineResponse]
