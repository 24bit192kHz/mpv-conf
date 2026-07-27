# Surround Sound with ALSA

mpv defaults to `auto` for `--audio-channels`, and for the majority of files it will not output a raw multichannel PCM stream to an external multi-channel receiver (AVR). As a workaround, you can use:

```
--audio-channels=2.0
--audio-channels=5.1
--audio-channels=7.1
```

or whatever you need. If you output compressed audio (AC3, DTS) pass-through with `--audio-spdif=ac3,dts,hdaudio-mpeg` and correct ALSA configuration (or just use `--ao=wasapi` on Windows).

## Other Options

If you pass raw PCM to your receiver, you can keep mpv's mixer out of the chain with either:

- Setting `volume-max=100` in mpv.conf, which disables the softvol filter.
- Or use `--audio-exclusive` on platforms that support it (Windows only currently).

Alternatively, for a digital live bin with pulseaudio or ALSA, you can use `--audio-channels=auto` and then let your software mixer (pulseaudio) downmix the audio to stereo with a downmix matrix filter as needed.

## Relevant

https://github.com/mpv-player/mpv/issues/7510
