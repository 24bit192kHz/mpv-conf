### Streaming

#### Twitch.tv streaming over mpv

If [yt-dlp](https://wiki.archlinux.org/title/Yt-dlp) or `youtube-dl` is installed, _mpv_ can directly open a Twitch livestream.

Alternatively, see [Streamlink#Twitch](https://wiki.archlinux.org/title/Streamlink#Twitch).

Another alternative based on Livestreamer is this Lua script: <https://gist.github.com/ChrisK2/8701184fe3ea7701c9cc>

#### youtube-dl and choosing formats

The default `--ytdl-format` is `bestvideo+bestaudio/best`. For youtube videos that have 4K resolutions available, this may mean that your device will struggle to decode 4K VP9 encoded video in software even if the attached monitor is much lower resolution.

Setting the right youtube-dl format selectors can fix this easily though. In the following configuration example, only videos with a vertical resolution of 1080 pixels or less will be considered.

```
ytdl-format="bestvideo[height<=?1080]+bestaudio/best"
```

If you wish to avoid a certain codec altogether because you cannot hardware-decode it, you can add this to the format selector. For example, we can additionally choose to ignore VP9 as follows:

```
ytdl-format="bestvideo[height<=?1080][vcodec!~='vp0?9']+bestaudio/best"
```

If you prefer best quality open codecs (VP9 and Opus), use:

```
ytdl-format="((bestvideo[vcodec^=vp9]/bestvideo)+(bestaudio[acodec=opus]/bestaudio[acodec=vorbis]/bestaudio[acodec=aac]/bestaudio))/best"
```

#### youtube-dl audio with search

To find and stream audio from your terminal emulator with `yta <search terms>`, put the following function in your [shell startup file](https://wiki.archlinux.org/title/Command-line_shell#Configuration_files):

```
function yta() {
    mpv --ytdl-format=bestaudio ytdl://ytsearch:"$*"
}
```

#### V4L2 AV capture device

For example, live streaming from an USB webcam or from an USB HDMI capture device.

Find the V4L2 device's video device node:

```
$ v4l2-ctl --list-devices
HDMI Capture: HDMI Capture (usb-0000:07:00.1-2):
    /dev/video2
    /dev/video3
    /dev/media1
```

Usually this is the first listed `/dev/video*` node, here `/dev/video2`.

Then, find the name of the capture device's PulseAudio source:

```
$ pactl list short sources | grep --invert-match --regexp=.monitor
8750 alsa_input.usb-XF_HDMI_Capture_20000130041415-02.iec958-stereo PipeWire s16le 2ch 48000Hz SUSPENDED
```

That name would here be `alsa_input.usb-XF_HDMI_Capture_20000130041415-02.iec958-stereo`.

Now you can launch MPV with this command:

```
$ mpv --audio-file=av://pulse:alsa_input.usb-XF_HDMI_Capture_20000130041415-02.iec958-stereo -- av://v4l2:/dev/video2
```

### System integration

#### Opening video links from the KDE clipboard

If `youtube-dl` or `yt-dlp` is installed and [KDE Plasma](https://wiki.archlinux.org/title/KDE_Plasma) is being used, it is possible to create a custom action in the KDE clipboard to conveniently play links from video sharing sites.

1. Open the clipboard configuration menu (typically by right-clicking its icon in the system tray) and go to the _Actions_ tab.
2. Click _Add Action_ then enter a regular expression to detect the sites you would like to play video from (e.g. `^http.+(youtube|twitch)` to detect YouTube and Twitch URLs).
3. Click _Add Command_, under _Command_ enter `mpv %s` and under _Description_ enter `mpv`.

Now, you can play video links from your clipboard in _mpv_ by pressing `Ctrl+Alt+r` and selecting _mpv_ from the context menu. You may need to go to _Advanced Settings_ and remove Firefox from the section _Disable Actions for Windows of Type WM_CLASS_.
