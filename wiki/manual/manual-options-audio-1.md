## Audio

`--audio-pitch-correction=<yes|no>`

If this is enabled (default), playing with a speed different from normal
automatically inserts the `scaletempo2` audio filter. You can insert
filters besides `scaletempo2` and modify their params using
[Conditional auto profiles](manual-configuration-files-1.md):

```
[af_insert]
profile-cond=speed ~= 1
profile-restore=copy
af-add=scaletempo2=search-interval=50 # Insert filter and params here.
```

Filters set this way replace the `scaletempo2` default, instead of
overlapping with it. If there are multiple audio filters inserted that can do
pitch correction, then only the last one in the filter chain is used.
For details on the specifics of each available filter, see the audio filter
section.

`--audio-device=<name>`

Use the given audio device. This consists of the audio output name, e.g.
`alsa`, followed by `/`, followed by the audio output specific device
name. The default value for this option is `auto`, which tries every audio
output in preference order with the default device.

You can list audio devices with `--audio-device=help`. This outputs the
device name in quotes, followed by a description. The device name is what
you have to pass to the `--audio-device` option. The list of audio devices
can be retrieved by API by using the `audio-device-list` property.

While the option normally takes one of the strings as indicated by the
methods above, you can also force the device for most AOs by building it
manually. For example `name/foobar` forces the AO `name` to use the
device `foobar`. However, the `--ao` option will strictly force a
specific AO. To avoid confusion, don't use `--ao` and `--audio-device`
together.

Example for ALSA

MPlayer and mplayer2 required you to replace any ',' with '.' and
any ':' with '=' in the ALSA device name. For example, to use the
device named `dmix:default`, you had to do:

> `-ao alsa:device=dmix=default`

In mpv you could instead use:

> `--audio-device=alsa/dmix:default`

`--audio-exclusive=<yes|no>`

Enable exclusive output mode. In this mode, the system is usually locked
out, and only mpv will be able to output audio.

This only works for some audio outputs, such as `wasapi`, `coreaudio`,
`pipewire` and `audiounit`. Other audio outputs silently ignore this option.
They either have no concept of exclusive mode, or the mpv side of the
implementation is missing.

`--audio-fallback-to-null=<yes|no>`

If no audio device can be opened, behave as if `--ao=null` was given. This
is useful in combination with `--audio-device`: instead of causing an
error if the selected device does not exist, the client API user (or a
Lua script) could let playback continue normally, and check the
`current-ao` and `audio-device-list` properties to make high-level
decisions about how to continue.

`--ao=<driver>`

Specify the audio output drivers to be used. See [AUDIO OUTPUT DRIVERS](manual-audio-output-drivers-1.md) for
details and descriptions of available drivers.

`--af=<filter1[=parameter1:parameter2:...],filter2,...>`

Specify a list of audio filters to apply to the audio stream. See
[AUDIO FILTERS](manual-audio-filters-1.md) for details and descriptions of the available filters.
The option variants `--af-add`, `--af-pre`, and `--af-clr` exist
to modify a previously specified list, but you should not need these for
typical use.

`--audio-spdif=<codecs>`

List of codecs for which compressed audio passthrough should be used. This
works for both classic S/PDIF and HDMI.

Possible codecs are `ac3`, `dts`, `dts-hd`, `eac3`, `truehd`.
Multiple codecs can be specified by separating them with `,`. `dts`
refers to low bitrate DTS core, while `dts-hd` refers to DTS MA (receiver
and OS support varies). If both `dts` and `dts-hd` are specified, it
behaves equivalent to specifying `dts-hd` only.

In earlier mpv versions you could use `--ad` to force the spdif wrapper.
This does not work anymore.

Warning

There is not much reason to use this. HDMI supports uncompressed
multichannel PCM, and mpv supports lossless DTS-HD decoding via
FFmpeg's new DCA decoder (based on libdcadec).

`--ad=<decoder1,decoder2,...[-]>`

Specify a priority list of audio decoders to be used, according to their
decoder name. When determining which decoder to use, the first decoder that
matches the audio format is selected. If that is unavailable, the next
decoder is used. Finally, it tries all other decoders that are not
explicitly selected or rejected by the option.

`-` at the end of the list suppresses fallback on other available
decoders not on the `--ad` list. This should not normally be used,
because they break normal decoder auto-selection! The `-` mode is
deprecated.

Examples

`--ad=mp3float`

Prefer the FFmpeg `mp3float` decoder over all other MP3
decoders.

`--ad=help`

List all available decoders.

Warning

Enabling compressed audio passthrough (AC3 and DTS via SPDIF/HDMI) with
this option is not possible. Use `--audio-spdif` instead.

`--volume=<value>`

Set the startup volume. 0 means silence, 100 means no volume reduction or
amplification. Negative values can be passed for compatibility, but are
treated as 0.

Since mpv 0.18.1, this always controls the internal mixer (aka software
volume).

`--volume-max=<100.0-1000.0>`

Set the maximum amplification level in percent (default: 130). A value of
130 will allow you to adjust the volume up to about double the normal level.

`--volume-gain=<db>`

Set the volume gain in dB. This is applied on top of other volume and gain
settings.

`--volume-gain-max=<0.0-150.0>`, `--volume-gain-min=<-150.0-0.0>`

Set the volume gain range in dB (default: -96 dB min, 12 dB max).

`--replaygain=<no|track|album>`

Adjust volume gain according to replaygain values stored in the file
metadata. With `--replaygain=no` (the default), perform no adjustment.
With `--replaygain=track`, apply track gain. With `--replaygain=album`,
apply album gain if present and fall back to track gain otherwise.

`--replaygain-preamp=<db>`

Pre-amplification gain in dB to apply to the selected replaygain gain
(default: 0).

`--replaygain-clip=<yes|no>`

Allow the volume gain to clip (default: no). If this option is not
enabled, mpv automatically will prevent clipping by lowering the gain.

`--replaygain-fallback=<db>`

Gain in dB to apply if the file has no replay gain tags. This option
is always applied if the replaygain logic is somehow inactive. If this
is applied, no other replaygain options are applied.

`--audio-delay=<sec>`

Audio delay in seconds (positive or negative float value). Positive values
delay the audio, and negative values delay the video.

`--mute=<yes|no>`

Set startup audio mute status (default: no).

See also: `--volume`.

`--audio-demuxer=<[+]name>`

Use this audio demuxer type when using `--audio-file`. Use a '+' before
the name to force it; this will skip some checks. Give the demuxer name as
