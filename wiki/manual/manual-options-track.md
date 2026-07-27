## Track Selection

`--alang=<languagecode[,languagecode,...]>`

Specify a prioritized list of audio languages to use, as IETF language tags.
Equivalent ISO 639-1 two-letter and ISO 639-2 three-letter codes are treated
the same. The first tag in the list that matches track's language in the file
will be used. A track that matches more subtags will be preferred over one
that matches fewer. See also `--aid`.

This is a string list option. See [List Options](manual-options-track.md) for details.

Examples

- `mpv dvd://1 --alang=hu,en` chooses the Hungarian language track
on a DVD and falls back on English if Hungarian is not available.

- `mpv --alang=jpn example.mkv` plays a Matroska file with Japanese
audio.

`--slang=<languagecode[,languagecode,...]>`

Analogous to `--alang`, for subtitle tracks.

This is a string list option. See [List Options](manual-options-track.md) for details.

Examples

- `mpv dvd://1 --slang=hu,en` chooses the Hungarian subtitle track on
a DVD and falls back on English if Hungarian is not available.

- `mpv --slang=jpn example.mkv` plays a Matroska file with Japanese
subtitles.

- `mpv --slang=pt-BR example.mkv` plays a Matroska file with Brazilian
Portuguese subtitles if available, and otherwise any Portuguese subtitles.

`--vlang=<...>`

Analogous to `--alang` and `--slang`, for video tracks.

This is a string list option. See [List Options](manual-options-track.md) for details.

`--aid=<ID|auto|no>`

Select audio track. `auto` selects the default, `no` disables audio.
See also `--alang`. mpv normally prints available audio tracks on the
terminal when starting playback of a file.

`--audio` is an alias for `--aid`.

`--aid=no` or `--audio=no` disables audio playback.

Note

The track selection options (`--aid` but also `--sid` and the
others) sometimes expose behavior that may appear strange. Also, the
behavior tends to change around with each mpv release.

The track selection properties will return the option value outside of
playback (as expected), but during playback, the affective track
selection is returned. For example, with `--aid=auto`, the `aid`
property will suddenly return `2` after playback initialization
(assuming the file has at least 2 audio tracks, and the second is the
default).

At mpv 0.32.0 (and some releases before), if you passed a track value
for which a corresponding track didn't exist (e.g. `--aid=2` and there
was only 1 audio track), the `aid` property returned `no`. However if
another audio track was added during playback, and you tried to set the
`aid` property to `2`, nothing happened, because the `aid` option
still had the value `2`, and writing the same value has no effect.

With mpv 0.33.0, the behavior was changed. Now track selection options
are reset to `auto` at playback initialization, if the option had
tries to select a track that does not exist. The same is done if the
track exists, but fails to initialize. The consequence is that unlike
before mpv 0.33.0, the user's track selection parameters are clobbered
in certain situations.

Also since mpv 0.33.0, trying to select a track by number will strictly
select this track. Before this change, trying to select a track which
did not exist would fall back to track default selection at playback
initialization. The new behavior is more consistent.

Setting a track selection property at runtime, and then playing a new
file might reset the track selection to defaults, if the fingerprint
of the track list of the new file is different.

Be aware of tricky combinations of all of all of the above: for example,
`mpv --aid=2 file_with_2_audio_tracks.mkv file_with_1_audio_track.mkv`
would first play the correct track, and the second file without audio.
If you then go back the first file, its first audio track will be played,
and the second file is played with audio. If you do the same thing again
but instead of using `--aid=2` you run `set aid 2` while the file is
playing, then changing to the second file will play its audio track.
This is because runtime selection enables the fingerprint heuristic.

Most likely this is not the end.

`--sid=<ID|auto|no>`

Display the subtitle stream specified by `<ID>`. `auto` selects
the default, `no` disables subtitles.

`--sub` is an alias for `--sid`.

`--sid=no` or `--sub=no` disables subtitle decoding.

`--vid=<ID|auto|no>`

Select video channel. `auto` selects the default, `no` disables video.

`--video` is an alias for `--vid`.

`--vid=no` or `--video=no` disables video playback.

If video is disabled, mpv will try to download the audio only if media is
streamed with youtube-dl, because it saves bandwidth. This is done by
setting the ytdl_format to "bestaudio/best" in the ytdl_hook.lua script.

`--edition=<ID|auto>`

(Matroska files only)
Specify the edition (set of chapters) to use, where 0 is the first. If set
to `auto` (the default), mpv will choose the first edition declared as a
default, or if there is no default, the first edition defined.

`--track-auto-selection=<yes|no>`

Enable the default track auto-selection (default: yes). Enabling this will
make the player select streams according to `--aid`, `--alang`, and
others. If it is disabled, no tracks are selected. In addition, the player
will not exit if no tracks are selected, and wait instead (this wait mode
is similar to pausing, but the pause option is not set).

This is useful with `--lavfi-complex`: you can start playback in this
mode, and then set select tracks at runtime by setting the filter graph.
Note that if `--lavfi-complex` is set before playback is started, the
referenced tracks are always selected.

`--subs-with-matching-audio=<yes|forced|no>`

When autoselecting a subtitle track, select it even if the selected audio
stream matches you preferred subtitle language (default: yes). If this
option is set to `no`, then no subtitle track that matches the audio
language will ever be autoselected by mpv regardless of `--slang` or
`subs-fallback`. If set to `forced`, then only forced subtitles
will be selected.

`--subs-match-os-language=<yes|no>`

When autoselecting a subtitle track, select the track that matches the language of your OS
if the audio stream is in a different language if suitable (default track or a forced track
under the right conditions). Note that if `--slang` is set, this will be completely ignored
(default: yes).

`--subs-fallback=<yes|default|no>`

When autoselecting a subtitle track, if no tracks match your preferred languages,
select a full track even if it doesn't match your preferred subtitle language (default: default).
Setting this to <cite>default</cite> means that only streams flagged as <cite>default</cite> will be selected.

`--subs-fallback-forced=<yes|no|always>`

When autoselecting a subtitle track, the default value of <cite>yes</cite> will prefer using a forced
subtitle track if the subtitle language matches the audio language and matches your list of
preferred languages. The special value <cite>always</cite> will only select forced subtitle tracks and
never fallback on a non-forced track. Conversely, <cite>no</cite> will never select a forced subtitle
track.
