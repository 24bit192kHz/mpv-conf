lower CPU usage. Default: 4.

`--openal-num-samples=<256-32768>`

Specify the number of complete samples to use for each buffer. Higher
values are better for lower CPU usage. Default: 8192.

`--openal-direct-channels=<yes|no>`

Enable OpenAL Soft's direct channel extension when available to avoid
tinting the sound with ambisonics or HRTF. Default: yes.

`pulse`

PulseAudio audio output driver

The following global options are supported by this audio output:

`--pulse-host=<host>`

Specify the host to use. An empty <host> string uses a local connection,
"localhost" uses network transfer (most likely not what you want).

`--pulse-buffer=<1-2000|native>`

Set the audio buffer size in milliseconds. A higher value buffers
more data, and has a lower probability of buffer underruns. A smaller
value makes the audio stream react faster, e.g. to playback speed
changes. "native" lets the sound server determine buffers.

`--pulse-latency-hacks=<yes|no>`

Enable hacks to workaround PulseAudio timing bugs (default: yes). If
enabled, mpv will do elaborate latency calculations on its own. If
disabled, it will use PulseAudio automatically updated timing
information. Disabling this might help with e.g. networked audio or
some plugins, while enabling it might help in some unknown situations
(it is currently enabled due to known bugs with PulseAudio 16.0).

`--pulse-allow-suspended=<yes|no>`

Allow mpv to use PulseAudio even if the sink is suspended (default: no).
Can be useful if PulseAudio is running as a bridge to jack and mpv has its sink-input set to the one jack is using.

`pipewire`

PipeWire audio output driver

The following global options are supported by this audio output:

`--pipewire-buffer=<1-2000|native>`

Set the audio buffer size in milliseconds. A higher value buffers
more data, and has a lower probability of buffer underruns. A smaller
value makes the audio stream react faster, e.g. to playback speed
changes. "native" lets the sound server determine buffers.

`--pipewire-remote=<remote>`

Specify the PipeWire remote daemon name to connect to via local UNIX
sockets.
An empty <remote> string uses the default remote named `pipewire-0`.

`--pipewire-volume-mode=<channel|global>`

Specify if the `ao-volume` property should apply to the channel
volumes or the global volume.
By default the channel volumes are used.

`sdl`

SDL 2.0+ audio output driver. Should work on any platform supported by SDL
2.0, but may require the `SDL_AUDIODRIVER` environment variable to be set
appropriately for your system.

Note

This driver is for compatibility with extremely foreign
environments, such as systems where none of the other drivers
are available.

The following global options are supported by this audio output:

`--sdl-buflen=<length>`

Sets the audio buffer length in seconds. Is used only as a hint by the
sound system. Playing a file with `-v` will show the requested and
obtained exact buffer size. A value of 0 selects the sound system
default.

`null`

Produces no audio output but maintains video playback speed. You can use
`--ao=null --ao-null-untimed` for benchmarking.

The following global options are supported by this audio output:

`--ao-null-untimed`

Do not simulate timing of a perfect audio device. This means audio
decoding will go as fast as possible, instead of timing it to the
system clock.

`--ao-null-buffer`

Simulated buffer length in seconds.

`--ao-null-outburst`

Simulated chunk size in samples.

`--ao-null-speed`

Simulated audio playback speed as a multiplier. Usually, a real audio
device will not go exactly as fast as the system clock. It will deviate
just a little, and this option helps to simulate this.

`--ao-null-latency`

Simulated device latency. This is additional to EOF.

`--ao-null-broken-eof`

Simulate broken audio drivers, which always add the fixed device
latency to the reported audio playback position.

`--ao-null-broken-delay`

Simulate broken audio drivers, which don't report latency correctly.

`--ao-null-channel-layouts`

If not empty, this is a `,` separated list of channel layouts the
AO allows. This can be used to test channel layout selection.

`--ao-null-format`

Force the audio output format the AO will accept. If unset accepts any.

`pcm`

Raw PCM/WAVE file writer audio output

The following global options are supported by this audio output:

`--ao-pcm-waveheader=<yes|no>`

Include or do not include the WAVE header (default: included). When
not included, raw PCM will be generated.

`--ao-pcm-file=<filename>`

Write the sound to `<filename>` instead of the default
`audiodump.wav`. If `no-waveheader` is specified, the default is
`audiodump.pcm`.

`--ao-pcm-append=<yes|no>`

Append to the file, instead of overwriting it. Always use this with the
`no-waveheader` option - with `waveheader` it's broken, because
it will write a WAVE header every time the file is opened.

`sndio`

Audio output to the OpenBSD sndio sound system

(Note: only supports mono, stereo, 4.0, 5.1 and 7.1 channel
layouts.)

`wasapi`

Audio output to the Windows Audio Session API.

The following global options are supported by this audio output:

`--wasapi-exclusive-buffer=<default|min|1-2000000>`

Set buffer duration in exclusive mode (i.e., with
`--audio-exclusive=yes`). `default` and `min` use the default and
minimum device period reported by WASAPI, respectively. You can also
directly specify the buffer duration in microseconds, in which case a
duration shorter than the minimum device period will be rounded up to
the minimum period.

The default buffer duration should provide robust playback in most
cases, but reportedly on some devices there are glitches following
stream resets under the default setting. In such cases, specifying a
shorter duration might help.
