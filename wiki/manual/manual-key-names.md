## Key matching

mpv maintains key press history. If the current key completes one or more bound
sequences (including single-key bindings), then mpv chooses the longest. If this
sequence is bound to `ignore`, then tracking continues as if nothing was
matched. Otherwise, it triggers the command bound to this sequence and clears
the key history.

Note that while single-key bindings override builtin bindings, this is not the
case with multi-key sequences. For example, a `b-c` sequence in input.conf
would be overridden by a builtin binding `b`. In this case, if you don't care
about `b`, you can bind it to `ignore`.

As a more complex example, if you want to bind both `b` and `a-b-c`, then it
won't work, because `b` would override `a-b-c`. However, binding `a-b` to
`ignore` would allow that, because after `a-b` the longest match `a-b` is
ignored, and a following `c` would trigger the sequence `a-b-c` while `b`
alone would still work.

## Key names

All mouse and keyboard input is to converted to mpv-specific key names. Key
names are either special symbolic identifiers representing a physical key, or
text key names, which are Unicode code points encoded as UTF-8. These are what
keyboard input would normally produce, for example `a` for the A key.
These are influenced by keyboard modifiers which affect produced text, such as
shift and caps lock. As a consequence, mpv uses input translated by the current
OS keyboard layout, rather than physical scan codes.

Currently there is the hardcoded assumption that every text key can be
represented as a single Unicode code point (in NFKC form).

All key names can be combined with the modifiers `Shift`, `Ctrl`, `Alt`,
`Meta`. They must be prefixed to the actual key name, where each modifier
is followed by a `+` (for example `ctrl+q`).

Note

The `Shift` modifier requires some attention. In general, when the
`Shift` modifier is combined with a key which produces text, the actual
produced text key name when shift is pressed should be used.

For instance, on the US keyboard layout, `Shift+2` should usually be
specified as key-name `@` at `input.conf`, and similarly the
combination `Alt+Shift+2` is usually `Alt+@`, etc.

In general, the `Shift` modifier, when specified with text key names,
is ignored: for instance, mpv interprets `Shift+2` as `2`.
The only exceptions are ASCII letters, which are normalized by mpv.
For example, `Shift+a` is interpreted as `A`.

Special key names like `Shift+LEFT` work as expected.
If in doubt - use `--input-test` to check how a key/combination is seen
by mpv.

Symbolic key names and modifier names are case-insensitive. Unicode key names
are case-sensitive just like how keyboard text input would produce.

Another type of key names are hexadecimal key names, which start with `0x`,
followed by the hexadecimal value of the key. The hexadecimal value can be
either a Unicode code point value, or can serve as fallback for special keys
that do not have a special mpv defined name. They will break as soon as mpv
adds proper names for them, but can enable you to use a key at all if that
does not happen.

All symbolic names are listed by `--input-keylist`. `--input-test` is a
special mode that prints all input on the OSD.

Comments on some symbolic names:

`KP*`

Keypad names. Behavior varies by backend (whether they implement this, and
on how they treat numlock), but typically, mpv tries to map keys on the
keypad to separate names, even if they produce the same text as normal keys.

`MOUSE_BTN*`, `MBTN*`

Various mouse buttons.

Depending on backend, the mouse wheel might also be represented as a button.
In addition, `MOUSE_BTN3` to `MOUSE_BTN6` are deprecated aliases for
`WHEEL_UP`, `WHEEL_DOWN`, `WHEEL_LEFT`, `WHEEL_RIGHT`.

`MBTN*` are aliases for `MOUSE_BTN*`.

`WHEEL_*`

Mouse wheels and touch pads (typically).

These key are scalable when used with scalable commands if the underlying
device supports high-resolution scrolling (e.g. touch pads).

`AXIS_*`

Deprecated aliases for `WHEEL_*`.

`*_DBL`

Mouse button double clicks.

`MOUSE_MOVE`, `MOUSE_ENTER`, `MOUSE_LEAVE`

Emitted by mouse move events. Enter/leave happens when the mouse enters or
leave the mpv window (or the current mouse region, using the deprecated
mouse region input section mechanism).

`CLOSE_WIN`

Pseudo key emitted when closing the mpv window using the OS window manager
(for example, by clicking the close button in the window title bar).

`GAMEPAD_*`

Keys emitted by the SDL gamepad backend.

`UNMAPPED`

Pseudo-key that matches any unmapped key. (You should probably avoid this
if possible, because it might change behavior or get removed in the future.)

`ANY_UNICODE`

Pseudo-key that matches any key that produces text. (You should probably
avoid this if possible, because it might change behavior or get removed in
the future.)
