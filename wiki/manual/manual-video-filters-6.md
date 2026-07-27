
`w=

`, `h=

`

Size of the output in pixels (default: 0). If not positive, this will
use the size of the first filtered input frame.

Warning

This is highly experimental. Performance is bad, and it will not work
everywhere in the first place. Some features are not supported.

Warning

This does not do OSD rendering. If you see OSD, then it has been
rendered by the VO backend. (Subtitles are rendered by the `gpu`
filter, if possible.)

Warning

If you use this with encoding mode, keep in mind that encoding mode will
convert the RGB filter's output back to yuv420p in software, using the
configured software scaler. Using `zimg` might improve this, but in
any case it might go against your goals when using this filter.

Warning

Do not use this with `--vo=gpu`. It will apply filtering twice, since
most `--vo=gpu` options are unconditionally applied to the `gpu`
filter. There is no mechanism in mpv to prevent this.
