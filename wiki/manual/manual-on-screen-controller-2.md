### Configurable Options

`layout`

Default: bottombar

The layout for the OSC. Currently available are: box, slimbox,
bottombar, topbar, slimbottombar and slimtopbar. Default pre-0.21.0 was
'box'.

`seekbarstyle`

Default: bar

Sets the style of the playback position marker and overall shape
of the seekbar: `bar`, `diamond` or `knob`.

`seekbarhandlesize`

Default: 0.6

Size ratio of the seek handle if `seekbarstyle` is set to `diamond`
or `knob`. This is relative to the full height of the seekbar.

`seekbarkeyframes`

Default: yes

Controls the mode used to seek when dragging the seekbar. If set to `yes`,
default seeking mode is used (usually keyframes, but player defaults and
heuristics can change it to exact). If set to `no`, exact seeking on
mouse drags will be used instead. Keyframes are preferred, but exact seeks
may be useful in cases where keyframes cannot be found. Note that using
exact seeks can potentially make mouse dragging much slower.

`seekrangestyle`

Default: inverted

Display seekable ranges on the seekbar. `bar` shows them on the full
height of the bar, `line` as a thick line and `inverted` as a thin
line that is inverted over playback position markers. `none` will hide
them. Additionally, `slider` will show a permanent handle inside the seekbar
with cached ranges marked inside. Note that these will look differently
based on the seekbarstyle option. Also, `slider` does not work with
`seekbarstyle` set to `bar`.

`seekrangeseparate`

Default: yes

Controls whether to show line-style seekable ranges on top of the
seekbar or separately if `seekbarstyle` is set to `bar`.

`seekrangealpha`

Default: 20

Alpha of the seekable ranges, 0 (opaque) to 255 (fully transparent).

`scrollcontrols`

Default: yes

By default, going up or down with the mouse wheel can trigger certain
actions (such as seeking) if the mouse is hovering an OSC element.
Set to `no` to disable any special mouse wheel behavior.

`deadzonesize`

Default: 0.5

Size of the deadzone. The deadzone is an area that makes the mouse act
like leaving the window. Movement there won't make the OSC show up and
it will hide immediately if the mouse enters it. The deadzone starts
at the window border opposite to the OSC and the size controls how much
of the window it will span. Values between 0.0 and 1.0, where 0 means the
OSC will always popup with mouse movement in the window, and 1 means the
OSC will only show up when the mouse hovers it. Default pre-0.21.0 was 0.

`minmousemove`

Default: 0

Minimum amount of pixels the mouse has to move between ticks to make
the OSC show up. Default pre-0.21.0 was 3.

`showwindowed`

Default: yes

Enable the OSC when windowed

`showfullscreen`

Default: yes

Enable the OSC when fullscreen

`idlescreen`

Default: yes

Show the mpv logo and message when idle

`scalewindowed`

Default: 1.0

Scale factor of the OSC when windowed.

`scalefullscreen`

Default: 1.0

Scale factor of the OSC when fullscreen

`vidscale`

Default: auto

Scale the OSC with the video.
`no` tries to keep the OSC size constant as much as the window size allows.
`auto` scales the OSC with the OSD, which is scaled with the window or kept at a
constant size, depending on the `--osd-scale-by-window` option.

`valign`

Default: 0.8

Vertical alignment in box and slimbox layouts, -1 (top) to 1 (bottom).

`halign`

Default: 0.0

Horizontal alignment in box and slimbox layouts, -1 (left) to 1 (right).

`barmargin`

Default: 0

Margin from bottom (bottombar, slimbottombar) or top (topbar, slimtopbar),
in pixels.

`boxalpha`

Default: 80

Alpha of the background box, 0 (opaque) to 255 (fully transparent)

`hidetimeout`

Default: 500

Duration in ms until the OSC hides if no mouse movement, must not be
negative

`fadeduration`

Default: 200

Duration of fade effects in ms, 0 = no fade.

`fadein`

Default: no

Enable fade-in.

`title`

Default: ${!playlist-count==1:[${playlist-pos-1}/${playlist-count}] }${media-title}

String that supports property expansion that will be displayed as
OSC title.
ASS tags are escaped and newlines are converted to spaces.

`tooltipborder`

Default: 1

Size of the tooltip outline when using bottombar or topbar layouts

`timetotal`

Default: no

Show total time instead of time remaining

`remaining_playtime`

Default: yes

Whether the time-remaining display takes speed into account.
