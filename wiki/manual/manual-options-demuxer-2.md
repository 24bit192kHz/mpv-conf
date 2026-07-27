be calculated after cropping. However, the majority of files do not adhere
to this rule, as it would cause incompatibility with crop-unaware players.
Additionally, MKVToolNix does not automatically adjust DisplayWidth and
DisplayHeight when cropping metadata is applied, leading to most of files
created with it also failing to conform to the specification.

See for more details:
[https://github.com/ietf-wg-cellar/matroska-specification/pull/947](https://github.com/ietf-wg-cellar/matroska-specification/pull/947)
[https://gitlab.com/mbunkus/mkvtoolnix/-/issues/2389](https://gitlab.com/mbunkus/mkvtoolnix/-/issues/2389)
[https://github.com/mpv-player/mpv/pull/13446](https://github.com/mpv-player/mpv/pull/13446)

`--demuxer-rawaudio-channels=<value>`

Number of channels (or channel layout) if `--demuxer=rawaudio` is used
(default: stereo).

`--demuxer-rawaudio-format=<value>`

Sample format for `--demuxer=rawaudio` (default: s16le).
Use `--demuxer-rawaudio-format=help` to get a list of all formats.

`--demuxer-rawaudio-rate=<value>`

Sample rate for `--demuxer=rawaudio` (default: 44 kHz).

`--demuxer-rawvideo-fps=<value>`

Rate in frames per second for `--demuxer=rawvideo` (default: 25.0).

`--demuxer-rawvideo-w=<value>`, `--demuxer-rawvideo-h=<value>`

Image dimension in pixels for `--demuxer=rawvideo`.

Example

Play a raw YUV sample:

```
mpv sample-720x576.yuv --demuxer=rawvideo \
--demuxer-rawvideo-w=720 --demuxer-rawvideo-h=576
```

`--demuxer-rawvideo-format=<value>`

Color space (fourcc) in hex or string for `--demuxer=rawvideo`
(default: `YV12`).

`--demuxer-rawvideo-mp-format=<value>`

Color space by internal video format for `--demuxer=rawvideo`. Use
`--demuxer-rawvideo-mp-format=help` for a list of possible formats.

`--demuxer-rawvideo-codec=<value>`

Set the video codec instead of selecting the rawvideo codec when using
`--demuxer=rawvideo`. This uses the same values as codec names in
`--vd` (but it does not accept decoder names).

`--demuxer-rawvideo-size=<value>`

Frame size in bytes when using `--demuxer=rawvideo`.

`--demuxer-max-bytes=<bytesize>`

This controls how much the demuxer is allowed to buffer ahead. The demuxer
will normally try to read ahead as much as necessary, or as much is
requested with `--demuxer-readahead-secs`. The option can be used to
restrict the maximum readahead. This limits excessive readahead in case of
broken files or desynced playback. The demuxer will stop reading additional
packets as soon as one of the limits is reached. (The limits still can be
slightly overstepped due to technical reasons.)

Set these limits higher if you get a packet queue overflow warning, and
you think normal playback would be possible with a larger packet queue.

See `--list-options` for defaults and value range. `<bytesize>` options
accept suffixes such as `KiB` and `MiB`.

`--demuxer-max-back-bytes=<bytesize>`

This controls how much past data the demuxer is allowed to preserve. This
is useful only if the cache is enabled.

Unlike the forward cache, there is no control how many seconds are actually
cached - it will simply use as much memory this option allows. Setting this
option to 0 will strictly disable any back buffer, but this will lead to
the situation that the forward seek range starts after the current playback
position (as it removes past packets that are seek points).

If the end of the file is reached, the remaining unused forward buffer space
is "donated" to the backbuffer (unless the backbuffer size is set to 0, or
`--demuxer-donate-buffer` is set to `no`).
This still limits the total cache usage to the sum of the forward and
backward cache, and effectively makes better use of the total allowed memory
budget. (The opposite does not happen: free backward buffer is never
"donated" to the forward buffer.)

Keep in mind that other buffers in the player (like decoders) will cause the
demuxer to cache "future" frames in the back buffer, which can skew the
impression about how much data the backbuffer contains.

See `--list-options` for defaults and value range.

`--demuxer-donate-buffer=<yes|no>`

Whether to let the back buffer use part of the forward buffer (default: yes).
If set to `yes`, the "donation" behavior described in the option
description for `--demuxer-max-back-bytes` is enabled. This means the
back buffer may use up memory up to the sum of the forward and back buffer
options, minus the active size of the forward buffer. If set to `no`, the
options strictly limit the forward and back buffer sizes separately.

Note that if the end of the file is reached, the buffered data stays the
same, even if you seek back within the cache. This is because the back
buffer is only reduced when new data is read.

`--demuxer-seekable-cache=<yes|no|auto>`

Debugging option to control whether seeking can use the demuxer cache
(default: auto). Normally you don't ever need to set this; the default
`auto` does the right thing and enables cache seeking it if `--cache`
is set to `yes` (or is implied `yes` if `--cache=auto`).

If enabled, short seek offsets will not trigger a low level demuxer seek
(which means for example that slow network round trips or FFmpeg seek bugs
can be avoided). If a seek cannot happen within the cached range, a low
level seek will be triggered. Seeking outside of the cache will start a new
cached range, but can discard the old cache range if the demuxer exhibits
certain unsupported behavior.

The special value `auto` means `yes` in the same situation as
`--cache-secs` is used (i.e. when the stream appears to be a network
stream or the stream cache is enabled).

`--demuxer-thread=<yes|no>`

Run the demuxer in a separate thread, and let it prefetch a certain amount
of packets (default: yes). Having this enabled leads to smoother playback,
enables features like prefetching, and prevents that stuck network freezes
the player. On the other hand, it can add overhead, or the background
prefetching can hog CPU resources.

Disabling this option is not recommended. Use it for debugging only.

`--demuxer-termination-timeout=<seconds>`

Number of seconds the player should wait to shutdown the demuxer (default:
0.1). The player will wait up to this much time before it closes the
stream layer forcefully. Forceful closing usually means the network I/O is
given no chance to close its connections gracefully (of course the OS can
still close TCP connections properly), and might result in annoying messages
being logged, and in some cases, confused remote servers.

This timeout is usually only applied when loading has finished properly. If
loading is aborted by the user, or in some corner cases like removing
external tracks sourced from network during playback, forceful closing is
always used.

`--demuxer-readahead-secs=<seconds>`

If `--demuxer-thread` is enabled, this controls how much the demuxer
should buffer ahead in seconds (default: 1). As long as no packet has
a timestamp difference higher than the readahead amount relative to the
last packet returned to the decoder, the demuxer keeps reading.

Note that enabling the cache (such as `--cache=yes`, or if the input
is considered a network stream, and `--cache=auto` is used), this option
is mostly ignored. (`--cache-secs` will override this. Technically, the
maximum of both options is used.)

The main purpose of this option is to limit the readhead for local playback,
since a large readahead value is not overly useful in this case.

(This value tends to be fuzzy, because many file formats don't store linear
timestamps.)

`--demuxer-hysteresis-secs=<seconds>`

Once the demuxer limit is reached (`--demuxer-max-bytes`,
`--demuxer-readahead-secs` or `--cache-secs`), this value can be used
to specify a hysteresis before the demuxer will buffer ahead again. This
specifies the maximum number of seconds from the current playback position
that needs to be remaining in the cache before the demuxer will continue
buffering ahead.

For example, with a value of 10 seconds specified, the demuxer will buffer
ahead up to the demuxer limit and won't start buffering ahead again until
there is only 10 seconds of content left in the cache.

This can provide significant power savings and reduce load by making the
demuxer only buffer ahead in chunks at a time rather than buffering ahead
nonstop to keep the cache filled.

If you want to save power and reduce load, configure this to a small number
that's much lower than `--cache-secs` or `--demuxer-readahead-secs`.
