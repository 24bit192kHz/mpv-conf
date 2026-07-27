(Advanced users only) Choose a custom windowing function for the kernel.
Defaults to the filter's preferred window if unset. Use
`--scale-window=help` to get a list of supported windowing functions.

`--scale-wparam=<window>`, `--cscale-wparam=<window>`, `--cscale-wparam=<window>`, `--tscale-wparam=<window>`

(Advanced users only) Configure the parameter for the window function given
by `--scale-window` etc. By default, these are set to the special string
`default`, which maps to a window-specific default value. Ignored if the
window is not tunable. Currently, this affects the following window
parameters:

kaiser

Window parameter (alpha). Defaults to 6.33.

blackman

Window parameter (alpha). Defaults to 0.16.

gaussian

Scale parameter (t). Increasing this makes the window wider. Defaults
to 1.

`--scaler-resizes-only`

Disable the scaler if the video image is not resized. In that case,
`bilinear` is used instead of whatever is set with `--scale`. Bilinear
will reproduce the source image perfectly if no scaling is performed.
Enabled by default. Note that this option never affects `--cscale`.

`--correct-downscaling`

When using convolution based filters, extend the filter size when
downscaling. Increases quality, but reduces performance while downscaling.
Enabled by default.

This will perform slightly sub-optimally for anamorphic video (but still
better than without it) since it will extend the size to match only the
milder of the scale factors between the axes.

Note: this option is ignored when using bilinear downscaling with `--vo=gpu`.

`--linear-downscaling`

Scale in linear light when downscaling. It should only be used with a
`--fbo-format` that has at least 16 bit precision. This option
has no effect on HDR content. Enabled by default.

`--linear-upscaling`

Scale in linear light when upscaling. Like `--linear-downscaling`, it
should only be used with a `--fbo-format` that has at least 16 bits
precisions. This is not usually recommended except for testing/specific
purposes. Users are advised to either enable `--sigmoid-upscaling` or
keep both options disabled (i.e. scaling in gamma light).

`--sigmoid-upscaling`

When upscaling, use a sigmoidal color transform to avoid emphasizing
ringing artifacts. Enabled by default. This is incompatible with and replaces
`--linear-upscaling`. (Note that sigmoidization also requires
linearization, so the `LINEAR` rendering step fires in both cases)

For more information about sigmoidization, see:
[https://imagemagick.org/Usage/resize/#resize_sigmoidal](https://imagemagick.org/Usage/resize/#resize_sigmoidal)

`--sigmoid-center`

The center of the sigmoid curve used for `--sigmoid-upscaling`, must be a
float between 0.0 and 1.0. Defaults to 0.75 if not specified.

`--sigmoid-slope`

The slope of the sigmoid curve used for `--sigmoid-upscaling`, must be a
float between 1.0 and 20.0. Defaults to 6.5 if not specified.

`--interpolation`

Reduce stuttering caused by mismatches in the video fps and display refresh
rate (also known as judder).

Warning

This requires setting the `--video-sync` option to one
of the `display-` modes, or it will be silently disabled.
This was not required before mpv 0.14.0.

This essentially attempts to interpolate the missing frames by convoluting
the video along the temporal axis. The filter used can be controlled using
the `--tscale` setting.

`--interpolation-threshold=<0..1,-1>`

Threshold below which frame ratio interpolation gets disabled (default:
`0.01`). This is calculated as `abs(disphz/vfps - 1) < threshold`,
where `vfps` is the speed-adjusted video FPS, and `disphz` the
display refresh rate. (The speed-adjusted video FPS is roughly equal to
the normal video FPS, but with slowdown and speedup applied. This matters
if you use `--video-sync=display-resample` to make video run synchronously
to the display FPS, or if you change the `speed` property.)

The default is intended to enable interpolation in scenarios where
retiming with the `--video-sync=display-*` cannot adjust the speed of
the video sufficiently for smooth playback. For example if a video is
60.00 FPS and your display refresh rate is 59.94 Hz, interpolation will
never be activated, since the mismatch is within 1% of the refresh
rate. The default also handles the scenario when mpv cannot determine the
container FPS, such as during certain live streams, and may dynamically
toggle interpolation on and off. In this scenario, the default would be to
not use interpolation but rather to allow `--video-sync=display-*` to
retime the video to match display refresh rate. See
`--video-sync-max-video-change` for more information about how mpv
will retime video.

Also note that if you use e.g. `--video-sync=display-vdrop`, small
deviations in the rate can disable interpolation and introduce a
discontinuity every other minute.

Set this to `-1` to disable this logic.

`--interpolation-preserve`

Preserve the previous frames' interpolated results even when renderer
parameters are changed - with the exception of options related to
cropping and video placement, which always invalidate the cache. Enabling
this option makes dynamic updates of renderer settings slightly smoother at
the cost of slightly higher latency in response to such changes. Defaults
to on. (Only affects `--vo=gpu-next`, note that `--vo=gpu` always
invalidates interpolated frames)

`--opengl-pbo`

Enable use of PBOs. On some drivers this can be faster, especially if the
source video size is huge (e.g. so called "4K" video). On other drivers it
might be slower or cause latency issues.

`--dither-depth=<N|no|auto>`

Set dither target depth to N. Default: auto.

no

Disable any dithering done by mpv.

auto

Automatic selection.
On `--vo=gpu`: detected depth or 8 bpc otherwise
On `--vo=gpu-next`: detected depth or 8 bpc (for SDR target)

8

Dither to 8 bit output.

Note that the on-the-wire bit depth cannot be detected except when using
`gpu-api=d3d11`. Explicitly setting the value to your display's bit depth
is recommended, as dithering performed by some LCD panels can be of low
quality.

`--dither-size-fruit=<2-8>`

Set the size of the dither matrix (default: 6). The actual size of the
matrix is `(2^N) x (2^N)` for an option value of `N`, so a value of 6
gives a size of 64x64. The matrix is generated at startup time, and a large
matrix can take rather long to compute (seconds).

Used in `--dither=fruit` mode only.

`--dither=<fruit|ordered|error-diffusion|no>`

Select dithering algorithm (default: fruit). (Normally, the
`--dither-depth` option controls whether dithering is enabled.)

The `error-diffusion` option requires compute shader support. It also
requires large amount of shared memory to run, the size of which depends on
both the kernel (see `--error-diffusion` option below) and the height of
video window. It will fallback to `fruit` dithering if there is no enough
shared memory to run the shader.

`--temporal-dither`

Enable temporal dithering. (Only active if dithering is enabled in
general.) This changes between 8 different dithering patterns on each frame
by changing the orientation of the tiled dithering matrix. Unfortunately,
this can lead to flicker on LCD displays, since these have a high reaction
time.

`--temporal-dither-period=<1-128>`

Determines how often the dithering pattern is updated when
`--temporal-dither` is in use. 1 (the default) will update on every video
frame, 2 on every other frame, etc.

