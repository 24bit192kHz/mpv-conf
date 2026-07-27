
Set line spacing value for SSA/ASS renderer.

`--sub-shaper=<simple|complex>`

Set the text layout engine used by libass.
| simple: | uses Fribidi only, fast, doesn't render some languages correctly |
| --- | --- |
| complex: | uses HarfBuzz, slower, wider language support |

`complex` is the default. If libass hasn't been compiled against HarfBuzz,
libass silently reverts to `simple`.

`--sub-ass-prune-delay=<-1|seconds>`

Set the delay for automatic pruning of events from memory in libass. When
enabled, subtitle events are removed from memory once their end timestamp is
older than the specified delay.
| -1: | disables automatic pruning (default). |
| --- | --- |
| seconds: | specify how many seconds after an event is no longer displayed
should the pruning occur. `0` prunes events as soon as they're
off screen. |

Note

This breaks sub-seek and subtitle rendering when changing play-direction
from forward to backward during runtime for events that were already
"seen" and need to be rendered again, if those events got pruned.

`--sub-glyph-limit=<value>`

Set the maximum number of cached glyphs in libass cache for the subtitle
track. 0 means libass uses its default value.

Default: 0.

`--sub-bitmap-max-size=<value>`

Set the maximum bitmap cache size in libass cache for the subtitle track. 0
means libass uses its default value. This accepts values in MB.

Default: 0.

`--sub-ass-styles=<filename>`

Load all SSA/ASS styles found in the specified file and use them for
rendering text subtitles. The syntax of the file is exactly like the `[V4
Styles]` / `[V4+ Styles]` section of SSA/ASS.

Note

Using this option may lead to incorrect subtitle rendering.

`--sub-ass-override=<no|yes|scale|force|strip>`

Control whether user style overrides should be applied. Note that all of
these overrides try to be somewhat smart about figuring out whether or not
a subtitle is considered a "sign" and try to be as non-destructive as
possible.
| no: | Render subtitles as specified by the subtitle scripts, without
overrides. |
| --- | --- |
| yes: | Apply all the `--sub-ass-*` style override options. Changing the
default for any of these options can lead to incorrect subtitle
rendering. |
| scale: | Like `yes`, but also apply `--sub-scale` (default). |
| force: | Like `yes`, but also force all `--sub-*` options. Can break
rendering easily. Certain options aren't overridden if they can
potentially be too destructive. |
| strip: | Radically strip all ASS tags and styles from the subtitle. This
is equivalent to the old `--no-ass` / `--no-sub-ass` options. |

This also controls some bitmap subtitle overrides, as well as HTML tags in
formats like SRT, despite the name of the option.

`--secondary-sub-ass-override=<no|yes|scale|force|strip>`

Control whether user secondary substyle overrides should be applied. This
works exactly like `--sub-ass-override`.

Default: strip.

`--sub-ass-force-margins`

Enables placing toptitles and subtitles in black borders when they are
available, if the subtitles are in the ASS format.

Default: no.

`--sub-use-margins`

Enables placing toptitles and subtitles in black borders when they are
available, if the subtitles are in a plain text format  (or ASS if
`--sub-ass-override` is set high enough).

Default: yes.

`--sub-ass-use-video-data=<none|aspect-ratio|all>`

Controls which information about the video stream is passed to libass.
Any option but `all` is incompatible with standard ASS as defined by VSFilter,
whose behavior most subtitle scripts and renderers target, including libass.
Video stream properties are needed to accurately emulate VSFilter semantics and
withholding them will likely result in broken subtitle rendering for most files.
It's thus recommended to only change this selectively if required on a per-file basis.
| none: | Don't forward any video stream information. |
| --- | --- |
| aspect-ratio: | Only forward aspect ratio; fallbacks are used for other properties.
This makes behavior consistent across different video resolutions. |
| all: | Forward all available information, notably including storage resolution. |

For certain kinds of broken ASS files which got repurposed across
several video resolutions without either setting `LayoutRes` headers
or adjusting affected effects, it may be desirable to withhold storage resolution
information from libass to ensure consistent rendering across resolutions.
Among others this affects 3D rotations and blurs.
When encountering such files, try setting `aspect-ratio`.

Even more broken files on anamorphic video might also exhibit stretching
unless aspect ratio information is also faked, in this case you can try
using `none`. This has never an effect on non-anamorphic video.

Default: `all`

`--sub-ass-video-aspect-override=<no|ratio>`

Allows passing any arbitrary aspect ratio to libass instead of the video’s
actual aspect ratio. Zero aspect ratio is identical to `no`.

This has no effect if `sub-ass-use-video-data` is set to `none`.

`--sub-vsfilter-bidi-compat=<yes|no>`

Set implicit bidi detection to `ltr` instead of `auto` to match ASS'
default. This also disables libass' incompatible extensions. This currently
includes bracket pair matching according to the revised Unicode
Bidirectional Algorithm introduced in Unicode 6.3, and also affects how BiDi
runs are split and processed, as well as soft linewrapping of Unicode text.

This affects plaintext (non-ASS) subtitles only. Default: no.

`--sub-ass-vsfilter-color-compat=<basic|full|force-601|no>`

Mangle colors like (xy-)vsfilter do (default: basic). Historically, VSFilter
was not color space aware. This was no problem as long as the color space
used for SD video (BT.601) was used. But when everything switched to HD
(BT.709), VSFilter was still converting RGB colors to BT.601, rendered
them into the video frame, and handled the frame to the video output, which
would use BT.709 for conversion to RGB. The result were mangled subtitle
colors. Later on, bad hacks were added on top of the ASS format to control
how colors are to be mangled.
| basic: | Handle only BT.601->BT.709 mangling, if the subtitles seem to
indicate that this is required (default). |
| --- | --- |
| full: | Handle the full `YCbCr Matrix` header with all video color spaces
supported by libass and mpv. This might lead to bad breakages in
corner cases and is not strictly needed for compatibility
(hopefully), which is why this is not default. |
| force-601: | Force BT.601->BT.709 mangling, regardless of subtitle headers
or video color space. |
| no: | Disable color mangling completely. All colors are RGB. |

Choosing anything other than `no` will make the subtitle color depend on
the video color space, and it's for example in theory not possible to reuse
a subtitle script with another video file. The `--sub-ass-override`
option doesn't affect how this option is interpreted.

`--stretch-dvd-subs=<yes|no>`

Stretch DVD subtitles when playing anamorphic videos for better looking
fonts on badly mastered DVDs. This switch has no effect when the
video is stored with square pixels - which for DVD input cannot be the case
though.

Many studios tend to use bitmap fonts designed for square pixels when
authoring DVDs, causing the fonts to look stretched on playback on DVD
players. This option fixes them, however at the price of possibly
misaligning some subtitles (e.g. sign translations).

Disabled by default.

`--stretch-image-subs-to-screen=<yes|no>`

Stretch DVD and other image subtitles to the screen, ignoring the video
margins. This has a similar effect as `--sub-use-margins` for text
subtitles, except that the text itself will be stretched, not only just
repositioned. (At least in general it is unavoidable, as an image bitmap
can in theory consist of a single bitmap covering the whole screen, and
the player won't know where exactly the text parts are located.)

This option does not display subtitles correctly. Use with care.

Disabled by default.

