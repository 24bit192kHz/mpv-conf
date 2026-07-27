
It's also possible to write the property using this format.

`seekable`

Whether it's generally possible to seek in the current file.

`partially-seekable`

Whether the current file is considered seekable, but only because the cache
is active. This means small relative seeks may be fine, but larger seeks
may fail anyway. Whether a seek will succeed or not is generally not known
in advance.

If this property returns `yes`/true, so will `seekable`.

`playback-abort`

Whether playback is stopped or is to be stopped. (Useful in obscure
situations like during `on_load` hook processing, when the user can stop
playback, but the script has to explicitly end processing.)

`cursor-autohide` (RW)

See `--cursor-autohide`. Setting this to a new value will always update
the cursor, and reset the internal timer.

`term-clip-cc`

Inserts the symbol to force line truncation to the current terminal width.
This can be used for `show-text` and other OSD messages. It must be the
first character in the line. It takes effect until the end of the line.

`osd-sym-cc`

Inserts the current OSD symbol as opaque OSD control code (cc). This makes
sense only with the `show-text` command or options which set OSD messages.
The control code is implementation specific and is useless for anything else.

`osd-ass-cc`

`${osd-ass-cc/0}` disables escaping ASS sequences of text in OSD,
`${osd-ass-cc/1}` enables it again. By default, ASS sequences are
escaped to avoid accidental formatting, and this property can disable
this behavior. Note that the properties return an opaque OSD control
code, which only makes sense for the `show-text` command or options
which set OSD messages.

Example

- `--osd-msg3='This is ${osd-ass-cc/0}{\\b1}bold text'`

- `show-text "This is ${osd-ass-cc/0}{\\b1}bold text"`

Any ASS override tags as understood by libass can be used.

Note that you need to escape the `\` character, because the string is
processed for C escape sequences before passing it to the OSD code. See
[Flat command syntax](manual-input-commands-1.md) for details.

A list of tags can be found here:
[https://aegisub.org/docs/latest/ass_tags/](https://aegisub.org/docs/latest/ass_tags/)

`vo-configured`

Whether the VO is configured right now. Usually this corresponds to whether
the video window is visible. If the `--force-window` option is used, this
usually always returns `yes`/true.

`vo-passes`

Contains introspection about the VO's active render passes and their
execution times. Not implemented by all VOs.

This is further subdivided into two frame types, `vo-passes/fresh` for
fresh frames (which have to be uploaded, scaled, etc.) and
`vo-passes/redraw` for redrawn frames (which only have to be re-painted).
The number of passes for any given subtype can change from frame to frame,
and should not be relied upon.

Each frame type has a number of further sub-properties. Replace `TYPE`
with the frame type, `N` with the 0-based pass index, and `M` with the
0-based sample index.

`vo-passes/TYPE/count`

Number of passes.

`vo-passes/TYPE/N/desc`

Human-friendy description of the pass.

`vo-passes/TYPE/N/last`

Last measured execution time, in nanoseconds.

`vo-passes/TYPE/N/avg`

Average execution time of this pass, in nanoseconds. The exact
timeframe varies, but it should generally be a handful of seconds.

`vo-passes/TYPE/N/peak`

The peak execution time (highest value) within this averaging range, in
nanoseconds.

`vo-passes/TYPE/N/count`

The number of samples for this pass.

`vo-passes/TYPE/N/samples/M`

The raw execution time of a specific sample for this pass, in
nanoseconds.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_MAP
"TYPE" MPV_FORMAT_NODE_ARRAY
    MPV_FORMAT_NODE_MAP
        "desc"    MPV_FORMAT_STRING
        "last"    MPV_FORMAT_INT64
        "avg"     MPV_FORMAT_INT64
        "peak"    MPV_FORMAT_INT64
        "count"   MPV_FORMAT_INT64
        "samples" MPV_FORMAT_NODE_ARRAY
             MP_FORMAT_INT64
```

Note that directly accessing this structure via subkeys is not supported,
the only access is through aforementioned `MPV_FORMAT_NODE`.

`perf-info`

Further performance data. Querying this property triggers internal
collection of some data, and may slow down the player. Each query will reset
some internal state. Property change notification doesn't and won't work.
All of this may change in the future, so don't use this. The builtin
`stats` script is supposed to be the only user; since it's bundled and
built with the source code, it can use knowledge of mpv internal to render
the information properly. See `stats` script description for some details.

`video-bitrate`, `audio-bitrate`, `sub-bitrate`

Bitrate values calculated on the packet level. This works by dividing the
bit size of all packets between two keyframes by their presentation
timestamp distance. (This uses the timestamps are stored in the file, so
e.g. playback speed does not influence the returned values.) In particular,
the video bitrate will update only per keyframe, and show the "past"
bitrate. To make the property more UI friendly, updates to these properties
are throttled in a certain way.

The unit is bits per second. OSD formatting turns these values in kilobits
(or megabits, if appropriate), which can be prevented by using the
raw property value, e.g. with `${=video-bitrate}`.

Note that the accuracy of these properties is influenced by a few factors.
If the underlying demuxer rewrites the packets on demuxing (done for some
file formats), the bitrate might be slightly off. If timestamps are bad
or jittery (like in Matroska), even constant bitrate streams might show
fluctuating bitrate.

How exactly these values are calculated might change in the future.

In earlier versions of mpv, these properties returned a static (but bad)
guess using a completely different method.

`audio-device-list`

The list of discovered audio devices. This is mostly for use with the
client API, and reflects what `--audio-device=help` with the command line
player returns.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_ARRAY
    MPV_FORMAT_NODE_MAP (for each device entry)
        "name"          MPV_FORMAT_STRING
        "description"   MPV_FORMAT_STRING
```

The `name` is what is to be passed to the `--audio-device` option (and
often a rather cryptic audio API-specific ID), while `description` is
human readable free form text. The description is set to the device name
(minus mpv-specific `<driver>/` prefix) if no description is available
or the description would have been an empty string.

The special entry with the name set to `auto` selects the default audio
output driver and the default device.
