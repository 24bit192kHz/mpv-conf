# ON SCREEN CONTROLLER

The On Screen Controller (short: OSC) is a minimal GUI integrated with mpv to
offer basic mouse-controllability. It is intended to make interaction easier
for new users and to enable precise and direct seeking.

The OSC is enabled by default if mpv was compiled with Lua support. It can be
disabled entirely using the `--osc=no` option.

## Using the OSC

By default, the OSC will show up whenever the mouse is moved inside the
player window and will hide if the mouse is not moved outside the OSC for
0.5 seconds or if the mouse leaves the window.

### The Interface

```
+------+---------+---------+-----------------------------------------------+
| menu | pl prev | pl next | title                                   cache |
+------+------+------+---------+-----------+------+-------+-----+-----+----+
| play | skip | skip | time    |  seekbar  | time | audio | sub | vol | fs |
|      | back | frwd | elapsed |           | left |       |     |     |    |
+------+------+------+---------+-----------+------+-------+-----+-----+----+
```

menu

| left-click | open the menu |
| --- | --- |

pl prev

| left-click | play previous file in playlist |
| --- | --- |
| shift+L-click | show the playlist |
| middle-click | show the playlist |
| right-click | open the playlist menu |

pl next

| left-click | play next file in playlist |
| --- | --- |
| shift+L-click | show the playlist |
| middle-click | show the playlist |
| right-click | open the playlist menu |

title

Displays the current playlist position and media-title, filename or custom
title, or the target chapter name while hovering the seekbar.

| left-click | show file and track info |
| --- | --- |
| shift+L-click | show the path |
| middle-click | show the path |
| right-click | open the history menu |

cache

Shows current cache fill status

play

| left-click | toggle play/pause |
| --- | --- |
| shift+L-click | toggle infinite looping of the playlist |
| middle-click | toggle infinite looping of the playlist |
| right-click | toggle infinite looping of the current file |

skip back

| left-click | go to beginning of chapter / previous chapter |
| --- | --- |
| shift+L-click | show chapters |
| middle-click | show chapters |
| right-click | open the chapter menu |

skip frwd

| left-click | go to next chapter |
| --- | --- |
| shift+L-click | show chapters |
| middle-click | show chapters |
| right-click | open the chapter menu |

time elapsed

Shows current playback position timestamp

| left-click | toggle displaying timecodes with milliseconds |
| --- | --- |

seekbar

Indicates current playback position and position of chapters

| left-click | seek to position |
| --- | --- |
| right-click | seek to the nearest chapter |
| mouse wheel | seek forward/backward |

time left

Shows remaining playback time timestamp

| left-click | toggle between total and remaining time |
| --- | --- |

audio and sub

Displays selected track and amount of available tracks

| left-click | cycle audio/sub tracks forward |
| --- | --- |
| shift+L-click | cycle audio/sub tracks backwards |
| middle-click | cycle audio/sub tracks backwards |
| right-click | open the audio/sub track menu |
| mouse wheel | cycle audio/sub tracks forward/backwards |

vol

| left-click | toggle mute |
| --- | --- |
| right-click | open the audio device menu |
| mouse wheel | volume up/down |

fs

| left-click | toggle fullscreen |
| --- | --- |
| right-click | toggle whether the window is maximized |

Since mpv 0.40.0, it is possible to configure the commands to run with mouse
actions on some interface elements, and the default behaviors of several
elements were changed. If you miss some older behaviors, look at
`etc/restore-osc-bindings.conf` in the mpv git repository.

### Key Bindings

These key bindings are active by default if nothing else is already bound to
these keys. In case of collision, the function needs to be bound to a
different key. See the [Script Commands](manual-input-commands-1.md) section.
| del | Cycles visibility between never / auto (mouse-move) / always |
| --- | --- |

## Configuration

This script can be customized through a config file `script-opts/osc.conf`
placed in mpv's user directory and through the `--script-opts` command-line
option. The configuration syntax is described in [mp.options functions](manual-lua-scripting-1.md).

### Command-line Syntax

To avoid collisions with other scripts, all options need to be prefixed with
`osc-`.

Example:

```
--script-opts=osc-optionA=value1,osc-optionB=value2
```

