
`fs-only` asks the window manager to disable the compositor only in
fullscreen mode.

`no` sets `_NET_WM_BYPASS_COMPOSITOR` to 0, which is the default value
as declared by the EWMH specification, i.e. no change is done.

`never` asks the window manager to never disable the compositor.

`--x11-present=<no|auto|yes>`

Whether or not to use presentation statistics from X11's presentation
extension (default: `auto`).

mpv asks X11 for present events which it then may use for more accurate
frame presentation. This only has an effect if `--video-sync=display-...`
is being used.

The auto option enumerates XRandr providers for autodetection. If amd, radeon,
intel, or nouveau (the standard x86 Mesa drivers) is found presentation
feedback is enabled. Other drivers are not assumed to work, so they are not
enabled automatically.

`yes` or `no` can still be passed regardless to enable/disable this
mechanism in case there is good/bad behavior with whatever your combination
of hardware/drivers/etc. happens to be.

`--x11-wid-title=<yes|no>`

Whether or not to set the window title when mpv is embedded on X11 (default:
`no`).
