# TERMINAL STATUS LINE

During playback, mpv shows the playback status on the terminal. It looks like
something like this:

> `AV: 00:03:12 / 00:24:25 (13%) A-V: -0.000`

The status line can be overridden with the `--term-status-msg` option.

The following is a list of things that can show up in the status line. Input
properties, that can be used to get the same information manually, are also
listed.

- `AV:` or `V:` (video only) or `A:` (audio only)

- The current time position in `HH:MM:SS` format (`playback-time` property)

- The total file duration (absent if unknown) (`duration` property)

- Playback speed, e.g. `x2.0`. Only visible if the speed is not normal. This
is the user-requested speed, and not the actual speed  (usually they should
be the same, unless playback is too slow). (`speed` property.)

- Playback percentage, e.g. `(13%)`. How much of the file has been played.
Normally calculated out of playback position and duration, but can fallback
to other methods (like byte position) if these are not available.
(`percent-pos` property.)

- The audio/video sync as `A-V:  0.000`. This is the difference between
audio and video time. Normally it should be 0 or close to 0. If it's growing,
it might indicate a playback problem. (`avsync` property.)

- Total A/V sync change, e.g. `ct: -0.417`. Normally invisible. Can show up
if there is audio "missing", or not enough frames can be dropped. Usually
this will indicate a problem. (`total-avsync-change` property.)

- Encoding state in `{...}`, only shown in encoding mode.

- Display sync state. If display sync is active (`display-sync-active`
property), this shows `DS: 2.500/13`, where the first number is average
number of vsyncs per video frame (e.g. 2.5 when playing 24Hz videos on 60Hz
screens), which might jitter if the ratio doesn't round off, or there are
mistimed frames (`vsync-ratio`), and the second number of estimated number
of vsyncs which took too long (`vo-delayed-frame-count` property). The
latter is a heuristic, as it's generally not possible to determine this with
certainty.

- Dropped frames, e.g. `Dropped: 4`. Shows up only if the count is not 0. Can
grow if the video framerate is higher than that of the display, or if video
rendering is too slow. May also be incremented on "hiccups" and when the video
frame couldn't be displayed on time. (`frame-drop-count` property.)
If the decoder drops frames, the number of decoder-dropped frames is appended
to the display as well, e.g.: `Dropped: 4/34`. This happens only if
decoder frame dropping is enabled with the `--framedrop` options.
(`decoder-frame-drop-count` property.)

- Cache state, e.g. `Cache:  2s/134KB`. Visible if the stream cache is enabled.
The first value shows the amount of video buffered in the demuxer in seconds,
the second value shows the estimated size of the buffered amount in kilobytes.
(`demuxer-cache-duration` and `demuxer-cache-state` properties.)
