### OSD Commands

`show-text <text> [<duration>|-1 [<level>]]`

Show text on the OSD. The string can contain properties, which are expanded
as described in [Property Expansion](manual-property-list-1.md). This can be used to show playback
time, filename, and so on. `no-osd` has no effect on this command.

<duration>

The time in ms to show the message for. By default, it uses the same
value as `--osd-duration`.

<level>

The minimum OSD level to show the text at (see `--osd-level`).

`show-progress`

Show the progress bar, the elapsed time and the total duration of the file
on the OSD. `no-osd` has no effect on this command.

`overlay-add <id> <x> <y> <file> <offset> <fmt> <w> <h> <stride> <dw> <dh>`

Add an OSD overlay sourced from raw data. This might be useful for scripts
and applications controlling mpv, and which want to display things on top
of the video window.

Overlays are usually displayed in screen resolution, but with some VOs,
the resolution is reduced to that of the video's. You can read the
`osd-width` and `osd-height` properties. At least with `--vo-xv` and
anamorphic video (such as DVD), `osd-par` should be read as well, and the
overlay should be aspect-compensated.

This has the following named arguments. The order of them is not guaranteed,
so you should always call them with named arguments, see [Named arguments](manual-input-commands-1.md).

`id` is an integer between 0 and 63 identifying the overlay element. The
ID can be used to add multiple overlay parts, update a part by using this
command with an already existing ID, or to remove a part with
`overlay-remove`. Using a previously unused ID will add a new overlay,
while reusing an ID will update it.

`x` and `y` specify the position where the OSD should be displayed.

`file` specifies the file the raw image data is read from. It can be
either a numeric UNIX file descriptor prefixed with `@` (e.g. `@4`),
or a filename. The file will be mapped into memory with `mmap()`,
copied, and unmapped before the command returns (changed in mpv 0.18.1).

It is also possible to pass a raw memory address for use as bitmap memory
by passing a memory address as integer prefixed with an `&` character.
Passing the wrong thing here will crash the player. This mode might be
useful for use with libmpv. The `offset` parameter is simply added to the
memory address (since mpv 0.8.0, ignored before).

`offset` is the byte offset of the first pixel in the source file.
(The current implementation always mmap's the whole file from position 0 to
the end of the image, so large offsets should be avoided. Before mpv 0.8.0,
the offset was actually passed directly to `mmap`, but it was changed to
make using it easier.)

`fmt` is a string identifying the image format. Currently, only `bgra`
is defined. This format has 4 bytes per pixels, with 8 bits per component.
The least significant 8 bits are blue, and the most significant 8 bits
are alpha (in little endian, the components are B-G-R-A, with B as first
byte). This uses premultiplied alpha: every color component is already
multiplied with the alpha component. This means the numeric value of each
component is equal to or smaller than the alpha component. (Violating this
rule will lead to different results with different VOs: numeric overflows
resulting from blending broken alpha values is considered something that
shouldn't happen, and consequently implementations don't ensure that you
get predictable behavior in this case.)

`w`, `h`, and `stride` specify the size of the overlay. `w` is the
visible width of the overlay, while `stride` gives the width in bytes in
memory. In the simple case, and with the `bgra` format, `stride==4*w`.
In general, the total amount of memory accessed is `stride * h`.
(Technically, the minimum size would be `stride * (h - 1) + w * 4`, but
for simplicity, the player will access all `stride * h` bytes.)

`dw` and `dh` specify the (optional) display size of the overlay.
The overlay visible portion of the overlay (`w` and `h`) is scaled to
in display to `dw` and `dh`.  If parameters are not present, the
values for `w` and `h` are used.

Note

Before mpv 0.18.1, you had to do manual "double buffering" when updating
an overlay by replacing it with a different memory buffer. Since mpv
0.18.1, the memory is simply copied and doesn't reference any of the
memory indicated by the command's arguments after the command returns.
If you want to use this command before mpv 0.18.1, reads the old docs
to see how to handle this correctly.

`overlay-remove <id>`

Remove an overlay added with `overlay-add` and the same ID. Does nothing
if no overlay with this ID exists.

`osd-overlay`

Add/update/remove an OSD overlay.

(Although this sounds similar to `overlay-add`, `osd-overlay` is for
text overlays, while `overlay-add` is for bitmaps. Maybe `overlay-add`
will be merged into `osd-overlay` to remove this oddity.)

You can use this to add text overlays in ASS format. ASS has advanced
positioning and rendering tags, which can be used to render almost any kind
of vector graphics.

This command accepts the following parameters:

`id`

Arbitrary integer that identifies the overlay. Multiple overlays can be
added by calling this command with different `id` parameters. Calling
this command with the same `id` replaces the previously set overlay.

There is a separate namespace for each libmpv client (i.e. IPC
connection, script), so IDs can be made up and assigned by the API user
without conflicting with other API users.

If the libmpv client is destroyed, all overlays associated with it are
also deleted. In particular, connecting via `--input-ipc-server`,
adding an overlay, and disconnecting will remove the overlay immediately
again.

`format`

String that gives the type of the overlay. Accepts the following values
(HTML rendering of this is broken, view the generated manpage instead,
or the raw RST source):

`ass-events`

The `data` parameter is a string. The string is split on the
newline character. Every line is turned into the `Text` part of
a `Dialogue` ASS event. Timing is unused (but behavior of timing
dependent ASS tags may change in future mpv versions).

Note that it's better to put multiple lines into `data`, instead
of adding multiple OSD overlays.

This provides 2 ASS `Styles`. `OSD` contains the text style as
defined by the current `--osd-...` options. `Default` is
similar, and contains style that `OSD` would have if all options
were set to the default.

In addition, the `res_x` and `res_y` options specify the value
of the ASS `PlayResX` and `PlayResY` header fields. If `res_y`
is set to 0, `PlayResY` is initialized to an arbitrary default
value (but note that the default for this command is 720, not 0).
If `res_x` is set to 0, `PlayResX` is set based on `res_y`
such that a virtual ASS pixel has a square pixel aspect ratio.

`none`

Special value that causes the overlay to be removed. Most parameters
other than `id` and `format` are mostly ignored.

`data`

String defining the overlay contents according to the `format`
parameter.

`res_x`, `res_y`

Used if `format` is set to `ass-events` (see description there).
Optional, defaults to 0/720.

`z`

The Z order of the overlay. Optional, defaults to 0.

Note that Z order between different overlays of different formats is
static, and cannot be changed (currently, this means that bitmap
overlays added by `overlay-add` are always on top of the ASS overlays
added by `osd-overlay`). In addition, the builtin OSD components are
always below any of the custom OSD. (This includes subtitles of any kind
as well as text rendered by `show-text`.)

It's possible that future mpv versions will randomly change how Z order
between different OSD formats and builtin OSD is handled.

`hidden`

If set to true, do not display this (default: false).

`compute_bounds`

If set to true, attempt to determine bounds and write them to the
command's result value as `x0`, `x1`, `y0`, `y1` rectangle
(default: false). If the rectangle is empty, not known, or somehow
