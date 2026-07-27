
Register callback to be run on a key binding. The binding will be mapped to
the given `key`, which is a string describing the physical key. This uses
the same key names as in input.conf, and also allows combinations
(e.g. `ctrl+a`). If the key is empty or `nil`, no physical key is
registered, but the user still can create own bindings (see below).

After calling this function, key presses will cause the function `fn` to
be called (unless the user remapped the key with another binding).
However, if the key binding is canceled , the function will not be called,
unless `complex` flag is set to `true`, where the function will be
called with the `canceled` entry set to `true`.

For example, a canceled key binding can happen in the following situations:

- If key A is pressed while key B is being held down, key B is logically
released ("canceled" by key A), which stops the current autorepeat
action key B has.

- If key A is pressed while a mouse button is being held down, the mouse
button is logically released, but the mouse button's action will not be
called, unless `complex` flag is set to `true`.

The `name` argument should be a short symbolic string. It allows the user
to remap the key binding via input.conf using the `script-message`
command, and the name of the key binding (see below for
an example). The name should be unique across other bindings in the same
script - if not, the previous binding with the same name will be
overwritten. You can omit the name, in which case a random name is generated
internally. (Omitting works as follows: either pass `nil` for `name`,
or pass the `fn` argument in place of the name. The latter is not
recommended and is handled for compatibility only.)

The `flags` argument is used for optional parameters. This is a table,
which can have the following entries:

> `repeatable`
>
>
> If set to `true`, enables key repeat for this specific binding.
> This option only makes sense when `complex` is not set to `true`.
>
>
> `scalable`
>
>
> If set to `true`, enables key scaling for this specific binding.
> This option only makes sense when `complex` is set to `true`.
> Note that this has no effect if the key binding is invoked by
> `script-binding` command, where the scalability of the command
> takes precedence.
>
>
> `complex`
>
>
>
>
> If set to `true`, then `fn` is called on key down, repeat and up
> events, with the first argument being a table. This table has the
> following entries (and may contain undocumented ones):
>
>
>
> `event`
>
>
> Set to one of the strings `down`, `repeat`, `up` or
> `press` (the latter if key up/down/repeat can't be
> tracked), which indicates the key's logical state.
>
>
> `is_mouse`
>
>
> Boolean: Whether the event was caused by a mouse button.
>
>
> `canceled`
>
>
> Boolean: Whether the event was canceled.
> Not all types of cancellations set this flag.
>
>
> `key_name`
>
>
> The name of they key that triggered this, or `nil` if
> invoked artificially. If the key name is unknown, it's an
> empty string.
>
>
> `key_text`
>
>
> Text if triggered by a text key, otherwise `nil`. See
> description of `script-binding` command for details (this
> field is equivalent to the 5th argument).
>
>
> `scale`
>
>
> The scale of the key, such as the ones produced by `WHEEL_*`
> keys. The scale is 1 if the key is nonscalable.
>
>
> `arg`
>
>
> User-provided string in the `arg` argument in the
> `script-binding` command if the key binding is invoked
> by that command.

Internally, key bindings are dispatched via the `script-message-to` or
`script-binding` input commands and `mp.register_script_message`.

Trying to map multiple commands to a key will essentially prefer a random
binding, while the other bindings are not called. It is guaranteed that
user defined bindings in the central input.conf are preferred over bindings
added with this function (but see `mp.add_forced_key_binding`).

Example:

```
function something_handler()
    print("the key was pressed")
end
mp.add_key_binding("x", "something", something_handler)
```

This will print the message `the key was pressed` when `x` was pressed.

The user can remap these key bindings. Then the user has to put the
following into their input.conf to remap the command to the `y` key:

```
y script-binding something
```

This will print the message when the key `y` is pressed. (`x` will
still work, unless the user remaps it.)

You can also explicitly send a message to a named script only. Assume the
above script was using the filename `fooscript.lua`:

```
y script-binding fooscript/something
```

`mp.add_forced_key_binding(...)`

This works almost the same as `mp.add_key_binding`, but registers the
key binding in a way that will overwrite the user's custom bindings in their
input.conf. (`mp.add_key_binding` overwrites default key bindings only,
but not those by the user's input.conf.)

`mp.remove_key_binding(name)`

Remove a key binding added with `mp.add_key_binding` or
`mp.add_forced_key_binding`. Use the same name as you used when adding
the bindings. It's not possible to remove bindings for which you omitted
the name.

`mp.register_event(name, fn)`

Call a specific function when an event happens. The event name is a string,
and the function fn is a Lua function value.

Some events have associated data. This is put into a Lua table and passed
as argument to fn. The Lua table by default contains a `name` field,
which is a string containing the event name. If the event has an error
associated, the `error` field is set to a string describing the error,
on success it's not set.

If multiple functions are registered for the same event, they are run in
registration order, which the first registered function running before all
the other ones.

Returns true if such an event exists, false otherwise.

See [Events](manual-lua-scripting-1.md) and [List of events](manual-list-of-commands-1.md) for details.

`mp.unregister_event(fn)`

Undo `mp.register_event(..., fn)`. This removes all event handlers that
are equal to the `fn` parameter. This uses normal Lua `==` comparison,
so be careful when dealing with closures.

`mp.observe_property(name, type, fn)`

Watch a property for changes. If the property `name` is changed, then
the function `fn(name)` will be called. `type` can be `nil`, or be
set to one of `none`, `native`, `bool`, `string`, or `number`.
