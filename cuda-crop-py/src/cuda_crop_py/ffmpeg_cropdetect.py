import re
import subprocess
from dataclasses import dataclass
from functools import lru_cache
from time import perf_counter

from cuda_crop_py.detect import crop_from_string, stable_crop_markers
from cuda_crop_py.model import AnalyzerConfig, CropBox, CropMarker
from cuda_crop_py.segment import build_idle_command

CROP_LINE_RE = re.compile(r"\bt:(?P<time>\d+(?:\.\d+)?)\b.*\bcrop=(?P<crop>\d+:\d+:\d+:\d+)")
BIT_DEPTH_RE = re.compile(r"p0?(?P<bits>10|12|14|16)")
CROPDETECT_PREROLL_FRAMES = 2
CROPDETECT_LETTERBOX_HEIGHT_PAD = 2


class CropdetectError(RuntimeError):
    def __init__(self, stderr: str) -> None:
        super().__init__("ffmpeg cropdetect failed")
        self.stderr = stderr


@dataclass(frozen=True, slots=True)
class VideoSignal:
    bit_depth: int
    limited_range: bool


@lru_cache(maxsize=16)
def probe_video_signal(source: str) -> VideoSignal:
    result = subprocess.run(
        [
            "ffprobe",
            "-hide_banner",
            "-loglevel",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=pix_fmt,color_range",
            "-of",
            "csv=p=0",
            source,
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise CropdetectError(result.stderr)

    fields = [field for field in result.stdout.splitlines()[0].split(",") if field]
    pix_fmt = fields[0]
    color_range = fields[1] if len(fields) > 1 else "tv"
    bit_depth_match = BIT_DEPTH_RE.search(pix_fmt)
    bit_depth = int(bit_depth_match.group("bits")) if bit_depth_match else 8
    return VideoSignal(bit_depth=bit_depth, limited_range=color_range == "tv")


def cropdetect_limit(config: AnalyzerConfig, signal: VideoSignal) -> float:
    if signal.limited_range:
        return float(16 * (1 << max(0, signal.bit_depth - 8)))
    return config.threshold


def hwdownload_format(signal: VideoSignal) -> str:
    return "p010le" if signal.bit_depth > 8 else "nv12"


def build_cropdetect_command(config: AnalyzerConfig, signal: VideoSignal) -> list[str]:
    limit = cropdetect_limit(config, signal)
    filters = (
        f"hwdownload,format={hwdownload_format(signal)},"
        f"cropdetect=limit={limit:g}:round={config.round_to}:skip={CROPDETECT_PREROLL_FRAMES}:reset=1"
    )
    command = [
        "ffmpeg",
        "-hide_banner",
        "-nostdin",
        "-loglevel",
        "info",
        "-hwaccel",
        "cuda",
        "-hwaccel_output_format",
        "cuda",
        "-ss",
        f"{config.start_seconds:.3f}",
        "-t",
        f"{config.duration_seconds:.3f}",
        "-i",
        str(config.source),
        "-map",
        "0:v:0",
        "-an",
        "-sn",
        "-dn",
        "-vf",
        filters,
        "-f",
        "null",
        "-",
    ]
    return build_idle_command(command)


def crop_samples(stderr: str, sample_step: int) -> list[tuple[float, CropBox]]:
    samples: list[tuple[float, CropBox]] = []
    for frame_index, match in enumerate(CROP_LINE_RE.finditer(stderr)):
        if frame_index % sample_step != 0:
            continue
        crop = crop_from_string(match.group("crop"))
        if crop.x == 0 and crop.y > 0:
            crop = CropBox(
                width=crop.width,
                height=crop.height + CROPDETECT_LETTERBOX_HEIGHT_PAD,
                x=crop.x,
                y=crop.y,
            )
        samples.append((float(match.group("time")), crop))
    return samples


def analyze_timeline_events(config: AnalyzerConfig) -> list[CropMarker]:
    started = perf_counter()
    signal = probe_video_signal(str(config.source))
    result = subprocess.run(
        build_cropdetect_command(config, signal),
        check=False,
        capture_output=True,
        text=True,
    )
    analyze_seconds = perf_counter() - started
    if result.returncode != 0:
        raise CropdetectError(result.stderr)

    return [
        CropMarker(
            crop=marker.crop,
            relative_seconds=marker.relative_seconds,
            votes=marker.votes,
            sampled_frames=marker.sampled_frames,
            remux_seconds=0.0,
            analyze_seconds=analyze_seconds,
        )
        for marker in stable_crop_markers(
            crop_samples(result.stderr, config.sample_step),
            config.min_votes,
            config.current_crop,
        )
    ]
