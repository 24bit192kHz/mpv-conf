from collections import Counter
from collections.abc import Iterable
from dataclasses import dataclass

from cuda_crop_py.model import CropBox, CropMarker, CropVote

MIN_ACTIVE_ROW_FRACTION = 0.003
EQUIVALENT_CROP_SIZE_TOLERANCE = 8
EQUIVALENT_CROP_OFFSET_TOLERANCE = 4
TRANSIENT_REVERT_MAX_SECONDS = 0.24


@dataclass(frozen=True, slots=True)
class ActiveBounds:
    left: int
    right: int
    top: int
    bottom: int


def round_down(value: int, unit: int) -> int:
    return value if unit <= 1 else value - (value % unit)


def active_bounds(
    values: Iterable[float],
    active_fractions: Iterable[float],
    threshold: float,
    min_active_fraction: float = MIN_ACTIVE_ROW_FRACTION,
) -> tuple[int, int] | None:
    active_indexes = [
        index
        for index, (value, active_fraction) in enumerate(zip(values, active_fractions, strict=True))
        if value > threshold or active_fraction >= min_active_fraction
    ]
    if not active_indexes:
        return None
    return active_indexes[0], active_indexes[-1]


def active_row_bounds(
    row_means: Iterable[float],
    active_fractions: Iterable[float],
    threshold: float,
    min_active_fraction: float = MIN_ACTIVE_ROW_FRACTION,
) -> tuple[int, int] | None:
    return active_bounds(row_means, active_fractions, threshold, min_active_fraction)


def crop_from_bounds(source_width: int, source_height: int, bounds: ActiveBounds, round_to: int) -> CropBox:
    crop_width = max(0, bounds.right - bounds.left + 1)
    rounded_width = round_down(crop_width, round_to)
    rounded_left = round_down(bounds.left + max(0, crop_width - rounded_width) // 2, round_to)

    crop_height = max(0, bounds.bottom - bounds.top + 1)
    rounded_height = round_down(crop_height, round_to)
    rounded_top = round_down(bounds.top + max(0, crop_height - rounded_height) // 2, round_to)

    return CropBox(
        width=min(rounded_width, round_down(source_width, round_to)),
        height=min(rounded_height, round_down(source_height, round_to)),
        x=rounded_left,
        y=rounded_top,
    )


def crop_from_string(value: str) -> CropBox:
    width, height, x, y = value.split(":", maxsplit=3)
    return CropBox(width=int(width), height=int(height), x=int(x), y=int(y))


def equivalent_crop(left: CropBox | None, right: CropBox | None) -> bool:
    if left == right:
        return True
    if left is None or right is None:
        return False
    return (
        abs(left.width - right.width) <= EQUIVALENT_CROP_SIZE_TOLERANCE
        and abs(left.height - right.height) <= EQUIVALENT_CROP_SIZE_TOLERANCE
        and abs(left.x - right.x) <= EQUIVALENT_CROP_OFFSET_TOLERANCE
        and abs(left.y - right.y) <= EQUIVALENT_CROP_OFFSET_TOLERANCE
    )


def choose_crop(
    crops: Iterable[CropBox],
    min_votes: int,
    remux_seconds: float = 0.0,
    analyze_seconds: float = 0.0,
) -> CropVote | None:
    counter = Counter(crops)
    if not counter:
        return None

    crop, votes = counter.most_common(1)[0]
    sampled_frames = counter.total()
    if votes < min_votes:
        return None
    return CropVote(
        crop=crop,
        votes=votes,
        sampled_frames=sampled_frames,
        remux_seconds=remux_seconds,
        analyze_seconds=analyze_seconds,
    )


def suppress_transient_reverts(markers: list[CropMarker], current_crop: CropBox | None) -> list[CropMarker]:
    filtered: list[CropMarker] = []
    previous_crop = current_crop
    index = 0
    while index < len(markers):
        current = markers[index]
        following = markers[index + 1] if index + 1 < len(markers) else None
        if (
            following is not None
            and equivalent_crop(following.crop, previous_crop)
            and following.relative_seconds - current.relative_seconds < TRANSIENT_REVERT_MAX_SECONDS
        ):
            index += 2
            continue

        filtered.append(current)
        previous_crop = current.crop
        index += 1
    return filtered


def first_stable_crop(
    samples: Iterable[tuple[float, CropBox]],
    min_votes: int,
    current_crop: CropBox | None = None,
    remux_seconds: float = 0.0,
    analyze_seconds: float = 0.0,
) -> CropMarker | None:
    run_crop: CropBox | None = None
    run_start = 0.0
    run_votes = 0

    for sampled_frames, (relative_seconds, crop) in enumerate(samples, start=1):
        if equivalent_crop(crop, run_crop):
            run_votes += 1
        else:
            run_crop = crop
            run_start = relative_seconds
            run_votes = 1

        if run_votes >= min_votes and not equivalent_crop(crop, current_crop):
            return CropMarker(
                crop=crop,
                relative_seconds=run_start,
                votes=run_votes,
                sampled_frames=sampled_frames,
                remux_seconds=remux_seconds,
                analyze_seconds=analyze_seconds,
            )

    return None


def stable_crop_markers(
    samples: Iterable[tuple[float, CropBox]],
    min_votes: int,
    current_crop: CropBox | None = None,
    remux_seconds: float = 0.0,
    analyze_seconds: float = 0.0,
) -> list[CropMarker]:
    markers: list[CropMarker] = []
    run_crop: CropBox | None = None
    run_start = 0.0
    run_votes = 0
    emitted_crop = current_crop

    for sampled_frames, (relative_seconds, crop) in enumerate(samples, start=1):
        if equivalent_crop(crop, run_crop):
            run_votes += 1
        else:
            run_crop = crop
            run_start = relative_seconds
            run_votes = 1

        if run_votes >= min_votes and not equivalent_crop(crop, emitted_crop):
            markers.append(
                CropMarker(
                    crop=crop,
                    relative_seconds=run_start,
                    votes=run_votes,
                    sampled_frames=sampled_frames,
                    remux_seconds=remux_seconds,
                    analyze_seconds=analyze_seconds,
                ),
            )
            emitted_crop = crop

    return suppress_transient_reverts(markers, current_crop)
