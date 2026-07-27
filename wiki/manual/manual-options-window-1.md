## Window

`--title=<string>`

Set the window title. This is used for the video window, and if possible,
also sets the audio stream title.

Properties are expanded. (See [Property Expansion](manual-property-list-1.md).)

Warning

There is a danger of this causing significant CPU usage, depending on
the properties used. Changing the window title is often a slow
operation, and if the title changes every frame, playback can be ruined.

`--screen=<default|0-32>`

In multi-monitor configurations (i.e. a single desktop that spans across
multiple displays), this option tells mpv which screen to display the
video on.

Note (X11)

This option does not work properly with all window managers. In these
cases, you can try to use `--geometry` to position the window
explicitly. It's also possible that the window manager provides native
features to control which screens application windows should use.

Note (Wayland)

This option does not actually work on wayland since window placement is
not allowed. However setting this option does influence mpv's initial
guess at finding an output which may be useful for options like
`--geometry` or `--autofit` which depend on the monitor resolution.

See also `--fs-screen`.

`--screen-name=<string>`

In multi-monitor configurations, this option tells mpv which screen to
display the video on based on the screen name from the video backend. The
same caveats in the `--screen` option also apply here. This option is
ignored and does nothing if `--screen` is explicitly set.

`--fullscreen`, `--fs`

Fullscreen playback.

`--fs-screen=<all|current|0-32>`

In multi-monitor configurations (i.e. a single desktop that spans across
multiple displays), this option tells mpv which screen to go fullscreen to.
If `current` is used mpv will fallback on what the user provided with
the `screen` option.

Note (X11)

This option works properly only with window managers which
understand the EWMH `_NET_WM_FULLSCREEN_MONITORS` hint.

Note (macOS)

`all` does not work on macOS and will behave like `current`.

See also `--screen`.

`--fs-screen-name=<string>`

In multi-monitor configurations, this option tells mpv which screen to go
fullscreen to based on the screen name from the video backend. The same
caveats in the `--fs-screen` option also apply here. This option is
ignored and does nothing if `--fs-screen` is explicitly set.

`--keep-open=<yes|no|always>`

Do not terminate when playing or seeking beyond the end of the file, and
there is no next file to be played (and `--loop` is not used).
Instead, pause the player. When trying to seek beyond end of the file, the
player will attempt to seek to the last frame.

Normally, this will act like `set pause yes` on EOF, unless the
`--keep-open-pause=no` option is set.

The following arguments can be given:
| no: | If the current file ends, go to the next file or terminate.
(Default.) |
| --- | --- |
| yes: | Don't terminate if the current file is the last playlist entry.
Equivalent to `--keep-open` without arguments. |
| always: | Like `yes`, but also applies to files before the last playlist
entry. This means playback will never automatically advance to
the next file. |

Note

This option is not respected when using `--frames`. Explicitly
skipping to the next file if the binding uses `force` will terminate
playback as well.

Also, if errors or unusual circumstances happen, the player can quit
anyway.

Since mpv 0.6.0, this doesn't pause if there is a next file in the playlist,
or the playlist is looped. Approximately, this will pause when the player
would normally exit, but in practice there are corner cases in which this
is not the case (e.g. `mpv --keep-open file.mkv /dev/null` will play
file.mkv normally, then fail to open `/dev/null`, then exit). (In
mpv 0.8.0, `always` was introduced, which restores the old behavior.)

`--keep-open-pause=<yes|no>`

If set to `no`, instead of pausing when `--keep-open` is active, just
stop at end of file and continue playing forward when you seek backwards
until end where it stops again. Default: `yes`.

`--image-display-duration=<seconds|inf>`

If the current file is an image, play the image for the given amount of
seconds (default: 5). `inf` means the file is kept open forever (until
the user stops playback manually).

Unlike `--keep-open`, the player is not paused, but simply continues
playback until the time has elapsed. (It should not use any resources
during "playback".)

This affects image files, which are defined as having only 1 video frame
and no audio. The player may recognize certain non-images as images, for
example if `--length` is used to reduce the length to 1 frame, or if
you seek to the last frame.

This option does not affect the framerate used for `mf://` or
`--merge-files`. For that, use `--mf-fps` instead.

When viewing images, the playback time is not tracked on the command line
output, and the image frame is not duplicated when encoding. To force the
player into "dumb mode" and actually count out seconds, or to duplicate the
image when encoding, you need to use `--demuxer=lavf
--demuxer-lavf-o=loop=1`, and use `--length` or `--frames` to stop
after a particular time.

`--force-window=<yes|no|immediate>`

Create a video output window even if there is no video. This can be useful
when pretending that mpv is a GUI application. Currently, the window
always has the size 960x540, and is subject to `--geometry`,
`--autofit`, and similar options.

Warning

The window is created only after initialization (to make sure default
window placement still works if the video size is different from the
`--force-window` default window size). This can be a problem if
initialization doesn't work perfectly, such as when opening URLs with
bad network connection, or opening broken video files. The `immediate`
mode can be used to create the window always on program start, but this
may cause other issues.

`--taskbar-progress=<yes|no>`

(Windows only)
Enable/disable playback progress rendering in taskbar (Windows 7 and above).

Enabled by default.

`--snap-window`

(Windows only) Snap the player window to screen edges.

`--drag-and-drop=<no|auto|replace|append|insert-next>`

Controls the default behavior of drag and drop on platforms that support
this. `auto` will obey what the underlying os/platform gives mpv.
Typically, holding shift during the drag and drop will append the item to
the playlist. Otherwise, it will completely replace it. `replace`,
`append`, and `insert-next` always force replacing, appending to, and
inserting next into the playlist respectively. `no` disables all drag and
drop behavior.

`--ontop`

Makes the player window stay on top of other windows.

On Windows, if combined with fullscreen mode, this causes mpv to be
treated as exclusive fullscreen window that bypasses the Desktop Window
Manager.

`--ontop-level=<window|system|desktop|level>`

(macOS only)
Sets the level of an on-top window (default: window).
| window: | On top of all other windows. |
| --- | --- |
| system: | On top of system elements like Taskbar, Menubar and Dock. |
| desktop: | On top of the Desktop behind windows and Desktop icons. |
| level: | A level as integer. |
