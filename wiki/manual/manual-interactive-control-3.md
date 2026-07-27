
g-w

Select a file from watch later config files (see [RESUMING PLAYBACK](manual-resuming-playback.md)) to
resume playing. Requires `--write-filename-in-watch-later-config`.

g-b

Select a defined input binding.

g-r

Show the values of all properties.

g-m, MENU, Ctrl+p

Show a menu with miscellaneous entries.

See [SELECT](manual-select.md) for more information.

(The following keys are valid if you have a keyboard with multimedia keys.)

PAUSE

Pause.

STOP

Stop playing and quit.

PREVIOUS and NEXT

Seek backward/forward 1 minute.

ZOOMIN and ZOOMOUT

Change video zoom.

If you miss some older key bindings, look at `etc/restore-old-bindings.conf`
in the mpv git repository.

## Mouse Control

Ctrl+left click

Pan while holding the button, keeping the clicked part of the video under
the cursor.

Left double click

Toggle fullscreen on/off.

Right click

Toggle pause on/off.

Forward/Back button

Skip to next/previous entry in playlist.

Wheel up/down

Decrease/increase volume.

Wheel left/right

Seek forward/backward 10 seconds.

Ctrl+Wheel up/down

Change video zoom keeping the part of the video hovered by the cursor under
it.

## Context Menu

Context Menu is a menu that pops up on the video window on user interaction
(mouse right click, etc.).

To use this feature, you need to fill the `menu-data` property with menu
definition data, and add a keybinding to run the `context-menu` command,
which can be done with a user script.
