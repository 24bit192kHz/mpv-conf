## Audio Resampler

This controls the default options of any resampling done by mpv (but not within
libavfilter, within the system audio API resampler, or any other places).

`--audio-resample-filter-size=<length>`

Length of the filter with respect to the lower sampling rate. (default:
16)

`--audio-resample-phase-shift=<count>`

Log2 of the number of polyphase entries. (..., 10->1024, 11->2048,
12->4096, ...) (default: 10->1024)

`--audio-resample-cutoff=<cutoff>`

Cutoff frequency (0.0-1.0), default set depending upon filter length.

`--audio-resample-linear=<yes|no>`

If set then filters will be linearly interpolated between polyphase
entries. (default: no)

`--audio-normalize-downmix=<yes|no>`

Enable/disable normalization if surround audio is downmixed to stereo
(default: no). If this is disabled, downmix can cause clipping. If it's
enabled, the output might be too quiet. It depends on the source audio.

If downmix happens outside of mpv for some reason, or in the decoder
(decoder downmixing), or in the audio output (system mixer), this has no
effect.

`--audio-resample-max-output-size=<length>`

Limit maximum size of audio frames filtered at once, in ms (default: 40).
The output size size is limited in order to make resample speed changes
react faster. This is necessary especially if decoders or filters output
very large frame sizes (like some lossless codecs or some DRC filters).
This option does not affect the resampling algorithm in any way.

For testing/debugging only. Can be removed or changed any time.

`--audio-swresample-o=<string>`

Set AVOptions on the SwrContext or AVAudioResampleContext. These should
be documented by FFmpeg.

This is a key/value list option. See [List Options](manual-options-track.md) for details.
