# INTERACTIVE CONTROL

mpv has a fully configurable, command-driven control layer which allows you
to control mpv using keyboard, mouse, or remote control (there is no
LIRC support - configure remotes as input devices instead).

See the `--input-` options for ways to customize it.

The following listings are not necessarily complete. See `etc/input.conf`
in the mpv source files for a list of default bindings. User `input.conf`
files and Lua scripts can define additional key bindings.

See [COMMAND INTERFACE](manual-input-conf.md) and [Key names](manual-key-names.md) sections for more details on
configuring keybindings.

See also `--input-test` for interactive binding details by key, and the
[stats](manual-stats-1.md) built-in script for key bindings list (including print to terminal). By
default, the ? key toggles the display of this list.

## Keyboard Control

LEFT and RIGHT

Seek backward/forward 5 seconds. Shift+arrow does a 1 second exact seek
(see `--hr-seek`).

UP and DOWN

Seek forward/backward 1 minute. Shift+arrow does a 5 second exact seek (see
`--hr-seek`).

Ctrl+LEFT and Ctrl+RIGHT

Seek to the previous/next subtitle. Subject to some restrictions and
might not always work; see `sub-seek` command.

Ctrl+Shift+LEFT and Ctrl+Shift+RIGHT

Adjust subtitle delay so that the previous or next subtitle is displayed
now. This is especially useful to sync subtitles to audio.

[ and ]

Decrease/increase current playback speed by 10%.

{ and }

Halve/double current playback speed.

BACKSPACE

Reset playback speed to normal.

Shift+BACKSPACE

Undo the last seek. This works only if the playlist entry was not changed.
Hitting it a second time will go back to the original position.
See `revert-seek` command for details.

Shift+Ctrl+BACKSPACE

Mark the current position. This will then be used by `Shift+BACKSPACE`
as revert position (once you seek back, the marker will be reset). You can
use this to seek around in the file and then return to the exact position
where you left off.

< and >

Go backward/forward in the playlist.

ENTER

Go forward in the playlist.

Shift+HOME and Shift+END

Go to the first/last playlist entry.

p and SPACE

Pause (pressing again unpauses).

.

Step forward. Pressing once will pause, every consecutive press will
play one frame and then go into pause mode again.

,

Step backward. Pressing once will pause, every consecutive press will
play one frame in reverse and then go into pause mode again.

q

Stop playing and quit.

Q

Like `q`, but store the current playback position. Playing the same file
later will resume at the old playback position if possible. See
[RESUMING PLAYBACK](manual-resuming-playback.md).

/ and *

Decrease/increase volume.

KP_DIVIDE and KP_MULTIPLY

Decrease/increase volume.

9 and 0

Decrease/increase volume.

m

Mute sound.

_

Cycle through the available video tracks.

#

Cycle through the available audio tracks.

E

Cycle through the available Editions.

f

Toggle fullscreen (see also `--fs`).

ESC

Exit fullscreen mode.

T

Toggle stay-on-top (see also `--ontop`).

w and W

Decrease/increase pan-and-scan range. The `e` key does the same as
`W` currently, but use is discouraged. See `--panscan` for more
information.

o and P

Show progression bar, elapsed time and total duration on the OSD.

O

Toggle OSD states between normal and playback time/duration.

v

Toggle subtitle visibility.

Alt+v

Toggle secondary subtitle visibility.

j and J

Cycle through the available subtitles.

z and Z

Adjust subtitle delay by -/+ 0.1 seconds. The `x` key does the same as
`Z` currently, but use is discouraged.

l

Set/clear A-B loop points. See `ab-loop` command for details.

L

Toggle infinite looping.

Ctrl++ and Ctrl+-

Adjust audio delay (A/V sync) by +/- 0.1 seconds.

Ctrl+KP_ADD and Ctrl+KP_SUBTRACT

Adjust audio delay (A/V sync) by +/- 0.1 seconds.

G and F

Adjust subtitle font size by +/- 10%.

u

