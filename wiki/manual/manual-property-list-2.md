`time-remaining`

Remaining length of the file in seconds. Note that the file duration is not
always exactly known, so this is an estimate.

This has a sub-property:

`time-remaining/full`

`time-remaining` with milliseconds.

`audio-pts`

Current audio playback position in current file in seconds. Unlike `time-pos`,
this updates more often than once per frame. This is mostly equivalent to
`time-pos` for audio-only files however it also takes into account the audio
driver delay. This can lead to negative values in certain cases, so in
general you probably want to simply use `time-pos`.

This has a sub-property:

`audio-pts/full`

`audio-pts` with milliseconds.

`playtime-remaining`

`time-remaining` scaled by the current `speed`.

This has a sub-property:

`playtime-remaining/full`

`playtime-remaining` with milliseconds.

`playback-time` (RW)

Alias for `time-pos`.

Prior to mpv 0.39.0, `time-pos` and `playback-time` could report
different values in certain edge cases.

This has a sub-property:

`playback-time/full`

`playback-time` with milliseconds.

`remaining-file-loops`

How many more times the current file is going to be looped. This is
initialized from the value of `--loop-file`. This counts the number of
times it causes the player to seek to the beginning of the file, so it is 0
the last the time is played. -1 corresponds to infinity.

`remaining-ab-loops`

How many more times the current A-B loop is going to be looped, if one is
active. This is initialized from the value of `--ab-loop-count`. This
counts the number of times it causes the player to seek to `--ab-loop-a`,
so it is 0 the last the time the loop is played. -1 corresponds to infinity.

`chapter` (RW)

Current chapter number. The number of the first chapter is 0.
A value of -1 indicates that the current playback position is before the
start of the first chapter,

Setting this property results in an absolute seek to the start of the
chapter. However, if the property is changed with `add` or `cycle`
command which results in a decrement in value, it may go to the start of
the current chapter instead of the previous chapter.
See `--chapter-seek-threshold` for details.

`edition` (RW)

Current edition number. Setting this property to a different value will
restart playback. The number of the first edition is 0.

For Matroska files, this is the edition. For DVD/Blu-ray, this is the title.

Before mpv 0.31.0, this showed the actual edition selected at runtime, if
you didn't set the option or property manually. With mpv 0.31.0 and later,
this strictly returns the user-set option or property value, and the
`current-edition` property was added to return the runtime selected
edition (this matters with `--edition=auto`, the default).

`current-edition`

Currently selected edition. This property is unavailable if no file is
loaded, or the file has no editions. (Matroska files make a difference
between having no editions and a single edition, which will be reflected by
the property, although in practice it does not matter.)

`chapters`

Number of chapters.

`editions`

Number of editions.

`edition-list`

List of editions, current entry marked.

This has a number of sub-properties. Replace `N` with the 0-based edition
index.

`edition-list/count`

Number of editions. If there are no editions, this can be 0 or 1 (1
if there's a useless dummy edition).

`edition-list/N/id`

Edition ID as integer. Currently, this is the same as the edition index.

`edition-list/N/default`

Whether this is the default edition.

`edition-list/N/title`

Edition title as stored in the file. Not always available.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_ARRAY
    MPV_FORMAT_NODE_MAP (for each edition)
        "id"                MPV_FORMAT_INT64
        "title"             MPV_FORMAT_STRING
        "default"           MPV_FORMAT_FLAG
```

`metadata`

Metadata key/value pairs.

If the property is accessed with Lua's `mp.get_property_native`, this
returns a table with metadata keys mapping to metadata values. If it is
accessed with the client API, this returns a `MPV_FORMAT_NODE_MAP`,
with tag keys mapping to tag values.

For OSD, it returns a formatted list. Trying to retrieve this property as
a raw string doesn't work.

This has a number of sub-properties:

`metadata/by-key/<key>`

Value of metadata entry `<key>`.

`metadata/list/count`

Number of metadata entries.

`metadata/list/N/key`

Key name of the Nth metadata entry. (The first entry is `0`).

`metadata/list/N/value`

Value of the Nth metadata entry.

`metadata/<key>`

Old version of `metadata/by-key/<key>`. Use is discouraged, because
the metadata key string could conflict with other sub-properties.

The layout of this property might be subject to change. Suggestions are
welcome how exactly this property should work.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_MAP
    (key and string value for each metadata entry)
```

`filtered-metadata`

Like `metadata`, but includes only fields listed in the `--display-tags`
option. This is the same set of tags that is printed to the terminal.

`chapter-metadata`

Metadata of current chapter. Works similar to `metadata` property. It
also allows the same access methods (using sub-properties).

