## List of Input Commands

Commands with parameters have the parameter name enclosed in `<` / `>`.
Don't add those to the actual command. Optional arguments are enclosed in
`[` / `]`. If you don't pass them, they will be set to a default value.

Remember to quote string arguments in input.conf (see [Flat command syntax](manual-input-commands-1.md)).

### Playback Control

`seek <target> [<flags>]`

Change the playback position. By default, seeks by a relative amount of
seconds.

The second argument consists of flags controlling the seek mode:

relative (default)

Seek relative to current position (a negative value seeks backwards).

absolute

Seek to a given time (a negative value starts from the end of the file).

absolute-percent

Seek to a given percent position.

relative-percent

Seek relative to current position in percent.

keyframes

Always restart playback at keyframe boundaries (fast).

exact

Always do exact/hr/precise seeks (slow).

Multiple flags can be combined, e.g.: `absolute+keyframes`.

By default, `keyframes` is used for `relative`, `relative-percent`,
and `absolute-percent` seeks, while `exact` is used for `absolute`
seeks.

Before mpv 0.9, the `keyframes` and `exact` flags had to be passed as
3rd parameter (essentially using a space instead of `+`). The 3rd
parameter is still parsed, but is considered deprecated.

This is a scalable command. See the documentation of `nonscalable` input
command prefix in [Input Command Prefixes](manual-input-commands-1.md) for details.

`revert-seek [<flags>]`

Undoes the `seek` command, and some other commands that seek (but not
necessarily all of them). Calling this command once will jump to the
playback position before the seek. Calling it a second time undoes the
`revert-seek` command itself. This only works within a single file.

The first argument is optional, and can change the behavior:

mark

Mark the current time position. The next normal `revert-seek` command
will seek back to this point, no matter how many seeks happened since
last time.

mark-permanent

If set, mark the current position, and do not change the mark position
before the next `revert-seek` command that has `mark` or
`mark-permanent` set (or playback of the current file ends). Until
this happens, `revert-seek` will always seek to the marked point. This
flag cannot be combined with `mark`.

Using it without any arguments gives you the default behavior.

`sub-seek <skip> [<flags>]`

Change video and audio position such that the subtitle event after
`<skip>` subtitle events is displayed. For example, `sub-seek 1` skips
to the next subtitle, `sub-seek -1` skips to the previous subtitles, and
`sub-seek 0` seeks to the beginning of the current subtitle.

This is similar to `sub-step`, except that it seeks video and audio
instead of adjusting the subtitle delay.

Secondary argument:

primary (default)

Seeks through the primary subtitles.

secondary

Seeks through the secondary subtitles.

For embedded subtitles (like with Matroska), this works only with subtitle
events that have already been displayed, or are within a short prefetch
range. See [Cache](manual-options-cache-1.md) for details on how to control the available prefetch range.

`frame-step [<frames>] [<flags>]`

Go forward or backwards by a given amount of frames. If `<frames>` is
omitted, the value is assumed to be `1`.

The second argument consists of flags controlling the frameskip mode:

play (default)

Play the video forward by the desired amount of frames and then pause.
This only works with a positive value (i.e. frame stepping forwards).

seek

Perform a very exact seek that attempts to seek by the desired amount
of frames. If `<frames>` is `-1`, this will go exactly to the
previous frame.

mute

The same as `play` but mutes the audio stream if there is any during
the duration of the frame step.

Note that the default frameskip mode, play, is more accurate but can be
slow depending on how many frames you are skipping (i.e. skipping forward
100 frames will play 100 frames of video before stopping). This mode only
works when going forwards. Frame stepping back always performs a seek.

When using seek mode, this can still be very slow (it tries to be precise,
not fast), and sometimes fails to behave as expected. How well this works
depends on whether precise seeking works correctly (e.g. see the
`--hr-seek-demuxer-offset` option). Video filters or other video
post-processing that modifies timing of frames (e.g. deinterlacing) should
usually work, but might make framestepping silently behave incorrectly in
corner cases. Using `--hr-seek-framedrop=no` should help, although it
might make precise seeking slower. Also if the video is VFR, framestepping
using seeks will probably not work correctly except for the `-1` case.

This does not work with audio-only playback.

`frame-back-step`

Calls `frame-step` with a value of `-1` and the `seek` flag.

This does not work with audio-only playback.

`stop [<flags>]`

Stop playback and clear playlist. With default settings, this is
essentially like `quit`. Useful for the client API: playback can be
stopped without terminating the player.

The first argument is optional, and supports the following flags:

keep-playlist

Do not clear the playlist.

