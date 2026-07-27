# EXIT CODES

Normally **mpv** returns 0 as exit code after finishing playback successfully.
If errors happen, the following exit codes can be returned:

> | 1: | Error initializing mpv. This is also returned if unknown options are
> passed to mpv. |
| --- | --- |
| 2: | The file passed to mpv couldn't be played. This is somewhat fuzzy:
> currently, playback of a file is considered to be successful if
> initialization was mostly successful, even if playback fails
> immediately after initialization. |
| 3: | There were some files that could be played, and some files which
> couldn't (using the definition of success from above). |
| 4: | Quit due to a signal, Ctrl+c in a VO window (by default), or from the
> default quit key bindings in encoding mode. |

Note that quitting the player manually will always lead to exit code 0,
overriding the exit code that would be returned normally. Also, the `quit`
input command can take an exit code: in this case, that exit code is returned.
