# TAKING SCREENSHOTS

Screenshots of the currently played file can be taken using the 'screenshot'
input mode command, which is by default bound to the `s` key. Files named
`mpv-shotNNNN.jpg` will be saved in the working directory, using the first
available number - no files will be overwritten. In pseudo-GUI mode, the
screenshot will be saved somewhere else. See [PSEUDO GUI MODE](manual-pseudo-gui-mode.md).

A screenshot will usually contain the unscaled video contents at the end of the
video filter chain and subtitles. By default, `S` takes screenshots without
subtitles, while `s` includes subtitles.

Unlike with MPlayer, the `screenshot` video filter is not required. This
filter was never required in mpv, and has been removed.
