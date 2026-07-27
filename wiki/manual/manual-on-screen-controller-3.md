`yes` - how much playback time remains at the current speed.
`no` - how much video-time remains.

`timems`

Default: no

Display timecodes with milliseconds

`tcspace`

Default: 100 (allowed: 50-200)

Adjust space reserved for timecodes (current time and time remaining) in
the `bottombar` and `topbar` layouts. The timecode width depends on the
font, and with some fonts the spacing near the timecodes becomes too small.
Use values above 100 to increase that spacing, or below 100 to decrease it.

`visibility`

Default: auto (auto hide/show on mouse move)

Also supports `never` and `always`

`visibility_modes`

Default: never_auto_always

The list of visibility modes to cycle through when calling the
osc-visibility cycle script message. Modes are separated by `_`.

`boxmaxchars`

Default: 80

Max chars for the osc title at the box layout. mpv does not measure the
text width on screen and so it needs to limit it by number of chars. The
default is conservative to allow wide fonts to be used without overflow.
However, with many common fonts a bigger number can be used. YMMV.

`boxvideo`

Default: no

Whether to overlay the osc over the video (`no`), or to box the video
within the areas not covered by the osc (`yes`). If this option is set,
the osc may overwrite the `--video-margin-ratio-*` options, even if the
user has set them. (It will not overwrite them if all of them are set to
default values.) Additionally, `visibility` must be set to `always`.
Otherwise, this option does nothing.

Currently, this is supported for the `bottombar`, `slimbottombar`,
`topbar` and `slimtopbar` layouts only. The other layouts do not change
if this option is set. Separately, if window controls are present (see
below), they will be affected regardless of which osc layout is in use.

The border is static and appears even if the OSC is configured to appear
only on mouse interaction. If the OSC is invisible, the border is simply
filled with the background color (black by default).

This currently still makes the OSC overlap with subtitles (if the
`--sub-use-margins` option is set to `yes`, the default). This may be
fixed later.

This does not work correctly with video outputs like `--vo=xv`, which
render OSD into the unscaled video.

`windowcontrols`

Default: auto (Show window controls if there is no window border)

Whether to show window management controls over the video, and if so,
which side of the window to place them. This may be desirable when the
window has no decorations, either because they have been explicitly
disabled (`border=no`) or because the current platform doesn't support
them (eg: gnome-shell with wayland).

The set of window controls is fixed, offering `minimize`, `maximize`,
and `quit`. Not all platforms implement `minimize` and `maximize`,
but `quit` will always work.

`windowcontrols_alignment`

Default: right

If window controls are shown, indicates which side should they be aligned
to.

Supports `left` and `right` which will place the controls on those
respective sides.

`windowcontrols_title`

Default: ${media-title}

String that supports property expansion that will be displayed as the
windowcontrols title.
ASS tags are escaped, and newlines and trailing slashes are stripped.

`greenandgrumpy`

Default: no

Set to `yes` to reduce festivity (i.e. disable santa hat in December.)

`livemarkers`

Default: yes

Update chapter markers positions on duration changes, e.g. live streams.
The updates are unoptimized - consider disabling it on very low-end systems.

`chapter_fmt`

Default: `Chapter: %s`

Template for the chapter-name display when hovering the seekbar.
Use `no` to disable chapter display on hover. Otherwise it's a lua
`string.format` template and `%s` is replaced with the actual name.

`unicodeminus`

Default: no

Use a Unicode minus sign instead of an ASCII hyphen when displaying
the remaining playback time.

`background_color`

Default: #000000

Sets the background color of the OSC.

`timecode_color`

Default: #FFFFFF

Sets the color of the timecode and seekbar, of the OSC.

`title_color`

Default: #FFFFFF

Sets the color of the video title. Formatted as #RRGGBB.

`time_pos_color`

Default: #FFFFFF

Sets the color of the timecode at hover position in the seekbar.

`time_pos_outline_color`

Default: #FFFFFF

Sets the color of the timecode's outline at hover position in the seekbar.
Also affects the timecode in the slimbox layout.

`buttons_color`

Default: #FFFFFF

Sets the colors of the big buttons.

`top_buttons_color`

Default: #FFFFFF

Sets the colors of the top buttons.

`small_buttonsL_color`

Default: #FFFFFF

Sets the colors of the small buttons on the left in the box layout.

`small_buttonsR_color`

Default: #FFFFFF

Sets the colors of the small buttons on the right in the box layout.

`held_element_color`

Default: #999999

Sets the colors of the elements that are being pressed or held down.

`tick_delay`

Default: 1/60

Sets the minimum interval between OSC redraws in seconds. This can be
decreased on fast systems to make OSC rendering smoother.

