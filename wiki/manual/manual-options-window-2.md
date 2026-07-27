
`--focus-on=<never|open|all>`,

(macOS only)
Focus the video window and make it the front most window on specific events (default: open).
| never: | Never focus the window on open or new file load events. |
| --- | --- |
| open: | Focus the window on creation, eg when a vo is initialised. |
| all: | Focus the window on open and new file load event. |

`--window-corners=<default|donotround|round|roundsmall>`

(Windows only)
Set the preference for window corner rounding.
| default: | Let the system decide whether or not to round window corners |
| --- | --- |
| donotround: | Never round window corners |
| round: | Round the corners if appropriate |
| roundsmall: | Round the corners if appropriate, with a small radius |

`--border=<yes|no>`

Play video with window border and decorations. Since this is on by
default, use `--no-border` to disable the standard window decorations.

`--title-bar=<yes|no>`

(Windows and X11 only)
Play video with the window title bar. Since this is on by default,
use `--title-bar=no` to hide the title bar. The `--border` option takes
precedence.

`--on-all-workspaces`

(X11 and macOS only)
Show the video window on all virtual desktops.

`--geometry=<[W[xH]][+-x+-y][/WS]>`, `--geometry=<x:y>`

Adjust the initial window position or size. `W` and `H` set the window
size in pixels. `x` and `y` set the window position, measured in pixels
from the top-left corner of the screen to the top-left corner of the image
being displayed. If a percentage sign (`%`) is given after the argument,
it turns the value into a percentage of the screen size in that direction.
Positions are specified similar to the standard X11 `--geometry` option
format, in which e.g. +10-50 means "place 10 pixels from the left border and
50 pixels from the lower border" and "--20+-10" means "place 20 pixels
beyond the right and 10 pixels beyond the top border". A trailing `/`
followed by an integer denotes on which workspace (virtual desktop) the
window should appear (X11 only).

If an external window is specified using the `--wid` option, this
option is ignored.

The coordinates are relative to the screen given with `--screen` for the
video output drivers that fully support `--screen`.

Note

Generally only supported by GUI VOs. Ignored for encoding.

Note (macOS)

On macOS, the origin of the screen coordinate system is located on the
bottom-left corner. For instance, `0:0` will place the window at the
bottom-left of the screen.

Note (X11)

This option does not work properly with all window managers.

Note (Wayland)

Wayland does not allow a client to position itself so this option will
only affect the window size.

Examples

`50:40`

Places the window at x=50, y=40.

`50%:50%`

Places the window in the middle of the screen.

`100%:100%`

Places the window at the bottom right corner of the screen.

`50%`

Sets the window width to half the screen width. Window height is set
so that the window has the video aspect ratio.

`50%x50%`

Forces the window width and height to half the screen width and
height. Will show black borders to compensate for the video aspect
ratio (with most VOs and with `--keepaspect=yes`).

`50%+10+10/2`

Sets the window to half the screen widths, and positions it 10
pixels below/left of the top left corner of the screen, on the
second workspace.

See also `--autofit` and `--autofit-larger` for fitting the window into
a given size without changing aspect ratio.

`--autofit=<[W[xH]]>`

Set the initial window size to a maximum size specified by `WxH`, without
changing the window's aspect ratio. The size is measured in pixels, or if
a number is followed by a percentage sign (`%`), in percents of the
screen size.

This option never changes the aspect ratio of the window. If the aspect
ratio mismatches, the window's size is reduced until it fits into the
specified size.

Window position is not taken into account, nor is it modified by this
option (the window manager still may place the window differently depending
on size). Use `--geometry` to change the window position. Its effects
are applied after this option.

See `--geometry` for details how this is handled with multi-monitor
setups.

Use `--autofit-larger` instead if you just want to limit the maximum size
of the window, rather than always forcing a window size.

Use `--geometry` if you want to force both window width and height to a
specific size.

Note

Generally only supported by GUI VOs. Ignored for encoding.

Examples

`70%`

Make the window width 70% of the screen size, keeping aspect ratio.

`1000`

Set the window width to 1000 pixels, keeping aspect ratio.

`70%x60%`

Make the window as large as possible, without being wider than 70%
of the screen width, or higher than 60% of the screen height.

`--autofit-larger=<[W[xH]]>`

This option behaves exactly like `--autofit`, except that it sets the
maximum size of the window.

Example

`90%x80%`

If the video is larger than 90% of the screen width or 80% of the
screen height, make the window smaller until either its width is 90%
of the screen, or its height is 80% of the screen.

`--autofit-smaller=<[W[xH]]>`

This option behaves exactly like `--autofit`, except that it sets the
minimum size of the window (just as `--autofit-larger` sets the maximum).

Example

`500x500`

Make the window at least 500 pixels wide and 500 pixels high
(depending on the video aspect ratio, the width or height will be
larger than 500 in order to keep the aspect ratio the same).

`--window-scale=<factor>`

Resize the video window to a multiple (or fraction) of the video size. This
option is applied before `--autofit` and other options are applied (so
they override this option). Changing this option while the window is
maximized can unmaximize the window depending on the OS and window manager.
If the window does not unmaximize, the multiplier will be applied if the user
unmaximizes the window later.

For example, `--window-scale=0.5` would show the window at half the
video size.

`--window-minimized=<yes|no>`

Whether the video window is minimized or not. Setting this will minimize,
