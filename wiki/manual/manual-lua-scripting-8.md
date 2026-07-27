
The string to be displayed before the input field.

`items`

The table of the entries to choose from.

`default_item`

The 1-based integer index of the preselected item.

`submit`

The callback invoked when the user presses Enter. The first argument is
the 1-based index of the selected item.

`keep_open`

Whether to keep the console open on submit. Defaults to `false`.

Example:

> ```
> input.select({
>     items = {
>         "First playlist entry",
>         "Second playlist entry",
>     },
>     submit = function (id)
>         mp.commandv("playlist-play-index", id - 1)
>     end,
> })
> ```

## Events

Events are notifications from player core to scripts. You can register an
event handler with `mp.register_event`.

Note that all scripts (and other parts of the player) receive events equally,
and there's no such thing as blocking other scripts from receiving events.

Example:

```
function my_fn(event)
    print("start of playback!")
end

mp.register_event("file-loaded", my_fn)
```

For the existing event types, see [List of events](manual-list-of-commands-1.md).

## Extras

This documents experimental features, or features that are "too special" to
guarantee a stable interface.

`mp.add_hook(type, priority, fn)`

Add a hook callback for `type` (a string identifying a certain kind of
hook). These hooks allow the player to call script functions and wait for
their result (normally, the Lua scripting interface is asynchronous from
the point of view of the player core). `priority` is an arbitrary integer
that allows ordering among hooks of the same kind. Using the value 50 is
recommended as neutral default value.

`fn(hook)` is the function that will be called during execution of the
hook. The parameter passed to it (`hook`) is a Lua object that can control
further aspects about the currently invoked hook. It provides the following
methods:

> `defer()`
>
>
> Returning from the hook function should not automatically continue
> the hook. Instead, the API user wants to call `hook:cont()` on its
> own at a later point in time (before or after the function has
> returned).
>
>
> `cont()`
>
>
> Continue the hook. Doesn't need to be called unless `defer()` was
> called.

See [Hooks](manual-hooks.md) for currently existing hooks and what they do - only the hook
list is interesting; handling hook execution is done by the Lua script
function automatically.
