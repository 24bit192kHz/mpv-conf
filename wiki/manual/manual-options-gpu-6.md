`--blend-subtitles=video` is applied.

Note

With `--vo=gpu`, `MAIN` and `MAINPRESUB` are separate shader
stages, this allows rendering overlays directly onto the pre-scaled
video stage. `--vo=gpu-next` does not support this feature,
and as such, the `MAINPRESUB` shader stage does not exist.
It is still valid to refer to this name in shaders, but it is
handled identically to `MAIN`.

MAIN (resizable)

The main image, after conversion to RGB but before upscaling.

LINEAR (fixed)

Linear light image, before scaling. This only fires when
`--linear-upscaling`, `--linear-downscaling` or
`--sigmoid-upscaling` is in effect.

SIGMOID (fixed)

Sigmoidized light, before scaling. This only fires when
`--sigmoid-upscaling` is in effect.

PREKERNEL (fixed)

The image immediately before the scaler kernel runs.

POSTKERNEL (fixed)

The image immediately after the scaler kernel runs.

SCALED (fixed)

The final upscaled image, before color management.

OUTPUT (fixed)

The final output image, after color management but before dithering and
drawing to screen.

Only the textures labelled with `resizable` may be transformed by the
pass. When overwriting a texture marked `fixed`, the WIDTH, HEIGHT and
OFFSET must be left at their default values.

`--glsl-shader=<file>`

CLI/config file only alias for `--glsl-shaders-append`.

`--glsl-shader-opts=param1=value1,param2=value2,...`

Specifies the options to use for tunable shader parameters. You can target
specific named shaders by prefixing the shader name with a `/`, e.g.
`shader/param=value`. Without a prefix, parameters affect all shaders.
The shader name is the base part of the shader filename, without the
extension. (`--vo=gpu-next` only)

Some parameters are filled automatically if the shader requests them.
Currently following parameters are available:

`PTS`

PTS of the current frame in seconds.

`chroma_offset_x`

chroma offset to the reference plane in x direction.

`chroma_offset_y`

chroma offset to the reference plane in y direction.

`min_luma`

Minimum luminance value (in cd/m²).

`max_luma`

Maximum luminance value (in cd/m²).

`max_cll`

Maximum Content Light Level (in cd/m²).

`max_fall`

Maximum Frame Average Light Level (in cd/m²).

`scene_max_r`

Maximum scene light level of the red channel (in cd/m²).

`scene_max_g`

Maximum scene light level of the green channel (in cd/m²).

`scene_max_b`

Maximum scene light level of the blue channel (in cd/m²).

`scene_avg`

Average scene light level (in cd/m²).

`max_pq_y`

Maximum PQ luminance (in PQ, 0-1).

`avg_pq_y`

Average PQ luminance (in PQ, 0-1).

`--deband`

Enable the debanding algorithm. This greatly reduces the amount of visible
banding, blocking and other quantization artifacts, at the expense of
very slightly blurring some of the finest details. In practice, it's
virtually always an improvement - the only reason to disable it would be
for performance.

`--deband-iterations=<0..16>`

The number of debanding steps to perform per sample. Each step reduces a
bit more banding, but takes time to compute. Note that the strength of each
step falls off very quickly, so high numbers (>4) are practically useless.
(Default 1)

`--deband-threshold=<0..4096>`

The debanding filter's cut-off threshold. Higher numbers increase the
debanding strength dramatically but progressively diminish image details.
(Default 48)

`--deband-range=<1..64>`

The debanding filter's initial radius. The radius increases linearly for
each iteration. A higher radius will find more gradients, but a lower
radius will smooth more aggressively. (Default 16)

If you increase the `--deband-iterations`, you should probably decrease
this to compensate.

`--deband-grain=<0..4096>`

Add some extra noise to the image. This significantly helps cover up
remaining quantization artifacts. Higher numbers add more noise. (Default
32)

`--corner-rounding=<0..1>`

If set to a value above 0.0, the output will be rendered with rounded
corners, as if an alpha transparency mask had been applied. The value
indicates the relative fraction of the side length to round - a value of
1.0 rounds the corners as much as possible. (`--vo=gpu-next` only)

`--sharpen=<value>`

If set to a value other than 0, enable an unsharp masking filter. Positive
values will sharpen the image (but add more ringing and aliasing). Negative
values will blur the image. If your GPU is powerful enough, consider
alternatives like the `ewa_lanczossharp` scale filter, or the
`--scale-blur` option. (Only for `--vo=gpu`)

`--opengl-glfinish`

Call `glFinish()` before swapping buffers (default: disabled). Slower,
but might improve results when doing framedropping. Can completely ruin
performance. The details depend entirely on the OpenGL driver.

`--opengl-waitvsync`

Call `glXWaitVideoSyncSGI` after each buffer swap (default: disabled).
This may or may not help with video timing accuracy and frame drop. It's
possible that this makes video output slower, or has no effect at all.

X11/GLX only.

`--opengl-dwmflush=<no|windowed|yes|auto>`

(Windows only)
Calls `DwmFlush` after swapping buffers on Windows (default: auto). It
also sets `SwapInterval(0)` to ignore the OpenGL timing. Values are: no
(disabled), windowed (only in windowed mode), yes (also in full screen).

The value `auto` will try to determine whether the compositor is active,
and calls `DwmFlush` only if it seems to be.

This may help to get more consistent frame intervals, especially with
high-fps clips - which might also reduce dropped frames. Typically, a value
of `windowed` should be enough, since full screen may bypass the DWM.

`--angle-d3d11-feature-level=<11_0|10_1|10_0|9_3>`

