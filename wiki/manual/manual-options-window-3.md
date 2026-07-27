or unminimize, the video window if the current VO supports it. Note that
some VOs may support minimization while not supporting unminimization
(eg: Wayland).

Whether this option and `--window-maximized` work on program start or
at runtime, and whether they're (at runtime) updated to reflect the actual
window state, heavily depends on the VO and the windowing system. Some VOs
simply do not implement them or parts of them, while other VOs may be
restricted by the windowing systems (especially Wayland).

`--window-maximized=<yes|no>`

Whether the video window is maximized or not. Setting this will maximize,
or unmaximize, the video window if the current VO supports it. See
`--window-minimized` for further remarks.

`--cursor-autohide=<number|no|always>`

Make mouse cursor automatically hide after given number of milliseconds
(default: 1000 ms). `no` will disable cursor autohide. `always`
means the cursor will stay hidden.

`--cursor-autohide-fs-only`

If this option is given, the cursor is always visible in windowed mode. In
fullscreen mode, the cursor is shown or hidden according to
`--cursor-autohide`.

`--force-rgba-osd-rendering`

Change how some video outputs render the OSD and text subtitles. This
does not change appearance of the subtitles and only has performance
implications. For VOs which support native ASS rendering (like `gpu`,
`vdpau`, `direct3d`), this can be slightly faster or slower,
depending on GPU drivers and hardware. For other VOs, this just makes
rendering slower.

`--force-render`

Forces mpv to always render frames regardless of the visibility of the
window. Currently only affects X11, Wayland and macvk VOs since they are the
only ones that have this optimization (i.e. everything else always renders
regardless of visibility).

`--force-window-position`

Forcefully move mpv's video output window to default location whenever
there is a change in video parameters, video stream or file. This used to
be the default behavior. Currently only affects X11, macvk and SDL VOs.

`--auto-window-resize=<yes|no>`

By default, mpv will automatically resize itself if the video's size changes
(i.e. advancing forward in a playlist). Setting this to `no` disables this
behavior so the window size never changes automatically. This option does
not have any impact on the `--autofit` or `--geometry` options.

`--keepaspect=<yes|no>`

`--keepaspect=no` will always stretch the video to window size, and will
disable the window manager hints that force the window aspect ratio.
(Ignored in fullscreen mode.)

`--keepaspect-window=<yes|no>`

`--keepaspect-window=yes` (the default) will lock the window size to the
video aspect. `--keepaspect-window=no` disables this behavior, and will
instead add black bars if window aspect and video aspect mismatch. Whether
this actually works depends on the VO backend.
(Ignored in fullscreen mode.)

`--monitoraspect=<ratio>`

Set the aspect ratio of your monitor or TV screen. A value of 0 disables a
previous setting (e.g. in the config file). Overrides the
`--monitorpixelaspect` setting if enabled.

See also `--monitorpixelaspect` and `--video-aspect-override`.

Examples

- `--monitoraspect=4:3`  or `--monitoraspect=1.3333`

- `--monitoraspect=16:9` or `--monitoraspect=1.7777`

`--hidpi-window-scale=<yes|no>`

Scale the window size according to the backing DPI scale factor from the OS
(default: no). For example, if the OS DPI scaling is set to 200%, mpv's window
size will be multiplied by 2.

`--native-fs=<yes|no>`

(macOS only)
Uses the native fullscreen mechanism of the OS (default: yes).

`--show-in-taskbar=<yes|no>`

(Windows and X11 only)
Show mpv in the taskbar (default: yes). If set to no, mpv will no longer
appear in taskbars and tasklists in supported window managers, and may be
excluded from Alt+Tab window switching.

`--monitorpixelaspect=<ratio>`

Set the aspect of a single pixel of your monitor or TV screen (default:
1). A value of 1 means square pixels (correct for (almost?) all LCDs). See
also `--monitoraspect` and `--video-aspect-override`.

`--stop-screensaver=<yes|no|always>`

Turns off the screensaver (or screen blanker and similar mechanisms) at
startup and turns it on again on exit (default: yes). When using `yes`,
the screensaver will re-enable when playback is not active. `always` will
always disable the screensaver. Note that stopping the screensaver is only
possible if a video output is available (i.e. there is an open mpv window).
This is not supported on all video outputs, platforms, or desktop environments.

Before mpv 0.33.0, the X11 backend ran `xdg-screensaver reset` in 10 second
intervals when not paused in order to support screensaver inhibition in some
environments. This functionality was removed in 0.33.0, but it is possible to
call the `xdg-screensaver` command line program from a user script instead.

`--wid=<ID|-1>`

This tells mpv to attach to an existing window. If a VO is selected that
supports this option, it will use that window for video output. mpv will
scale the video to the size of this window, and will add black bars to
compensate if the aspect ratio of the video is different.

An ID of value `-1` is interpreted specially, and mpv will detach from
the currently attached window to its own window.

On X11, the ID is interpreted as a `Window` on X11. Unlike
MPlayer/mplayer2, mpv always creates its own window, and sets the wid
window as parent. The window will always be resized to cover the parent
window fully. The value `0` is interpreted specially, and mpv will
draw directly on the root window.

On win32, the ID is interpreted as `HWND`. Pass it as value cast to
`uint32_t` (all Windows handles are 32-bit), this is important as mpv will
not accept negative values. mpv will create its own window and set the
wid window as parent, like with X11. The value `0` is interpreted
specially, and mpv will draw on top of the desktop wallpaper and below
desktop icons.

On Android, the ID is interpreted as `android.view.Surface`. Pass it as a
value cast to `intptr_t`. Use with `--vo=mediacodec_embed` and
`--hwdec=mediacodec` for direct rendering using MediaCodec, or with
`--vo=gpu --gpu-context=android` (with or without `--hwdec=mediacodec`).

Note

On win32, if desktop wallpaper transition occurs (e.g. setting desktop
slideshow of multiple images in Windows settings) and an ID value `0`
is used, Windows may sometimes destroy the window mpv is attached to.
mpv will simply treat this as a quit signal in this case.

To prevent this from happening, set a static desktop wallpaper,
such as single image or pure color.

`--window-dragging=<yes|no>`

Move the window when clicking on it and moving the mouse pointer (default: yes).

`--x11-name=<string>`

Set the window instance name for X11-based video output methods.

`--x11-netwm=<yes|no|auto>`

(X11 only)
Control the use of NetWM protocol features.

This may or may not help with broken window managers. This provides some
functionality that was implemented by the now removed `--fstype` option.
Actually, it is not known to the developers to which degree this option
was needed, so feedback is welcome.

Specifically, `yes` will force use of NetWM fullscreen support, even if
not advertised by the WM. This can be useful for WMs that are broken on
purpose, like XMonad. (XMonad supposedly doesn't advertise fullscreen
support, because Flash uses it. Apparently, applications which want to
use fullscreen anyway are supposed to either ignore the NetWM support hints,
or provide a workaround. Shame on XMonad for deliberately breaking X
protocols (as if X isn't bad enough already).

By default, NetWM support is autodetected (`auto`).

This option might be removed in the future.

`--x11-bypass-compositor=<yes|no|fs-only|never>`

If set to `yes`, then ask the compositor to unredirect the mpv window
(default: `fs-only`). This uses the `_NET_WM_BYPASS_COMPOSITOR` hint.
