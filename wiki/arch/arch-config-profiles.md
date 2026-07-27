### Custom profiles

In `mpv.conf` it is possible to create _profiles_ which are essentially just "groups of options" with which you can:

- Quickly switch between different configurations without having to rewrite the file.
- Create special profiles for special content.
- _nest_ profiles so that you can make more complicated _profiles_ out of simpler ones.

Creating a profile is easy. The area at the top of `mpv.conf` is called the top level, any options you write there will kick into effect once _mpv_ is started. However, once you define a profile by writing its name in brackets, every option you write below it (until you define a new profile) is considered part of that profile. Here is an example `mpv.conf`:

```
profile=myprofile2        # Top level area, load myprofile2
ontop=yes                 # Always on top

[myprofile1]              # A simple profile, top level area ends here
profile-desc="a profile"  # Optional description for profile
fs=yes                    # Start in full screen

[myprofile2]              # Another simple profile
profile=high-quality      # A built in profile that comes with mpv
log-file=~~/log           # Sets a location for writing a log file, ~~/ translates to ~/.config/mpv
```

There are only two lines within the top level area and there are two separate profiles defined below it. When _mpv_ starts, it sees the first line, loads the options in `myprofile2` (which means it loads the options in `high-quality` and `log-file=~~/log`) finally it loads `ontop=yes` and finishes starting up. Note, `myprofile1` is never loaded because it is never called in the top level area.

Alternatively, one could call _mpv_ from the command line with:

```
$ mpv --profile=myprofile1 video.mkv
```

and it would ignore all options except the ones for `myprofile1`.

#### Automatic profiles

Certain types of profiles will be loaded automatically based on either the file extension or the protocol used.

These profiles will be loaded for all files with a matching file extension (for all _.mkv_ and _.gif_ files respectively):

```
[extension.mkv]
keep-open
volume-max=150

[extension.gif]
osc=no
loop-file
```

This profile will be loaded automatically whenever any http or https streams are played (e.g. `mpv https://example.com/video.mp4`):

```
[protocol.https]
speed=2
keep-open

[protocol.http]
profile=protocol.https
```

Run `mpv --list-protocols` to see the different protocols supported by mpv.
