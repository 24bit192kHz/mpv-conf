
This option specifies the vertical margins of unstyled text subtitles.
If you just want to raise the vertical subtitle position, use `--sub-pos`.

Default: 34

`--sub-align-x=<left|center|right>`

Control to which corner of the screen text subtitles should be
aligned to (default: `center`).

Never applied to ASS subtitles, except in `--sub-ass=no` mode. Likewise,
this does not apply to image subtitles.

`--sub-align-y=<top|center|bottom>`

Vertical position (default: `bottom`).
Details see `--sub-align-x`.

`--sub-justify=<auto|left|center|right>`

Control how multi line subs are justified irrespective of where they
are aligned (default: `auto` which justifies as defined by
`--sub-align-x`).
Left justification is recommended to make the subs easier to read
as it is easier for the eyes.

`--sub-ass-justify=<yes|no>`

Applies justification as defined by `--sub-justify` on ASS subtitles
if `--sub-ass-override` is not set to `no`.
Default: `no`.

`--sub-shadow-offset=<size>`

Displacement of the sub text shadow in scaled pixels (see
`--sub-font-size` for details). A value of 0 disables shadows.

Default: 0.

`--sub-spacing=<size>`

Horizontal sub font spacing in scaled pixels (see `--sub-font-size`
for details). This value is added to the normal letter spacing. Negative
values are allowed.

Default: 0.

`--sub-filter-sdh=<yes|no>`

Applies filter removing subtitle additions for the deaf or hard-of-hearing (SDH).
This is intended for English, but may in part work for other languages too.
The intention is that it can be always enabled so may not remove
all parts added.

It removes speaker labels (like MAN:) and any text enclosed within symbols like
parentheses or brackets as specified by the `--sub-filter-sdh-enclosures` option.
Note that parenthesis (full width parenthesis and the normal variant) are a special
case and only upper case text is removed. For more filtering, you can use the
`--sub-filter-sdh-harder` option.

Default: `no`.

`--sub-filter-sdh-harder=<yes|no>`

Do harder SDH filtering (if enabled by `--sub-filter-sdh`).
Will also remove speaker labels and text within parentheses using both
lower and upper case letters.

Default: `no`.

`--sub-filter-sdh-enclosures=<string>`

Specify pairs of characters that `--sub-filter-sdh` will use to
potentially remove text. This is a string list option. See [List Options](manual-options-track.md)
for details. Text that is enclosed within each specified pair will be
removed. Note that parenthesis pairs (normal and full width) are treated as
a special case and require `--sub-fitler-sdh-harder` to be removed.

Default: `(),[],（）`

`--sub-filter-regex-...=...`

Set a list of regular expressions to match on text subtitles, and remove any
lines that match (default: empty). This is a string list option. See
[List Options](manual-options-track.md) for details. Normally, you should use
`--sub-filter-regex-append=<regex>`, where each option use will append a
new regular expression, without having to fight escaping problems.

List items are matched in order. If a regular expression matches, the
process is stopped, and the subtitle line is discarded. The text matched
against is, by default, the `Text` field of ASS events (if the
subtitle format is different, it is always converted). This may include
formatting tags. Matching is case-insensitive, but how this is done depends
on the libc, and most likely works in ASCII only. It does not work on
bitmap/image subtitles. Unavailable on inferior OSes (requires POSIX regex
support).

Example

`--sub-filter-regex-append=opensubtitles\.org` filters some ads.

Technically, using a list for matching is redundant, since you could just
use a single combined regular expression. But it helps with diagnosis,
ease of use, and temporarily disabling or enabling individual filters.

Warning

This is experimental. The semantics most likely will change, and if you
use this, you should be prepared to update the option later. Ideas
include replacing the regexes with a very primitive and small subset of
sed, or some method to control case-sensitivity.

`--sub-filter-jsre-...=...`

Same as `--sub-filter-regex` but with JavaScript regular expressions.
Shares/affected-by all `--sub-filter-regex-*` control options (see below),
and also experimental. Requires only JavaScript support.

`--sub-filter-regex-plain=<yes|no>`

Whether to first convert the ASS "Text" field to plain-text (default: no).
This strips ASS tags and applies ASS directives, like `\N` to new-line.
If the result is multi-line then the regexp anchors `^` and `$` match
each line, but still any match discards all lines.

`--sub-filter-regex-warn=<yes|no>`

Log dropped lines with warning log level, instead of verbose (default: no).
Helpful for testing.

`--sub-filter-regex-enable=<yes|no>`

Whether to enable regex filtering (default: yes). Note that if no regexes
are added to the `--sub-filter-regex` list, setting this option to `yes`
has no effect. It's meant to easily disable or enable filtering
temporarily.

`--sub-create-cc-track=<yes|no>`

For every video stream, create a closed captions track (default: no). The
only purpose is to make the track available for selection at the start of
playback, instead of creating it lazily. This applies only to
`ATSC A53 Part 4 Closed Captions` (displayed by mpv as subtitle tracks
using the codec `eia_608`). The CC track is marked "default" and selected
according to the normal subtitle track selection rules. You can then use
`--sid` to explicitly select the correct track too.

If the video stream contains no closed captions, or if no video is being
decoded, the CC track will remain empty and will not show any text.

`--sub-font-provider=<auto|none|fontconfig>`

Which libass font provider backend to use (default: auto). `auto` will
attempt to use the native font provider: fontconfig on Linux, CoreText on
macOS, DirectWrite on Windows. `fontconfig` forces fontconfig, if libass
was built with support (if not, it behaves like `none`).

The `none` font provider effectively disables system fonts. It will still
attempt to use embedded fonts (unless `--embeddedfonts=no` is set; this is
the same behavior as with all other font providers), `subfont.ttf` if
provided, and fonts in  the `fonts` sub-directory if provided. (The
fallback is more strict than that of other font providers, and if a font
name does not match, it may prefer not to render any text that uses the
missing font.)

`--sub-fonts-dir=

`

Font files in this directory are used by mpv/libass for subtitles. Useful
if you do not want to install fonts to your system. Note that files in this
directory are loaded into memory before being used by mpv. If you have a
lot of fonts, consider using fonts.conf (see [FILES](manual-files.md) section) to include
additional mpv user settings.

If this option is not specified, `~~/fonts` will be used by default.
