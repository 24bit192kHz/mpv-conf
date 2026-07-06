import numpy as np

from cuda_crop_py.cpu_detect import _detect_luma_crop
from cuda_crop_py.model import CropBox


def test_detect_luma_crop_detects_letterbox_bounds() -> None:
    frame = np.zeros((10, 20), dtype=np.uint8)
    frame[2:8, :] = 255

    crop = _detect_luma_crop(frame, threshold=2.0, round_to=2)

    assert crop == CropBox(width=20, height=6, x=0, y=2)
