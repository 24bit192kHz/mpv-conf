transparency to work.

`--d3d11-sync-interval=<0..4>`

Schedule each frame to be presented for this number of VBlank intervals.
(default: 1) Setting to 1 will enable VSync, setting to 0 will disable it.

`--d3d11-adapter=<adapter name|help>`

Select a specific D3D11 adapter to utilize for D3D11 rendering.
Will pick the default adapter if unset. Alternatives are listed
when the name "help" is given.

Checks for matches based on the start of the string, case
insensitive. Thus, if the description of the adapter starts with
the vendor name, that can be utilized as the selection parameter.

Hardware decoders utilizing the D3D11 rendering abstraction's helper
functionality to receive a device, such as D3D11VA or DXVA2's DXGI
mode, will be affected by this choice.

`--d3d11-output-format=<auto|rgba8|bgra8|rgb10_a2|rgba16f>`

Select a specific D3D11 output format to utilize for D3D11 rendering.
"auto" is the default, which will pick either rgba8 or rgb10_a2 depending
on the configured desktop bit depth. rgba16f and bgra8 are left out of
the autodetection logic, and are available for manual testing.

Note

Desktop bit depth querying is only available from an API available
from Windows 10. Thus on older systems it will only automatically
utilize the rgba8 output format.

Note

For `--vo=gpu-next`, this is used as a best-effort hint and
libplacebo has the last say on which format is utilized.

`--d3d11-output-csp=<auto|srgb|linear|pq|bt.2020>`

Select a specific D3D11 output color space to utilize for D3D11 rendering.
"auto" is the default, which will select the color space of the desktop
on which the swap chain is located.

Values other than "srgb" and "pq" have had issues in testing, so they
are mostly available for manual testing.

Note

Swap chain color space configuration is only available from an API
available from Windows 10. Thus on older systems it will not work.

`--d3d11va-zero-copy=<yes|no>`

By default, when using hardware decoding with `--gpu-api=d3d11`, the
video image will be copied (GPU-to-GPU) from the decoder surface to a
shader resource. Set this option to avoid that copy by sampling directly
from the decoder image. This may increase performance and reduce power
usage, but can cause the image to be sampled incorrectly on the bottom and
right edges due to padding, and may invoke driver bugs, since Direct3D 11
technically does not allow sampling from a decoder surface (though most
drivers support it.)

Currently only relevant for `--gpu-api=d3d11`.

`--wayland-app-id=<string>`

Set the client app id for Wayland-based video output methods (default: `mpv`).

`--wayland-configure-bounds=<auto|yes|no>`

Controls whether or not mpv opts into the configure bounds event if sent by the
compositor (default: auto). This restricts the initial size of the mpv window to
a certain maximum size intended by the compositor. In most cases, this simply
just prevents the mpv window from being larger than the size of the monitor when
it first renders. With the default value of `auto`, configure-bounds will
silently be ignored if any `autofit` or `geometry` type option is also set.

`--wayland-content-type=<auto|none|photo|video|game>`

If supported by the compositor, mpv will send a hint using the content-type
protocol telling the compositor what type of content is being displayed. `auto`
(default) will automatically switch between telling the compositor the content
is a photo, video or possibly none depending on internal heuristics.

`--wayland-edge-pixels-pointer=<value>`

Defines the size of an edge border (default: 16) to initiate client side
resize events in the wayland contexts with the mouse. This is only active if
there are no server side decorations from the compositor.

`--wayland-edge-pixels-touch=<value>`

Defines the size of an edge border (default: 32) to initiate client side
resizes events in the wayland contexts with touch events.

`--wayland-internal-vsync=<no|auto|yes>`

Controls whether to use mpv's internal vsync for Wayland-base video outputs
(default: `auto`). This is mainly useful for benchmarking wayland VOs when
combined with `video-sync=display-desync`, `--audio=no`, and
`--untimed=yes`. The special `auto` value will disable the internal
vsync if the compositor supports the fifo protocol and version 2 of the
presentation time protocol when using `--gpu-api=vulkan`. In any other
situation, it is exactly the same as `yes`.

`--wayland-present=<yes|no>`

Enable the use of wayland's presentation time protocol for more accurate
frame presentation if it is supported by the compositor (default: `yes`).
This only has an effect if `--video-sync=display-...` is being used.

`--spirv-compiler=<compiler>`

Controls which compiler is used to translate GLSL to SPIR-V. This is
only relevant for `--gpu-api=d3d11` with `--vo=gpu`.
The possible choices are currently:

auto

Use the first available compiler. (Default)

shaderc

Use libshaderc, which is an API wrapper around glslang. This is
generally the most preferred, if available.

Note

This option is deprecated, since there is only one usable value.
It may be removed in the future.

`--glsl-shader=<file>`, `--glsl-shaders=<file-list>`

Custom GLSL hooks. These are a flexible way to add custom fragment shaders,
which can be injected at almost arbitrary points in the rendering pipeline,
and access all previous intermediate textures.

Each use of the `--glsl-shader` option will add another file to the
internal list of shaders, while `--glsl-shaders` takes a list of files,
and overwrites the internal list with it. The latter is a path list option
(see [List Options](manual-options-track.md) for details).

Warning

The syntax is not stable yet and may change any time.

The general syntax of a user shader looks like this:

```
//!METADATA ARGS...
//!METADATA ARGS...

vec4 hook() {
   ...
   return something;
}

//!METADATA ARGS...
//!METADATA ARGS...

...
```

Each section of metadata, along with the non-metadata lines after it,
defines a single block. There are currently two types of blocks, HOOKs and
TEXTUREs.

A `TEXTURE` block can set the following options:

TEXTURE <name> (required)

The name of this texture. Hooks can then bind the texture under this
name using BIND. This must be the first option of the texture block.

SIZE <width> [<height>] [<depth>] (required)

The dimensions of the texture. The height and depth are optional. The
type of texture (1D, 2D or 3D) depends on the number of components
specified.

FORMAT <name> (required)

The texture format for the samples. Supported texture formats are listed
in debug logging when the `gpu` VO is initialized (look for
`Texture formats:`). Usually, this follows OpenGL naming conventions.
For example, `rgb16` provides 3 channels with normalized 16 bit
components. One oddity are float formats: for example, `rgba16f` has
16 bit internal precision, but the texture data is provided as 32 bit
floats, and the driver converts the data on texture upload.

Although format names follow a common naming convention, not all of them
are available on all hardware, drivers, GL versions, and so on.

