The outline color of the selected item in lists.
See `--sub-color` for details.

`--osd-fractions`

Show OSD times with fractions of seconds (in millisecond precision). Useful
to see the exact timestamp of a video frame.

`--osd-level=<0-3>`

Specifies which mode the OSD should start in.
| 0: | OSD completely disabled (subtitles only) |
| --- | --- |
| 1: | enabled (shows up only on user interaction) |
| 2: | enabled + current time visible by default |
| 3: | enabled + `--osd-status-msg` (current time and status by default) |

`--osd-margin-x=<size>`

Left and right screen margin for the OSD in scaled pixels (see
`--sub-font-size` for details).

This option specifies the distance of the OSD to the left, as well as at
which distance from the right border long OSD text will be broken.

Default: 16

`--osd-margin-y=<size>`

Top and bottom screen margin for the OSD in scaled pixels (see
`--sub-font-size` for details).

This option specifies the vertical margins of the OSD.

Default: 16

`--osd-align-x=<left|center|right>`

Control to which corner of the screen OSD should be
aligned to (default: `left`).

`--osd-align-y=<top|center|bottom>`

Vertical position (default: `top`).
Details see `--osd-align-x`.

`--osd-scale=<factor>`

OSD font size multiplier, multiplied with `--osd-font-size` value.

`--osd-scale-by-window=<yes|no>`

Whether to scale the OSD with the window size (default: yes). If this is
disabled, `--osd-font-size` and other OSD options that use scaled pixels
are always in actual pixels. The effect is that changing the window size
won't change the OSD font size.

Note

For scripts which draw user interface elements, it is recommended to
respect the value of this option when deciding whether the elements
are scaled with window size or not.

`--osd-shadow-offset=<size>`

Displacement of the OSD shadow in scaled pixels (see
`--sub-font-size` for details). A value of 0 disables shadows.

Default: 0.

`--osd-spacing=<size>`

Horizontal OSD/sub font spacing in scaled pixels (see `--sub-font-size`
for details). This value is added to the normal letter spacing. Negative
values are allowed.

Default: 0.

`--video-osd=<yes|no>`

Enabled OSD rendering on the video window (default: yes). This can be used
in situations where terminal OSD is preferred. If you just want to disable
all OSD rendering, use `--osd-level=0`.

It does not affect subtitles or overlays created by scripts (in particular,
the OSC needs to be disabled with `--osc=no`).

This option is somewhat experimental and could be replaced by another
mechanism in the future.

`--osd-font-provider=<...>`

See `--sub-font-provider` for details and accepted values. Note that
unlike subtitles, OSD never uses embedded fonts from media files.

`--osd-fonts-dir=

`

See `--sub-fonts-dir` for details.  Defaults to `~~/fonts`.

`--osd-glyph-limit=<value>`

Set the maximum number of cached glyphs in libass cache for the OSD.
0 means libass uses its default value.

Default: 0.

`--osd-bitmap-max-size=<value>`

Set the maximum bitmap cache size in libass cache for the OSD. 0 means
libass uses its default value. This accepts values in MB.

Default: 0.

`--osd-prune-delay=<-1|seconds>`

Set the delay for automatic pruning of events from memory in libass.
Disabled by default. See also `--sub-ass-prune-delay`.

`--osd-shaper=<simple|complex>`

Set the text layout engine used by libass for the OSD. Default: complex.
See also `--sub-shaper`
