# Interpolation

Interpolation is a feature by which mpv creates new video frames to make motion appear smoother. It does this by blending two adjacent frames together. This is similar to the "smooth motion" features on TVs or in madVR.

Interpolation can be enabled with the `--interpolation` option, or by pressing `Alt+I` (bound to `cycle interpolation` by default). You can further customize the interpolation with the following options:

- `--interpolation-threshold`
- `--interpolation-parameter`
- `--tscale=oversample` for blur

You can also use `--tscale=mitchell` as a good starting point.

## Interpolation with `vo_gpu-next`

Interpolation in `vo_gpu-next` is slightly different:

- `--interpolation` is currently incompatible with `--vo=gpu-next` on some hardware/driver combinations.
- `--video-sync=display-resample` is currently required for interpolation in `gpu-next`.

## Notes

- Getting actual 30fps content on a 60Hz screen to play smoothly without judder is actually very easy with `interpolation` and an `mphase`/`mitchell` tscale.
- While interpolation can remove judder, it may also cause artifacts, in particular on low refresh rate displays.
- There are other alternatives: [[wiki-option-replacement-list]] discusses `--video-sync`.

![Comparisons](interpolation/)

The images under `interpolation/` show what's happening under the hood when interpolation is enabled and disabled for various refresh rates.
