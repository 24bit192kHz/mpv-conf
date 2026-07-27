## Configuration

_mpv_ comes with good all-around defaults that should work well on computers with weaker/older video cards. However, if you have a computer with a more modern video card, _mpv_ allows you to do a great deal of configuration to achieve better video quality (limited only by the power of your video card). To do this, one only needs to create a few configuration files (as they do not exist by default).

**Note:** Configuration files are read system-wide from `/etc/mpv/` and per-user from `~/.config/mpv/` (unless the environment variable `XDG_CONFIG_HOME` is set), where per-user settings override system-wide settings, all of which are overridden by the command line. User-specific configuration is suggested since it may require some trial and error.

To help you get started, _mpv_ provides sample configuration files with default settings. Copy them to use as a starting point:

```
$ cp -r /usr/share/doc/mpv/ ~/.config/
```

`mpv.conf` contains the majority of _mpv_'s settings, `input.conf` contains key bindings. Read through both of them to get an idea of how they work and what options are available.

### General settings

Add the following settings to `~/.config/mpv/mpv.conf`.

#### Subtitle configurations

Enable fuzzy searching:

```
sub-auto=fuzzy
```

Change font:

```
sub-font="fontName"
```

Bold the subtitles to increase readability:

```
sub-bold=yes
```

#### High quality configurations

By default, mpv utilizes settings that balance quality and performance. Additionally, two predefined profiles are available: `fast` for maximum performance and `high-quality` for superior rendering quality. You can apply a specific profile using the `--profile=name` option and inspect its contents using `--show-profile=name`.

```
profile=high-quality
```

Live statistics showing how well _mpv_ is performing can be brought up with the `i` key. It is very useful for making sure that your hardware can keep up with your configuration and for comparing different configurations.

These last two options are a little more complicated. `video-sync=display-resample` makes it so that if audio and video go out of sync, then instead of dropping video frames, it will resample the audio (a slight change in audio pitch is often less noticeable than dropped frames). The mpv wiki has an in depth article on it titled [Display Synchronization](https://github.com/mpv-player/mpv/wiki/Display-synchronization). `interpolation` makes motion appear smoother on your display by changing the way that frames are shown so that the source framerate jives better with your display's refresh rate (not to be confused with SVP's technique which actually converts video to 60fps). The mpv wiki has an in depth article on it titled [Interpolation](https://github.com/mpv-player/mpv/wiki/Interpolation) though it is also commonly known as _smoothmotion_.

```
profile=high-quality
video-sync=display-resample
interpolation
```

**Note:** If NVIDIA Optimus is being used, the line `video-sync=display-resample` may cause video to be sped up. It also completely messes up frame pacing on some systems, seemingly preventing interpolation from working at all.

Beyond this, there is still a lot you can do, but things become more complicated, require more powerful video cards, and are in constant development. As a brief overview, it is possible to load special shaders that perform exotic scaling and sharpening techniques including some that actually use deep neural networks trained on images (for both real world and animated content). To learn more about this, take a look around the [mpv wiki](https://github.com/mpv-player/mpv/wiki), particularly the [user shaders section](https://github.com/mpv-player/mpv/wiki/User-Scripts#user-shaders).

There are also plenty of other options you may find desirable as well. It is worthwhile taking a look at `man mpv`. It is also helpful to run _mpv_ from the command line to check for error messages about the config.
