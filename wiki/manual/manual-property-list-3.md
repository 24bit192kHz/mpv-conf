Per-chapter metadata is very rare. Usually, only the chapter name
(`title`) is set.

For accessing other information, like chapter start, see the
`chapter-list` property.

`vf-metadata/<filter-label>`

Metadata added by video filters. Accessed by the filter label,
which, if not explicitly specified using the `@filter-label:` syntax,
will be `<filter-name>.NN`.

Works similar to `metadata` property. It allows the same access
methods (using sub-properties).

An example of this kind of metadata are the cropping parameters
added by `--vf=lavfi=cropdetect`.

`af-metadata/<filter-label>`

Equivalent to `vf-metadata/<filter-label>`, but for audio filters.

`deinterlace-active`

Returns `yes`/true if mpv's deinterlacing filter is active. Note that it
will not detect any manually inserted deinterlacing filters done via
`--vf`.

`idle-active`

Returns `yes`/true if no file is loaded, but the player is staying around
because of the `--idle` option.

(Renamed from `idle`.)

`core-idle`

Whether the playback core is paused. This can differ from `pause` in
special situations, such as when the player pauses itself due to low
network cache.

This also returns `yes`/true if playback is restarting or if nothing is
playing at all. In other words, it's only `no`/false if there's actually
video playing. (Behavior since mpv 0.7.0.)

`cache-speed`

Current I/O read speed between the cache and the lower layer (like network).
This gives the number bytes per seconds over a 1 second window (using
the type `MPV_FORMAT_INT64` for the client API).

This is the same as `demuxer-cache-state/raw-input-rate`.

`demuxer-cache-duration`

Approximate duration of video buffered in the demuxer, in seconds. The
guess is very unreliable, and often the property will not be available
at all, even if data is buffered.

`demuxer-cache-time`

Approximate time of video buffered in the demuxer, in seconds. Same as
`demuxer-cache-duration` but returns the last timestamp of buffered
data in demuxer.

`demuxer-cache-idle`

Whether the demuxer is idle, which means that the demuxer cache is filled
to the requested amount, and is currently not reading more data.

`demuxer-cache-state`

Each entry in `seekable-ranges` represents a region in the demuxer cache
that can be seeked to, with a `start` and `end` fields containing the
respective timestamps. If there are multiple demuxers active, this only
returns information about the "main" demuxer, but might be changed in
future to return unified information about all demuxers. The ranges are in
arbitrary order. Often, ranges will overlap for a bit, before being joined.
In broken corner cases, ranges may overlap all over the place.

The end of a seek range is usually smaller than the value returned by the
`demuxer-cache-time` property, because that property returns the guessed
buffering amount, while the seek ranges represent the buffered data that
can actually be used for cached seeking.

`bof-cached` indicates whether the seek range with the lowest timestamp
points to the beginning of the stream (BOF). This implies you cannot seek
before this position at all. `eof-cached` indicates whether the seek range
with the highest timestamp points to the end of the stream (EOF). If both
`bof-cached` and `eof-cached` are true, and there's only 1 cache range,
the entire stream is cached.

`fw-bytes` is the number of bytes of packets buffered in the range
starting from the current decoding position. This is a rough estimate
(may not account correctly for various overhead), and stops at the
demuxer position (it ignores seek ranges after it).

`file-cache-bytes` is the number of bytes stored in the file cache. This
includes all overhead, and possibly unused data (like pruned data). This
member is missing if the file cache wasn't enabled with
`--cache-on-disk=yes`.

`cache-end` is `demuxer-cache-time`. Missing if unavailable.

`reader-pts` is the approximate timestamp of the start of the buffered
range. Missing if unavailable.

`cache-duration` is `demuxer-cache-duration`. Missing if unavailable.

`raw-input-rate` is the estimated input rate of the network layer (or any
other byte-oriented input layer) in bytes per second. May be inaccurate or
missing.

`ts-per-stream` is an array containing an entry for each stream type: video,
audio, and subtitle. For each stream type, the details for the demuxer cache
for that stream type are available as `cache-duration`, `reader-pts` and
`cache-end`.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_MAP
    "seekable-ranges"   MPV_FORMAT_NODE_ARRAY
        MPV_FORMAT_NODE_MAP
            "start"             MPV_FORMAT_DOUBLE
            "end"               MPV_FORMAT_DOUBLE
    "bof-cached"        MPV_FORMAT_FLAG
    "eof-cached"        MPV_FORMAT_FLAG
    "fw-bytes"          MPV_FORMAT_INT64
    "file-cache-bytes"  MPV_FORMAT_INT64
    "cache-end"         MPV_FORMAT_DOUBLE
    "reader-pts"        MPV_FORMAT_DOUBLE
    "cache-duration"    MPV_FORMAT_DOUBLE
    "raw-input-rate"    MPV_FORMAT_INT64
    "ts-per-stream"     MPV_FORMAT_NODE_ARRAY
        MPV_FORMAT_NODE_MAP
              "type"            MPV_FORMAT_STRING
              "cache-duration"  MPV_FORMAT_DOUBLE
              "reader-pts"      MPV_FORMAT_DOUBLE
              "cache-end"       MPV_FORMAT_DOUBLE
```

Other fields (might be changed or removed in the future):

`eof`

Whether the reader thread has hit the end of the file.

`underrun`

Whether the reader thread could not satisfy a decoder's request for a
new packet.

`idle`

Whether the thread is currently not reading.

`total-bytes`

Sum of packet bytes (plus some overhead estimation) of the entire packet
queue, including cached seekable ranges.

`demuxer-via-network`

Whether the stream demuxed via the main demuxer is most likely played via
network. What constitutes "network" is not always clear, might be used for
other types of untrusted streams, could be wrong in certain cases, and its
definition might be changing. Also, external files (like separate audio
files or streams) do not influence the value of this property (currently).

`demuxer-start-time`

The start time reported by the demuxer in fractional seconds.

`paused-for-cache`

Whether playback is paused because of waiting for the cache.

`cache-buffering-state`

The percentage (0-100) of the cache fill status until the player will
unpause (related to `paused-for-cache`).

`eof-reached`

Whether the end of playback was reached. Note that this is usually
interesting only if `--keep-open` is enabled, since otherwise the player
will immediately play the next file (or exit or enter idle mode), and in
these cases the `eof-reached` property will logically be cleared
immediately after it's set.

`seeking`

