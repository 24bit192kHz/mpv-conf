The option `--really-quiet` can help with that, and is recommended.
On some platforms, using the `--vo-sixel-buffered` option may work as
well.

You may need to use `--profile=sw-fast` to get decent performance.

Note: at the time of writing, `xterm` does not enable sixel by default -
launching it as `xterm -ti 340` is one way to enable it. Also, `xterm`
does not display images bigger than 1000x1000 pixels by default.

To render and align sixel images correctly, mpv needs to know the terminal
size both in cells and in pixels. By default it tries to use values which
the terminal reports, however, due to differences between terminals this is
an error-prone process which cannot be automated with certainty - some
terminals report the size in pixels including the padding - e.g. `xterm`,
while others report the actual usable number of pixels - like `mlterm`.
Additionally, they may behave differently when maximized or in fullscreen,
and mpv cannot detect this state using standard methods.

Sixel size and alignment options:

`--vo-sixel-cols=<columns>`, `--vo-sixel-rows=<rows>` (default: 0)

Specify the terminal size in character cells, otherwise (0) read it
from the terminal, or fall back to 80x25. Note that mpv doesn't use the
the last row with sixel because this seems to result in scrolling.

`--vo-sixel-width=<width>`, `--vo-sixel-height=<height>` (default: 0)

Specify the available size in pixels, otherwise (0) read it from the
terminal, or fall back to 320x240. Other than excluding the last line,
the height is also further rounded down to a multiple of 6 (sixel unit
height) to avoid overflowing below the designated size.

`--vo-sixel-left=<col>`, `--vo-sixel-top=<row>` (default: 0)

Specify the position in character cells where the image starts (1 is
the first column or row). If 0 (default) then try to automatically
determine it according to the other values and the image aspect ratio
and zoom.

`--vo-sixel-pad-x=

`, `--vo-sixel-pad-y=

` (default: -1)

Used only when mpv reads the size in pixels from the terminal.
Specify the number of padding pixels (on one side) which are included
at the size which the terminal reports. If -1 (default) then the number
of pixels is rounded down to a multiple of number of cells (per axis),
to take into account padding at the report - this only works correctly
when the overall padding per axis is smaller than the number of cells.

`--vo-sixel-config-clear=<yes|no>` (default: yes)

Whether or not to clear the terminal whenever the output is
reconfigured (e.g. when video size changes).

`--vo-sixel-alt-screen=<yes|no>` (default: yes)

Whether or not to use the alternate screen buffer and return the
terminal to its previous state on exit. When set to no, the last
sixel image stays on screen after quit, with the cursor following it.

`--vo-sixel-exit-clear` is a deprecated alias for this option and
may be removed in the future.

`--vo-sixel-buffered=<yes|no>` (default: no)

Buffers the full output sequence before writing it to the terminal.
On POSIX platforms, this can help prevent interruption (including from
other applications) and thus broken images, but may come at a
performance cost with some terminals and is subject to implementation
details.

Sixel image quality options:

`--vo-sixel-dither=<algo>`

Selects the dither algorithm which libsixel should apply.
Can be one of the below list as per libsixel's documentation.

auto (Default)

Let libsixel choose the dithering method.

none

Don't diffuse

atkinson

Diffuse with Bill Atkinson's method.

fs

Diffuse with Floyd-Steinberg method

jajuni

Diffuse with Jarvis, Judice & Ninke method

stucki

Diffuse with Stucki's method

burkes

Diffuse with Burkes' method

arithmetic

Positionally stable arithmetic dither

xor

Positionally stable arithmetic xor based dither

`--vo-sixel-fixedpalette=<yes|no>` (default: yes)

Use libsixel's built-in static palette using the XTERM256 profile
for dither. Fixed palette uses 256 colors for dithering. Note that
using `no` (at the time of writing) will slow down `xterm`.

`--vo-sixel-reqcolors=<colors>` (default: 256)

Has no effect with fixed palette. Set up libsixel to use required
number of colors for dynamic palette. This value depends on the
terminal emulator as well. Xterm supports 256 colors. Can set this to
a lower value for faster performance.

`--vo-sixel-threshold=<threshold>` (default: -1)

Has no effect with fixed palette. Defines the threshold to change the
palette - as percentage of the number of colors, e.g. 20 will change
the palette when the number of colors changed by 20%. It's a simple
measure to reduce the number of palette changes, because it can be slow
in some terminals (`xterm`). The default (-1) will choose a palette
on every frame and will have better quality.

`image`

Output each frame into an image file in the current directory. Each file
takes the frame number padded with leading zeros as name.

The following global options are supported by this video output:

`--vo-image-format=<format>`

Select the image file format.

jpg

JPEG files, extension .jpg. (Default.)

jpeg

JPEG files, extension .jpeg.

png

PNG files.

webp

WebP files.

`--vo-image-png-compression=<0-9>`

PNG compression factor (speed vs. file size tradeoff) (default: 7)

`--vo-image-png-filter=<0-5>`

Filter applied prior to PNG compression (0 = none; 1 = sub; 2 = up;
3 = average; 4 = Paeth; 5 = mixed) (default: 5)

`--vo-image-jpeg-quality=<0-100>`

JPEG quality factor (default: 90)

`--vo-image-jpeg-optimize=<0-100>`

JPEG optimization factor (default: 100)

`--vo-image-webp-lossless=<yes|no>`

Enable writing lossless WebP files (default: no)

`--vo-image-webp-quality=<0-100>`

WebP quality (default: 75)

`--vo-image-webp-compression=<0-6>`

