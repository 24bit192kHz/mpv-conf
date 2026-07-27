## Property list

Note

Most options can be set at runtime via properties as well. Just remove the
leading `--` from the option name. These are not documented below, see
[OPTIONS](manual-options-track.md) instead. Only properties which do not exist as option with the
same name, or which have very different behavior from the options are
documented below.

Properties marked as (RW) are writeable, while those that aren't are
read-only.

`audio-speed-correction`, `video-speed-correction`

Factor multiplied with `speed` at which the player attempts to play the
file. Usually it's exactly 1. (Display sync mode will make this useful.)

OSD formatting will display it in the form of `+1.23456%`, with the number
being `(raw - 1) * 100` for the given raw property value.

`display-sync-active`

Whether `--video-sync=display` is actually active.

`filename`

Currently played file, with path stripped. If this is an URL, try to undo
percent encoding as well. (The result is not necessarily correct, but
looks better for display purposes. Use the `path` property to get an
unmodified filename.)

This has a sub-property:

`filename/no-ext`

Like the `filename` property, but if the text contains a `.`, strip
all text after the last `.`. Usually this removes the file extension.

`file-size`

Length in bytes of the source file/stream. (This is the same as
`${stream-end}`. For segmented/multi-part files, this will return the
size of the main or manifest file, whatever it is.)

`estimated-frame-count`

Total number of frames in current file.

Note

This is only an estimate. (It's computed from two unreliable
quantities: fps and stream length.)

`estimated-frame-number`

Number of current frame in current stream.

Note

This is only an estimate. (It's computed from two unreliable
quantities: fps and possibly rounded timestamps.)

`pid`

Process-id of mpv.

`path`

Full absolute path of the currently played file.

`stream-open-filename`

The full path to the currently played media. This is different from
`path` only in special cases. In particular, if `--ytdl=yes` is used,
and the URL is detected by `youtube-dl`, then the script will set this
property to the actual media URL. This property should be set only during
the `on_load` or `on_load_fail` hooks, otherwise it will have no effect
(or may do something implementation defined in the future). The property is
reset if playback of the current media ends.

`media-title`

If the currently played file has a `title` tag, use that.

Otherwise, return the `filename` property.

`file-format`

Symbolic name of the file format. In some cases, this is a comma-separated
list of format names, e.g. mp4 is `mov,mp4,m4a,3gp,3g2,mj2` (the list
may grow in the future for any format).

`current-demuxer`

Name of the current demuxer. (This is useless.)

(Renamed from `demuxer`.)

`stream-path`

Filename (full path) of the stream layer filename. (This is probably
useless and is almost never different from `path`.)

`stream-pos`

Raw byte position in source stream. Technically, this returns the position
of the most recent packet passed to a decoder.

`stream-end`

Raw end position in bytes in source stream.

`duration`

Duration of the current file in seconds. If the duration is unknown, the
property is unavailable. Note that the file duration is not always exactly
known, so this is an estimate.

This replaces the `length` property, which was deprecated after the
mpv 0.9 release. (The semantics are the same.)

This has a sub-property:

`duration/full`

`duration` with milliseconds.

`avsync`

Last A/V synchronization difference. Unavailable if audio or video is
disabled.

`total-avsync-change`

Total A-V sync correction done. Unavailable if audio or video is
disabled.

`decoder-frame-drop-count`

Video frames dropped by decoder, because video is too far behind audio (when
using `--framedrop=decoder`). Sometimes, this may be incremented in other
situations, e.g. when video packets are damaged, or the decoder doesn't
follow the usual rules. Unavailable if video is disabled.

`frame-drop-count`

Frames dropped by VO (when using `--framedrop=vo`).

`mistimed-frame-count`

Number of video frames that were not timed correctly in display-sync mode
for the sake of keeping A/V sync. This does not include external
circumstances, such as video rendering being too slow or the graphics
driver somehow skipping a vsync. It does not include rounding errors either
(which can happen especially with bad source timestamps). For example,
using the `display-desync` mode should never change this value from 0.

`vsync-ratio`

For how many vsyncs a frame is displayed on average. This is available if
display-sync is active only. For 30 FPS video on a 60 Hz screen, this will
be 2. This is the moving average of what actually has been scheduled, so
24 FPS on 60 Hz will never remain exactly on 2.5, but jitter depending on
the last frame displayed.

`vo-delayed-frame-count`

Estimated number of frames delayed due to external circumstances in
display-sync mode. Note that in general, mpv has to guess that this is
happening, and the guess can be inaccurate.

`percent-pos` (RW)

Position in current file (0-100). The advantage over using this instead of
calculating it out of other properties is that it properly falls back to
estimating the playback position from the byte position, if the file
duration is not known.

`time-pos` (RW)

Position in current file in seconds.

This has a sub-property:

`time-pos/full`

`time-pos` with milliseconds.

`time-start`

Deprecated. Always returns 0. Before mpv 0.14, this used to return the start
time of the file (could affect e.g. transport streams). See
`--rebase-start-time` option.

