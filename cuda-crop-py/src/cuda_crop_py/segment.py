import subprocess
from dataclasses import dataclass
from pathlib import Path
from shutil import which


class SegmentError(RuntimeError):
    def __init__(self, stderr: str) -> None:
        super().__init__("ffmpeg segment remux failed")
        self.stderr = stderr

    @classmethod
    def missing_timestamp(cls) -> "SegmentError":
        return cls("missing frame timestamp")


@dataclass(frozen=True, slots=True)
class SegmentInfo:
    start_seconds: float
    frame_duration_seconds: float


def remux_segment(source: Path, target: Path, start_seconds: float, duration_seconds: float) -> SegmentInfo:
    result = subprocess.run(
        build_remux_command(source, target, start_seconds, duration_seconds),
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SegmentError(result.stderr)
    return SegmentInfo(
        start_seconds=probe_segment_start_seconds(target),
        frame_duration_seconds=probe_segment_frame_duration_seconds(target),
    )


def build_remux_command(
    source: Path,
    target: Path,
    start_seconds: float,
    duration_seconds: float,
) -> list[str]:
    command = [
        "ffmpeg",
        "-hide_banner",
        "-y",
        "-ss",
        f"{start_seconds:.3f}",
        "-copyts",
        "-avoid_negative_ts",
        "disabled",
        "-t",
        f"{duration_seconds:.3f}",
        "-i",
        str(source),
        "-map",
        "0:v:0",
        "-c",
        "copy",
        str(target),
    ]
    return build_idle_command(command)


def build_idle_command(command: list[str]) -> list[str]:
    if which("chrt"):
        command = ["chrt", "-i", "0", *command]
    if which("nice"):
        command = ["nice", "-n", "19", *command]
    if which("ionice"):
        command = ["ionice", "-c", "3", *command]
    return command


def probe_segment_start_seconds(segment_path: Path) -> float:
    result = subprocess.run(
        [
            "ffprobe",
            "-hide_banner",
            "-loglevel",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "frame=best_effort_timestamp_time",
            "-of",
            "csv=p=0",
            "-read_intervals",
            "%+#1",
            str(segment_path),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SegmentError(result.stderr)
    lines = result.stdout.splitlines()
    if not lines:
        raise SegmentError.missing_timestamp()
    first_line = lines[0]
    return float(first_line.split(",", maxsplit=1)[0])


def probe_segment_frame_duration_seconds(segment_path: Path) -> float:
    result = subprocess.run(
        [
            "ffprobe",
            "-hide_banner",
            "-loglevel",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=avg_frame_rate,r_frame_rate",
            "-of",
            "csv=p=0",
            str(segment_path),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SegmentError(result.stderr)
    line = result.stdout.splitlines()[0]
    rate = line.split(",", maxsplit=1)[0]
    numerator, denominator = rate.split("/", maxsplit=1)
    return int(denominator) / int(numerator)
