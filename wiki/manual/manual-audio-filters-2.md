Changing playback speed would change pitch, leaving audio tempo at
1.2x.

`scaletempo2[=option1:option2:...]`

Scales audio tempo without altering pitch.
The algorithm is ported from chromium and uses the
Waveform Similarity Overlap-and-add (WSOLA) method.
It seems to achieves higher audio quality than scaletempo, and rubberband R2
engine, or `engine=faster`. This filter is inserted automatically if
`audio-pitch-correction` option is used (on by default) when the playback
speed is changed.

By default, the `search-interval` and `window-size` parameters
have the same values as in chromium.

`min-speed=<speed>`

Mute audio if the playback speed is below `<speed>`. (default: 0.25)

`max-speed=<speed>`

Mute audio if the playback speed is above `<speed>`
and `<speed> != 0`. (default: 8.0)

`search-interval=<amount>`

Length in milliseconds to search for best overlap position. (default: 40)

`window-size=<amount>`

Length in milliseconds of the overlap-and-add window. (default: 12)

`rubberband`

High quality pitch correction with librubberband. This can be used in place
of `scaletempo` and `scaletempo2`, and will be used to adjust audio pitch
when playing at speed different from normal. It can also be used to adjust
audio pitch without changing playback speed.

`pitch-scale=<amount>`

Sets the pitch scaling factor. Frequencies are multiplied by this value.
(default: 1.0)

`engine=<faster|finer>`

Select the core Rubberband engine to be used. There are two available:
| Faster: | This is the Rubberband R2 engine. It uses significantly less
CPU than the Finer (R3) engine. |
| --- | --- |
| Finer: | This is the Rubberband R3 engine. This engine is only available
with librubberband version 3 or newer. This produces significantly
higher quality output, at the cost of higher CPU usage. (Default
if available) |

This filter has a number of additional sub-options. You can list them with
`mpv --af=rubberband=help`. This will also show the default values
for each option. The options are not documented here, because they are
merely passed to librubberband. Look at the librubberband documentation
to learn what each option does:
[https://breakfastquay.com/rubberband/code-doc/classRubberBand_1_1RubberBandStretcher.html](https://breakfastquay.com/rubberband/code-doc/classRubberBand_1_1RubberBandStretcher.html)
Do note that certain options are only applicable to one of R2 (faster) and
R3 (finer) engines.
(The mapping of the mpv rubberband filter sub-option names and values to
those of librubberband follows a simple pattern: `"Option" + Name + Value`.)

This filter supports the following `af-command` commands:

`set-pitch`

Set the `

` argument dynamically. This can be used to
change the playback pitch at runtime. Note that speed is controlled
using the standard `speed` property, not `af-command`.

`multiply-pitch <factor>`

Multiply the current value of `

` dynamically.

`lavfi=graph`

Filter audio using FFmpeg's libavfilter.

`<graph>`

Libavfilter graph. See `lavfi` video filter for details - the graph
syntax is the same.

Warning

Don't forget to quote libavfilter graphs as described in the lavfi
video filter section.

`o=<string>`

AVOptions.

`fix-pts=<yes|no>`

Determine PTS based on sample count (default: no). If this is enabled,
the player won't rely on libavfilter passing through PTS accurately.
Instead, it pass a sample count as PTS to libavfilter, and compute the
PTS used by mpv based on that and the input PTS. This helps with filters
which output a recomputed PTS instead of the original PTS (including
filters which require the PTS to start at 0). mpv normally expects
filters to not touch the PTS (or only to the extent of changing frame
boundaries), so this is not the default, but it will be needed to use
broken filters. In practice, these broken filters will either cause slow
A/V desync over time (with some files), or break playback completely if
you seek or start playback from the middle of a file.

`drop`

This filter drops or repeats audio frames to adapt to playback speed. It
always operates on full audio frames, because it was made to handle SPDIF
(compressed audio passthrough). This is used automatically if the
`--video-sync=display-adrop` option is used. Do not use this filter (or
the given option); they are extremely low quality.
