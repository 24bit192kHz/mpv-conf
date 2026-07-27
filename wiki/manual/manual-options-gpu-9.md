This is an object settings list option. See [List Options](manual-options-track.md) for details.

`--opengl-es=<mode>`

Controls which type of OpenGL context will be accepted:

auto

Allow all types of OpenGL (default)

yes

Only allow GLES

no

Only allow desktop/core GL

`--fbo-format=<fmt>`

Selects the internal format of textures used for FBOs. The format can
influence performance and quality of the video output. `fmt` can be one
of: rgb8, rgb10, rgb10_a2, rgb16, rgb16f, rgb32f, rgba12, rgba16, rgba16f,
rgba16hf, rgba32f.

Default: `auto`, which first attempts to utilize 16bit float
(rgba16f, rgba16hf), and falls back to rgba16 if those are not available.
Finally, attempts to utilize rgb10_a2 or rgba8 if all of the previous formats
are not available.

`--gamma-factor=<0.1..2.0>`

Set an additional raw gamma factor (default: 1.0). If gamma is adjusted in
other ways (like with the `--gamma` option or key bindings and the
`gamma` property), the value is multiplied with the other gamma value.

`--gamma-auto`

Automatically corrects the gamma value depending on ambient lighting
conditions (adding a gamma boost for bright rooms).

This option is deprecated and may be removed in the future.

NOTE: Only implemented on macOS and `--vo=gpu`.

`--image-lut=<file>`

Specifies a custom LUT file (in Adobe .cube format) to apply to the colors
during image decoding. The exact interpretation of the LUT depends on
the value of `--image-lut-type`. (Only for `--vo=gpu-next`)

`--image-lut-type=<value>`

Controls the interpretation of color values fed to and from the LUT
specified as `--image-lut`. Valid values are:

auto

Chooses the interpretation of the LUT automatically from tagged
metadata, and otherwise falls back to `native`. (Default)

native

Applied to the raw image contents in its native colorspace, before
decoding to RGB. For example, for a HDR10 image, this would be fed
PQ-encoded YCbCr values in the range 0.0 - 1.0.

normalized

Applied to the normalized RGB image contents, after decoding from
its native color encoding, but before linearization.

conversion

Fully replaces the color decoding. A LUT of this type should ingest the
image's native colorspace and output normalized non-linear RGB.

`--target-colorspace-hint=<auto|yes|no>`

When enabled, output colorspace metadata will be set on the swapchain
depending on the GPU context and platform this may affect compositor/display.
This can be used for "HDR passthrough" and to set the output colorspace
for SDR content. In `auto` mode, the target colorspace is only set if the
current display parameters are known. Currently, this is supported on
Wayland, D3D11 and winvk contexts. The `yes` option will always try to set
the colorspace, you may need to adjust the `--target-*` options to match
your display capabilities.
Requires a supporting driver and `--vo=gpu-next`. (Default: `auto`)

Note

Auto detected target colorspace metadata is not guaranteed to be always
best choice. It depends on your compositor, driver, and display
capabilities. However in most cases `auto` mode should work fine.

`--target-colorspace-hint-mode=<target|source|source-dynamic>`

Select which metadata to use for the `--target-colorspace-hint`.
(Only for `--vo=gpu-next`)

target

Uses metadata based on the target display's actual capabilities. This
mode adapts the source content to the target display before output.
Note: HDR primaries are not overridden by the `--target-prim` option
this only affects the enclosing container for the colorspace.
`--target-gamut` can be used to limit the output gamut if needed.

source

Uses the source content's metadata. This is the traditional
"HDR passthrough" mode (SDR too), where it is assumed that the compositor
and display will handle the colorspace directly and perform any necessary
mappings.

source-dynamic

The same as `source`, but uses dynamic per-scene metadata instead of
static HDR10. This is experimental and depends on the display's ability
to react to metadata changes. Note that this does not send full HDR10+
or Dolby Vision metadata, but uses that information to produce HDR10
with per-scene luminance values.

Default is `target`. If target display parameters are not available, this
will fall back to `source`. Note that this is done on individual properties
basis, i.e. it will merge source params into target for unknown properties,
though not the other way around.

`--target-*` options override the metadata in both modes.

Note

The ICC profile always takes precedence over any metadata.

Note

It is highly recommended to use `--target-colorspace-hint=<auto|yes>`
to ensure the output colorspace is set correctly. This is crucial for
all non-sRGB content, even SDR, to allow the compositor, driver, and
display to properly interpret the signal.

Unfortunately, it's not as easy as it sounds. While mpv performs
high-quality color processing, we cannot guarantee what will happen
after the signal leaves mpv. Therefore, you may need to adjust additional
settings to ensure proper output. A one-size-fits-all default is not
feasible.

Now with the backstory out of the way:

For HDR output the default of `target` should work fine, it will
automatically infer the best target HDR parameters and surface format.
For compatibility, displays are assumed to be in HDR mode, unless it's
reported otherwise. (you can override this with `--target-trc`).
This way the HDR metadata is set and hopefully the compositor will
handle the rest. If the input is SDR, it will be converted to PQ with
primaries set to source values.

For SDR output, for targets where mpv cannot determine whether the target
is HDR or SDR, you can use `source` mode. Metadata set will match the
input colorspace. In case of HDR input, it will be passthrough as-is.
Alternatively, you can use `target` mode and set `--target-trc` to
a SDR transfer function. This way any input will be converted to SDR.

Use the stats display to verify the input and output colorspace settings.

TL;DR: Use `--target-colorspace-hint=auto` and adjust `--target-*`
parameters to match your target display capabilities, until it looks best
for you. Use [Conditional auto profiles](manual-configuration-files-1.md) for specific adjustments. Avoid
using `--target-colorspace-hint=no` unless it's sRGB content, but even
then it's better to set the colorspace metadata.

Note

Additional chatter about the "HDR passthrough" mode: There is a belief
that this mode should send the source HDR signal as-is to the display,
and the display will magically handle it, no matter what. This is not
always true. In some cases it is better to send the HDR signal
tone-mapped to the target display's capabilities, and the best way to do
this is within mpv itself.

This is generally handled by either the compositor or the GPU driver.
You can probably find HDR "calibration" options somewhere in your system.

You can choose which metadata to send to the display and manually tweak
it using the `--target-*` options. You can also try
`--inverse-tone-mapping` if you want to make everything appear more
HDR-like.

Your mileage may vary, this highly depends on the target display, there
is no single answer, but try experimenting, you may be surprised.

`--target-colorspace-hint-strict`

When enabled (default), the configured swapchain colorspace (with the hint)
will be respected. In this mode, the `--target-*` options act only as a
