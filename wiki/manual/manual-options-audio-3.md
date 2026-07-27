
When starting a video file or after events such as seeking, mpv will by
default modify the audio stream to make it start from the same timestamp
as video, by either inserting silence at the start or cutting away the
first samples. Disabling this option makes the player behave like older
mpv versions did: video and audio are both started immediately even if
their start timestamps differ, and then video timing is gradually adjusted
if necessary to reach correct synchronization later.

`--audio-file-auto=<no|exact|fuzzy|all>`

Load additional audio files matching the video filename. The parameter
specifies how external audio files are matched.
| no: | Don't automatically load external audio files (default). |
| --- | --- |
| exact: | Load the media filename with audio file extension. |
| fuzzy: | Load all audio files containing the media filename. |
| all: | Load all audio files in the current and `--audio-file-paths`
directories. |

`--audio-exts=ext1,ext2,...`

Audio file extensions to try to match when using `--audio-file-auto`,
`--autocreate-playlist` or `--directory-filter-types`.

This is a string list option. See [List Options](manual-options-track.md) for details.
Use `--help=audio-exts` to see default extensions.

`--audio-file-paths=

`

Analogous to `--sub-file-paths` option, but for auto-loaded audio files.

This is a path list option. See [List Options](manual-options-track.md) for details.

`--audio-client-name=<name>`

The application name the player reports to the audio API. Can be useful
if you want to force a different audio profile (e.g. with PulseAudio),
or to set your own application name when using libmpv.

`--audio-set-media-role=<yes|no>`

If enabled, mpv will set the appropriate media role on supported audio
servers to indicate whether mpv is playing a video or an audio-only file.
This is disabled by default since per media role volumes have often caused
unexpected and confusing behavior.

Default: no.

`--audio-buffer=<seconds>`

Set the audio output minimum buffer. The audio device might actually create
a larger buffer if it pleases. If the device creates a smaller buffer,
additional audio is buffered in an additional software buffer.

Making this larger may make soft-volume and other filters react slower,
introduce additional issues on playback speed change, and block the
player on audio format changes. A smaller buffer might lead to audio
dropouts.

This option should be used for testing only. If a non-default value helps
significantly, the mpv developers should be contacted.

Default: 0.2 (200 ms).

`--audio-stream-silence=<yes|no>`

Cash-grab consumer audio hardware (such as A/V receivers) often ignore
initial audio sent over HDMI. This can happen every time audio over HDMI
is stopped and resumed. In order to compensate for this, you can enable
this option to not to stop and restart audio on seeks, and fill the gaps
with silence. Likewise, when pausing playback, audio is not stopped, and
silence is played while paused. Note that if no audio track is selected,
the audio device will still be closed immediately.

Not all AOs support this.

Warning

This modifies certain subtle player behavior, like A/V-sync and underrun
handling. Enabling this option is strongly discouraged.

`--audio-wait-open=<secs>`

This makes sense for use with `--audio-stream-silence=yes`. If this option
is given, the player will wait for the given amount of seconds after opening
the audio device before sending actual audio data to it. Useful if your
expensive hardware discards the first 1 or 2 seconds of audio data sent to
it. If `--audio-stream-silence=yes` is not set, this option will likely
just waste time.
