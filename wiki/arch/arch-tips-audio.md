### Audio

#### Volume is too low

Set `volume-max=value` in your configuration file to a reasonable amount, such as `volume-max=150`, which then allows you to increase your volume up to 150%, which is more than twice as loud. Increasing your volume too high will result in clipping artefacts. Additionally (or alternatively), you can utilize [dynamic range compression](https://en.wikipedia.org/wiki/Dynamic_range_compression) with `af=acompressor`.

#### Specify an audio output

Run the following command to get a list of available audio output devices:

```
$ mpv --audio-device=help
```

Then add one to `~/.config/mpv/mpv.conf`. For example:

```
audio-device=alsa/hdmi:CARD=NVidia,DEV=1
```

#### HD Audio passthrough

To enable HD audio codecs like TrueHD and DTS-MA to passthrough to an AV receiver, add the following to `~/.config/mpv/mpv.conf`:

```
audio-spdif=ac3,eac3,dts-hd,truehd
```

#### Volume normalization

**Expansion needed:** Add a little more details about the available filters, see [this comparison](https://superuser.com/a/323127) of `loudnorm` and `dynaudnorm`.

Different sources may have different or inconsistent loudness, so _mpv_ users may need to configure automatic volume normalization. For example:

```
n cycle_values af loudnorm=I=-30 loudnorm=I=-15 anull
```

This binds the key `n` to cycle the audio filter settings (`af`) through the specified values:

- `loudnorm=I=-30`: loudnorm setting with `I=-30`, soft volume, might be suitable for background music
- `loudnorm=I=-15`: louder volume, might be good for the video currently in view
- `anull`: reset audio filter to null, i.e., disable the audio filter

**Note:** Binding a key does not change the default audio filter. To change the default, add e.g. `af=loudnorm=I=-30` to the main configuration file.

Audio filtering in _mpv_ is provided by the [FFmpeg](https://wiki.archlinux.org/title/FFmpeg) backend. See [Wikipedia:EBU R 128](https://en.wikipedia.org/wiki/EBU_R_128) and [ffmpeg loudnorm filter](https://ffmpeg.org/ffmpeg-filters.html#loudnorm) for details.

See also upstream issues [#3979](https://github.com/mpv-player/mpv/issues/3979) and [#2883](https://github.com/mpv-player/mpv/issues/2883) which mention different options.

#### Improving mpv as a music player with Lua scripts

[This blog post](https://web.archive.org/web/20160320001546/http://bamos.github.io/2014/07/05/mpv-lua-scripting/) introduces the [music.lua](https://github.com/bamos/dotfiles/blob/master/.mpv/scripts.old/music.lua) script, which shows how Lua scripts can be used to improve _mpv_ as a music player.
