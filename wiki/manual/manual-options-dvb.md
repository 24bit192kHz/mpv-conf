## DVB

`--dvbin-prog=<string>`

This defines the program to tune to. Usually, you may specify this
by using a stream URI like `"dvb://ZDF HD"`, but you can tune to a
different channel by writing to this property at runtime.
Also see `dvbin-channel-switch-offset` for more useful channel
switching functionality.

`--dvbin-card=<0-15>`

Specifies using card number 0-15 (default: 0).

`--dvbin-file=<filename>`

Instructs mpv to read the channels list from `<filename>`. The default is
in the mpv configuration directory (usually `~/.config/mpv`) with the
filename `channels.conf.{sat,sat1,ter,ter1,cbl,atsc,isdbt}` (based on your
card type) or `channels.conf` as a last resort.
For cards supporting multiple delivery systems of the same kind, i.e.
DVB-T/T2 or DVB-S/S2, T2/S2 is assumed, unless the file extension
is `ter1` or `sat1`.
Please note that using specific file name with card type is recommended,
since the legacy channel format is not fully standardized
so autodetection of the delivery system may fail otherwise.
For DVB-S/2 cards, a VDR 1.7.x format channel list is recommended
as it allows tuning to DVB-S2 channels, enabling subtitles and
decoding the PMT (which largely improves the demuxing).
Classic mplayer format channel lists are still supported (without
these improvements), and for other card types, only limited VDR
format channel list support is implemented (patches welcome).
For channels with dynamic PID switching or incomplete
`channels.conf`, `--dvbin-full-transponder` or the magic PID
`8192` are recommended.

`--dvbin-timeout=<seconds>`

Maximum number of seconds to wait when trying to tune a frequency before
giving up (default: 30).

`--dvbin-full-transponder=<yes|no>`

Apply no filters on program PIDs, only tune to frequency and pass full
transponder to demuxer.
The player frontend selects the streams from the full TS in this case,
so the program which is shown initially may not match the chosen channel.
Switching between the programs is possible by cycling the `program`
property.
This is useful to record multiple programs on a single transponder,
or to work around issues in the `channels.conf`.
It is also recommended to use this for channels which switch PIDs
on-the-fly, e.g. for regional news.

Default: `no`

`--dvbin-channel-switch-offset=<integer>`

This value is not meant for setting via configuration, but used in channel
switching. An `input.conf` can `cycle` this value `up` and `down`
to perform channel switching. This number effectively gives the offset
to the initially tuned to channel in the channel list.

An example `input.conf` could contain:
`H cycle dvbin-channel-switch-offset up`, `K cycle dvbin-channel-switch-offset down`
