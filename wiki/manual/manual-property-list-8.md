Number of playlist entries (same as `playlist-count`).

`playlist/N/filename`

Filename of the Nth entry.

`playlist/N/playing`

`yes`/true if the `playlist-playing-pos` property points to this
entry, `no`/false or unavailable otherwise.

`playlist/N/current`

`yes`/true if the `playlist-current-pos` property points to this
entry, `no`/false or unavailable otherwise.

`playlist/N/title`

Name of the Nth entry. Available if the playlist file contains
such fields and mpv's parser supports it for the given
playlist format, or if the playlist entry has been opened before and a
media-title other than filename has been acquired.

`playlist/N/id`

Unique ID for this entry. This is an automatically assigned integer ID
that is unique for the entire life time of the current mpv core
instance. Other commands, events, etc. use this as `playlist_entry_id`
fields.

`playlist/N/playlist-path`

The original path of the playlist for this entry before mpv expanded
it. Unavailable if the file was not originally associated with a playlist
in some way.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_ARRAY
    MPV_FORMAT_NODE_MAP (for each playlist entry)
        "filename"  MPV_FORMAT_STRING
        "current"   MPV_FORMAT_FLAG (might be missing; since mpv 0.7.0)
        "playing"   MPV_FORMAT_FLAG (same)
        "title"     MPV_FORMAT_STRING (optional)
        "id"        MPV_FORMAT_INT64
```

`track-list`

List of audio/video/sub tracks, current entry marked.

This has a number of sub-properties. Replace `N` with the 0-based track
index.

`track-list/count`

Total number of tracks.

`track-list/video`

The list of video tracks. This is only usable for printing and its value
can't be retrieved.

`track-list/audio`

The list of audio tracks. This is only usable for printing and its value
can't be retrieved.

`track-list/sub`

The list of sub tracks. This is only usable for printing and its value
can't be retrieved.

`track-list/N/id`

The ID as it's used for `--sid`/`--aid`/`--vid`. This is unique
within tracks of the same type (sub/audio/video), but otherwise not.

`track-list/N/type`

String describing the media type. One of `audio`, `video`, `sub`.

`track-list/N/src-id`

Track ID as used in the source file. Not always available. (It is
missing if the format has no native ID, if the track is a pseudo-track
that does not exist in this way in the actual file, or if the format
is handled by libavformat, and the format was not whitelisted as having
track IDs.)

`track-list/N/title`

Track title as it is stored in the file. Not always available.

`track-list/N/lang`

Track language as identified by the file. Not always available.

`track-list/N/image`

`yes`/true if this is a video track that consists of a single
picture, `no`/false or unavailable otherwise. The heuristic used to
determine if a stream is an image doesn't attempt to detect images in
codecs normally used for videos. Otherwise, it is reliable.

`track-list/N/albumart`

`yes`/true if this is an image embedded in an audio file or external
cover art, `no`/false or unavailable otherwise.

`track-list/N/default`

`yes`/true if the track has the default flag set in the file,
`no`/false or unavailable otherwise.

`track-list/N/forced`

`yes`/true if the track has the forced flag set in the file,
`no`/false or unavailable otherwise.

`track-list/N/dependent`

`yes`/true if the track has the dependent flag set in the file,
`no`/false or unavailable otherwise.

`track-list/N/visual-impaired`

`yes`/true if the track has the visual impaired flag set in the file,
`no`/false or unavailable otherwise.

`track-list/N/hearing-impaired`

`yes`/true if the track has the hearing impaired flag set in the file,
`no`/false or unavailable otherwise.

`track-list/N/hls-bitrate`

The bitrate of the HLS stream, if available.

`track-list/N/program-id`

The program ID of the HLS stream, if available.

`track-list/N/codec`

The codec name used by this track, for example `h264`. Unavailable
in some rare cases.

`track-list/N/codec-desc`

The codec descriptive name used by this track.

`track-list/N/codec-profile`

The codec profile used by this track. Available only if the track has
been already decoded.

`track-list/N/external`

`yes`/true if the track is an external file, `no`/false or
unavailable otherwise. This is set for separate subtitle files.

`track-list/N/external-filename`

The filename if the track is from an external file, unavailable
otherwise.

`track-list/N/selected`

`yes`/true if the track is currently decoded, `no`/false or
unavailable otherwise.

`track-list/N/main-selection`

It indicates the selection order of tracks for the same type.
If a track is not selected, or is selected by the `--lavfi-complex`,
it is not available. For subtitle tracks, `0` represents the `sid`,
and `1` represents the `secondary-sid`.

`track-list/N/ff-index`

The stream index as usually used by the FFmpeg utilities. Note that
this can be potentially wrong if a demuxer other than libavformat
(`--demuxer=lavf`) is used. For mkv files, the index will usually
match even if the default (builtin) demuxer is used, but there is
no hard guarantee.

`track-list/N/decoder`

If this track is being decoded, the short decoder name,

`track-list/N/decoder-desc`
