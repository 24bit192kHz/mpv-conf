WebP compression factor (default: 4)

`--vo-image-outdir=<dirname>`

Specify the directory to save the image files to (default: `./`).

`libmpv`

For use with libmpv direct embedding. As a special case, on macOS it
is used like a normal VO within mpv (cocoa-cb). Otherwise useless in any
other contexts.
(See `<mpv/render.h>`.)

This also supports many of the options the `gpu` VO has, depending on the
backend.

`drm` (Direct Rendering Manager)

Video output driver using Kernel Mode Setting / Direct Rendering Manager.
Should be used when one doesn't want to install full-blown graphical
environment (e.g. no X). Does not support hardware acceleration (if you
need this, check the `drm` backend for `gpu` VO).

Since mpv 0.30.0, you may need to use `--profile=sw-fast` to get decent
performance.

The following global options are supported by this video output:

`--drm-connector=<name>`

Select the connector to use (usually this is a monitor.) If `<name>`
is empty or `auto`, mpv renders the output on the first available
connector. Use `--drm-connector=help` to get a list of available
connectors. (default: empty)

`--drm-device=

`

Select the DRM device file to use. If specified this overrides automatic
card selection. (default: empty)

`--drm-mode=

`

Mode to use (resolution and frame rate).
Possible values:
| preferred: | Use the preferred mode for the screen on the selected
connector. (default) |
| --- | --- |
| highest: | Use the mode with the highest resolution available on the
selected connector. |
| N: | Select mode by index. |
| WxH[@R]: | Specify mode by width, height, and optionally refresh rate.
In case several modes match, selects the mode that comes
first in the EDID list of modes. |

Use `--drm-mode=help` to get a list of available modes for all active
connectors.

`--drm-draw-plane=

`

Select the DRM plane to which video and OSD is drawn to, under normal
circumstances. The plane can be specified as `primary`, which will
pick the first applicable primary plane; `overlay`, which will pick
the first applicable overlay plane; or by index. The index is zero
based, and related to the CRTC.
(default: primary)

When using this option with the drmprime-overlay hwdec interop, only the
OSD is rendered to this plane.

`--drm-drmprime-video-plane=

`

Select the DRM plane to use for video with the drmprime-overlay hwdec
interop (used by e.g. the rkmpp hwdec on RockChip SoCs, and v4l2 hwdec:s
on various other SoC:s). The plane is unused otherwise. This option
accepts the same values as `--drm-draw-plane`. (default: overlay)

To be able to successfully play 4K video on various SoCs you might need
to set `--drm-draw-plane=overlay --drm-drmprime-video-plane=primary`
and setting `--drm-draw-surface-size=1920x1080`, to render the OSD at a
lower resolution (the video when handled by the hwdec will be on the
drmprime-video plane and at full 4K resolution)

`--drm-format=<xrgb8888|xbgr8888|xrgb2101010|xbgr2101010|yuyv>`

Select the DRM format to use (default: xrgb8888). This allows you to
choose the bit depth and color type of the DRM mode.

xrgb8888 is your usual 24bpp packed RGB format with 8 bits of padding.
xrgb2101010 is a 30bpp packed RGB format with 2 bits of padding.
yuyv is a 32bpp packed YUV 4:2:2 format. No planar formats are currently
supported.

There are cases when xrgb2101010 will work with the `drm` VO, but not
with the `drm` backend for the `gpu` VO. This is because with the
`gpu` VO, in addition to requiring support in your DRM driver,
requires support for xrgb2101010 in your EGL driver.
yuyv only ever works with the `drm` VO.

`--drm-draw-surface-size=<[WxH]>`

Sets the size of the surface used on the draw plane. The surface will
then be upscaled to the current screen resolution. This option can be
useful when used together with the drmprime-overlay hwdec interop at
high resolutions, as it allows scaling the draw plane (which in this
case only handles the OSD) down to a size the GPU can handle.

When used without the drmprime-overlay hwdec interop this option will
just cause the video to get rendered at a different resolution and then
scaled to screen size.

(default: display resolution)

`--drm-vrr-enabled=<no|yes|auto>`

Toggle use of Variable Refresh Rate (VRR), aka Freesync or Adaptive Sync
on compatible systems. VRR allows for the display to be refreshed at any
rate within a range (usually ~40Hz-60Hz for 60Hz displays). This can help
with playback of 24/25/50fps content. Support depends on the use of a
compatible monitor, GPU, and a sufficiently new kernel with drivers
that support the feature.
| no: | Do not attempt to enable VRR. (default) |
| --- | --- |
| yes: | Attempt to enable VRR, whether the capability is reported or not. |
| auto: | Attempt to enable VRR if support is reported. |

`mediacodec_embed` (Android)

Renders `IMGFMT_MEDIACODEC` frames directly to an `android.view.Surface`.
Requires `--hwdec=mediacodec` for hardware decoding, along with
`--vo=mediacodec_embed` and `--wid=(intptr_t)(*android.view.Surface)`.

Since this video output driver uses native decoding and rendering routines,
many of mpv's features (subtitle rendering, OSD/OSC, video filters, etc)
are not available with this driver.

To use hardware decoding with `--vo=gpu` instead, use `--hwdec=mediacodec`
or `mediacodec-copy` along with `--gpu-context=android`.

`wlshm` (Wayland only)

Shared memory video output driver without hardware acceleration that works
whenever Wayland is present.

Since mpv 0.30.0, you may need to use `--profile=sw-fast` to get decent
performance.

Note

This is a fallback only, and should not be normally used.
