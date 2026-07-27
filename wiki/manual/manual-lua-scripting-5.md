## Advanced mp functions

These also live in the `mp` module, but are documented separately as they
are useful only in special situations.

`mp.get_wakeup_pipe()`

Calls `mpv_get_wakeup_pipe()` and returns the read end of the wakeup
pipe. This is deprecated, but still works. (See `client.h` for details.)

`mp.get_next_timeout()`

Return the relative time in seconds when the next timer (`mp.add_timeout`
and similar) expires. If there is no timer, return `nil`.

`mp.dispatch_events([allow_wait])`

This can be used to run custom event loops. If you want to have direct
control what the Lua script does (instead of being called by the default
event loop), you can set the global variable `mp_event_loop` to your
own function running the event loop. From your event loop, you should call
`mp.dispatch_events()` to dequeue and dispatch mpv events.

If the `allow_wait` parameter is set to `true`, the function will block
until the next event is received or the next timer expires. Otherwise (and
this is the default behavior), it returns as soon as the event loop is
emptied. It's strongly recommended to use `mp.get_next_timeout()` and
`mp.get_wakeup_pipe()` if you're interested in properly working
notification of new events and working timers.

`mp.register_idle(fn)`

Register an event loop idle handler. Idle handlers are called before the
script goes to sleep after handling all new events. This can be used for
example to delay processing of property change events: if you're observing
multiple properties at once, you might not want to act on each property
change, but only when all change notifications have been received.

`mp.unregister_idle(fn)`

Undo `mp.register_idle(fn)`. This removes all idle handlers that
are equal to the `fn` parameter. This uses normal Lua `==` comparison,
so be careful when dealing with closures.

`mp.enable_messages(level)`

Set the minimum log level of which mpv message output to receive. These
messages are normally printed to the terminal. By calling this function,
you can set the minimum log level of messages which should be received with
the `log-message` event. See the description of this event for details.
The level is a string, see `msg.log` for allowed log levels.

`mp.register_script_message(name, fn)`

This is a helper to dispatch `script-message` or `script-message-to`
invocations to Lua functions. `fn` is called if `script-message` or
`script-message-to` (with this script as destination) is run
with `name` as first parameter. The other parameters are passed to `fn`.
If a message with the given name is already registered, it's overwritten.

Used by `mp.add_key_binding`, so be careful about name collisions.

`mp.unregister_script_message(name)`

Undo a previous registration with `mp.register_script_message`. Does
nothing if the `name` wasn't registered.

`mp.create_osd_overlay(format)`

Create an OSD overlay. This is a very thin wrapper around the `osd-overlay`
command. The function returns a table, which mostly contains fields that
will be passed to `osd-overlay`. The `format` parameter is used to
initialize the `format` field. The `data` field contains the text to
be used as overlay. For details, see the `osd-overlay` command.

In addition, it provides the following methods:

`update()`

Commit the OSD overlay to the screen, or in other words, run the
`osd-overlay` command with the current fields of the overlay table.
Returns the result of the `osd-overlay` command itself.

`remove()`

Remove the overlay from the screen. A `update()` call will add it
again.

Example:

```
ov = mp.create_osd_overlay("ass-events")
ov.data = "{\\an5}{\\b1}hello world!"
ov:update()
```

The advantage of using this wrapper (as opposed to running `osd-overlay`
directly) is that the `id` field is allocated automatically.

`mp.get_osd_size()`

Returns a tuple of `osd_width, osd_height, osd_par`. The first two give
the size of the OSD in pixels (for video outputs like `--vo=xv`, this may
be "scaled" pixels). The third is the display pixel aspect ratio.

May return invalid/nonsense values if OSD is not initialized yet.

`exit()` (global)

Make the script exit at the end of the current event loop iteration. This
does not terminate mpv itself or other scripts.

This can be polyfilled to support mpv versions older than 0.40 with:

```
if not _G.exit then
    function exit()
        mp.keep_running = false
    end
end
```

## mp.msg functions

This module allows outputting messages to the terminal, and can be loaded
with `require 'mp.msg'`.

`msg.log(level, ...)`

The level parameter is the message priority. It's a string and one of
`fatal`, `error`, `warn`, `info`, `v`, `debug`, `trace`. The
user's settings will determine which of these messages will be
visible. Normally, all messages are visible, except `v`, `debug` and
`trace`.

The parameters after that are all converted to strings. Spaces are inserted
to separate multiple parameters.

You don't need to add newlines.

`msg.fatal(...)`, `msg.error(...)`, `msg.warn(...)`, `msg.info(...)`, `msg.verbose(...)`, `msg.debug(...)`, `msg.trace(...)`

All of these are shortcuts and equivalent to the corresponding
`msg.log(level, ...)` call.

