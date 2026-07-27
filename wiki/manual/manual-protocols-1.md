# PROTOCOLS

`mpv://...`

> mpv protocol. This is used for starting mpv from URL handler. The protocol
> is stripped and the rest is passed to the player as a normal open argument.
> Only safe network protocols are allowed to be opened this way.

`http://...`, `https://`, ...

> Many network protocols are supported, but the protocol prefix must always
> be specified. mpv will never attempt to guess whether a filename is
> actually a network address. A protocol prefix is always required.
>
>
> Note that not all prefixes are documented here. Undocumented prefixes are
> either aliases to documented protocols, or are just redirections to
> protocols implemented and documented in FFmpeg.
>
>
> `data:` is supported, but needs to be in the format `data://`.
> This is done to avoid ambiguity with filenames. You
> can also prefix it with `lavf://` or `ffmpeg://`.

`ytdl://...`

> By default, the youtube-dl hook script only looks at http(s) URLs. Prefixing
> an URL with `ytdl://` forces it to be always processed by the script. This
> can also be used to invoke special youtube-dl functionality like playing a
> video by ID or invoking search.
>
>
> Keep in mind that you can't pass youtube-dl command line options by this,
> and you have to use `--ytdl-raw-options` instead.

`-`

> Play data from stdin.

`smb://PATH`

> Play a path from  Samba share. (Requires FFmpeg support.)

`bd://[title][/device]` `--bluray-device=PATH`

> Play a Blu-ray disc. Since libbluray 1.0.1, you can read from ISO files
> by passing them to `--bluray-device`.
>
>
> `title` can be: `longest` or `first` (selects the default
> playlist); `mpls/<number>` (selects <number>.mpls playlist);
> `<number>` (select playlist with the same index). mpv will list
> the available playlists on loading.
>
>
> `bluray://` is an alias.

`dvd://[title][/device]` `--dvd-device=PATH`

> Play a DVD. DVD menus are not supported. If no title is given, the longest
> title is auto-selected. Without `--dvd-device`, it will probably try
> to open an actual optical drive, if available and implemented for the OS.
>
>
> `dvdnav://` is an old alias for `dvd://` and does exactly the same
> thing.

`dvb://[cardnumber@]channel` `--dvbin-...`

> Digital TV via DVB. (Linux only.)

`mf://[@listfile|filemask|glob|printf-format]` `--mf-...`

> Play a series of images as video.
>
>
> If the URL path begins with `@`, it is interpreted as the path to a file
> containing a list of image paths separated by newlines. If the URL path
> contains `,`, it is interpreted as a list of image paths separated by
> `,`. If the URL path does not contain `%` and if on POSIX platforms, is
> interpreted as a glob, and `*` is automatically appended if it was not
> specified. Otherwise, the printf sequences `%[.][NUM]d`, where `NUM` is
> one, two, or three decimal digits, and `%%` and are interpreted. For
> example, `mf://image-%d.jpg` plays files like `image-1.jpg`,
> `image-2.jpg` and `image-10.jpg`, provided that there are no big gaps
> between the files.

`cdda://[device]` `--cdda-device=PATH`

> Play CD. You can select a specific range of tracks to play by using the
> `--start` and `--end` options and specifying chapters. Navigating
> forwards and backwards through tracks can also be done by navigating through
> chapters (`PGUP` and `PGDOWN` in the default keybinds).
>
>
>
> Example
>
> ```
> mpv cdda:// --start=#4 --end=#6
> ```
>
>
>
> This will start from track 4, play track 5, and then end.
>

`lavf://...`

> Access any FFmpeg libavformat protocol. Basically, this passed the
> string after the `//` directly to libavformat.

`av://type:options`

> This is intended for using libavdevice inputs. `type` is the libavdevice
> demuxer name, and `options` is the (pseudo-)filename passed to the
> demuxer.
>
>
>
> Example
>
> ```
> mpv av://v4l2:/dev/video0 --profile=low-latency --untimed
> ```
>
>
>
> This plays video from the first v4l input with nearly the lowest latency
> possible. It's a good replacement for the removed `tv://` input.
> Using `--untimed` is a hack to output a captured frame immediately,
> instead of respecting the input framerate. (There may be better ways to
> handle this in the future.)
>
>
>
> `avdevice://` is an alias.

`file://PATH`

> A local path as URL. Might be useful in some special use-cases. Note that
> `PATH` itself should start with a third `/` to make the path an
> absolute path.

`appending://PATH`

> Play a local file, but assume it's being appended to. This is useful for
> example for files that are currently being downloaded to disk. This will
> block playback, and stop playback only if no new data was appended after
> a timeout of about 2 seconds.
>
>
> Using this is still a bit of a bad idea, because there is no way to detect
> if a file is actually being appended, or if it's still written. If you're
> trying to play the  output of some program, consider using a pipe
> (`something | mpv -`). If it really has to be a file on disk, use tail to
> make it wait forever, e.g. `tail -f -c +0 file.mkv | mpv -`.

`fd://123`

> Read data from the given file descriptor (for example 123). This is similar
> to piping data to stdin via `-`, but can use an arbitrary file descriptor.
> mpv may modify some file descriptor properties when the stream layer "opens"
> it.

`fdclose://123`

> Like `fd://`, but the file descriptor is closed after use. When using this
> you need to ensure that the same fd URL will only be used once.

`edl://[edl specification as in edl-mpv.rst]`

> Stitch together parts of multiple files and play them.

`slice://start[-end]@URL`

> Read a slice of a stream.
>
>
> `start` and `end` represent a byte range and accept
> suffixes such as `KiB` and `MiB`. `end` is optional.
>
>
> if `end` starts with `+`, it is considered as offset from `start`.
>
>
> Only works with seekable streams.
>
>
> Examples:
>
> ```
> mpv slice://1g-2g@cap.ts
>
> This starts reading from cap.ts after seeking 1 GiB, then
