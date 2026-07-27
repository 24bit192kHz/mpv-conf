## Conditional auto profiles

Profiles which have the `profile-cond` option set are applied automatically
if the associated condition matches (unless auto profiles are disabled). The
option takes a string, which is interpreted as Lua expression. If the
expression evaluates as truthy, the profile is applied. If the expression
errors or evaluates as falsy, the profile is not applied. This Lua code
execution is not sandboxed.

Any variables in condition expressions can reference properties. If an
identifier is not already defined by Lua or mpv, it is interpreted as property.
For example, `pause` would return the current pause status. You cannot
reference properties with `-` this way since that would denote a subtraction,
but if the variable name contains any `_` characters, they are turned into
`-`. For example, `playback_time` would return the property
`playback-time`.

A more robust way to access properties is using `p.property_name` or
`get("property-name", default_value)`. The automatic variable to property
magic will break if a new identifier with the same name is introduced (for
example, if a function named `pause()` were added, `pause` would return a
function value instead of the value of the `pause` property).

Note that if a property is not available, it will return `nil`, which can
cause errors if used in expressions. These are logged in verbose mode, and the
expression is considered to be false.

Whenever a property referenced by a profile condition changes, the condition
is re-evaluated. If the return value of the condition changes from falsy or
error to truthy, the profile is applied.

This mechanism tries to "unapply" profiles once the condition changes from
truthy to falsy or error. If you want to use this, you need to set
`profile-restore` for the profile. Another possibility it to create another
profile with an inverse condition to undo the other profile.

Recursive profiles can be used. But it is discouraged to reference other
conditional profiles in a conditional profile, since this can lead to tricky
and unintuitive behavior.

Example

Make only HD video look funny:

```
[something]
profile-desc=HD video sucks
profile-cond=width >= 1280
hue=-50
```

Make only videos containing "youtube" or "youtu.be" in their path brighter:

```
[youtube]
profile-cond=path:find('youtu%.?be')
gamma=20
```

If you want the profile to be reverted if the condition goes to false again,
you can set `profile-restore`:

```
[something]
profile-desc=Mess up video when entering fullscreen
profile-cond=fullscreen
profile-restore=copy
vf-add=rotate=PI/2  # rotate by 90 degrees
```

This appends the `rotate` filter to the video filter chain when entering
fullscreen. When leaving fullscreen, the `vf` option is set to the value
it had before entering fullscreen. Note that this would also remove any
other filters that were added during fullscreen mode by the user. Avoiding
this is trickier, and could for example be solved by adding a second profile
with an inverse condition and operation:

```
[something]
profile-cond=fullscreen
vf-add=@rot:rotate=PI/2

[something-inv]
profile-cond=not fullscreen
vf-remove=@rot
```

Warning

Every time an involved property changes, the condition is evaluated again.
If your condition uses `p.playback_time` for example, the condition is
re-evaluated approximately on every video frame. This is probably slow.

This feature is managed by an internal Lua script. Conditions are executed as
Lua code within this script. Its environment contains at least the following
things:

`(function environment table)`

Every Lua function has an environment table. This is used for identifier
access. There is no named Lua symbol for it; it is implicit.

The environment does "magic" accesses to mpv properties. If an identifier
is not already defined in `_G`, it retrieves the mpv property of the same
name. Any occurrences of `_` in the name are replaced with `-` before
reading the property. The returned value is as retrieved by
`mp.get_property_native(name)`. Internally, a cache of property values,
updated by observing the property is used instead, so properties that are
not observable will be stuck at the initial value forever.

If you want to access properties, that actually contain `_` in the name,
use `get()` (which does not perform transliteration).

Internally, the environment table has a `__index` meta method set, which
performs the access logic.

`p`

A "magic" table similar to the environment table. Unlike the latter, this
does not prefer accessing variables defined in `_G` - it always accesses
properties.

`get(name [, def])`

Read a property and return its value. If the property value is `nil` (e.g.
if the property does not exist), `def` is returned.

This is superficially similar to `mp.get_property_native(name)`. An
important difference is that this accesses the property cache, and enables
the change detection logic (which is essential to the dynamic runtime
behavior of auto profiles). Also, it does not return an error value as
second return value.

The "magic" tables mentioned above use this function as backend. It does not
perform the `_` transliteration.

In addition, the same environment as in a blank mpv Lua script is present. For
example, `math` is defined and gives access to the Lua standard math library.

Warning

This feature is subject to change indefinitely. You might be forced to
adjust your profiles on mpv updates.

## Legacy auto profiles

Some profiles are loaded automatically using a legacy mechanism. The following
example demonstrates this:

Auto profile loading

```
[extension.mkv]
profile-desc="profile for .mkv files"
vf=vflip
```

The profile name follows the schema `type.name`, where type can be
`protocol` for the input/output protocol in use (see `--list-protocols`),
and `extension` for the extension of the path of the currently played file
(*not* the file format).

This feature is very limited, and is considered soft-deprecated. Use conditional
auto profiles.
