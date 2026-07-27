# gpu-next vs gpu

mpv has two video output drivers based on the GPU: `vo=gpu` and `vo=gpu-next`. This article describes the difference.

## What is vo_gpu

`vo_gpu` is the original GPU video output. It uses OpenGL (or Vulkan via the `--gpu-api=vulkan` option). It uses the `gpu/` directory in the source tree. It is well tested and stable, but has issues with some uses.

`vo_gpu` also supports `--vo=gpu` with the `--gpu-context` option (e.g. for use with `--vo=gpu --gpu-context=drm`).

## What is vo_gpu-next

`vo_gpu-next` is a rewrite of the GPU video output driver, based on libplacebo. It provides more features and better correctness, at the cost of potentially higher performance requirements. It can also use OpenGL or Vulkan.

It lives in the `gpu-next/` directory and is what upstream is currently focusing development on.

`vo_gpu-next` currently provides the following features not available in `vo_gpu`:

- Support for `--hdr-peak-percentile` and better HDR metadata handling.
- Support for Dolby Vision through libplacebo.
- Improved HDR to SDR conversion via color mapping.
- Support for `--target-contrast` and `--target-peak`.
- Support for `--hdr-computation-*` options.
- Better pass-through and rendering of HDR10+ dynamic metadata.
- Own the full video frame to better handle display resolution and hardware decoding.
- Support for nvdec and vulkan based hardware decoding.
- Correct debanding.
- Better vavpp and vf_vavpp support with vaapi hardware decoding.
- Support for `--gpu-context=drm` (via `--vo=gpu-next`).
- Improved performance in some cases.

## Limitations

`vo_gpu-next` does not support `--glsl-shaders` and user shaders that use shader hooks. The current version also does not support `--opengl-pbo`. It also does not blend with overlays correctly. See [issue #13085](https://github.com/mpv-player/mpv/issues/13085) and [issue #14273](https://github.com/mpv-player/mpv/issues/14273).

Some users report performance issues, frame drops with `gpu-next` especially with `--interpolation` (e.g. on AMD GPUs). The current recommendation is to test both VOs for your specific setup and decide accordingly. See [issue #12204](https://github.com/mpv-player/mpv/issues/12204).

## Recommendation

For new users, we currently recommend starting with `vo=gpu`. If you don't experience any problems with `vo=gpu-next`, feel free to use it. Once `vo=gpu-next` has matured enough, it will eventually replace `vo=gpu`.

## Background

`vo_gpu` was originally based on mplayer2 and had some issues with its architecture. In particular, OpenGL was the central component with vulkan added as an extension. In 2019, development on libplacebo was started, which eventually became the foundation for `gpu-next`, beginning with the rewrite in 2020. As of 2023, libplacebo is still maintained separately but mpv's `gpu-next/` includes it via source. So while `gpu-next` is based on libplacebo, a single build of mpv includes everything it needs.
