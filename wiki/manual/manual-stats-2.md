
Default: 1.65

Size of border drawn around the font.

`border_color`

Default: same as `osd-border-color`

Color of the text border.

`shadow_x_offset`

Default: same as `--osd-shadow-offset`

The horizontal distance from the text to position the shadow at.

`shadow_y_offset`

Default: same as `--osd-shadow-offset`

The vertical distance from the text to position the shadow at.

`shadow_color`

Default: same as `osd-shadow-color`

Color of the text shadow.

`alpha`

Default: 11

Transparency of text when `font_color` is specified, of text borders when
`border_color` is specified, and of text shadows when `shadow_color` is
specified.

`plot_bg_border_color`

Default: 0000FF

Border color used for drawing graphs.

`plot_bg_border_width`

Default: 1.25

Border width used for drawing graphs.

`plot_bg_color`

Default: 262626

Background color used for drawing graphs.

`plot_color`

Default: FFFFFF

Color used for drawing graphs.

`vidscale`

Default: auto

Scale the text and graphs with the video.
`no` tries to keep the sizes constant.
`auto` scales the text and graphs with the OSD, which is scaled with the
window or kept at a constant size, depending on the `--osd-scale-by-window` option.

Note: colors are given as hexadecimal values and use ASS tag order: BBGGRR
(blue green red).

### Different key bindings

Additional keys can be configured in `input.conf` to display the stats:

```
e script-binding stats/display-stats
E script-binding stats/display-stats-toggle
```

And to display a certain page directly:

```
i script-binding stats/display-page-1
h script-binding stats/display-page-4-toggle
```

### Active key bindings page

Lists the active key bindings and the commands they're bound to, excluding the
interactive keys of the stats script itself. See also `--input-test` for more
detailed view of each binding.

The keys are grouped automatically using a simple analysis of the command
string, and one should not expect documentation-level grouping accuracy,
however, it should still be reasonably useful.

Using `--idle --script-opt=stats-bindlist=yes` will print the list to
the terminal and quit immediately. Long lines are clipped to the terminal width
unless this is disabled with `--script-opt=stats-term_clip=no`. Escape
sequences can be disabled by adding `-` before `yes`, i.e.
`--script-opt=stats-bindlist=-yes`.

Like with `--input-test`, the list includes bindings from `input.conf` and
from user scripts. Use `--no-config` to list only built-in bindings.

### Internal stuff page

Most entries shown on this page have rather vague meaning. Likely none of this
is useful for you. Don't attempt to use it. Forget its existence.

Selecting this for the first time will start collecting some internal
performance data. That means performance will be slightly lower than normal for
the rest of the time the player is running (even if the stats page is closed).
Note that the stats page itself uses a lot of CPU and even GPU resources, and
may have a heavy impact on performance.

The displayed information is accumulated over the redraw delay (shown as
`poll-time` field).

This adds entries for each Lua script. If there are too many scripts running,
parts of the list will simply be out of the screen, but it can be scrolled.

If the underlying platform does not support pthread per thread times, the
displayed times will be 0 or something random (I suspect that at time of this
writing, only Linux provides the correct via pthread APIs for per thread times).

Most entries are added lazily and only during data collection, which is why
entries may pop up randomly after some time. It's also why the memory usage
entries for scripts that have been inactive since the start of data collection
are missing.

Memory usage is approximate and does not reflect internal fragmentation.

JS scripts memory reporting is disabled by default because collecting the data
at the JS side has an overhead and will increase memory usage. It can be
enabled by setting the `--js-memory-report` option before starting mpv.

If entries have `/time` and `/cpu` variants, the former gives the real time
(monotonic clock), while the latter the thread CPU time (only if the
corresponding pthread API works and is supported).
