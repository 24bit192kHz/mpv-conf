# AUDIO OUTPUT DRIVERS

Audio output drivers are interfaces to different audio output facilities. The
syntax is:

`--ao=<driver1,driver2,...[,]>`

Specify a priority list of audio output drivers to be used.

If the list has a trailing ',', mpv will fall back on drivers not contained
in the list.

This is an object settings list option. See [List Options](manual-options-track.md) for details.

Note

See `--ao=help` for a list of compiled-in audio output drivers sorted by
autoprobe order.

Note that the default audio output driver is subject to change, and must
not be relied upon. If a certain AO needs to be used, it must be
explicitly specified.

Available audio output drivers are:

`alsa`

ALSA audio output driver.

The following global options are supported by this audio output:

`--alsa-resample=yes`

Enable ALSA resampling plugin. (This is disabled by default, because
some drivers report incorrect audio delay in some cases.)

`--alsa-mixer-device=<device>`

Set the mixer device used with `ao-volume` (default: `default`).

`--alsa-mixer-name=<name>`

Set the name of the mixer element (default: `Master`). This is for
example `PCM` or `Master`.

`--alsa-mixer-index=<number>`

Set the index of the mixer channel (default: 0). Consider the output of
"`amixer scontrols`", then the index is the number that follows the
name of the element.

`--alsa-non-interleaved`

Allow output of non-interleaved formats (if the audio decoder uses
this format). Currently disabled by default, because some popular
ALSA plugins are utterly broken with non-interleaved formats.

`--alsa-ignore-chmap`

Don't read or set the channel map of the ALSA device - only request the
required number of channels, and then pass the audio as-is to it. This
option most likely should not be used. It can be useful for debugging,
or for static setups with a specially engineered ALSA configuration (in
this case you should always force the same layout with `--audio-channels`,
or it will work only for files which use the layout implicit to your
ALSA device).

`--alsa-buffer-time=<microseconds>`

Set the requested buffer time in microseconds. A value of 0 skips requesting
anything from the ALSA API. This and the `--alsa-periods` option uses the
ALSA `near` functions to set the requested parameters. If doing so results
in an empty configuration set, setting these parameters is skipped.

Both options control the buffer size. A low buffer size can lead to higher
CPU usage and audio dropouts, while a high buffer size can lead to higher
latency in volume changes and other filtering.

`--alsa-periods=<number>`

Number of periods requested from the ALSA API. See `--alsa-buffer-time`
for further remarks.

Warning

To get multichannel/surround audio, use `--audio-channels=auto`. The
default for this option is `auto-safe`, which makes this audio output
explicitly reject multichannel output, as there is no way to detect
whether a certain channel layout is actually supported.

You can also try [using the upmix plugin](https://github.com/mpv-player/mpv/wiki/ALSA-Surround-Sound-and-Upmixing).
This setup enables multichannel audio on the `default` device
with automatic upmixing with shared access, so playing stereo
and multichannel audio at the same time will work as expected.

`oss`

OSS audio output driver

`jack`

JACK (Jack Audio Connection Kit) audio output driver.

The following global options are supported by this audio output:

`--jack-port=<name>`

Connects to the ports with the given name (default: physical ports).

`--jack-name=<client>`

Client name that is passed to JACK (default: `mpv`). Useful
if you want to have certain connections established automatically.

`--jack-autostart=<yes|no>`

Automatically start jackd if necessary (default: disabled). Note that
this tends to be unreliable and will flood stdout with server messages.

`--jack-connect=<yes|no>`

Automatically create connections to output ports (default: enabled).
When enabled, the maximum number of output channels will be limited to
the number of available output ports.

`--jack-std-channel-layout=<waveext|any>`

Select the standard channel layout (default: waveext). JACK itself has no
notion of channel layouts (i.e. assigning which speaker a given
channel is supposed to map to) - it just takes whatever the application
outputs, and reroutes it to whatever the user defines. This means the
user and the application are in charge of dealing with the channel
layout. `waveext` uses WAVE_FORMAT_EXTENSIBLE order, which, even
though it was defined by Microsoft, is the standard on many systems.
The value `any` makes JACK accept whatever comes from the audio
filter chain, regardless of channel layout and without reordering. This
mode is probably not very useful, other than for debugging or when used
with fixed setups.

`coreaudio` (macOS only)

Native macOS audio output driver using AudioUnits and the CoreAudio
sound server.

Automatically redirects to `coreaudio_exclusive` when playing compressed
formats.

The following global options are supported by this audio output:

`--coreaudio-change-physical-format=<yes|no>`

Change the physical format to one similar to the requested audio format
(default: no). This has the advantage that multichannel audio output
will actually work. The disadvantage is that it will change the
system-wide audio settings. This is equivalent to changing the `Format`
setting in the `Audio Devices` dialog in the `Audio MIDI Setup`
utility. Note that this does not affect the selected speaker setup.

`--coreaudio-spdif-hack=<yes|no>`

Try to pass through AC3/DTS data as PCM. This is useful for drivers
which do not report AC3 support. It converts the AC3 data to float,
and assumes the driver will do the inverse conversion, which means
a typical A/V receiver will pick it up as compressed IEC framed AC3
stream, ignoring that it's marked as PCM. This disables normal AC3
passthrough (even if the device reports it as supported). Use with
extreme care.

`coreaudio_exclusive` (macOS only)

Native macOS audio output driver using direct device access and
exclusive mode (bypasses the sound server).

`avfoundation` (macOS only)

Native macOS audio output driver using `AVSampleBufferAudioRenderer`
in AVFoundation, which supports [spatial audio](https://support.apple.com/en-us/HT211775).

Warning

Turning on spatial audio may hang the playback
if mpv is not started out of the bundle,
though playback with spatial audio off always works.

`audiounit` (iOS only)

Native iOS audio output driver using `AudioUnits` and AudioToolbox.

`openal`

OpenAL audio output driver.

`--openal-num-buffers=<2-128>`

Specify the number of audio buffers to use. Lower values are better for
