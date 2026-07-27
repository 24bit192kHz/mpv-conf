Switch between applying only `--sub-ass-*` overrides (default) to SSA/ASS
subtitles, and overriding them almost completely with the normal subtitle
style. See `--sub-ass-override` for more info.

V

Cycle through which video data gets used for ASS rendering.
See `--sub-ass-use-video-data` for more info.

r and R

Move subtitles up/down. The `t` key does the same as `R` currently, but
use is discouraged.

s

Take a screenshot.

S

Take a screenshot, without subtitles. (Whether this works depends on VO
driver support.)

Ctrl+s

Take a screenshot, as the window shows it (with subtitles, OSD, and scaled
video).

HOME

Seek to the beginning of the file.

PGUP and PGDWN

Seek to the beginning of the previous/next chapter. In most cases,
"previous" will actually go to the beginning of the current chapter; see
`--chapter-seek-threshold`.

Shift+PGUP and Shift+PGDWN

Seek backward or forward by 10 minutes. (This used to be mapped to
PGUP/PGDWN without Shift.)

b

Activate/deactivate debanding.

d

Cycle the deinterlacing filter.

A

Cycle aspect ratio override.

Ctrl+h

Toggle hardware video decoding on/off.

Alt+LEFT, Alt+RIGHT, Alt+UP, Alt+DOWN

Move the video rectangle (panning).

Alt++ and Alt+-

Change video zoom.

Alt+KP_ADD and Alt+KP_SUBTRACT

Change video zoom.

Alt+BACKSPACE

Reset the pan/zoom settings.

F8

Show the playlist and the current position in it.

F9

Show the list of audio and subtitle streams.

Ctrl+v

Append the file or URL in the clipboard to the playlist. If nothing is
currently playing, it is played immediately. Only works on platforms that
support the `clipboard` property.

i and I

Show/toggle an overlay displaying statistics about the currently playing
file such as codec, framerate, number of dropped frames and so on. See
[STATS](manual-stats-1.md) for more information.

?

Toggle an overlay displaying the active key bindings. See [STATS](manual-stats-1.md) for more
information.

DEL

Cycle OSC visibility between never / auto (mouse-move) / always

`

Show the console. (ESC closes it again. See [CONSOLE](manual-console-1.md).)

(The following keys are valid only when using a video output that supports the
corresponding adjustment.)

1 and 2

Adjust contrast.

3 and 4

Adjust brightness.

5 and 6

Adjust gamma.

7 and 8

Adjust saturation.

Alt+0 (and Command+0 on macOS)

Resize video window to half its original size.

Alt+1 (and Command+1 on macOS)

Resize video window to its original size.

Alt+2 (and Command+2 on macOS)

Resize video window to double its original size.

Command + f (macOS only)

Toggle fullscreen (see also `--fs`).

(The following keybindings open a menu in the console that lets you choose from
a list of items by typing part of the desired item, by clicking the desired
item, or by navigating them with keybindings: `Down` and `Ctrl+n` go down,
`Up` and `Ctrl+p` go up, `Page down` and `Ctrl+f` scroll down one page,
and `Page up` and `Ctrl+b` scroll up one page.)

In track menus, selecting the current tracks disables it.

g-p

Select a playlist entry.

g-s

Select a subtitle track.

g-S

Select a secondary subtitle track.

g-a

Select an audio track.

g-v

Select a video track.

g-t

Select a track of any type.

g-c

Select a chapter.

g-e

Select an MKV edition or DVD/Blu-ray title.

g-l

Select a subtitle line to seek to. This currently requires `ffmpeg` in
`PATH`, or in the same folder as mpv on Windows.

g-d

Select an audio device.

g-h

Select a file from the watch history. Requires `--save-watch-history`.
