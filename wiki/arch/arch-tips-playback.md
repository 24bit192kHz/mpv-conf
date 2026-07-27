### Save position on quit

By default, you can save the position and quit by pressing `Shift+q`. The shortcut can be changed by setting `quit_watch_later` in the key bindings configuration file.

To automatically save the current playback position on quit, start _mpv_ with `--save-position-on-quit`, or add `save-position-on-quit` to the configuration file.

#### Save position of a playlist and pause on next file

A playlist could simply be a list of files, see `man mpv` (playlist section). To play a playlist and remember its position:

```
$ mpv --save-position-on-quit --pause --reset-on-next-file=pause --playlist=/path/to/playlist
```

With the option `--pause` _mpv_ will start in paused state and `--reset-on-next-file=pause` will reset the pause mode when switching to the next file.

### Play a DVD

mpv does not support DVD menus. To start the main stream with the longest title of a video DVD, use the command:

```
$ mpv dvd://
```

An optional title specifier is a number (starting at 0) which selects between separate video streams on the DVD:

```
$ mpv dvd://[title]
```

DVDs which have been copied on to a local file system (by e.g. the [dvdbackup](https://wiki.archlinux.org/title/Dvdbackup) tool) are accommodated by specifying the path to the local copy: `--dvd-device=PATH`.

See the following [desktop file](https://wiki.archlinux.org/title/Desktop_file) example for playing DVDs from a local file system:

```
[Desktop Entry]
Type=Application
Name=mpv Media Player DVD
GenericName=Multimedia player
Comment=Play movies and songs
Icon=mpv
Exec=mpv dvd:// --player-operation-mode=pseudo-gui --force-window --idle --dvd-device=%f
Terminal=false
Categories=AudioVideo;Audio;Video;Player;TV;
```

By replacing the Exec line with:

```
Exec=mpv dvd://0 dvd://1 dvd://2 dvd://3 dvd://4 dvd://5 dvd://6 dvd://7 dvd://8 dvd://9 --player-operation-mode=pseudo-gui --force-window --idle --dvd-device=%f
```

the mpv player will queue DVD title 0 to 9 in the playlist, which allows the user to play the titles consecutively or jump forward and backward in the DVD titles with the mpv GUI.

Install `libdvdcss`, to fix the error:

```
[dvdnav] Error getting next block from DVD 1 (Error reading from DVD.)
```

### Restoring old OSC

Since version 0.21.0, _mpv_ has replaced the on-screen controls by a bottombar. In case you want on-screen controls back, you can edit the _mpv_ configuration [as described here](https://github.com/mpv-player/mpv/wiki/FAQ#i-want-the-old-osc-back).

### Reproducible screenshots

The screenshot template option can include the precise timecode (HH:MM:SS.mmm) of the screenshoted frame. The meaningful filename makes it easy to know the origin of the screenshot. It can be set like this:

```
screenshot-template="%F - [%P] (%#01n)"
```

This expands to `filename - [HH:MM:SS.mmm] (number).jpg`. Example result:

```
Gunsmith Cats/
├── Gunsmith Cats Ep. 01 - [00:00:50.217] (1).jpg
├── Gunsmith Cats Ep. 01 - [00:22:55.874] (1).jpg
├── Gunsmith Cats Ep. 01 - [00:22:55.874] (2).jpg
└── Gunsmith Cats Ep. 02 - [00:15:05.778] (1).jpg
```

A bonus is it sorts nicely because alphabetically, the timecode is sorted within the episode number.

See `man mpv` (screenshot-template section) for more information.

### Creating a single screenshot

An example of creating a single screenshot, by using a start time (HH:MM:SS):

```
$ mpv --no-audio --start=00:01:30 --frames=1 /path/to/video/file --o=/path/to/screenshot.png
```

Screenshots will be saved in /path/to/screenshot.png.
