Note

Special values can be mixed with api names. eg: `vaapi,auto` will try
and use the `vaapi` hwdec, and if that fails, will run through the
normal `auto` logic.

Actively supported hwdecs:
| d3d11va: | requires `--vo=gpu` or `--vo=gpu-next` with `--gpu-context=d3d11` or
`--gpu-context=angle` (Windows 8+ only) |
| --- | --- |
| d3d11va-copy: | copies video back to system RAM (Windows 8+ only) |
| videotoolbox: | requires `--vo=gpu` or `--vo=gpu-next` (macOS 10.8 and up),
or `--vo=libmpv` (iOS 9.0 and up) |
| videotoolbox-copy: |
|  | copies video back into system RAM (macOS 10.8 or iOS 9.0 and up) |
| vaapi: | requires `--vo=gpu`, `--vo=gpu-next`, `--vo=vaapi` or `--vo=dmabuf-wayland` (Linux only) |
| vaapi-copy: | copies video back into system RAM (Linux with some GPUs or Windows) |
| nvdec: | requires `--vo=gpu` or `--vo=gpu-next` (Any platform CUDA is available) |
| nvdec-copy: | copies video back to system RAM (Any platform CUDA is available) |
| drm: | requires `--vo=gpu` or `--vo=gpu-next` (Linux only) |
| drm-copy: | copies video back to system RAM (Linux only) |
| vulkan: | requires `--vo=gpu-next` (Any platform with Vulkan Video Decoding) |
| vulkan-copy: | copies video back to system RAM (Any platform with Vulkan Video Decoding) |

Other hwdecs (only use if you know you have to):
| dxva2: | requires `--vo=gpu` with `--gpu-context=d3d11`,
`--gpu-context=angle` or `--gpu-context=dxinterop`
(Windows only) |
| --- | --- |
| dxva2-copy: | copies video back to system RAM (Windows only) |
| vdpau: | requires `--vo=gpu` with `--gpu-context=x11`, or
`--vo=vdpau` (Linux only) |
| vdpau-copy: | copies video back into system RAM (Linux with some GPUs only) |
| mediacodec: | requires `--vo=gpu --gpu-context=android`
or `--vo=mediacodec_embed` (Android only) |
| mediacodec-copy: |
|  | copies video back to system RAM (Android only) |
| cuda: | requires `--vo=gpu` (Any platform CUDA is available) |
| cuda-copy: | copies video back to system RAM (Any platform CUDA is available) |
| crystalhd: | copies video back to system RAM (Any platform supported by hardware) |
| rkmpp: | requires `--vo=gpu` (some RockChip devices only) |

`auto` tries to automatically enable hardware decoding using the
first available method, but allows only whitelisted methods that are
considered "safe". This is supposed to be a reasonable way to enable
hardware decoding by default in a config file (even though you shouldn't
do that anyway; prefer runtime enabling with `Ctrl+h`). Unlike
`auto-unsafe`, this will not try to enable unknown or known-to-be-bad
methods. In addition, this may disable hardware decoding in other situations
when it's known to cause problems, but currently this mechanism is quite
primitive. (As an example for something that still causes problems: certain
combinations of HEVC and Intel chips on Windows tend to cause mpv to crash,
most likely due to driver bugs.)

`auto-unsafe` is similar to `auto`, but without the whitelist.
In general, you should never need to use this beyond debugging or
development use. Any known unsafe hwdec you want to test can simply be
appended to the list option such as `--hwdec=auto,unsafe-hwdec`.
This still depends what VO you are using. See the list above, for which
`--vo` and `gpu-context` is required for a given hwdec. It will go down
the list of available hwdecs until one is successfully initialised. If all
of them fail, it will fallback to software decoding.

`auto-copy` selects only modes that copy the video data back to system
memory after decoding. This selects modes like `vaapi-copy` (and so on),
but it only allows whitelisted methods that are considered "safe". If none
of these work, hardware decoding is disabled. This mode is usually guaranteed
to incur no additional quality loss compared to software decoding (assuming
modern codecs and an error free video stream), and will allow CPU processing
with video filters. This mode works with all video filters and VOs.

`auto-copy-safe` is an alias for `auto-copy`

`auto-copy-unsafe` is the same as `auto-copy` except that it goes through
all methods and not just the whitelisted ones that are considered "safe".

Because these copy the decoded video back to system RAM, they're often less
efficient than the direct modes, and may not help too much over software
decoding if you are short on CPU resources.

Note

Most non-copy methods only work with the OpenGL GPU backend. Currently,
only the `vaapi`, `nvdec`, `cuda` and `vulkan` methods work with
Vulkan.

