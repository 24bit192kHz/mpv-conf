from cuda_crop_py.detect import ActiveBounds, active_bounds, crop_from_bounds
from cuda_crop_py.model import CropBox


def test_active_bounds_when_centered_box_has_black_sides() -> None:
    values = [0.0, 0.0, 10.0, 10.0, 10.0, 0.0]
    active_fractions = [0.0, 0.0, 0.8, 0.8, 0.8, 0.0]

    assert active_bounds(values, active_fractions, threshold=2.0) == (2, 4)


def test_crop_from_bounds_when_active_box_is_centered() -> None:
    bounds = ActiveBounds(left=135, right=1784, top=186, bottom=893)

    crop = crop_from_bounds(source_width=1920, source_height=1080, bounds=bounds, round_to=2)

    assert crop == CropBox(width=1650, height=708, x=134, y=186)
