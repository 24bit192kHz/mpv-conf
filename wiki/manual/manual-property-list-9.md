
If this track is being decoded, the human-readable decoder name,

`track-list/N/demux-w`, `track-list/N/demux-h`

Video size hint as indicated by the container. (Not always accurate.)

`track-list/N/demux-crop-x`, `track-list/N/demux-crop-y`

Crop offset of the source video frame.

`track-list/N/demux-crop-w`, `track-list/N/demux-crop-h`

Video size after cropping.

`track-list/N/demux-channel-count`

Number of audio channels as indicated by the container. (Not always
accurate - in particular, the track could be decoded as a different
number of channels.)

`track-list/N/demux-channels`

Channel layout as indicated by the container. (Not always accurate.)

`track-list/N/demux-samplerate`

Audio sample rate as indicated by the container. (Not always accurate.)

`track-list/N/demux-fps`

Video FPS as indicated by the container. (Not always accurate.)

`track-list/N/demux-bitrate`

Audio average bitrate, in bits per second. (Not always accurate.)

`track-list/N/demux-rotation`

Video clockwise rotation metadata, in degrees.

`track-list/N/demux-par`

Pixel aspect ratio.

`track-list/N/format-name`

Short name for format from ffmpeg. If the track is audio, this will be
the name of the sample format. If the track is video, this will be the
name of the pixel format.

`track-list/N/audio-channels` (deprecated)

Deprecated alias for `track-list/N/demux-channel-count`.

`track-list/N/replaygain-track-peak`, `track-list/N/replaygain-track-gain`

Per-track replaygain values. Only available for audio tracks with
corresponding information stored in the source file.

`track-list/N/replaygain-album-peak`, `track-list/N/replaygain-album-gain`

Per-album replaygain values. If the file has per-track but no per-album
information, the per-album values will be copied from the per-track
values currently. It's possible that future mpv versions will make
these properties unavailable instead in this case.

`track-list/N/dolby-vision-profile`, `track-list/N/dolby-vision-level`

Dolby Vision profile and level. May not be available if the container
does not provide this information.

`track-list/N/metadata`,

Works like the `metadata` property, but it accesses metadata that is
set per track/stream instead of global values for the entire file.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_ARRAY
    MPV_FORMAT_NODE_MAP (for each track)
        "id"                MPV_FORMAT_INT64
        "type"              MPV_FORMAT_STRING
        "src-id"            MPV_FORMAT_INT64
        "title"             MPV_FORMAT_STRING
        "lang"              MPV_FORMAT_STRING
        "image"             MPV_FORMAT_FLAG
        "albumart"          MPV_FORMAT_FLAG
        "default"           MPV_FORMAT_FLAG
        "forced"            MPV_FORMAT_FLAG
        "dependent"         MPV_FORMAT_FLAG
        "visual-impaired"   MPV_FORMAT_FLAG
        "hearing-impaired"  MPV_FORMAT_FLAG
        "hls-bitrate"       MPV_FORMAT_INT64
        "program-id"        MPV_FORMAT_INT64
        "selected"          MPV_FORMAT_FLAG
        "main-selection"    MPV_FORMAT_INT64
        "external"          MPV_FORMAT_FLAG
        "external-filename" MPV_FORMAT_STRING
        "codec"             MPV_FORMAT_STRING
        "codec-desc"        MPV_FORMAT_STRING
        "codec-profile"     MPV_FORMAT_STRING
        "ff-index"          MPV_FORMAT_INT64
        "decoder"           MPV_FORMAT_STRING
        "decoder-desc"      MPV_FORMAT_STRING
        "demux-w"           MPV_FORMAT_INT64
        "demux-h"           MPV_FORMAT_INT64
        "demux-crop-x"      MPV_FORMAT_INT64
        "demux-crop-y"      MPV_FORMAT_INT64
        "demux-crop-w"      MPV_FORMAT_INT64
        "demux-crop-h"      MPV_FORMAT_INT64
        "demux-channel-count" MPV_FORMAT_INT64
        "demux-channels"    MPV_FORMAT_STRING
        "demux-samplerate"  MPV_FORMAT_INT64
        "demux-fps"         MPV_FORMAT_DOUBLE
        "demux-bitrate"     MPV_FORMAT_INT64
        "demux-rotation"    MPV_FORMAT_INT64
        "demux-par"         MPV_FORMAT_DOUBLE
        "format-name"       MPV_FORMAT_STRING
        "audio-channels"    MPV_FORMAT_INT64
        "replaygain-track-peak" MPV_FORMAT_DOUBLE
        "replaygain-track-gain" MPV_FORMAT_DOUBLE
        "replaygain-album-peak" MPV_FORMAT_DOUBLE
        "replaygain-album-gain" MPV_FORMAT_DOUBLE
        "dolby-vision-profile" MPV_FORMAT_INT64
        "dolby-vision-level" MPV_FORMAT_INT64
        "metadata"           MPV_FORMAT_NODE_MAP
            (key and string value for each metadata entry)
```

`current-tracks/...`

This gives access to currently selected tracks. It redirects to the correct
entry in `track-list`.

The following sub-entries are defined: `video`, `audio`, `sub`,
`sub2`

For example, `current-tracks/audio/lang` returns the current audio track's
language field (the same value as `track-list/N/lang`).

If tracks of the requested type are selected via `--lavfi-complex`, the
first one is returned.

`chapter-list` (RW)

List of chapters, current entry marked.

This has a number of sub-properties. Replace `N` with the 0-based chapter
index.

`chapter-list/count`

Number of chapters.

`chapter-list/N/title`

Chapter title as stored in the file. Not always available.

`chapter-list/N/time`

Chapter start time in seconds as float.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_ARRAY
    MPV_FORMAT_NODE_MAP (for each chapter)
        "title" MPV_FORMAT_STRING
        "time"  MPV_FORMAT_DOUBLE
```

`af`, `vf` (RW)

See `--vf`/`--af` and the `vf`/`af` command.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_ARRAY
    MPV_FORMAT_NODE_MAP (for each filter entry)
        "name"      MPV_FORMAT_STRING
        "label"     MPV_FORMAT_STRING [optional]
        "enabled"   MPV_FORMAT_FLAG [optional]
        "params"    MPV_FORMAT_NODE_MAP [optional]
            "key"   MPV_FORMAT_STRING
            "value" MPV_FORMAT_STRING
```
