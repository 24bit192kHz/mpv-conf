`--image-subs-video-resolution=<yes|no>`

Override the image subtitle resolution with the video resolution
(default: no). Normally, the subtitle canvas is fit into the video canvas
(e.g. letterboxed). Setting this option uses the video size as subtitle
canvas size. Can be useful to test broken subtitles, which often happen
when the video was transcoded, while attempting to keep the old subtitles.

`--image-subs-hdr-peak=<sdr|video|10-10000>`

Controls the image subtitle diffuse white level in cd/m² (nits) for HDR
output (default: sdr). `sdr` is 203 cd/m² for standard SDR white, while
`video` uses video metadata. (`--vo=gpu-next` only)

This also affects image subtitle brightness in HDR tone mapping with
`--blend-subtitles=<yes|video>`.

`--sub-hdr-peak=<sdr|10-10000>`

Controls the text subtitle and OSD diffuse white level in cd/m² (nits)
for HDR output (default: sdr). `sdr` is 203 cd/m² for standard SDR white.
(`--vo=gpu-next` only)

This also affects text subtitle brightness in HDR tone mapping with
`--blend-subtitles=<yes|video>`.

`--sub-ass=<yes|no>`

Render ASS subtitles natively (default: yes).

Note

This has been deprecated by `--sub-ass-override=strip`. You also
may need `--embeddedfonts=no` to get the same behavior. Also,
using `--sub-ass-override=style` should give better results
without breaking subtitles too much.

If `--sub-ass=no` is specified, all tags and style declarations are
stripped and ignored on display. The subtitle renderer uses the font style
as specified by the `--sub-` options instead.

Note

Using `--sub-ass=no` may lead to incorrect or completely broken
rendering of ASS/SSA subtitles. It can sometimes be useful to forcibly
override the styling of ASS subtitles, but should be avoided in general.

`--sub-auto=<no|exact|fuzzy|all>`

Load additional subtitle files matching the video filename. The parameter
specifies how external subtitle files are matched. `exact` is enabled by
default.
| no: | Don't automatically load external subtitle files. |
| --- | --- |
| exact: | Load the media filename with subtitle file extension and possibly
language suffixes (default). |
| fuzzy: | Load all subs containing the media filename. |
| all: | Load all subs in the current and `--sub-file-paths` directories. |

`--sub-auto-exts=ext1,ext2,...`

Subtitle extensions to try and match when using `--sub-auto`. Note that
modifying this list will also affect what mpv recognizes as subtitles when
using drag and drop.

This is a string list option. See [List Options](manual-options-track.md) for details.
Use `--help=sub-auto-exts` to see default extensions.

`--sub-codepage=<codepage>`

You can use this option to specify the subtitle codepage. uchardet will be
used to guess the charset. (If mpv was not compiled with uchardet, then
`utf-8` is the effective default.)

The default value for this option is `auto`, which enables autodetection.

The following steps are taken to determine the final codepage, in order:

- if the specific codepage has a `+`, use that codepage

- if the data looks like UTF-8, assume it is UTF-8

- if `--sub-codepage` is set to a specific codepage, use that

- run uchardet, and if successful, use that

- otherwise, use `UTF-8-BROKEN`

Examples

- `--sub-codepage=latin2` Use Latin 2 if input is not UTF-8.

- `--sub-codepage=+cp1250` Always force recoding to cp1250.

The pseudo codepage `UTF-8-BROKEN` is used internally. If it's set,
subtitles are interpreted as UTF-8 with "Latin 1" as fallback for bytes
which are not valid UTF-8 sequences. iconv is never involved in this mode.

Note

This works for text subtitle files only. Other types of subtitles (in
particular subtitles in mkv files) are always assumed to be UTF-8.

`--sub-stretch-durations=<yes|no>`

Stretch a subtitle duration so it ends when the next one starts.
Should help with subtitles which erroneously have zero durations.

Note

Only applies to text subtitles.

`--sub-fix-timing=<yes|no>`

Adjust subtitle timing is to remove minor gaps or overlaps between
subtitles.

See also: `--sub-fix-timing-threshold` and `--sub-fix-timing-keep`.

`--sub-fix-timing-threshold=<amount>`

Set the threshold in milliseconds for fixing subtitle timing (default: 210).
If the gap between two subtitle events is smaller than this, the gap is
removed.

`--sub-fix-timing-keep=<amount>`

Set the minimum duration in milliseconds for subtitle events to be
considered for timing fixes (default: 400). If a subtitle event has a
duration smaller than this, its timing is not changed.

`--sub-forced-events-only=<yes|no>`

Enabling this displays only forced events within subtitle streams. Only
some bitmap subtitle formats (such as DVD or PGS) are capable of having a
mixture of forced and unforced events within the stream. Enabling this on
text subtitles will cause no subtitles to be displayed (default: `no`).

`--sub-fps=<rate>`

Specify the framerate of the subtitle file (default: video fps). Affects
text subtitles only.

Note

`<rate>` > video fps speeds the subtitles up for frame-based
subtitle files and slows them down for time-based ones.

See also: `--sub-speed`.

`--sub-gauss=<0.0-3.0>`

Apply Gaussian blur to image subtitles (default: 0). This can help to make
pixelated DVD/Vobsubs look nicer. A value other than 0 also switches to
software subtitle scaling. Might be slow.

Note

Never applied to text subtitles.

`--sub-gray`

Convert image subtitles to grayscale. Can help to make yellow DVD/Vobsubs
look nicer.

Note

Never applied to text subtitles.

`--sub-file-paths=

`

Specify extra directories to search for subtitles matching the video.
Multiple directories can be separated by ":" (";" on Windows).
Paths can be relative or absolute. Relative paths are interpreted relative
to video file directory.
If the file is a URL, only absolute paths and `sub` configuration
subdirectory will be scanned.

Example

Assuming that `/path/to/video/video.avi` is played and
`--sub-file-paths=sub:subtitles` is specified, mpv
searches for subtitle files in these directories:

- `/path/to/video/`

- `/path/to/video/sub/`

- `/path/to/video/subtitles/`

- the `sub` configuration subdirectory (usually `~/.config/mpv/sub/`)

This is a path list option. See [List Options](manual-options-track.md) for details.
