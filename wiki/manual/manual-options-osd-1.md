## OSD

`--osc=<yes|no>`

Whether to load the on-screen-controller (default: yes).

`--osd-bar=<yes|no>`

Enable display of the OSD bar (default: yes).

You can configure this on a per-command basis in input.conf using `osd-`
prefixes, see `Input Command Prefixes`. If you want to disable the OSD
completely, use `--osd-level=0`.

`--osd-on-seek=<no,bar,msg,msg-bar>`

Set what is displayed on the OSD during seeks. The default is `bar`.

You can configure this on a per-command basis in input.conf using `osd-`
prefixes, see `Input Command Prefixes`.

`--osd-duration=<time>`

Set the duration of the OSD messages in ms (default: 1000).

`--osd-font=<name>`

Specify font to use for OSD. The default is `sans-serif`.

Examples

- `--osd-font='Bitstream Vera Sans'`

- `--osd-font='Comic Sans MS'`

`--osd-font-size=<size>`

Specify the OSD font size. See `--sub-font-size` for details.

Default: 30

`--osd-msg1=<string>`

Show this string as message on OSD with OSD level 1 (visible by default).
The message will be visible by default, and as long as no other message
covers it, and the OSD level isn't changed (see `--osd-level`).
Expands properties; see [Property Expansion](manual-property-list-1.md).

`--osd-msg2=<string>`

Similar to `--osd-msg1`, but for OSD level 2. If this is an empty string
(default), then the playback time is shown.

`--osd-msg3=<string>`

Similar to `--osd-msg1`, but for OSD level 3. If this is an empty string
(default), then the playback time, duration, and some more information is
shown.

This is used for the `show-progress` command (by default mapped to `P`),
and when seeking if enabled with `--osd-on-seek` or by `osd-` prefixes
in input.conf (see `Input Command Prefixes`).

`--osd-status-msg` is a legacy equivalent (but with a minor difference).

`--osd-status-msg=<string>`

Show a custom string during playback instead of the standard status text.
This overrides the status text used for `--osd-level=3`, when using the
`show-progress` command (by default mapped to `P`), and when seeking if
enabled with `--osd-on-seek` or `osd-` prefixes in input.conf (see
`Input Command Prefixes`). Expands properties. See [Property Expansion](manual-property-list-1.md).

This option has been replaced with `--osd-msg3`. The only difference is
that this option implicitly includes `${osd-sym-cc}`. This option is
ignored if `--osd-msg3` is not empty.

`--osd-playing-msg=<string>`

Show a message on OSD when playback starts. The string is expanded for
properties, e.g. `--osd-playing-msg='file: ${filename}'` will show the
message `file:` followed by a space and the currently played filename.

See [Property Expansion](manual-property-list-1.md).

`--osd-playing-msg-duration=<time>`

Set the duration of `osd-playing-msg` in ms. If this is unset,
`osd-playing-msg` stays on screen for the duration of `osd-duration`.

`--osd-playlist-entry=<title|filename|both>`

Whether to display the media title, filename, or both. If the
`media-title` is not available, it will display only the `filename`.

Default: `title`.

`--osd-bar-align-x=<-1-1>`

Position of the OSD bar. -1 is far left, 0 is centered, 1 is far right.
Fractional values (like 0.5) are allowed.

`--osd-bar-align-y=<-1-1>`

Position of the OSD bar. -1 is top, 0 is centered, 1 is bottom.
Fractional values (like 0.5) are allowed.

`--osd-bar-w=<1-100>`

Width of the OSD bar, in percentage of the screen width (default: 75).
A value of 50 means the bar is half the screen wide.

`--osd-bar-h=<0.1-50>`

Height of the OSD bar, in percentage of the screen height (default: 3.125).

`--osd-bar-outline-size=<size>`

Size of the outline of the OSD bar in scaled pixels (see `--sub-font-size`
for details).

`--osd-bar-border-size` is an alias for `--osd-bar-outline-size`.

Default: 0.5.

`--osd-bar-marker-scale=<0-100>`

Factor for the OSD bar marker size relative to the OSD bar outline size.

Default: 1.3.

`--osd-bar-marker-min-size=<size>`

Minimum OSD bar marker size.

Default: 1.6.

`--osd-bar-marker-style=<none|triangle|line>`

Set the OSD bar marker style.
| none: | Don't draw markers. |
| --- | --- |
| triangle: | Draw markers as triangles (default). |
| line: | Draw markers as lines. |

`--osd-blur=<0..20.0>`

Gaussian blur factor applied to the OSD font border.
0 means no blur applied (default).

`--osd-bold=<yes|no>`

Format text on bold.

`--osd-italic=<yes|no>`

Format text on italic.

`--osd-outline-color=<color>`

See `--sub-color`. Color used for the OSD font outline.

`--osd-border-color` is an alias for `--osd-outline-color`.

`--osd-back-color=<color>`

See `--sub-color`. Color used for OSD text background.

`--osd-shadow-color` is an alias for `--osd-back-color`.

`--osd-outline-size=<size>`

Size of the OSD font outline in scaled pixels (see `--sub-font-size`
for details). A value of 0 disables outlines.

`--osd-border-size` is an alias for `--osd-outline-size`.

Default: 1.65

`--osd-border-style=<outline-and-shadow|opaque-box|background-box>`

See `--sub-border-style`. Style used for OSD text border.

`--osd-color=<color>`

Specify the color used for OSD.
See `--sub-color` for details.

`--osd-selected-color=<color>`

The color of the selected item in lists.
See `--sub-color` for details.

`--osd-selected-outline-color=<color>`

