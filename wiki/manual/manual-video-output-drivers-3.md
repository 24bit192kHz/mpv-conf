This is low quality, and has issues with OSD. We strongly recommend that
you use `--vo=gpu` with `--hwdec=vaapi` instead.

The following global options are supported by this video output:

`--vo-vaapi-scaling=<algorithm>`

default

Driver default (mpv default as well).

fast

Fast, but low quality.

hq

Unspecified driver dependent high-quality scaling, slow.

nla

`non-linear anamorphic scaling`

`--vo-vaapi-scaled-osd=<yes|no>`

If enabled, then the OSD is rendered at video resolution and scaled to
display resolution. By default, this is disabled, and the OSD is
rendered at display resolution if the driver supports it.

`null`

Produces no video output. Useful for benchmarking.

Usually, it's better to disable video with `--video=no` instead.

The following global options are supported by this video output:

`--vo-null-fps=<value>`

Simulate display FPS. This artificially limits how many frames the
VO accepts per second.

`caca`

Color ASCII art video output driver that works on a text console.

This driver reserves some keys for runtime configuration. These keys are
hardcoded and cannot be bound:

d and D

Toggle dithering algorithm.

a and A

Toggle antialiasing method.

h and H

Toggle charset method.

c and C

Toggle color method.

Note

This driver is a joke.

`tct`

Color Unicode art video output driver that works on a text console.
By default depends on support of true color by modern terminals to display
the images at full color range, but 256-colors output is also supported (see
below). On Windows it requires an ansi terminal such as mintty.

Since mpv 0.30.0, you may need to use `--profile=sw-fast` to get decent
performance.

Note: the TCT image output is not synchronized with other terminal output
from mpv, which can lead to broken images. The options `--terminal=no` or
`--really-quiet` can help with that.

`--vo-tct-algo=<algo>`

Select how to write the pixels to the terminal.

half-blocks

Uses Unicode LOWER HALF BLOCK character to achieve higher vertical
resolution. (Default.)

plain

Uses spaces. Causes vertical resolution to drop twofolds, but in
theory works in more places.

`--vo-tct-buffering=

`

Specifies the size of data batches buffered before being sent to the
terminal.

TCT image output is not synchronized with other terminal output from mpv,
which can lead to broken images. Sending data to the terminal in small
batches may improve parallelism between terminal processing and mpv
processing but incurs a static overhead of generating tens of thousands
of small writes. Also, depending on the terminal used, sending frames in
one chunk might help with tearing of the output, especially if not used
with `--really-quiet` and other logs interrupt the data stream.

pixel

Send data to terminal for each pixel.

line

Send data to terminal for each line. (Default)

frame

Send data to terminal for each frame.

`--vo-tct-width=<width>`  `--vo-tct-height=<height>`

Assume the terminal has the specified character width and/or height.
These default to 80x25 if the terminal size cannot be determined.

`--vo-tct-256=<yes|no>` (default: no)

Use 256 colors - for terminals which don't support true color.

`kitty`

Graphical output for the terminal, using the kitty graphics protocol.
Tested with kitty and Konsole.

You may need to use `--profile=sw-fast` to get decent performance.

Kitty size and alignment options:

`--vo-kitty-cols=<columns>`, `--vo-kitty-rows=<rows>` (default: 0)

Specify the terminal size in character cells, otherwise (0) read it
from the terminal, or fall back to 80x25.

`--vo-kitty-width=<width>`, `--vo-kitty-height=<height>` (default: 0)

Specify the available size in pixels, otherwise (0) read it from the
terminal, or fall back to 320x240.

`--vo-kitty-left=<col>`, `--vo-kitty-top=<row>` (default: 0)

Specify the position in character cells where the image starts (1 is
the first column or row). If 0 (default) then try to automatically
determine it according to the other values and the image aspect ratio
and zoom.

`--vo-kitty-config-clear=<yes|no>` (default: yes)

Whether or not to clear the terminal whenever the output is
reconfigured (e.g. when video size changes).

`--vo-kitty-alt-screen=<yes|no>` (default: yes)

Whether or not to use the alternate screen buffer and return the
terminal to its previous state on exit. When set to no, the last
kitty image stays on screen after quit, with the cursor following it.

`--vo-kitty-use-shm=<yes|no>` (default: no)

Use shared memory objects to transfer image data to the terminal.
This is much faster than sending the data as escape codes, but is not
supported by as many terminals. It also only works on the local machine
and not via e.g. SSH connections.

This option is not implemented on Windows.

`--vo-kitty-auto-multiplexer-passthrough=<yes|no>` (default: no)

Automatically detect terminal multiplexer to passthrough escape
sequences. This allows the image protocol to work in multiplexers that
might not support the kitty image protocol by passing through the
escape sequences directly to the terminal.

Currently only supports tmux and GNU screen.

`sixel`

Graphical output for the terminal, using sixels. Tested with `mlterm` and
`xterm`.

Note: the Sixel image output is not synchronized with other terminal
output from mpv, which can lead to broken images.
