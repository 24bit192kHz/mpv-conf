## Subtitles

Note

Changing styling and position does not work with all subtitles. Image-based
subtitles (DVD, Bluray/PGS, DVB) cannot changed for fundamental reasons.
Subtitles in ASS format are normally not changed intentionally, but
overriding them can be controlled with `--sub-ass-override`.

`--sub-demuxer=<[+]name>`

Force subtitle demuxer type for `--sub-file`. Give the demuxer name as
printed by `--sub-demuxer=help`.

`--sub-lavc-o=<key>=<value>[,<key>=<value>[,...]]`

Pass AVOptions to libavcodec decoder. Note, a patch to make the o=
unneeded and pass all unknown options through the AVOption system is
welcome. A full list of AVOptions can be found in the FFmpeg manual.

This is a key/value list option. See [List Options](manual-options-track.md) for details.

`--sub-delay=<sec>`

Delays primary subtitles by `<sec>` seconds. Can be negative.

`--secondary-sub-delay=<sec>`

Delays secondary subtitles by `<sec>` seconds. Can be negative.

`--sub-files=<file-list>`, `--sub-file=<filename>`

Add a subtitle file to the list of external subtitles.

If you use `--sub-file` only once, this subtitle file is displayed by
default.

If `--sub-file` is used multiple times, the subtitle to use can be
switched at runtime by cycling subtitle tracks. It's possible to show
two subtitles at once: use `--sid` to select the first subtitle index,
and `--secondary-sid` to select the second index. (The index is printed
on the terminal output after the `--sid=` in the list of streams.)

`--sub-files` is a path list option (see [List Options](manual-options-track.md)  for details), and
can take multiple file names separated by `:` (Unix) or `;` (Windows),
while  `--sub-file` takes a single filename, but can be used multiple
times to add multiple files. Technically, `--sub-file` is a CLI/config
file only alias for  `--sub-files-append`.

`--secondary-sid=<ID|auto|no>`

Select a secondary subtitle stream. This is similar to `--sid`. If a
secondary subtitle is selected, it will be rendered as toptitle (i.e. on
the top of the screen) alongside the normal subtitle by default, and
provides a way to render two subtitles at once.

There are some caveats associated with this feature. For example, bitmap
subtitles will always be rendered in their usual position, so selecting a
bitmap subtitle as secondary subtitle will result in overlapping subtitles.
Secondary subtitles are never shown on the terminal if video is disabled.

Note

Styling and interpretation of any formatting tags is disabled for the
secondary subtitle. Internally, the same mechanism as `--sub-ass=no`
is used to strip the styling.

Note

If the main subtitle stream contains formatting tags which display the
subtitle at the top of the screen, it will overlap with the secondary
subtitle. To prevent this, you could use `--sub-ass=no` to disable
styling in the main subtitle stream.

`--sub-scale=<0-100>`

Factor for the text subtitle font size (default: 1).

Note

This affects ASS subtitles as well, and may lead to incorrect subtitle
rendering. Use with care, or use `--sub-font-size` instead.

`--sub-scale-signs=<yes|no>`

When set to yes, also apply `--sub-scale` to typesetting (or "signs").
When this is set to no, `--sub-scale` is only applied to dialogue. The
distinction between dialogue and typesetting is done on a best effort basis
and is not infallible (default: no).

`--sub-scale-by-window=<yes|no>`

Whether to scale subtitles with the window size (default: yes). If this is
disabled while `--sub-scale-with-window` is set to yes, changing the window
size won't change the subtitle font size.

Affects plain text subtitles only (or ASS if `--sub-ass-override` is set
high enough).

`--sub-scale-with-window=<yes|no>`

Make the subtitle font size relative to the window (default: yes). If this is
disabled while `--sub-scale-by-window` is set to yes, the subtitle font
size is scaled relative to the video size instead.

Affects plain text subtitles only (or ASS if `--sub-ass-override` is set
high enough).

Note

By default, the subtitle font size is scaled with the window size.
To make the font size constant, set only `--sub-scale-by-window` to no.
To make the font size scale with video size instead, set only
`--sub-scale-with-window` to no.
It's not meaningful to set both options to no.

`--sub-ass-scale-with-window=<yes|no>`

Like `--sub-scale-with-window`, but affects subtitles in ASS format only.
Like `--sub-scale`, this can break ASS subtitles.

Default: no.

`--embeddedfonts=<yes|no>`

Use fonts embedded in Matroska container files and ASS scripts (default:
yes). These fonts can be used for SSA/ASS subtitle rendering.

`--sub-pos=<0-150>`

Specify the position of subtitles on the screen. The value is the vertical
position of the subtitle in % of the screen height. 100 is the original
position, which is often not the absolute bottom of the screen, but with
some margin between the bottom and the subtitle. Values above 100 move the
subtitle further down.

Warning

Text subtitles (as opposed to image subtitles) may be cut off if the
value of the option is above 100. This is a libass restriction.

This affects ASS subtitles as well, and may lead to incorrect subtitle
rendering in addition to the problem above.

Using `--sub-margin-y` can achieve this in a better way.

`--secondary-sub-pos=<0-150>`

Specify the position of secondary subtitles on the screen. This is similar
to `--sub-pos` but for secondary subtitles.

`--sub-speed=<0.1-10.0>`

Multiply the subtitle event timestamps with the given value. Can be used
to fix the playback speed for frame-based subtitle formats. Affects text
subtitles only.

Example

`--sub-speed=25/23.976` plays frame based subtitles which have been
loaded assuming a framerate of 23.976 at 25 FPS.

`--sub-ass-style-overrides=<[Style.]Param=Value[,...]>`

Override some style or script info parameters.

This is a string list option. See [List Options](manual-options-track.md) for details.

Examples

- `--sub-ass-style-overrides=FontName=Arial,Default.Bold=1`

- `--sub-ass-style-overrides=PlayResY=768`

Note

Using this option may lead to incorrect subtitle rendering.

`--sub-hinting=<none|light|normal|native>`

Set font hinting type. <type> can be:
| none: | no hinting (default) |
| --- | --- |
| light: | FreeType autohinter, light mode |
| normal: | FreeType autohinter, normal mode |
| native: | font native hinter |

Warning

Enabling hinting can lead to mispositioned text (in situations it's
supposed to match up video background), or reduce the smoothness
of animations with some badly authored ASS scripts. It is recommended
to not use this option, unless really needed.

`--sub-line-spacing=<value>`
