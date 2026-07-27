As of [`c172a65`](https://github.com/mpv-player/mpv/commit/c172a650c41a28d77d14de4af398cfd90caaa805), the default downsampling kernel in mpv has been changed to `--dscale=hermite` to match libplacebo's defaults.

The rationale behind this change is explained in this talk from VDD 2023:

**WATCH**: [Faster (and better) GPU (down)scaling in libplacebo by Niklas Haas (haasn)](https://youtu.be/y1YeL-MP_Aw?t=7017)

![hermite is love](https://github.com/mpv-player/mpv/assets/139610756/573abbab-f4b6-4222-8c61-2954aa314772)
