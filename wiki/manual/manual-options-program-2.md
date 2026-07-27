`exclude=<URL1|URL2|...`

A `|`-separated list of URL patterns which mpv should not use with
youtube-dl. The patterns are matched after the `http(s)://` part of
the URL.

`^` matches the beginning of the URL, `$` matches its end, and you
should use `%` before any of the characters `^$()%|,.[]*+-?` to
match that character.

URLs are converted to lower case before matching.

Examples

- `--script-opts=ytdl_hook-exclude='^youtube%.com'`
will exclude any URL that starts with `http://youtube.com` or
`https://youtube.com`.

- `--script-opts=ytdl_hook-exclude='%.mkv$|%.mp4$'`
will exclude any URL that ends with `.mkv` or `.mp4`.

See more lua patterns here: [https://www.lua.org/manual/5.1/manual.html#5.4.1](https://www.lua.org/manual/5.1/manual.html#5.4.1)

`include=<URL1|URL2|...`

A `|`-separated list of URL patterns which mpv should try to parse with
youtube-dl first when `try_ytdl_first` is `no`. The patterns are
matched in the same way as `exclude`.

Default: `^%w+%.youtube%.com/|^youtube%.com/|^youtu%.be/|^%w+%.twitch%.tv/|^twitch%.tv/`

`all_formats=<yes|no>`

If 'yes' will attempt to add all formats found reported by youtube-dl
(default: no). Each format is added as a separate track. In addition,
they are delay-loaded, and actually opened only when a track is selected
(this should keep load times as low as without this option).

It adds average bitrate metadata, if available, which means you can use
`--hls-bitrate` to decide which track to select. (HLS used to be the
only format whose alternative quality streams were exposed in a similar
way, thus the option name.)

Tracks which represent formats that were selected by youtube-dl as
default will have the default flag set. This means mpv should generally
still select formats chosen with `--ytdl-format` by default.

Although this mechanism makes it possible to switch streams at runtime,
it's not suitable for this purpose for various technical reasons. (It's
slow, which can't be really fixed.) In general, this option is not
useful, and was only added to show that it's possible.

There are two cases that must be considered when doing quality/bandwidth
selection:

> -
>
> Completely separate audio and video streams (DASH-like). Each of
> these streams contain either only audio or video, so you can
> mix and combine audio/video bandwidths without restriction. This
> intuitively matches best with the concept of selecting quality
> by track (what `all_formats` is supposed to do).
>
> -
>
> Separate sets of muxed audio and video streams. Each version of
> the media contains both an audio and video stream, and they are
> interleaved. In order not to waste bandwidth, you should only
> select one of these versions (if, for example, you select an
> audio stream, then video will be downloaded, even if you selected
> video from a different stream).
>
>
> mpv will still represent them as separate tracks, but will set
> the title of each track to `muxed-N`, where `N` is replaced
> with the youtube-dl format ID of the originating stream.

Some sites will mix 1. and 2., but we assume that they do so for
compatibility reasons, and there is no reason to use them at all.

`force_all_formats=<yes|no>`

If set to 'yes', and `all_formats` is also set to 'yes', this will
try to represent all youtube-dl reported formats as tracks, even if
mpv would normally use the direct URL reported by it (default: yes).

It appears this normally makes a difference if youtube-dl works on a
master HLS playlist.

If this is set to 'no', this specific kind of stream is treated like
`all_formats` is set to 'no', and the stream selection as done by
youtube-dl (via `--ytdl-format`) is used.

`thumbnails=<all|best|none>`

Add thumbnails as video tracks (default: none).

Thumbnails get downloaded when they are added as tracks, so 'all' can
have a noticeable impact on how long it takes to open the video when
there are a lot of thumbnails.

`use_manifests=<yes|no>`

Make mpv use the master manifest URL for formats like HLS and DASH,
if available, allowing for video/audio selection in runtime (default:
no). It's disabled ("no") by default for performance reasons.

`ytdl_path=youtube-dl`

Configure paths to youtube-dl's executable or a compatible fork's. The
paths should be separated by : on Unix and ; on Windows. mpv looks in
order for the configured paths in PATH and in mpv's config directory.
The defaults are "yt-dlp", "yt-dlp_x86" and "youtube-dl". On Windows
the suffix extension is not necessary, but only ".exe" is acceptable.

Why do the option names mix `_` and `-`?

I have no idea.

`--ytdl-format=<|ytdl|best|worst|mp4|webm|...>`

Format selection string that is directly passed to youtube-dl.
The possible values are specific to the website and the video, for a given
URL the available formats can be found with the command
`youtube-dl -F URL`. See youtube-dl's documentation for available aliases.
(Default: empty)

An empty value or `ytdl` does not pass a `--format` option to youtube-dl
at all, and thus uses its default format selection behavior.

`--ytdl-raw-options=<key>=<value>[,<key>=<value>[,...]]`

Pass arbitrary options to youtube-dl. Parameter and argument should be
passed as a key-value pair. Options without argument must include `=`.

There is no sanity checking so it's possible to break things (i.e.
passing invalid parameters to youtube-dl).

A proxy URL can be passed for youtube-dl to use it in parsing the website.
This is useful for geo-restricted URLs. After youtube-dl parsing, some
URLs also require a proxy for playback, so this can pass that proxy
information to mpv. Take note that SOCKS proxies aren't supported and
https URLs also bypass the proxy. This is a limitation in FFmpeg.

This is a key/value list option. See [List Options](manual-options-track.md) for details.

Example

- `--ytdl-raw-options=username=user,password=pass`

- `--ytdl-raw-options=force-ipv6=`

- `--ytdl-raw-options=proxy=[http://127.0.0.1:3128]`

- `--ytdl-raw-options-append=proxy=http://127.0.0.1:3128`

`--js-memory-report=<yes|no>`

Enable memory reporting for javascript scripts in the stats overlay.
This is disabled by default because it has an overhead and increases
memory usage. This option will only work if it is enabled before mpv is
started.

`--load-stats-overlay=<yes|no>`

Enable the builtin script that shows useful playback information on a key
binding (default: yes). By default, the `i` key is used (`I` to make
the overlay permanent).

`--load-console=<yes|no>`

Enable the built-in script to handle textual input (default: yes).

`--load-commands=<yes|no>`

Enable the built-in script to enter commands in the console (default: yes).
The ``` key is used to activate this by default.

`--load-auto-profiles=<yes|no|auto>`

Enable the builtin script that does auto profiles (default: auto). See
[Conditional auto profiles](manual-configuration-files-1.md) for details. `auto` will load the script,
but immediately unload it if there are no conditional profiles.

`--load-select=<yes|no>`

Enable the builtin script that lets you select from lists of items (default:
yes). By default, its keybindings start with the `g` key.

`--load-context-menu=<yes|no>`

Enable the builtin script that implements a context menu. Defaults to
`yes` on platforms where integration with a native context menu is not
implemented, and to `no` on platform where it is.

