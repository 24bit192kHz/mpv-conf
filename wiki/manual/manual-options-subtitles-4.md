
`--sub-visibility=<yes|no>`

Can be used to disable display of subtitles, but still select and decode
them.

`--secondary-sub-visibility=<yes|no>`

Can be used to disable display of secondary subtitles, but still select and
decode them.

`--sub-clear-on-seek`

(Obscure, rarely useful.) Can be used to play broken mkv files with
duplicate ReadOrder fields. ReadOrder is the first field in a
Matroska-style ASS subtitle packets. It should be unique, and libass
uses it for fast elimination of duplicates. This option disables caching
of subtitles across seeks, so after a seek libass can't eliminate subtitle
packets with the same ReadOrder as earlier packets. Note that enabling this
option can result in broken subtitle behavior if you are not actually
playing one of the aforementioned broken mkv files.

`--teletext-page=<-1-999>`

Select a teletext page number to decode.

This works for `dvb_teletext` subtitle streams, and if FFmpeg has been
compiled with support for it.

Values `1-999` are for individual pages. Special value `0` (default)
matches all subtitle pages. Special value `-1` matches all pages.

Note that page `100` is the default start page of actual teletext. It is
also the former default value of this option.

See the `libzvbi-teletext` section in FFmpeg documentation for details.

Default: 0

`--sub-past-video-end`

After the last frame of video, if this option is enabled, subtitles will
continue to update based on audio timestamps. Otherwise, the subtitles
for the last video frame will stay onscreen.

Default: disabled

`--sub-font=<name>`

Specify font to use for subtitles that do not themselves
specify a particular font. The default is `sans-serif`.

Examples

- `--sub-font='Bitstream Vera Sans'`

- `--sub-font='Comic Sans MS'`

Note

The `--sub-font` option (and many other style related `--sub-`
options) are ignored when ASS-subtitles are rendered, unless
`--sub-ass=no` is specified.

This used to support fontconfig patterns. Starting with libass 0.13.0,
this stopped working.

`--sub-font-size=<size>`

Specify the sub font size. The unit is the size in scaled pixels at a
window height of 720. The actual pixel size is scaled with the window
height: if the window height is larger or smaller than 720, the actual size
of the text increases or decreases as well.

Default: 38

`--sub-blur=<0..20.0>`

Gaussian blur factor applied to the sub font border.
0 means no blur applied (default).

`--sub-bold=<yes|no>`

Format text on bold.

`--sub-italic=<yes|no>`

Format text on italic.

`--sub-outline-color=<color>`

See `--sub-color`. Color used for the sub font outline.

`--sub-border-color` is an alias for `--sub-outline-color`.

`--sub-back-color=<color>`

See `--sub-color`. Color used for sub text background.

`--sub-shadow-color` is an alias for `--sub-back-color`.

`--sub-outline-size=<size>`

Size of the sub font outline in scaled pixels (see `--sub-font-size`
for details). A value of 0 disables outlines.

`--sub-border-size` is an alias for `--sub-outline-size`.

Default: 1.65

`--sub-border-style=<outline-and-shadow|opaque-box|background-box>`

The style of the border.

- `outline-and-shadow`: draw outline and shadow.
The size of the outline is determined by `--sub-outline-size`,
and the offset of the shadow is determined by `--sub-shadow-offset`.
The outline is colored by `--sub-outline-color`,
and the shadow is colored by `--sub-back-color`.
This corresponds to `BorderStyle=1` in the ASS spec.

- `opaque-box`: draw outline and shadow as opaque boxes that tightly wrap each lines of text.
The margin of the outline opaque box is determined by `--sub-outline-size`,
and the offset of the shadow opaque box is determined by `--sub-shadow-offset`.
The outline opaque box is colored by `--sub-outline-color`,
and the shadow opaque box is colored by `--sub-back-color`.
Despite its name, the opaque box can be semi-transparent.
This corresponds to `BorderStyle=3` in the ASS spec.

- `background-box`: draw a background box that bounds all lines of text.
The background box is colored by `--sub-back-color`,
and the margin of the background box is determined by `--sub-shadow-offset`.
The behavior of the outline is the same as the `outline-and-shadow` style.
This corresponds to `BorderStyle=4`, which is a libass-specific extension.

Default: `outline-and-shadow`.

Predefined profiles are available to enable optimized `background-box` style
for OSD and subtitles.

Profiles

- `--profile=sub-box` applies the `background-box` style to subtitles

- `--profile=osd-box` applies the `background-box` style to the OSD,
including stats and console

- `--profile=box` applies the `background-box` style to both subtitles and OSD

`--sub-color=<color>`

Specify the color used for unstyled text subtitles.

The color is specified in the form `r/g/b`, where each color component
is specified as number in the range 0.0 to 1.0. It's also possible to
specify the transparency by using `r/g/b/a`, where the alpha value 0
means fully transparent, and 1.0 means opaque. If the alpha component is
not given, the color is 100% opaque.

Passing a single number to the option sets the sub to gray, and the form
`gray/a` lets you specify alpha additionally.

Examples

- `--sub-color=1.0/0.0/0.0` set sub to opaque red

- `--sub-color=1.0/0.0/0.0/0.75` set sub to opaque red with 75% alpha

- `--sub-color=0.5/0.75` set sub to 50% gray with 75% alpha

Alternatively, the color can be specified as a RGB hex triplet in the form
`#RRGGBB`, where each 2-digit group expresses a color value in the
range 0 (`00`) to 255 (`FF`). For example, `#FF0000` is red.
Alpha is given with `#AARRGGBB`.

Examples

- `--sub-color='#FF0000'` set sub to opaque red

- `--sub-color='#C0808080'` set sub to 50% gray with 75% alpha

`--sub-margin-x=<size>`

Left and right screen margin for the subs in scaled pixels (see
`--sub-font-size` for details).

This option specifies the distance of the sub to the left, as well as at
which distance from the right border long sub text will be broken.

Default: 19

`--sub-margin-y=<size>`

Top and bottom screen margin for the subs in scaled pixels (see
`--sub-font-size` for details).
