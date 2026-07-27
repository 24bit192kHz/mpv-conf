## Hooks

Hooks are synchronous events between player core and a script or similar. This
applies to client API (including the Lua scripting interface). Normally,
events are supposed to be asynchronous, and the hook API provides a way to
handle events that require stricter coordination. Not following the protocol
exactly can make the player freeze. Use with caution, avoid if synchronous event
handling is not required.

The C API is described in the header files. The Lua API is described in the
Lua section.

Before a hook is actually invoked on an API clients, it will attempt to return
new values for all observed properties that were changed before the hook. This
may make it easier for an application to set defined "barriers" between property
change notifications by registering hooks. (That means these hooks will have an
effect, even if you do nothing and make them continue immediately.)

The following hooks are currently defined:

`on_load`

Called when a file is to be opened, before anything is actually done.
For example, you could read and write the `stream-open-filename`
property to redirect an URL to something else (consider support for
streaming sites which rarely give the user a direct media URL), or
you could set per-file options with by setting the property
`file-local-options/<option name>`. The player will wait until all
hooks are run.

Ordered after `start-file` and before `playback-restart`.

`on_load_fail`

Called after after a file has been opened, but failed to. This can be
used to provide a fallback in case native demuxers failed to recognize
the file, instead of always running before the native demuxers like
`on_load`. Demux will only be retried if `stream-open-filename`
was changed. If it fails again, this hook is _not_ called again, and
loading definitely fails.

Ordered after `on_load`, and before `playback-restart` and `end-file`.

`on_preloaded`

Called after a file has been opened, and before tracks are selected and
decoders are created. This has some usefulness if an API users wants
to select tracks manually, based on the set of available tracks. It's
also useful to initialize `--lavfi-complex` in a specific way by API,
without having to "probe" the available streams at first.

Note that this does not yet apply default track selection. Which operations
exactly can be done and not be done, and what information is available and
what is not yet available yet, is all subject to change.

Ordered after `on_load_fail` etc. and before `playback-restart`.

`on_unload`

Run before closing a file, and before actually uninitializing
everything. It's not possible to resume playback in this state.

Ordered before `end-file`. Will also happen in the error case (then after
`on_load_fail`).

`on_before_start_file`

Run before a `start-file` event is sent. (If any client changes the
current playlist entry, or sends a quit command to the player, the
corresponding event will not actually happen after the hook returns.)
Useful to drain property changes before a new file is loaded.

`on_after_end_file`

Run after an `end-file` event. Useful to drain property changes after a
file has finished.
