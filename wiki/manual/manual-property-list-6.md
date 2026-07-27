Estimated timecode based on the current playback position and frame count.

`container-fps`

Container FPS. This can easily contain bogus values. For videos that use
modern container formats or video codecs, this will often be incorrect.

(Renamed from `fps`.)

`estimated-vf-fps`

Estimated/measured FPS of the video filter chain output. (If no filters
are used, this corresponds to decoder output.) This uses the average of
the 10 past frame durations to calculate the FPS. It will be inaccurate
if frame-dropping is involved (such as when framedrop is explicitly
enabled, or after precise seeking). Files with imprecise timestamps (such
as Matroska) might lead to unstable results.

`current-window-scale` (RW)

The `window-scale` value calculated from the current window size. This
has the same value as `window-scale` if the window size was not changed
since setting the option, and the window size was not restricted in other
ways. If the window is fullscreened, this will return the scale value
calculated from the last non-fullscreen size of the window. The property
is unavailable if no video is active.

It is also possible to write to this property. This has the same behavior as
writing `window-scale`. Note that writing to `current-window-scale` will
not affect the value of `window-scale`.

`focused`

Whether the window has focus. Might not be supported by all VOs.

`ambient-light`

Ambient lighting condition in lux. Only observable on macOS (macOS and Linux only)

`display-names`

Names of the displays that the mpv window covers. On X11, these
are the xrandr names (LVDS1, HDMI1, DP1, VGA1, etc.). On Windows, these
are the GDI names (\.DISPLAY1, \.DISPLAY2, etc.) and the first display
in the list will be the one that Windows considers associated with the
window (as determined by the MonitorFromWindow API.) On macOS these are the
Display Product Names as used in the System Information with a serial number
in parentheses and only one display name is returned since a window can only be
on one screen. On Wayland, these are the wl_output names if protocol
version >= 4 is used (LVDS-1, HDMI-A-1, X11-1, etc.), or the wl_output model
reported by the geometry event if protocol version < 4 is used.

`display-fps`

The refresh rate of the current display. Currently, this is the lowest FPS
of any display covered by the video, as retrieved by the underlying system
APIs (e.g. xrandr on X11). It is not the measured FPS. It's not necessarily
available on all platforms. Note that any of the listed facts may change
any time without a warning.

`estimated-display-fps`

The actual rate at which display refreshes seem to occur, measured by
system time. Only available if display-sync mode (as selected by
`--video-sync`) is active.

`vsync-jitter`

Estimated deviation factor of the vsync duration.

`display-width`, `display-height`

The current display's horizontal and vertical resolution in pixels. Whether
or not these values update as the mpv window changes displays depends on
the windowing backend. It may not be available on all platforms.

`display-hidpi-scale`

The HiDPI scale factor as reported by the windowing backend. If no VO is
active, or if the VO does not report a value, this property is unavailable.
It may be saner to report an absolute DPI, however, this is the way HiDPI
support is implemented on most OS APIs. See also `--hidpi-window-scale`.

`osd-width`, `osd-height`

Last known OSD width (can be 0). This is needed if you want to use the
`overlay-add` command. It gives you the actual OSD/window size (not
including decorations drawn by the OS window manager).

Alias to `osd-dimensions/w` and `osd-dimensions/h`.

`osd-par`

Last known OSD display pixel aspect (can be 0).

Alias to `osd-dimensions/osd-par`.

`osd-dimensions`

Last known OSD dimensions.

Has the following sub-properties (which can be read as `MPV_FORMAT_NODE`
or Lua table with `mp.get_property_native`):

`osd-dimensions/w`

Size of the VO window in OSD render units (usually pixels, but may be
scaled pixels with VOs like `xv`).

`osd-dimensions/h`

Size of the VO window in OSD render units,

`osd-dimensions/par`

Pixel aspect ratio of the OSD (usually 1).

`osd-dimensions/aspect`

Display aspect ratio of the VO window. (Computing from the properties
above.)

`osd-dimensions/mt`, `osd-dimensions/mb`, `osd-dimensions/ml`, `osd-dimensions/mr`

OSD to video margins (top, bottom, left, right). This describes the
area into which the video is rendered.

Any of these properties may be unavailable or set to dummy values if the
VO window is not created or visible.

`term-size`

The current terminal size.

This has two sub-properties.

`term-size/w`

width of the terminal in cells

`term-size/h`

height of the terminal in cells

This property is not observable. Reacting to size changes requires
polling.

`window-id`

Read-only - mpv's window id. May not always be available, i.e due to window
not being opened yet or not being supported by the VO.

`display-swapchain`

Read-only - Direct3D 11 swapchain address. Returns an int64 type value
representing the memory address of the D3D11 swapchain. May not always be
available, i.e d3d11-output-mode is not set to `composition` or the VO
does not support it.

`mouse-pos`

Read-only - last known mouse position, normalized to OSD dimensions.

Has the following sub-properties (which can be read as `MPV_FORMAT_NODE`
or Lua table with `mp.get_property_native`):

`mouse-pos/x`, `mouse-pos/y`

Last known coordinates of the mouse pointer.

`mouse-pos/hover`

Boolean - whether the mouse pointer hovers the video window. The
coordinates should be ignored when this value is false, because the
video backends update them only when the pointer hovers the window.

`touch-pos`

Read-only - last known touch point positions, normalized to OSD dimensions.

This has a number of sub-properties. Replace `N` with the 0-based touch
point index. Whenever a new finger touches the screen, a new touch point is
added to the list of touch points with the smallest unused `N` available.

`touch-pos/count`

Number of active touch points.

`touch-pos/N/x`, `touch-pos/N/y`

Position of the Nth touch point.

`touch-pos/N/id`

Unique identifier of the touch point. This can be used to identify
