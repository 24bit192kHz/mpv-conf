in certain situations, it may not be enough.

`--hwdec-image-format=<name>`

Set the internal pixel format used by hardware decoding via `--hwdec`
(default `no`). The special value `no` selects an implementation
specific standard format. Most decoder implementations support only one
format, and will fail to initialize if the format is not supported.

Some implementations might support multiple formats. In particular,
videotoolbox is known to require `uyvy422` for good performance on some
older hardware. d3d11va can always use `yuv420p`, which uses an opaque
format, with likely no advantages.

`--cuda-decode-device=<auto|0..>`

Choose the GPU device used for decoding when using the `cuda` or
`nvdec` hwdecs with the OpenGL GPU backend, and with the `cuda-copy`
or `nvdec-copy` hwdecs in all cases.

For the OpenGL GPU backend, the default device used for decoding is the one
being used to provide `gpu` output (and in the vast majority of cases,
only one GPU will be present).

For the `copy` hwdecs, the default device will be the first device
enumerated by the CUDA libraries - however that is done.

For the Vulkan GPU backend, decoding must always happen on the display
device, and this option has no effect.

`--vaapi-device=<device file|adapter name>`

Choose the DRM device for `vaapi-copy`. This should be the path to a
DRM device file. (Default: `/dev/dri/renderD128`)

On Windows this takes adapter name as an input. Will pick the default adapter
if unset. Alternatives are listed when the name "help" is given.

`--panscan=<0.0-1.0>`

Enables pan-and-scan functionality (cropping the sides of e.g. a 16:9
video to make it fit a 4:3 display without black bands). The range
controls how much of the image is cropped. May not work with all video
output drivers.

This option has no effect if `--video-unscaled` option is used.

The difference between `--panscan` and `--video-zoom` is that
`--panscan` can only zoom in until either the video width or height fills
the window, while `--video-zoom` can zoom in or out arbitrary amounts, and
also works with `--video-unscaled`.

`--video-aspect-override=<ratio|no>`

Override video aspect ratio, in case aspect information is incorrect or
missing in the file being played.

These values have special meaning:
| no: | use the method of the `--video-aspect-method` option (default) |
| --- | --- |
| 0: | disable aspect ratio handling, pretend the video has square pixels
(deprecated, use
`--video-aspect-override=no --video-aspect-method=ignore` instead) |
| -1: | strictly prefer the container aspect ratio (deprecated, use
`--video-aspect-override=no --video-aspect-method=container` instead) |

But note that handling of these special values might change in the future.

Examples

- `--video-aspect-override=4:3`  or `--video-aspect-override=1.3333`

- `--video-aspect-override=16:9` or `--video-aspect-override=1.7777`

- `--no-video-aspect-override` or `--video-aspect-override=no`

`--video-aspect-method=<bitstream|container|ignore>`

This sets the default video aspect determination method (if the aspect is
_not_ overridden by the user with `--video-aspect-override` or others).
| container: | Strictly prefer the container aspect ratio. This is apparently
the default behavior with VLC, at least with Matroska. Note that
if the container has no aspect ratio set, the behavior is the
same as with bitstream. |
| --- | --- |
| bitstream: | Strictly prefer the bitstream aspect ratio, unless the bitstream
aspect ratio is not set. This is apparently the default behavior
with XBMC/kodi, at least with Matroska. |
| ignore: | Disable aspect ratio handling, pretend the video has square
pixels. |

The current default for mpv is `container`.

Normally you should not set this. Try the various choices if you encounter
video that has the wrong aspect ratio in mpv, but seems to be correct in
other players.

`--video-unscaled=<no|yes|downscale-big>`

Disable scaling of the video. If the window is larger than the video,
black bars are added. Otherwise, the video is cropped, unless the option
is set to `downscale-big`, in which case the video is fit to window. The
video still can be influenced by the other `--video-...` options. This
option disables the effect of `--panscan`.

Note that the scaler algorithm may still be used, even if the video isn't
scaled. For example, this can influence chroma conversion. The video will
also still be scaled in one dimension if the source uses non-square pixels
(e.g. anamorphic widescreen DVDs).

This option is disabled if `--keepaspect=no` is used.

`--video-pan-x=<value>`, `--video-pan-y=<value>`

Moves the displayed video rectangle by the given value in the X or Y
direction. The unit is in fractions of the size of the scaled video (the
full size, even if parts of the video are not visible due to panscan or
other options).

For example, displaying a video fullscreen on a 1920x1080 screen with
`--video-pan-x=-0.1` would move the video 192 pixels to the left and
`--video-pan-y=-0.1` would move the video 108 pixels up.

This option is disabled if `--keepaspect=no` is used.

`--video-rotate=<0-359|no>`

Rotate the video clockwise, in degrees. If `no` is given, the video is
never rotated, even if the file has rotation metadata. (The rotation value
is added to the rotation metadata, which means the value `0` would rotate
the video according to the rotation metadata.)

When using hardware decoding without copy-back, only 90° steps work, while
software decoding and hardware decoding methods that copy the video back to
system memory support all values between 0 and 359.

`--video-crop=<[W[xH]][+x+y]>`, `--video-crop=<x:y>`

Crop the video by starting at the x, y offset for w, h pixels. The crop is
applied to the source video rectangle (before anamorphic stretch) by the VO.
A crop rectangle that is not within the video rectangle will be ignored.
This works with hwdec, unlike the equivalent 'lavfi-crop'. When offset is
omitted, the central area will be cropped. Setting the crop to empty one
`--video-crop=0x0+0+0` overrides container crop and disables cropping.
Setting the crop to `--video-crop=""` disables manual cropping and restores
the container crop if it's specified.

`--video-zoom=<value>`

Adjust the video display scale factor by the given value. The parameter is
given log 2. For example, `--video-zoom=0` is unscaled,
`--video-zoom=1` is twice the size, `--video-zoom=-2` is one fourth of
the size, and so on.

This option is disabled if `--keepaspect=no` is used.

`--video-scale-x=<value>`, `--video-scale-y=<value>`

Multiply the video display size with the given value (default: 1.0). If a
non-default value is used, this will be different from the window size, so
video will be either cut off, or black bars are added.

This value is multiplied with the value derived from `--video-zoom` and
the normal video aspect ratio. This option is disabled if
`--keepaspect=no` is used.

`--video-align-x=<-1-1>`, `--video-align-y=<-1-1>`

When the video is bigger than the window, these move the displayed rectangle
to show different parts of the video. `--video-align-y=-1` would display
the top of the video, `0` would display the center (default), and `1`
would display the bottom.

When the video is smaller than the window and `--video-recenter` is
disabled, these move the video rectangle within the black borders, which are
usually added to pad the video to the window if video and window aspect
ratios are different. `--video-align-y=-1` would move the video to the top
of the window (leaving a border only on the bottom), `0` would center it,
and `1` would put the video at the bottom of the window.

If video and screen aspect match perfectly, these options do nothing.

Unlike `--video-pan-x` and `--video-pan-y`, these don't go beyond the
video's or window's boundaries or make the displayed rectangle drift off
after zooming.

This option is disabled if `--keepaspect=no` is used.

`--video-recenter=<yes|no>`

Whether to behave as if `--video-align-x` and `--video-align-y` were 0
when the video becomes smaller than the window in the respective direction

After zooming in until the video is bigger the window, panning with
<cite>--video-align-x</cite> and/or <cite>--video-align-y</cite>, and zooming out until the video
