
spline

Specifies the knee point (in PQ space). Defaults to 0.30.

st2094-10

Specifies the contrast (slope) at the knee point. Defaults to 1.0.

`--inverse-tone-mapping`

If set, allows inverse tone mapping (expanding dynamic range). Can be used
for upscaling SDR content to HDR, or for making HDR content brighter.
Not supported by all tone mapping curves. Use with caution.
(`--vo=gpu-next` only)

`--tone-mapping-max-boost=<1.0..10.0>`

Upper limit for how much the tone mapping algorithm is allowed to boost
the average brightness by over-exposing the image. The default value of 1.0
allows no additional brightness boost. A value of 2.0 would allow
over-exposing by a factor of 2, and so on. Raising this setting can help
reveal details that would otherwise be hidden in dark scenes, but raising
it too high will make dark scenes appear unnaturally bright. (`--vo=gpu`
only)

`--tone-mapping-visualize`

Display a (PQ-PQ) graph of the active tone-mapping LUT. Intended only for
debugging purposes. The X axis shows PQ input values, the Y axis shows PQ
output values. The tone-mapping curve is shown in green/yellow. Yellow
means the brightness has been boosted from the source, dark blue regions
show where the brightness has been reduced. The extra colored regions and
lines indicate various monitor limits, as well a reference diagonal
(neutral tone-mapping) and source scene average brightness information (if
available). (`--vo=gpu-next` only)

`--gamut-mapping-mode`

Specifies the algorithm used for reducing the gamut of images for the
target display, after any tone mapping is done.

auto

Choose the best mode automatically. (Default)

clip

Hard-clip to the gamut (per-channel). Very low quality, but free.

perceptual

Performs a perceptually balanced gamut mapping using a soft knee
function to roll-off clipped regions, and a hue shifting function to
preserve saturation. (`--vo=gpu-next` only)

relative

Performs relative colorimetric clipping, while maintaining an
exponential relationship between brightness and chromaticity.
(`--vo=gpu-next` only)

saturation

Performs simple RGB->RGB saturation mapping. The input R/G/B channels
are mapped directly onto the output R/G/B channels. Will never clip,
but will distort all hues and/or result in a faded look.
(`--vo=gpu-next` only)

absolute

Performs absolute colorimetric clipping. Like `relative`, but does
not adapt the white point. (`--vo=gpu-next` only)

desaturate

Performs constant-luminance colorimetric clipping, desaturing colors
towards white until they're in-range.

darken

Uniformly darkens the input slightly to prevent clipping on blown-out
highlights, then clamps colorimetrically to the input gamut boundary,
biased slightly to preserve chromaticity over luminance.
(`--vo=gpu-next` only)

warn

Performs no gamut mapping, but simply highlights out-of-gamut pixels.

linear

Linearly/uniformly desaturates the image in order to bring the entire
image into the target gamut. (`--vo=gpu-next` only)

`--hdr-compute-peak=<auto|yes|no>`

Compute the HDR peak and frame average brightness per-frame instead of
relying on tagged metadata. These values are averaged over local regions as
well as over several frames to prevent the value from jittering around too
much. This option basically gives you dynamic, per-scene tone mapping.
Requires compute shaders, which is a fairly recent OpenGL feature, and will
probably also perform horribly on some drivers, so enable at your own risk.
The special value `auto` (default) will enable HDR peak computation
automatically if compute shaders and SSBOs are supported.

`--allow-delayed-peak-detect`

When using `--hdr-compute-peak`, allow delaying the detected peak by a
frame when beneficial for performance. In particular, this is required to
avoid an unnecessary FBO indirection when no advanced rendering is required
otherwise. Has no effect if there already is an indirect pass, such as when
advanced scaling is enabled. Defaults to no. (Only affects
`--vo=gpu-next`, note that `--vo=gpu` always delays the peak.)

`--hdr-peak-percentile=<0.0..100.0>`

Which percentile of the input image brightness histogram to consider as the
true peak of the scene. If this is set to 100 (default), the
brightest pixel is measured. Otherwise, the top of the frequency
distribution is progressively cut off. Setting this too low will cause
clipping of very bright details, but can improve the dynamic brightness
range of scenes with very bright isolated highlights. Values other than 100
come with a small performance penalty. (Only for `--vo=gpu-next`)

`--hdr-peak-decay-rate=<0.0..1000.0>`

The decay rate used for the HDR peak detection algorithm (default: 20.0).
This is only relevant when `--hdr-compute-peak` is enabled. Higher values
make the peak decay more slowly, leading to more stable values at the cost
of more "eye adaptation"-like effects (although this is mitigated somewhat
by `--hdr-scene-threshold`). A value of 0.0 (the lowest possible) disables
all averaging, meaning each frame's value is used directly as measured,
but doing this is not recommended for "noisy" sources since it may lead
to excessive flicker. (In signal theory terms, this controls the time
constant "tau" of an IIR low pass filter)

`--hdr-scene-threshold-low=<0.0..100.0>`, `--hdr-scene-threshold-high=<0.0..100.0>`

The lower and upper thresholds (in dB) for a brightness difference
to be considered a scene change (default: 1.0 low, 3.0 high). This is only
relevant when `--hdr-compute-peak` is enabled. Normally, small
fluctuations in the frame brightness are compensated for by the peak
averaging mechanism, but for large jumps in the brightness this can result
in the frame remaining too bright or too dark for up to several seconds,
depending on the value of `--hdr-peak-decay-rate`. To counteract this,
when the brightness between the running average and the current frame
exceeds the low threshold, mpv will make the averaging filter more
aggressive, up to the limit of the high threshold (at which point the
filter becomes instant).

`--hdr-contrast-recovery=<0.0..2.0>`, `--hdr-contrast-smoothness=<1.0..100.0>`

Enables the HDR contrast recovery algorithm, which is to designed to
enhance contrast of HDR video after tone mapping. The strength (default:
0.0) indicates the degree of contrast recovery, with 0.0 being completely
disabled and 1.0 being 100% strength. Values higher than 1.0 are allowed,
but may result in excessive sharpening. The smoothness (default: 3.5)
indicates the degree to which the HDR source is low-passed in order to
obtain contrast information - a value of 2.0 corresponds to 2x downscaling.
Users on low DPI displays (<= 100) may want to lower this value, while
users on very high DPI displays ("retina") may want to increase it. (Only
for `vo=gpu-next`)

`--use-embedded-icc-profile`

Load the embedded ICC profile contained in media files such as PNG images.
(Default: yes). Note that this option only works when also using a display
ICC profile (`--icc-profile` or `--icc-profile-auto`), and also
requires LittleCMS 2 support.

`--icc-profile=<file>`

Load an ICC profile and use it to transform video RGB to screen output.
Needs LittleCMS 2 support compiled in. This option overrides the
`--target-prim`, `--target-trc` and `--icc-profile-auto` options.

`--icc-profile-auto`

Automatically select the ICC display profile currently specified by the
display settings of the operating system.

NOTE: On Windows, the default profile must be an ICC profile. WCS profiles
are not supported.

Applications using libmpv with the render API need to provide the ICC
profile via `MPV_RENDER_PARAM_ICC_PROFILE`.

`--icc-cache`

Store and load 3DLUTs created from the ICC profile on disk in the
cache directory (Default: `yes`). This can be used to speed up loading,
since LittleCMS 2 can take a while to create a 3D LUT. Note that these
files contain uncompressed LUTs. Their size depends on the
`--icc-3dlut-size`, and can be very big.
