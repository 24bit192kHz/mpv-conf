while changing the volume by scrolling on a touchpad with the default
keybind. Due to the deadzone mechanism used, disabling the preprocessing
allows for diagonal scrolling (such as panning) and potentially reduces
input latency.

Note that disabling the preprocessing does not affect any filtering done
by the OS/driver before these events are delivered to mpv, if any.

`--input-right-alt-gr=<yes|no>`

(macOS and Windows only)
Use the right Alt key as Alt Gr to produce special characters. If disabled,
count the right Alt as an Alt modifier key. Enabled by default.

`--input-vo-keyboard=<yes|no>`

Disable all keyboard input on for VOs which can't participate in proper
keyboard input dispatching. May not affect all VOs. Generally useful for
embedding only.

On X11, a sub-window with input enabled grabs all keyboard input as long
as it is 1. a child of a focused window, and 2. the mouse is inside of
the sub-window. It can steal away all keyboard input from the
application embedding the mpv window, and on the other hand, the mpv
window will receive no input if the mouse is outside of the mpv window,
even though mpv has focus. Modern toolkits work around this weird X11
behavior, but naively embedding foreign windows breaks it.

The only way to handle this reasonably is using the XEmbed protocol, which
was designed to solve these problems. GTK provides `GtkSocket`, which
supports XEmbed. Qt doesn't seem to provide anything working in newer
versions.

If the embedder supports XEmbed, input should work with default settings
and with this option disabled. Note that `input-default-bindings` is
disabled by default in libmpv as well - it should be enabled if you want
the mpv default key bindings.

`--input-touch-emulate-mouse=<yes|no>`

When multi-touch support is enabled (either required by the platform,
or enabled by `--native-touch`), emulate mouse move and button presses
for the touch events (default: yes). This is useful for compatibility
for mouse key bindings and scripts which read mouse positions for platforms
which do not support `--native-touch=no` (e.g. Wayland).

`--input-tablet-emulate-mouse=<yes|no>`

Emulate mouse move and button presses for tablet events (default: yes).

Wayland only.

`--input-dragging-deadzone=<N>`

Begin the built-in window dragging when the mouse moves outside a deadzone of
`N` pixels while the mouse button is being held down (default: 3). This only
affects VOs which support the `begin-vo-dragging` command.

`--input-ime=<yes|no>`

Enable keyboard input via an active input method (IME) connected to the VO.
(default: no). The input popup window, if there is any, is always
positioned at the top left of the window. Whether pre-edit text is drawn
depends on the platform. You may need to configure your IME to display the
pre-edit inside of the input popup window if you cannot read the pre-edit
text in the mpv window.

Wayland and Windows only. This option is not applicable to terminal input.

Note

Enabling IME can cause problems with key bindings, because mpv cannot
detect any key presses when they go into the IME pre-edit area.
It is recommended to enable IME on demand only for the duration
while text input is expected.

The builtin console and input selector enable IME for the duration
of accepting text input.
