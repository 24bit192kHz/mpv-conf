## Raw and Formatted Properties

Normally, properties are formatted as human-readable text, meant to be
displayed on OSD or on the terminal. It is possible to retrieve an unformatted
(raw) value from a property by prefixing its name with `=`. These raw values
can be parsed by other programs and follow the same conventions as the options
associated with the properties. Additionally, there is a `>` prefix to format
human-readable text, with fixed precision for floating-point values. This is
useful for printing values where a constant width is important.

Examples

- `${time-pos}` expands to `00:14:23` (if playback position is at 14
minutes 23 seconds)

- `${=time-pos}` expands to `863.4` (same time, plus 400 milliseconds -
milliseconds are normally not shown in the formatted case)

- `${avsync}` expands to `+0.003`

- `${>avsync}` expands to `+0.0030`

- `${=avsync}` expands to `0.003028`

Sometimes, the difference in amount of information carried by raw and formatted
property values can be rather big. In some cases, raw values have more
information, like higher precision than seconds with `time-pos`. Sometimes
it is the other way around, e.g. `aid` shows track title and language in the
formatted case, but only the track number if it is raw.
