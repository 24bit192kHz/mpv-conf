## List of events

This is a partial list of events. This section describes what
`mpv_event_to_node()` returns, and which is what scripting APIs and the JSON
IPC sees. Note that the C API has separate C-level declarations with
`mpv_event`, which may be slightly different.

Note that events are asynchronous: the player core continues running while
events are delivered to scripts and other clients. In some cases, you can use
hooks to enforce synchronous execution.

All events can have the following fields:

`event`

Name as the event (as returned by `mpv_event_name()`).

`id`

The `reply_userdata` field (opaque user value). If `reply_userdata` is 0,
the field is not added.

`error`

Set to an error string (as returned by `mpv_error_string()`). This field
is missing if no error happened, or the event type does not report error.
Most events leave this unset.

This list uses the event name field value, and the C API symbol in brackets:

`start-file` (`MPV_EVENT_START_FILE`)

Happens right before a new file is loaded. When you receive this, the
player is loading the file (or possibly already done with it).

This has the following fields:

`playlist_entry_id`

Playlist entry ID of the file being loaded now.

`end-file` (`MPV_EVENT_END_FILE`)

Happens after a file was unloaded. Typically, the player will load the
next file right away, or quit if this was the last file.

The event has the following fields:

`reason`

Has one of these values:

`eof`

The file has ended. This can (but doesn't have to) include
incomplete files or broken network connections under
circumstances.

`stop`

Playback was ended by a command.

`quit`

Playback was ended by sending the quit command.

`error`

An error happened. In this case, an `error` field is present with
the error string.

`redirect`

Happens with playlists and similar. Details see
`MPV_END_FILE_REASON_REDIRECT` in the C API.

`unknown`

Unknown. Normally doesn't happen, unless the Lua API is out of sync
with the C API. (Likewise, it could happen that your script gets
reason strings that did not exist yet at the time your script was
written.)

`playlist_entry_id`

Playlist entry ID of the file that was being played or attempted to be
played. This has the same value as the `playlist_entry_id` field in the
corresponding `start-file` event.

`file_error`

Set to mpv error string describing the approximate reason why playback
failed. Unset if no error known. (In Lua scripting, this value was set
on the `error` field directly. This is deprecated since mpv 0.33.0.
In the future, this `error` field will be unset for this specific
event.)

`playlist_insert_id`

If loading ended, because the playlist entry to be played was for example
a playlist, and the current playlist entry is replaced with a number of
other entries. This may happen at least with MPV_END_FILE_REASON_REDIRECT
(other event types may use this for similar but different purposes in the
future). In this case, playlist_insert_id will be set to the playlist
entry ID of the first inserted entry, and playlist_insert_num_entries to
the total number of inserted playlist entries. Note this in this specific
case, the ID of the last inserted entry is playlist_insert_id+num-1.
Beware that depending on circumstances, you may observe the new playlist
entries before seeing the event (e.g. reading the "playlist" property or
getting a property change notification before receiving the event).
If this is 0 in the C API, this field isn't added.

`playlist_insert_num_entries`

See playlist_insert_id. Only present if playlist_insert_id is present.

`file-loaded`  (`MPV_EVENT_FILE_LOADED`)

Happens after a file was loaded and begins playback.

`seek` (`MPV_EVENT_SEEK`)

Happens on seeking. (This might include cases when the player seeks
internally, even without user interaction. This includes e.g. segment
changes when playing ordered chapters Matroska files.)

`playback-restart` (`MPV_EVENT_PLAYBACK_RESTART`)

Start of playback after seek or after file was loaded.

`shutdown` (`MPV_EVENT_SHUTDOWN`)

Sent when the player quits, and the script should terminate. Normally
handled automatically. See [Details on the script initialization and lifecycle](manual-lua-scripting-1.md).

`log-message` (`MPV_EVENT_LOG_MESSAGE`)

Receives messages enabled with `mpv_request_log_messages()` (Lua:
`mp.enable_messages`).

This contains, in addition to the default event fields, the following
fields:

`prefix`

The module prefix, identifies the sender of the message. This is what
the terminal player puts in front of the message text when using the
`--v` option, and is also what is used for `--msg-level`.

`level`

The log level as string. See `msg.log` for possible log level names.
Note that later versions of mpv might add new levels or remove
(undocumented) existing ones.

`text`

The log message. The text will end with a newline character. Sometimes
it can contain multiple lines.

Keep in mind that these messages are meant to be hints for humans. You
should not parse them, and prefix/level/text of messages might change
any time.

`hook`

The event has the following fields:

`hook_id`

ID to pass to `mpv_hook_continue()`. The Lua scripting wrapper
provides a better API around this with `mp.add_hook()`.

`get-property-reply` (`MPV_EVENT_GET_PROPERTY_REPLY`)

See C API.

`set-property-reply` (`MPV_EVENT_SET_PROPERTY_REPLY`)

See C API.

`command-reply` (`MPV_EVENT_COMMAND_REPLY`)

This is one of the commands for which the ``error` field is meaningful.

JSON IPC and Lua and possibly other backends treat this specially and may
not pass the actual event to the user. See C API.

The event has the following fields:

`result`

The result (on success) of any `mpv_node` type, if any.

`client-message` (`MPV_EVENT_CLIENT_MESSAGE`)
