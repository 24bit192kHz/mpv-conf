printed by `--audio-demuxer=help`.

`--ad-lavc-ac3drc=<level>`

Select the Dynamic Range Compression level for AC-3 audio streams.
`<level>` is a float value ranging from 0 to 1, where 0 means no
compression (which is the default) and 1 means full compression (make loud
passages more silent and vice versa). Values up to 6 are also accepted, but
are purely experimental. This option only shows an effect if the AC-3 stream
contains the required range compression information.

The standard mandates that DRC is enabled by default, but mpv (and some
other players) ignore this for the sake of better audio quality.

`--ad-lavc-downmix=<yes|no>`

Whether to request audio channel downmixing from the decoder (default: no).
Some decoders, like AC-3, AAC and DTS, can remix audio on decoding. The
requested number of output channels is set with the `--audio-channels` option.
Useful for playing surround audio on a stereo system.

`--ad-lavc-threads=<0-16>`

Number of threads to use for decoding. Whether threading is actually
supported depends on codec. As of this writing, it's supported for some
lossless codecs only. 0 means autodetect number of cores on the
machine and use that, up to the maximum of 16 (default: 1).

`--ad-lavc-o=<key>=<value>[,<key>=<value>[,...]]`

Pass AVOptions to libavcodec decoder. Note, a patch to make the o=
unneeded and pass all unknown options through the AVOption system is
welcome. A full list of AVOptions can be found in the FFmpeg manual.

This is a key/value list option. See [List Options](manual-options-track.md) for details.

`--ad-spdif-dtshd=<yes|no>`, `--dtshd=<yes|no>`

If DTS is passed through, use DTS-HD.

Warning

This and enabling passthrough via `--ad` are deprecated in favor of
using `--audio-spdif=dts-hd`.

`--audio-channels=<auto-safe|auto|layouts>`

Control which audio channels are output (e.g. surround vs. stereo). There
are the following possibilities:

- `--audio-channels=auto-safe`

Use the system's preferred channel layout. If there is none (such
as when accessing a hardware device instead of the system mixer),
force stereo. Some audio outputs might simply accept any layout and
do downmixing on their own.

This is the default.

- `--audio-channels=auto`

Send the audio device whatever it accepts, preferring the audio's
original channel layout. Can cause issues with HDMI (see the warning
below).

- `--audio-channels=layout1,layout2,...`

List of `,`-separated channel layouts which should be allowed.
Technically, this only adjusts the filter chain output to the best
matching layout in the list, and passes the result to the audio API.
It's possible that the audio API will select a different channel
layout.

Using this mode is recommended for direct hardware output, especially
over HDMI (see HDMI warning below).

- `--audio-channels=<stereo|mono>`

Force a downmix to stereo or mono. These are special-cases of the
previous item. (See paragraphs below for implications.)

If a list of layouts is given, each item can be either an explicit channel
layout name (like `5.1`), or a channel number. Channel numbers refer to
default layouts, e.g. 2 channels refer to stereo, 6 refers to 5.1.

See `--audio-channels=help` output for defined default layouts. This also
lists speaker names, which can be used to express arbitrary channel
layouts (e.g. `fl-fr-lfe` is 2.1).

If the list of channel layouts has only 1 item, the decoder is asked to
produce according output. This sometimes triggers decoder-downmix, which
might be different from the normal mpv downmix. (Only some decoders support
remixing audio, like AC-3, AAC or DTS. You can use `--ad-lavc-downmix=no`
to make the decoder always output its native layout.) One consequence is
that `--audio-channels=stereo` triggers decoder downmix, while `auto`
or `auto-safe` never will, even if they end up selecting stereo. This
happens because the decision whether to use decoder downmix happens long
before the audio device is opened.

If the channel layout of the media file (i.e. the decoder) and the AO's
channel layout don't match, mpv will attempt to insert a conversion filter.
You may need to change the channel layout of the system mixer to achieve
your desired output as mpv does not have control over it. Another
work-around for this on some AOs is to use `--audio-exclusive=yes` to
circumvent the system mixer entirely.

Warning

Using `auto` can cause issues when using audio over HDMI. The OS will
typically report all channel layouts that _can_ go over HDMI, even if
the receiver does not support them. If a receiver gets an unsupported
channel layout, random things can happen, such as dropping the
additional channels, or adding noise.

You are recommended to set an explicit whitelist of the layouts you
want. For example, most A/V receivers connected via HDMI and that can
do 7.1 would  be served by: `--audio-channels=7.1,5.1,stereo`

`--audio-display=<no|embedded-first|external-first>`

Determines whether to display cover art when playing audio files and with
what priority. It will display the first image found, and additional images
are available as video tracks.
| no: | Disable display of video entirely when playing audio
files. |
| --- | --- |
| embedded-first: | Display embedded images and external cover art, giving
priority to embedded images (default). |
| external-first: | Display embedded images and external cover art, giving
priority to external files. |

This option has no influence on files with normal video tracks.

`--audio-files=<files>`

Play audio from an external file while viewing a video.

This is a path list option. See [List Options](manual-options-track.md) for details.

`--audio-file=<file>`

CLI/config file only alias for `--audio-files-append`. Each use of this
option will add a new audio track. The details are similar to how
`--sub-file` works.

`--audio-format=<format>`

Select the sample format used for output from the audio filter layer to
the sound card. The values that `<format>` can adopt are listed below in
the description of the `format` audio filter.

`--audio-samplerate=<Hz>`

Select the output sample rate to be used (of course sound cards have
limits on this). If the sample frequency selected is different from that
of the current media, the internal swresample audio filter will be inserted
into the audio filter layer to compensate for the difference.

`--gapless-audio=<no|yes|weak>`

Try to play consecutive audio files with no silence or disruption at the
point of file change. Default: `weak`.
| no: | Disable gapless audio. |
| --- | --- |
| yes: | The audio device is opened using parameters chosen for the first
file played and is then kept open for gapless playback. This
means that if the first file for example has a low sample rate, then
the following files may get resampled to the same low sample rate,
resulting in reduced sound quality. If you play files with different
parameters, consider using options such as `--audio-samplerate`
and `--audio-format` to explicitly select what the shared output
format will be. |
| weak: | Normally, the audio device is kept open (using the format it was
first initialized with). If the audio format the decoder output
changes, the audio device is closed and reopened. This means that
you will normally get gapless audio with files that were encoded
using the same settings, but might not be gapless in other cases.
The exact conditions under which the audio device is kept open is
an implementation detail, and can change from version to version.
Currently, the device is kept even if the sample format changes,
but the sample formats are convertible.
If video is still going on when there is still audio, trying to use
gapless is also explicitly given up. |

Note

This feature is implemented in a simple manner and relies on audio
output device buffering to continue playback while moving from one file
to another. If playback of the new file starts slowly, for example
because it is played from a remote network location or because you have
specified cache settings that require time for the initial cache fill,
then the buffered audio may run out before playback of the new file
can start.

`--initial-audio-sync=<yes|no>`
