`--target-gamut=<value>`

Constrains the gamut of the display. You can use this option to output e.g.
DCIP3-in-BT.2020. Set `--target-prim` to the primaries of the containing
colorspace (into which values will be encoded), and `--target-gamut` to
the gamut you want to limit colors to. Takes the same values as
`--target-prim`. (Only for `--vo=gpu-next`)

Note

If the selected gamut is wider, it will be limited to `--target-prim`.
Additionally, if `--target-colorspace-hint` is specified, the signaled
gamut will be limited to the supported gamut of the swapchain. Which may
differ from the requested `--target-prim`.

`--target-lut=<file>`

Specifies a custom LUT file (in Adobe .cube format) to apply to the colors
before display on-screen. This LUT is fed values in normalized RGB, after
encoding into the target colorspace, so after the application of
`--target-trc`. (Only for `--vo=gpu-next`)

`--hdr-reference-white=<auto|10-1000000>`

Specifies the assumed peak brightness of the mastering display for SDR
content, in cd/m² (nits). This is used as HDR diffuse white level for SDR
content. Essentially this is the SDR brightness in HDR container.
Default is 203 cd/m². (Only for `--vo=gpu-next`)

Note

This option overrides the `--target-peak` if is set and the target
transfer function is SDR. This way you can control SDR output separately
from HDR output.

`--sdr-adjust-gamma=<auto|yes|no>`

SDR transfer functions are often ambiguous or mismatched. Even if files are
tagged with a specific function (e.g. `bt.709`), the actual content may
not match. For example, most screen capture software tags its output as
`bt.709`, but the content is usually a direct sRGB capture.

On the target side, "sRGB" is also ambiguous, some displays are factory
calibrated to a pure power 2.2 gamma, while others may use the sRGB
piecewise curve. Both of which are typically configured as "sRGB" in the
swapchain configuration. Similar inconsistencies exist across compositor
implementations of color management, as different platforms handle this in
different ways. See also `--treat-srgb-as-power22`.
Additionally, `bt.1886` requires display contrast ratio to be known for
correct rendering, which is often unavailable. Use``--target-contrast`` to
specify it.

This option controls whether SDR content should have its gamma adjusted.
It only applies to the "sRGB" swapchain target configuration, since that is
the most common and ambiguous case. If set to `no`, content tagged as
`sRGB`, `gamma2.2` or `bt.1886` will be rendered as-is. If set to
`yes`, it will be converted based on the available metadata.

`auto` (default) behaves like `no`, except when `--target-trc` is
explicitly set, in which case it behaves like `yes`.

Generally it's recommended to enable this option, if you can ensure that
both source and target metadata is correct.

(Only for `--vo=gpu-next`)

`--treat-srgb-as-power22=<no|input|output|both|auto>`

When enabled, sRGB is (de)linearized using a pure power 2.2 curve instead of
the standard sRGB piecewise transfer function.

`auto` behaves like `both`, with possible platform-specific adjustments
to ensure a consistent appearance. Depending on the platform, the sRGB EOTF
used by the system compositor may differ.

The default is `auto`. (Only for `--vo=gpu-next`)

`--tone-mapping=<value>`

Specifies the algorithm used for tone-mapping images onto the target
display. This is relevant for both HDR->SDR conversion as well as gamut
reduction (e.g. playing back BT.2020 content on a standard gamut display).
Valid values are:

auto

Maps to `bt.2390` when using `--vo=gpu`, and to `spline` with
`--vo=gpu-next`. (Default)

clip

Hard-clip any out-of-range values. Use this when you care about
perfect color accuracy for in-range values at the cost of completely
distorting out-of-range values. Not generally recommended.

mobius

Generalization of Reinhard to a Möbius transform with linear section.
Smoothly maps out-of-range values while retaining contrast and colors
for in-range material as much as possible. Use this when you care about
color accuracy more than detail preservation. This is somewhere in
between `clip` and `reinhard`, depending on the value of
`--tone-mapping-param`.

reinhard

Reinhard tone mapping algorithm. Very simple continuous curve.
Preserves overall image brightness but uses nonlinear contrast, which
results in flattening of details and degradation in color accuracy.

hable

Similar to `reinhard` but preserves both dark and bright details
better (slightly sigmoidal), at the cost of slightly darkening /
desaturating everything. Developed by John Hable for use in video
games. Use this when you care about detail preservation more than
color/brightness accuracy. This is roughly equivalent to
`--tone-mapping=reinhard --tone-mapping-param=0.24`. If possible,
you should also enable `--hdr-compute-peak` for the best results.

bt.2390

Perceptual tone mapping curve (EETF) specified in ITU-R Report BT.2390.

gamma

Fits a logarithmic transfer between the tone curves.

linear

Linearly stretches the entire reference gamut to (a linear multiple of)
the display.

spline

Perceptually linear single-pivot polynomial. (`--vo=gpu-next` only)

bt.2446a

HDR<->SDR mapping specified in ITU-R Report BT.2446, method A. This is
the recommended curve for well-mastered content. (`--vo=gpu-next`
only)

st2094-40

Dynamic HDR10+ tone-mapping method specified in SMPTE ST2094-40 Annex
B. In the absence of metadata, falls back to a fixed spline matched to
the input/output average brightness characteristics. (`--vo=gpu-next`
only)

st2094-10

Dynamic tone-mapping method specified in SMPTE ST2094-10 Annex B.2.
Conceptually simpler than ST2094-40, and generally produces worse
results.

`--tone-mapping-param=<value>`

Set tone mapping parameters. By default, this is set to the special string
`default`, which maps to an algorithm-specific default value. Ignored if
the tone mapping algorithm is not tunable. This affects the following tone
mapping algorithms:

clip

Specifies an extra linear coefficient to multiply into the signal
before clipping. Defaults to 1.0.

mobius

Specifies the transition point from linear to mobius transform. Every
value below this point is guaranteed to be mapped 1:1. The higher the
value, the more accurate the result will be, at the cost of losing
bright details. Defaults to 0.3, which due to the steep initial slope
still preserves in-range colors fairly accurately.

reinhard

Specifies the local contrast coefficient at the display peak. Defaults
to 0.5, which means that in-gamut values will be about half as bright
as when clipping.

bt.2390

Specifies the offset for the knee point. Defaults to 1.0, which is
higher than the value from the original ITU-R specification (0.5).
(`--vo=gpu-next` only)

gamma

Specifies the exponent of the function. Defaults to 1.8.

linear

Specifies the scale factor to use while stretching. Defaults to 1.0.
