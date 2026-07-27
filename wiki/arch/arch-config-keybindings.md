### Key bindings

Key bindings are fairly straightforward given the examples in `/usr/share/doc/mpv/input.conf` and `man mpv` (COMMAND INTERFACE section).

Add the following examples to `~/.config/mpv/input.conf`:

```
shift+s         screenshot each-frame
Shift+UP        seek  600
Shift+DOWN      seek -600
=               cycle video-unscaled
-               cycle-values window-scale 2 3 1 .5
WHEEL_UP        add volume 5
WHEEL_DOWN      add volume -5
WHEEL_LEFT      ignore
WHEEL_RIGHT     ignore
Alt+RIGHT       add video-rotate 90
Alt+LEFT        add video-rotate -90
Alt+-           add video-zoom -0.25
Alt+=           add video-zoom 0.25
Alt+j           add video-pan-x -0.05
Alt+l           add video-pan-x 0.05
Alt+i           add video-pan-y 0.05
Alt+k           add video-pan-y -0.05
Alt+BS          set video-zoom 0; set video-pan-x 0; set video-pan-y 0
```

For an attempt to reproduce MPC-HC key bindings in mpv, see [this config](https://github.com/dragons4life/MPC-HC-config-for-MPV/blob/master/input.conf).

### Additional configuration files

In addition there are a few more configuration files and directories that can be created, among which:

- `~/.config/mpv/script-opts/osc.conf` manages the On Screen Controller. See `man mpv` (ON SCREEN CONTROLLER section) for more information.
- `~/.config/mpv/scripts/script-name.lua` for Lua scripts. See [this example](https://github.com/mpv-player/mpv/issues/3500#issuecomment-305646994).

See `man mpv` (FILES section) for information on other files and directories.
