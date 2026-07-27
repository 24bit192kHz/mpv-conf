## GPU renderer options

The following video options are currently all specific to `--vo=gpu`,
`--vo=libmpv` and `--vo=gpu-next`, which are the only VOs that implement
them.

`--scale=<filter>`

The filter function to use when upscaling video.

`bilinear`

Bilinear hardware texture filtering (fastest, very low quality). This is
the default when using the `fast` profile.

`lanczos`

Lanczos scaling. Provides good balance between quality and performance.
This is the default for `scale`. The number of taps can be controlled
with `scale-radius`, but is best left unchanged.

(This filter is an alias for `sinc`-windowed `sinc`)

`ewa_lanczos`

Elliptic weighted average Lanczos scaling. Also known as Jinc.
Relatively slow, but very good quality. The radius can be controlled
with `scale-radius`. Increasing the radius makes the filter sharper
but adds more ringing.

(This filter is an alias for `jinc`-windowed `jinc`)

`ewa_lanczossharp`

A slightly sharpened version of `ewa_lanczos`. This is the default
when using the `high-quality` profile. Blur value determined by method
originally developed by Nicolas Robidoux for Image Magick, see:
[https://www.imagemagick.org/discourse-server/viewtopic.php?p=89068#p89068](https://www.imagemagick.org/discourse-server/viewtopic.php?p=89068#p89068)

`ewa_lanczos4sharpest`

Very sharp scaler, but also slightly slower than `ewa_lanczossharp`.
Prone to ringing, so it's recommended to combine this with an
anti-ringing shader. On `--vo=gpu-next`, setting this filter enables
built-in anti-ringing, so no extra action needs to be taken.

For more details, see:
[https://www.imagemagick.org/discourse-server/viewtopic.php?p=128587#p128587](https://www.imagemagick.org/discourse-server/viewtopic.php?p=128587#p128587)

`mitchell`

Mitchell-Netravali. Piecewise cubic filter with a support of radius 2.0.
Provides a balanced compromise of all scaling artifacts. This filter has
both `B` and `C` set to `1/3`. The `B` and `C` parameters can
be controlled with `--scale-param1` and `--scale-param2`.

`hermite`

Hermite spline. Similar to `bicubic` but with `B` set to `0.0`.
This filter has the special property of having a support of radius 1.0,
making it very fast in comparison, but prone to blocking. This is the
default for `--dscale`.

`catmull_rom`

Catmull-Rom spline. Similar to `mitchell`, but with `B` and `C`
set to `0.0` and `0.5` respectively. This filter is sharper than
`mitchell`, but prone to ringing.

`oversample`

A version of nearest neighbour that (naively) oversamples pixels, so
that pixels overlapping edges get linearly interpolated instead of
rounded. This essentially removes the small imperfections and judder
artifacts caused by nearest-neighbour interpolation, in exchange for
adding some blur. This can also be used for frame mixing, where it
is commonly known as "smoothmotion" (see `--tscale`).

`linear`

A `--tscale` filter.

There are some more filters, but most are not as useful. For a complete
list, pass `help` as value, e.g.:

```
mpv --scale=help
```

`--cscale=<filter>`

As `--scale`, but for interpolating chroma information. If the image is
not subsampled, this option is ignored entirely. If this option is unset,
the filter implied by `--scale` will be applied.

`--dscale=<filter>`

Like `--scale`, but apply these filters on downscaling instead.

`--tscale=<filter>`

The filter used for interpolating the temporal axis (frames). This is only
used if `--interpolation` is enabled. The only valid choices for
`--tscale` are separable convolution filters (use `--tscale=help` to
get a list). The default is `oversample`.

Common `--tscale` choices include `oversample`, `linear`,
`catmull_rom`, `mitchell`, `gaussian`, or `bicubic`. These are
listed in increasing order of smoothness/blurriness, with `bicubic`
being the smoothest/blurriest and `oversample` being the sharpest/least
smooth.

`--scale-param1=<value>`, `--scale-param2=<value>`, `--cscale-param1=<value>`, `--cscale-param2=<value>`, `--dscale-param1=<value>`, `--dscale-param2=<value>`, `--tscale-param1=<value>`, `--tscale-param2=<value>`

Set filter parameters. By default, these are set to the special string
`default`, which maps to a scaler-specific default value. Ignored if the
filter is not tunable. Currently, this affects the following filter
parameters:

bicubic

Spline parameters (`B` and `C`). Defaults to B=1 and C=0.

gaussian

Scale parameter (`t`). Increasing this makes the result blurrier.
Defaults to 1.

oversample

Minimum distance to an edge before interpolation is used. Setting this
to 0 will always interpolate edges, whereas setting it to 0.5 will
never interpolate, thus behaving as if the regular nearest neighbour
algorithm was used. Defaults to 0.0.

`--scale-blur=<value>`, `--cscale-blur=<value>`, `--dscale-blur=<value>`, `--tscale-blur=<value>`

Kernel scaling factor (also known as a blur factor). Decreasing this makes
the result sharper, increasing it makes it blurrier (default 0). If set to
0, the kernel's preferred blur factor is used. Note that setting this too
low (eg. 0.5) leads to bad results. It's generally recommended to stick to
values between 0.8 and 1.2.

`--scale-clamp=<0.0-1.0>`, `--cscale-clamp`, `--dscale-clamp`, `--tscale-clamp`

Specifies a weight bias to multiply into negative coefficients. Specifying
`--scale-clamp=1` has the effect of removing negative weights completely,
thus effectively clamping the value range to [0-1]. Values between 0.0 and
1.0 can be specified to apply only a moderate diminishment of negative
weights. This is especially useful for `--tscale`, where it reduces
excessive ringing artifacts in the temporal domain (which typically
manifest themselves as short flashes or fringes of black, mostly around
moving edges) in exchange for potentially adding more blur. The default for
`--tscale-clamp` is 1.0, the others default to 0.0.

`--scale-taper=<value>`, `--scale-wtaper=<value>`, `--dscale-taper=<value>`, `--dscale-wtaper=<value>`, `--cscale-taper=<value>`, `--cscale-wtaper=<value>`, `--tscale-taper=<value>`, `--tscale-wtaper=<value>`

Kernel/window taper factor. Increasing this flattens the filter function.
Value range is 0 to 1. A value of 0 (the default) means no flattening, a
value of 1 makes the filter completely flat (equivalent to a box function).
Values in between mean that some portion will be flat and the actual filter
function will be squeezed into the space in between.

`--scale-radius=<value>`, `--cscale-radius=<value>`, `--dscale-radius=<value>`, `--tscale-radius=<value>`

Set radius for tunable filters, must be a float number between 0.5 and
16.0. Defaults to the filter's preferred radius if not specified. Doesn't
work for every scaler and VO combination.

Note that depending on filter implementation details and video scaling
ratio, the radius that actually being used might be different (most likely
being increased a bit).

`--scale-antiring=<value>`, `--cscale-antiring=<value>`, `--dscale-antiring=<value>`, `--tscale-antiring=<value>`

Set the antiringing strength. This tries to eliminate ringing, but can
introduce other artifacts in the process. Must be a float number between
0.0 and 1.0. The default value of 0.0 disables antiringing entirely.

Note that this doesn't affect the special filters `bilinear` and
`bicubic_fast`, nor does it affect any polar (EWA) scalers.

On `--vo=gpu-next`, this also affects polar (EWA) scalers. Certain
filter aliases may also implicitly enable antiringing, regardless of this
setting (see `--scale`).

Note

When downscaling with separable (orthogonal) filters, setting
`--dscale-antiring` to a value other than 0.0 (default) will reduce
scaler quality and produce aliasing artifacts. On `--vo=gpu-next`,
`--dscale-antiring` is disabled for separable (orthogonal) filters.

`--scale-window=<window>`, `--cscale-window=<window>`, `--dscale-window=<window>`, `--tscale-window=<window>`

