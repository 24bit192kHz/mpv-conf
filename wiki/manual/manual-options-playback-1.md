## Playback Control

`--start=<relative time>`

Seek to given time position.

The general format for times is `[+|-][[hh:]mm:]ss[.ms]`. If the time is
prefixed with `-`, the time is considered relative from the end of the
file (as signaled by the demuxer/the file). A `+` is usually ignored (but
see below).

The following alternative time specifications are recognized:

`pp%` seeks to percent position pp (0-100).

`#c` seeks to chapter number c. (Chapters start from 1.)

`none` resets any previously set option (useful for libmpv).

If `--rebase-start-time=no` is given, then prefixing times with `+`
makes the time relative to the start of the file. A timestamp without
prefix is considered an absolute time, i.e. should seek to a frame with a
timestamp as the file contains it. As a bug, but also a hidden feature,
putting 1 or more spaces before the `+` or `-` always interprets the
time as absolute, which can be used to seek to negative timestamps (useful
for debugging at most).

Examples

`--start=+56`, `--start=00:56`

Seeks to the start time + 56 seconds.

`--start=-56`, `--start=-00:56`

Seeks to the end time - 56 seconds.

`--start=01:10:00`

Seeks to 1 hour 10 min.

`--start=50%`

Seeks to the middle of the file.

`--start=30 --end=40`

Seeks to 30 seconds, plays 10 seconds, and exits.

`--start=-3:20 --length=10`

Seeks to 3 minutes and 20 seconds before the end of the file, plays
10 seconds, and exits.

`--start='#2' --end='#4'`

Plays chapters 2 and 3, and exits.

`--end=<relative time>`

Stop at given time. Use `--length` if the time should be relative
to `--start`. See `--start` for valid option values and examples.

`--length=<relative time>`

Stop after a given time relative to the start time.
See `--start` for valid option values and examples.

If both `--end` and `--length` are provided, playback will stop when it
reaches either of the two endpoints.

Obscurity note: this does not work correctly if `--rebase-start-time=no`,
and the specified time is not an "absolute" time, as defined in the
`--start` option description.

`--rebase-start-time=<yes|no>`

Whether to move the file start time to `00:00:00` (default: yes). This
is less awkward for files which start at a random timestamp, such as
transport streams. On the other hand, if there are timestamp resets, the
resulting behavior can be rather weird. For this reason, and in case you
are actually interested in the real timestamps, this behavior can be
disabled with `no`.

`--speed=<0.01-100>`

Slow down or speed up playback by the factor given as parameter.

If `--audio-pitch-correction` (on by default) is used, playing with a
speed higher than normal automatically inserts the `scaletempo2` audio
filter.

`--pitch=<0.01-100>`

Raise or lower the audio's pitch by the factor given as parameter. Does not
affect playback speed. Playing with an altered pitch automatically inserts
the `scaletempo2` audio filter.

Since pitch change is achieved by combining pitch-preserving speed change and
resampling, the range of pitch change is effectively limited by the
`min-speed` and `max-speed` parameters of `scaletempo2`: for example,
a `min-speed` of 0.25 limits the highest pitch factor to 4 (1/0.25).

In a standard 12-tone scale system, octaves are separated by a factor of 2
whereas semitones are represented by a factor of 2^(1/12). This means
pitches can easily be shifted up or down with a simple multiplier.

Examples

`--pitch=2`

Shifts the pitch up a full octave.

`--pitch=0.5`

Shifts the pitch down an octave.

`--pitch=1.498307` (2^(7/12))

Shifts the pitch up a perfect fifth.

`--pitch=0.667420` (2^(-7/12))

Shifts the pitch down a perfect fifth.

`--pitch=1.059463` (2^(1/12))

Shifts the pitch up a semitone.

`--pitch=0.943874` (2^(-1/12))

Shifts the pitch down a semitone.

`--pause`

Start the player in paused state.

`--shuffle`

Play files in random order.

`--playlist-start=<auto|index>`

Set which file on the internal playlist to start playback with. The index
is an integer, with 0 meaning the first file. The value `auto` means that
the selection of the entry to play is left to the playback resume mechanism
(default). If an entry with the given index doesn't exist, the behavior is
unspecified and might change in future mpv versions. The same applies if
the playlist contains further playlists (don't expect any reasonable
behavior). Passing a playlist file to mpv should work with this option,
though. E.g. `mpv playlist.m3u --playlist-start=123` will work as expected,
as long as `playlist.m3u` does not link to further playlists.

The value `no` is a deprecated alias for `auto`.

`--playlist=<filename>`

Play files according to a playlist file. Supports some common formats. If
no format is detected, it will be treated as list of files, separated by
newline characters. You may need this option to load plaintext files as
a playlist. Note that XML playlist formats are not supported.

This option forces `--demuxer=playlist` to interpret the playlist file.
Some playlist formats, notably CUE and optical disc formats, need to use
different demuxers and will not work with this option. They still can be
played directly, without using this option.

You can play playlists directly, without this option. Before mpv version
0.31.0, this option disabled any security mechanisms that might be in
place, but since 0.31.0 it uses the same security mechanisms as playing a
playlist file directly. If you trust the playlist file, you can disable
any security checks with `--load-unsafe-playlists`. Because playlists
can load other playlist entries, consider applying this option only to the
playlist itself and not its entries, using something along these lines:

> `mpv --{ --playlist=filename --load-unsafe-playlists --}`

Warning

The way older versions of mpv played playlist files via `--playlist`
was not safe against maliciously constructed files. Such files may
trigger harmful actions. This has been the case for all versions of
mpv prior to 0.31.0, and all MPlayer versions, but unfortunately this
fact was not well documented earlier, and some people have even
misguidedly recommended the use of `--playlist` with untrusted
sources. Do NOT use `--playlist` with random internet sources or
files you do not trust if you are not sure your mpv is at least 0.31.0.

In particular, playlists can contain entries using protocols other than
local files, such as special protocols like `avdevice://` (which are
inherently unsafe).

`--chapter-merge-threshold=<number>`

Threshold for merging almost consecutive ordered chapter parts in
