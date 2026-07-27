individual touch points when their indexes change.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_ARRAY
    MPV_FORMAT_NODE_MAP (for each touch point)
        "x"        MPV_FORMAT_INT64
        "y"        MPV_FORMAT_INT64
        "id"       MPV_FORMAT_INT64
```

`tablet-pos`

Read-only - last known tablet tool (pen) position, normalized to OSD dimensions,
and tool state.

Has the following sub-properties:

`tablet-pos/x`, `tablet-pos/y`

Last known coordinates of the tablet tool.

`tablet-pos/tool-in-proximity`

Boolean - whether a tablet tool is currently in proximity of the tablet
surface / hovers above the tablet surface.

`tablet-pos/tool-tip`,

The state of the tablet tool tip, `up` or `down.`

`tablet-pos/tool-stylus-btn1`, `tablet-pos/tool-stylus-btn2`, `tablet-pos/tool-stylus-btn3`

The state of tablet tool side buttons, `pressed` or `released`.

`tablet-pos/pad-focus`

Boolean - whether a tablet pad is currently focused.

`tablet-pos/pad-btns/N`

The state of the Nth tablet pad button, `pressed` or `released`.

`sub-ass-extradata`

The current ASS subtitle track's extradata. There is no formatting done.
The extradata is returned as a string as-is. This property is not
available for non-ASS subtitle tracks.

`sub-text`

The current subtitle text regardless of sub visibility. Formatting is
stripped. If the subtitle is not text-based (i.e. DVD/BD subtitles), an
empty string is returned.

This has sub-properties for different formats:

`sub-text/ass`

Like `sub-text`, but return the text in ASS format. Text subtitles in
other formats are converted. For native ASS subtitles, events that do
not contain any text (but vector drawings etc.) are not filtered out. If
multiple events match with the current playback time, they are concatenated
with line breaks. Contains only the "Text" part of the events.

This property is not enough to render ASS subtitles correctly, because ASS
header and per-event metadata are not returned. Use `/ass-full` for that.

`sub-text/ass-full`

Like `sub-text-ass`, but return the full event with all fields, formatted as
lines in a .ass text file. Use with `sub-ass-extradata` for style information.

`sub-text-ass` (deprecated)

Deprecated alias for `sub-text/ass`.

`secondary-sub-text`

Same as `sub-text` (with the same sub-properties), but for the secondary subtitles.

`sub-start`

The current subtitle start time (in seconds). If there's multiple current
subtitles, returns the first start time. If no current subtitle is present
null is returned instead.

This has a sub-property:

`sub-start/full`

`sub-start` with milliseconds.

`secondary-sub-start`

Same as `sub-start`, but for the secondary subtitles.

`sub-end`

The current subtitle end time (in seconds). If there's multiple current
subtitles, return the last end time. If no current subtitle is present, or
if it's present but has unknown or incorrect duration, null is returned
instead.

This has a sub-property:

`sub-end/full`

`sub-end` with milliseconds.

`secondary-sub-end`

Same as `sub-end`, but for the secondary subtitles.

`playlist-pos` (RW)

Current position on playlist. The first entry is on position 0. Writing to
this property may start playback at the new position.

In some cases, this is not necessarily the currently playing file. See
explanation of `current` and `playing` flags in `playlist`.

If there the playlist is empty, or if it's non-empty, but no entry is
"current", this property returns -1. Likewise, writing -1 will put the
player into idle mode (or exit playback if idle mode is not enabled). If an
out of range index is written to the property, this behaves as if writing -1.
(Before mpv 0.33.0, instead of returning -1, this property was unavailable
if no playlist entry was current.)

Writing the current value back to the property will have no effect.
Use `playlist-play-index` to restart the playback of the current entry if
desired.

`playlist-pos-1` (RW)

Same as `playlist-pos`, but 1-based.

`playlist-current-pos` (RW)

Index of the "current" item on playlist. This usually, but not necessarily,
the currently playing item (see `playlist-playing-pos`). Depending on the
exact internal state of the player, it may refer to the playlist item to
play next, or the playlist item used to determine what to play next.

For reading, this is exactly the same as `playlist-pos`.

For writing, this *only* sets the position of the "current" item, without
stopping playback of the current file (or starting playback, if this is done
in idle mode). Use -1 to remove the current flag.

This property is only vaguely useful. If set during playback, it will
typically cause the playlist entry *after* it to be played next. Another
possibly odd observable state is that if `playlist-next` is run during
playback, this property is set to the playlist entry to play next (unlike
the previous case). There is an internal flag that decides whether the
current playlist entry or the next one should be played, and this flag is
currently inaccessible for API users. (Whether this behavior will kept is
possibly subject to change.)

`playlist-playing-pos`

Index of the "playing" item on playlist. A playlist item is "playing" if
it's being loaded, actually playing, or being unloaded. This property is set
during the `MPV_EVENT_START_FILE` (`start-file`) and the
`MPV_EVENT_START_END` (`end-file`) events. Outside of that, it returns
-1. If the playlist entry was somehow removed during playback, but playback
hasn't stopped yet, or is in progress of being stopped, it also returns -1.
(This can happen at least during state transitions.)

In the "playing" state, this is usually the same as `playlist-pos`, except
during state changes, or if `playlist-current-pos` was written explicitly.

`playlist-count`

Number of total playlist entries.

`playlist-path`

The original path of the playlist for the current entry before mpv expanded
the entries. Unavailable if the file was not originally associated with a
playlist in some way.

`playlist`

Playlist, current entry marked. Currently, the raw property value is
useless.

This has a number of sub-properties. Replace `N` with the 0-based playlist
entry index.

`playlist/count`

