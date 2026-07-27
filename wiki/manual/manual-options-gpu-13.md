
On <cite>--vo=gpu-next</cite>, files that have not been accessed in the last 24 hours
may be cleared if the cache limit (1.5 GiB) is exceeded.

On `--vo=gpu`, this is not cleaned automatically, so old, unused cache
files may stick around indefinitely.

`--icc-cache-dir`

The directory where icc cache is stored. Cache is stored in the system's
cache directory (usually `~/.cache/mpv`) if this is unset.

`--icc-intent=<value>`

Specifies the ICC intent used for the color transformation (when using
`--icc-profile`).

0

perceptual

1

relative colorimetric (default)

2

saturation

3

absolute colorimetric

`--icc-3dlut-size=<auto|RxGxB>`

Size of the 3D LUT generated from the ICC profile in each dimension. The
default of `auto` means to pick the size automatically based on the
profile characteristics. Sizes may range from 2 to 512.

NOTE: Setting this option to anything other than `auto` is **strongly**
discouraged, except for testing.

`--icc-force-contrast=<no|0-1000000|inf>`

Override the target device's detected contrast ratio by a specific value.
This is detected automatically from the profile if possible, but for some
profiles it might be missing, causing the contrast to be assumed as
infinite. As a result, video may appear darker than intended. If this is
the case, setting this option might help. This only affects BT.1886
content. The default of `no` means to use the profile values. The special
value `inf` causes the BT.1886 curve to be treated as a pure power gamma
2.4 function.

`--icc-use-luma`

Use ICC profile luminance value. (Only for `--vo=gpu-next`)

`--lut=<file>`

Specifies a custom LUT (in Adobe .cube format) to apply to the colors
as part of color conversion. The exact interpretation depends on the value
of `--lut-type`. (Only for `--vo=gpu-next`)

`--lut-type=<value>`

Controls the interpretation of color values fed to and from the LUT
specified as `--lut`. Valid values are:

auto

Chooses the interpretation of the LUT automatically from tagged
metadata, and otherwise falls back to `native`. (Default)

native

Applied to raw image contents in its native RGB colorspace (non-linear
light), before conversion to the output color space.

normalized

Applied to the normalized RGB image contents, in linear light, before
conversion to the output color space.

conversion

Fully replaces the conversion from the image color space to the output
color space. If such a LUT is present, it has the highest priority, and
overrides any ICC profiles, as well as options related to tone mapping
and output colorimetry (`--target-prim`, `--target-trc` etc.).

`--blend-subtitles=<yes|video|no>`

Blend subtitles directly onto upscaled video frames, before interpolation
and/or color management (default: no). Enabling this causes subtitles to be
affected by `--icc-profile`, `--target-prim`, `--target-trc`,
`--interpolation`, `--gamma-factor` and `--glsl-shaders`. It also
increases subtitle performance when using `--interpolation`.

The downside of enabling this is that it restricts subtitles to the visible
portion of the video, so you can't have subtitles exist in the black
margins below a video (for example).

If `video` is selected, the behavior is similar to `yes`, but subs are
drawn at the video's native resolution, and scaled along with the video.

Note

`--vo=gpu-next` with `--blend-subtitles=video` will
correctly follow `--video-rotate` if rotated in 90-degree steps.

Warning

With `--vo=gpu-next`, the `--blend-subtitles=video` mode
blends the subtitles after scaling the video, similar to
`--blend-subtitles=yes`. The difference is that the subtitles
are rendered at the video's native resolution and then scaled
separately to blend with the video. This is useful for
performance reasons, as it allows subtitles to be rendered at a
lower resolution, but it does not have the same effect as
hardsubbing, which would require blending before scaling. This
may change in the future.

Warning

This changes the way subtitle colors are handled. Normally,
subtitle colors are assumed to be in sRGB and color managed as
such. Enabling this makes them treated as being in the video's
color space instead. This is good if you want things like
softsubbed ASS signs to match the video colors, but may cause
SRT subtitles or similar to look slightly off.

`--background=<none|color|tiles>`

If the frame has an alpha component, decide what kind of background, if any,
to blend it with. This does nothing if there is no alpha component.

color

Blend the frame against the background color (`--background-color`,
normally black).

tiles

Blend the frame against a checkerboard pattern with colors specified
in the `--background-tile-color-0` and `--background-tile-color-1`
options and tile size specified in the `--background-tile-size` option
(default).

none

Do not blend the frame and leave the alpha as is.

Background transparency on d3d11 requires `--d3d11-flip=no`.

Before mpv 0.38.0, this option used to accept a color value specifying the
background color. This is now done by the `--background-color` option.
Use that instead.

`--background-color=<color>`

Color used to draw parts of the mpv window not covered by video in
`--background=color` mode.
See the `--sub-color` option for how colors are defined.

`--background-tile-color-0=<color>`, `--background-tile-color-1=<color>`

Colors used to draw parts of the mpv window not covered by video in
`--background=tiles` mode.
See the `--sub-color` option for how colors are defined.

`--background-tile-size=<1-4096>`

Tile size used to draw parts of the mpv window not covered by video in
`--background=tiles` mode (default: 16).

`--border-background=<none|color|tiles|blur>`

Same as `--background` but only applies to the black bar/border area of
the window. `vo=gpu-next` only. Defaults to `color`.

`--background-blur-radius=<radius>`

The blur radius (in pixels) to use for `--border-background=blur`

`--opengl-rectangle-textures`

Force use of rectangle textures (default: no). Normally this shouldn't have
any advantages over normal textures. Note that hardware decoding overrides
this flag. Could be removed any time.

`--gpu-tex-pad-x`, `--gpu-tex-pad-y`

Enlarge the video source textures by this many pixels. For debugging only
(normally textures are sized exactly, but due to hardware decoding interop
we may have to deal with additional padding, which can be tested with these
