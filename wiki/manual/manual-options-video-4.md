is smaller than the window, this is useful to recenter the video in the
window.

Default: no.

`--video-margin-ratio-left=<val>`, `--video-margin-ratio-right=<val>`, `--video-margin-ratio-top=<val>`, `--video-margin-ratio-bottom=<val>`

Set extra video margins on each border (default: 0). Each value is a ratio
of the window size, using a range 0.0-1.0. For example, setting the option
`--video-margin-ratio-right=0.2` at a window size of 1000 pixels will add
a 200 pixels border on the right side of the window.

The video is "boxed" by these margins. The window size is not changed. In
particular it does not enlarge the window, and the margins will cause the
video to be downscaled by default. This may or may not change in the future.

The margins are applied after 90° video rotation, but before any other video
transformations.

This option is disabled if `--keepaspect=no` is used.

Subtitles still may use the margins, depending on `--sub-use-margins` and
similar options.

These options were created for the OSC. Some odd decisions, such as making
the margin values a ratio (instead of pixels), were made for the sake of
the OSC. It's possible that these options may be replaced by ones that are
more generally useful. The behavior of these options may change to fit
OSC requirements better, too.

`--correct-pts=<yes|no>`

`--correct-pts=no` switches mpv to a mode where video timing is
determined using a fixed framerate value (either using the
`--container-fps-override` option, or using file information). Sometimes,
files with very broken timestamps can be played somewhat well in this mode.
Note that video filters, subtitle rendering, seeking (including hr-seeks and
backstepping), and audio synchronization can be completely broken in this mode.

`--container-fps-override=<float>`

Override video framerate. Useful if the original value is wrong or missing.

Note

Works in `--correct-pts=no` mode only.

`--deinterlace=<yes|no|auto>`

Enable or disable deinterlacing (default: no).
Interlaced video shows ugly comb-like artifacts, which are visible on
fast movement. Enabling this typically inserts the bwdif video filter in
order to deinterlace the video, or lets the video output apply deinterlacing
if supported.

When using `auto`, mpv will insert a deinterlacing filter if ffmpeg
detects that the video frame is interlaced. Be aware that there can be false
positives in certain cases, such as when files are encoded as interlaced
despite the video not actually being so. This is why `auto` is not the
default value.

Keep in mind that using this filter **will** conflict with any manually
inserted deinterlacing filters, and that this will make video look worse if
it's not actually interlaced.

`--deinterlace-field-parity=<tff|bff|auto>`

Specify the field parity/order when deinterlacing (default: auto).
Each frame of an interlaced video is divided into two fields, which are
then separately transmitted. Top field represents even lines while bottom
field represents odd lines. When deinterlacing the deinterlacer needs to
know the correct temporal order of the fields else the video will appear
jittery.

`auto` will automatically try to detect the field order of the video,
`tff` forces top field first while `bff` forces bottom field first.

`--frames=<number>`

Play/convert only first `<number>` video frames, then quit.

`--frames=0` loads the file, but immediately quits before initializing
playback. (Might be useful for scripts which just want to determine some
file properties.)

For audio-only playback, any value greater than 0 will quit playback
immediately after initialization. The value 0 works as with video.

`--video-output-levels=<outputlevels>`

RGB color levels used with YUV to RGB conversion. Normally, output devices
such as PC monitors use full range color levels. However, some TVs and
video monitors expect studio RGB levels. Providing full range output to a
device expecting studio level input results in crushed blacks and whites,
the reverse in dim gray blacks and dim whites.

Not all VOs support this option. Some will silently ignore it.

Available color ranges are:
| auto: | automatic selection (equals to full range) (default) |
| --- | --- |
| limited: | limited range (16-235 per component), studio levels |
| full: | full range (0-255 per component), PC levels |

Note

It is advisable to use your graphics driver's color range option
instead, if available.

`--hwdec-codecs=<codec1,codec2,...|all>`

Allow hardware decoding for a given list of codecs only. The special value
`all` always allows all codecs.

You can get the list of allowed codecs with `mpv --vd=help`. Remove the
prefix, e.g. instead of `lavc:h264` use `h264`.

By default, this is set to `h264,vc1,hevc,vp8,vp9,av1,prores,prores_raw,ffv1,dpx`. Note that
the hardware acceleration special codecs like `h264_vdpau` are not
relevant anymore, and in fact have been removed from FFmpeg in this form.

This is usually only needed with broken GPUs, where a codec is reported
as supported, but decoding causes more problems than it solves.

Note

On some broken drivers (e.g. NVIDIA on Linux), probing for codecs which
the GPU does not support can unnecessarily slow down video playback
initialization. To alleviate this, explicitly specify a list which
only includes the codecs supported on the setup.

Example

`mpv --hwdec=vdpau --hwdec-codecs=h264,mpeg2video`

Enable vdpau decoding for h264 and mpeg2 only.

`--hwdec-threads=<N>`

Number of threads used for hardware decoding (default: 4). This, as opposed
to vd-queue, enables frame and slice threading in libavcodec. It can help
with pipelining the decoding process and improve performance. The exact
behavior depends on the hardware decoder API used.

If this is set to 0, the number of threads will be automatically determined
by the number of CPU cores available.

`--hwdec-software-fallback=<yes|no|N>`

Fallback to software decoding if the hardware-accelerated decoder fails
(default: 3). If this is a number, then fallback will be triggered if
N frames fail to decode in a row. 1 is equivalent to `yes`.

Setting this to a higher number might break the playback start fallback: if
a fallback happens, parts of the file will be skipped, approximately by to
the number of packets that could not be decoded. Values below an unspecified
count will not have this problem, because mpv retains the packets.

`--vd-lavc-check-hw-profile=<yes|no>`

Check hardware decoder profile (default: yes). If `no` is set, the
highest profile of the hardware decoder is unconditionally selected, and
decoding is forced even if the profile of the video is higher than that.
The result is most likely broken decoding, but may also help if the
detected or reported profiles are somehow incorrect.

`--vd-lavc-film-grain=<auto|cpu|gpu>`

Enables film grain application on the GPU. If video decoding is done on
the CPU, doing film grain application on the GPU can speed up decoding.
This option can also help hardware decoding, as it can reduce the number
of frame copies done.

By default, it's set to `auto`, so if the VO supports film grain
application, then it will be treated as `gpu`. If the VO does not
support this, then it will be treated as `cpu`, regardless of the setting.
Currently, only `gpu-next` supports film grain application.

`--vd-lavc-dr=<auto|yes|no>`

Enable direct rendering (default: auto). If this is set to `yes`, the
video will be decoded directly to GPU video memory (or staging buffers).
This can speed up video upload, and may help with large resolutions or
slow hardware. This works only with the following VOs:

> - `gpu`: requires at least OpenGL 4.4 or Vulkan.
>
> - `libmpv`: The libmpv render API has optional support.

The `auto` option will try to guess whether DR can improve performance
on your particular hardware. Currently this enables it on AMD or NVIDIA
if using OpenGL or unconditionally if using Vulkan.

Using video filters of any kind that write to the image data (or output
newly allocated frames) will silently disable the DR code path.