The `vaapi` mode, if used with `--vo=gpu` or `--vo=gpu-next` most
likely works with Intel and AMD GPUs only. It requires the opengl EGL
backend if the GPU does not support drm modifiers.

`nvdec` and `nvdec-copy` are the newest, and recommended method to do
hardware decoding on Nvidia GPUs.

`cuda` and `cuda-copy` are an older implementation of hardware decoding
on Nvidia GPUs that uses Nvidia's bitstream parsers rather than FFmpeg's.
This can lead to feature deficiencies, such as incorrect playback of HDR
content, and `nvdec`/`nvdec-copy` should always be preferred unless you
specifically need Nvidia's deinterlacing algorithms. To use this
deinterlacing you must pass the option:
`vd-lavc-o=deint=[weave|bob|adaptive]`.
Pass `weave` (or leave the option unset) to not attempt any
deinterlacing.

Quality reduction with hardware decoding

In theory, hardware decoding does not reduce video quality (at least
for the codecs h264 and HEVC). However, due to restrictions in video
output APIs, as well as bugs in the actual hardware decoders, there can
be some loss, or even blatantly incorrect results. This has largely
ceased to be a problem with modern hardware, but there is a lot of
hardware out there, so caveat emptor. Known problems are discussed
below, but the list cannot be considered exhaustive, as even hwdecs that
work well on certain hardware generations may be problematic on other
ones.

In some cases, RGB conversion is forced, which means the RGB conversion
is performed by the hardware decoding API, instead of the shaders
used by `--vo=gpu`. This means certain colorspaces may not display
correctly, and certain filtering (such as debanding) cannot be applied
in an ideal way. This will also usually force the use of low quality
chroma scalers instead of the one specified by `--cscale`. In other
cases, hardware decoding can also reduce the bit depth of the decoded
image, which can introduce banding or precision loss for 10-bit files.

`vdpau` always does RGB conversion in hardware, which does not
support newer colorspaces like BT.2020 correctly. However, `vdpau`
doesn't support 10 bit or HDR encodings, so these limitations are
unlikely to be relevant.

`dxva2` is not safe. It appears to always use BT.601 for forced RGB
conversion, but actual behavior depends on the GPU drivers. Some drivers
appear to convert to limited range RGB, which gives a faded appearance.
In addition to driver-specific behavior, global system settings might
affect this additionally. This can give incorrect results even with
completely ordinary video sources.

`mediacodec` is not safe. It forces RGB conversion (not with `-copy`)
and how well it handles non-standard colorspaces is not known.
In the rare cases where 10-bit is supported the bit depth of the output
will be reduced to 8.

`cuda` should usually be safe, but depending on how a file/stream
has been mixed, it has been reported to corrupt the timestamps causing
glitched, flashing frames. It can also sometimes cause massive
framedrops for unknown reasons. Caution is advised, and `nvdec`
should always be preferred.

`crystalhd` is not safe. It always converts to 4:2:2 YUV, which
may be lossy, depending on how chroma sub-sampling is done during
conversion. It also discards the top left pixel of each frame for
some reason.

If you run into any weird decoding issues, frame glitches or
discoloration, and you have `--hwdec` turned on, the first thing you
should try is disabling it.

`--gpu-hwdec-interop=<auto|all|no|name>`

This option is for troubleshooting hwdec interop issues. Since it's a
debugging option, its semantics may change at any time.

This is useful for the `gpu` and `libmpv` VOs for selecting which
hwdec interop context to use exactly. Effectively it also can be used
to block loading of certain backends.

If set to `auto` (default), the behavior depends on the VO: for `gpu`,
it does nothing, and the interop context is loaded on demand (when the
decoder probes for `--hwdec` support). For `libmpv`, which has
has no on-demand loading, this is equivalent to `all`.

The empty string is equivalent to `auto`.

If set to `all`, it attempts to load all interop contexts at GL context
creation time.

Other than that, a specific backend can be set, and the list of them can
be queried with `help` (mpv CLI only).

Runtime changes to this are ignored (the current option value is used
whenever the renderer is created).

`--hwdec-extra-frames=<N>`

Number of GPU frames hardware decoding should preallocate (default: see
`--list-options` output). If this is too low, frame allocation may fail
during decoding, and video frames might get dropped and/or corrupted.
Setting it too high simply wastes GPU memory and has no advantages.

This value is used only for hardware decoding APIs which require
preallocating surfaces (known examples include `d3d11va` and `vaapi`).
For other APIs, frames are allocated as needed. The details depend on the
libavcodec implementations of the hardware decoders.

The required number of surfaces depends on dynamic runtime situations. The
default is a fixed value that is thought to be sufficient for most uses. But
