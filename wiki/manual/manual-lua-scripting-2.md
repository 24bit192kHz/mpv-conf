## mp functions

The `mp` module is preloaded, although it can be loaded manually with
`require 'mp'`. It provides the core client API.

`mp.command(string)`

Run the given command. This is similar to the commands used in input.conf.
See [List of Input Commands](manual-list-of-commands-1.md).

By default, this will show something on the OSD (depending on the command),
as if it was used in `input.conf`. See [Input Command Prefixes](manual-input-commands-1.md) how
to influence OSD usage per command.

Returns `true` on success, or `nil, error` on error.

`mp.commandv(arg1, arg2, ...)`

Similar to `mp.command`, but pass each command argument as separate
parameter. This has the advantage that you don't have to care about
quoting and escaping in some cases.

Example:

```
mp.command("loadfile " .. filename .. " append")
mp.commandv("loadfile", filename, "append")
```

These two commands are equivalent, except that the first version breaks
if the filename contains spaces or certain special characters.

Note that properties are *not* expanded.  You can use either `mp.command`,
the `expand-properties` prefix, or the `mp.get_property` family of
functions.

Unlike `mp.command`, this will not use OSD by default either (except
for some OSD-specific commands).

`mp.command_native(table [,def])`

Similar to `mp.commandv`, but pass the argument list as table. This has
the advantage that in at least some cases, arguments can be passed as
native types. It also allows you to use named argument.

If the table is an array, each array item is like an argument in
`mp.commandv()` (but can be a native type instead of a string).

If the table contains string keys, it's interpreted as command with named
arguments. This requires at least an entry with the key `name` to be
present, which must be a string, and contains the command name. The special
entry `_flags` is optional, and if present, must be an array of
[Input Command Prefixes](manual-input-commands-1.md) to apply. All other entries are interpreted as
arguments.

Returns a result table on success (usually empty), or `def, error` on
error. `def` is the second parameter provided to the function, and is
nil if it's missing.

`mp.command_native_async(table [,fn])`

Like `mp.command_native()`, but the command is ran asynchronously (as far
as possible), and upon completion, fn is called. fn has three arguments:
`fn(success, result, error)`:

> `success`
>
>
> Always a Boolean and is true if the command was successful,
> otherwise false.
>
>
> `result`
>
>
> The result value (can be nil) in case of success, nil otherwise (as
> returned by `mp.command_native()`).
>
>
> `error`
>
>
> The error string in case of an error, nil otherwise.

Returns a table with undefined contents, which can be used as argument for
`mp.abort_async_command`.

If starting the command failed for some reason, `nil, error` is returned,
and `fn` is called indicating failure, using the same error value.

`fn` is always called asynchronously, even if the command failed to start.

`mp.abort_async_command(t)`

Abort a `mp.command_native_async` call. The argument is the return value
of that command (which starts asynchronous execution of the command).
Whether this works and how long it takes depends on the command and the
situation. The abort call itself is asynchronous. Does not return anything.

`mp.del_property(name)`

Delete the given property. See `mp.get_property` and [Properties](manual-properties.md) for more
information about properties. Most properties cannot be deleted.

Returns true on success, or `nil, error` on error.

`mp.get_property(name [,def])`

Return the value of the given property as string. These are the same
properties as used in input.conf. See [Properties](manual-properties.md) for a list of
properties. The returned string is formatted similar to `${=name}`
(see [Property Expansion](manual-property-list-1.md)).

Returns the string on success, or `def, error` on error. `def` is the
second parameter provided to the function, and is nil if it's missing.

`mp.get_property_osd(name [,def])`

Similar to `mp.get_property`, but return the property value formatted for
OSD. This is the same string as printed with `${name}` when used in
input.conf.

Returns the string on success, or `def, error` on error. `def` is the
second parameter provided to the function, and is an empty string if it's
missing. Unlike `get_property()`, assigning the return value to a variable
will always result in a string.

`mp.get_property_bool(name [,def])`

Similar to `mp.get_property`, but return the property value as Boolean.

Returns a Boolean on success, or `def, error` on error.

`mp.get_property_number(name [,def])`

Similar to `mp.get_property`, but return the property value as number.

Note that while Lua does not distinguish between integers and floats,
mpv internals do. This function simply request a double float from mpv,
and mpv will usually convert integer property values to float.

Returns a number on success, or `def, error` on error.

`mp.get_property_native(name [,def])`

Similar to `mp.get_property`, but return the property value using the best
Lua type for the property. Most time, this will return a string, Boolean,
or number. Some properties (for example `chapter-list`) are returned as
tables.

Returns a value on success, or `def, error` on error. Note that `nil`
might be a possible, valid value too in some corner cases.

`mp.set_property(name, value)`

Set the given property to the given string value. See `mp.get_property`
and [Properties](manual-properties.md) for more information about properties.

Returns true on success, or `nil, error` on error.

`mp.set_property_bool(name, value)`

Similar to `mp.set_property`, but set the given property to the given
Boolean value.

`mp.set_property_number(name, value)`

Similar to `mp.set_property`, but set the given property to the given
numeric value.

Note that while Lua does not distinguish between integers and floats,
mpv internals do. This function will test whether the number can be
represented as integer, and if so, it will pass an integer value to mpv,
otherwise a double float.

`mp.set_property_native(name, value)`

Similar to `mp.set_property`, but set the given property using its native
type.

Since there are several data types which cannot represented natively in
Lua, this might not always work as expected. For example, while the Lua
wrapper can do some guesswork to decide whether a Lua table is an array
or a map, this would fail with empty tables. Also, there are not many
properties for which it makes sense to use this, instead of
`set_property`, `set_property_bool`, `set_property_number`.
For these reasons, this function should probably be avoided for now, except
for properties that use tables natively.

`mp.get_time()`

Return the current mpv internal time in seconds as a number. This is
basically the system time, with an arbitrary offset.

`mp.add_key_binding(key, name|fn [,fn [,flags]])`
