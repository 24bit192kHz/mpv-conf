# RESUMING PLAYBACK

mpv is capable of storing the playback position of the currently playing file
and resume from there the next time that file is played. This is done with the
commands `quit-watch-later` (bound to Shift+Q by default) and
`write-watch-later-config`, and with the `--save-position-on-quit` option.

The difference between always quitting with a key bound to `quit-watch-later`
and using `--save-position-on-quit` is that the latter will save the playback
position even when mpv is closed with a method other than a keybinding, such as
clicking the close button in the window title bar. However if mpv is terminated
abruptly and doesn't have the time to save, then the position will not be saved.
For example, if you shutdown your system without closing mpv beforehand.

mpv also stores options other than the playback position when they have been
modified after playback began, for example the volume and selected audio/subtitles,
and restores their values the next time the file is played. Which options are
saved can be configured with the `--watch-later-options` option.

When playing multiple playlist entries, mpv checks if one them has a resume
config file associated, and if it finds one it restarts playback from it. For
example, if you use `quit-watch-later` on the 5th episode of a show, and
later play all the episodes, mpv will automatically resume playback from
episode 5.

More options to configure this functionality are listed in [Watch Later](manual-options-watch-later.md).
