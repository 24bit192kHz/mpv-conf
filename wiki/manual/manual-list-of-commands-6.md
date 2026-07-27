degenerate, it is not set. `x1`/`y1` is the coordinate of the
bottom exclusive corner of the rectangle.

The result value may depend on the VO window size, and is based on the
last known window size at the time of the call. This means the results
may be different from what is actually rendered.

For `ass-events`, the result rectangle is recomputed to `PlayRes`
coordinates (`res_x`/`res_y`). If window size is not known, a
fallback is chosen.

You should be aware that this mechanism is very inefficient, as it
renders the full result, and then uses the bounding box of the rendered
bitmap list (even if `hidden` is set). It will flush various caches.
Its results also depend on the used libass version.

This feature is experimental, and may change in some way again.

Note

Always use named arguments (`mpv_command_node()`). Lua scripts should
use the `mp.create_osd_overlay()` helper instead of invoking this
command directly.

### Input and Keybind Commands

`mouse <x> <y> [<button> [<mode>]]`

Send a mouse event with given coordinate (`<x>`, `<y>`).

Second argument:

<button>

The button number of clicked mouse button. This should be one of 0-19.
If `<button>` is omitted, only the position will be updated.

Third argument:

<single> (default)

The mouse event represents regular single click.

<double>

The mouse event represents double-click.

`keypress <name> [<scale>]`

Send a key event through mpv's input handler, triggering whatever
behavior is configured to that key. `name` uses the `input.conf`
naming scheme for keys and modifiers. `scale` is used to scale numerical
change effected by the bound command (same mechanism as precise scrolling).
Useful for the client API: key events can be sent to libmpv to handle
internally.

`keydown <name>`

Similar to `keypress`, but sets the `KEYDOWN` flag so that if the key is
bound to a repeatable command, it will be run repeatedly with mpv's key
repeat timing until the `keyup` command is called.

`keyup [<name>]`

Set the `KEYUP` flag, stopping any repeated behavior that had been
triggered. `name` is optional. If `name` is not given or is an
empty string, `KEYUP` will be set on all keys. Otherwise, `KEYUP` will
only be set on the key specified by `name`.

`keybind <name> <cmd> [<comment>]`

Binds a key to an input command. `cmd` must be a complete command
containing all the desired arguments and flags. Both `name` and
`cmd` use the `input.conf` naming scheme. `comment` is an optional
string which can be read as the `comment` entry of `input-bindings`.
This is primarily useful for the client API.

`enable-section <name> [<flags>]`

This command is deprecated, except for mpv-internal uses.

Enable all key bindings in the named input section.

The enabled input sections form a stack. Bindings in sections on the top of
the stack are preferred to lower sections. This command puts the section
on top of the stack. If the section was already on the stack, it is
implicitly removed beforehand. (A section cannot be on the stack more than
once.)

The `flags` parameter can be a combination (separated by `+`) of the
following flags:

<exclusive>

All sections enabled before the newly enabled section are disabled.
They will be re-enabled as soon as all exclusive sections above them
are removed. In other words, the new section shadows all previous
sections.

<allow-hide-cursor>

This feature can't be used through the public API.

<allow-vo-dragging>

Same.

`disable-section <name>`

This command is deprecated, except for mpv-internal uses.

Disable the named input section. Undoes `enable-section`.

`define-section <name> <contents> [<flags>]`

This command is deprecated, except for mpv-internal uses.

Create a named input section, or replace the contents of an already existing
input section. The `contents` parameter uses the same syntax as the
`input.conf` file (except that using the section syntax in it is not
allowed), including the need to separate bindings with a newline character.

If the `contents` parameter is an empty string, the section is removed.

The section with the name `default` is the normal input section.

In general, input sections have to be enabled with the `enable-section`
command, or they are ignored.

The last parameter has the following meaning:

<default> (also used if parameter omitted)

Use a key binding defined by this section only if the user hasn't
already bound this key to a command.

<force>

Always bind a key. (The input section that was made active most recently
wins if there are ambiguities.)

This command can be used to dispatch arbitrary keys to a script or a client
API user. If the input section defines `script-binding` commands, it is
also possible to get separate events on key up/down, and relatively detailed
information about the key state. The special key name `unmapped` can be
used to match any unmapped key.

`load-input-conf <filename>`

Load an input configuration file, similar to the `--input-conf` option. If
the file was already included, its previous bindings are not reset before it
is reparsed.

