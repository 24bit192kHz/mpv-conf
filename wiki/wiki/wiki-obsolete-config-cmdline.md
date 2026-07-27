> **OBSOLETE**: This page contains old brainstorming about how sub-option handling could be improved. It does not reflect current syntax. Whether something like this will be implemented or not is up to the stars.

## Command Line Example

```
--include=local.conf
--softvol=yes
--ass=yes
--embeddedfonts=yes
--vf-add=screenshot
--vo=vdpau=[ deint=-4 pullup ]
--vc=[ item=ffmpeg12vdpau item=ffwmv3vdpau item=ffc1vdpau item=ffh264vdpau SUPER ]
--vc-pre=ffh264vdpau
--vc-pre=[ item=ffc1vdpau ]
--vc-pre=ffwmv3vdpau
--vc-pre=ffmpeg12vdpau
--vo=xv
--lavdopts=[ threads=4 ]
--ao=alsa
--include=/usr/share/doc/mplayer/examples/encoding-example-profiles.conf
--profile=enc-to-iphone
--vf-add=ass
--ass-force-style="Fontname=sans"
--ovcopts-add=[ tune=animation threads=4 ]
```

## Config Example

```
include = local.conf
ass = yes
embeddedfonts = yes
vf-add = screenshot
vo = xv
lavdopts = [ threads = 4 ]
ao = alsa
include = /usr/share/doc/mplayer/examples/encoding-example-profiles.conf

[enc]
profile = enc-to-iphone
vf-add = ass
ass-force-style = "Fontname=sans"
ovcopts-add = [ tune = animation threads = 4 ]
```

## Alternative Syntax (Space-separated lists)

```
--lavdopts [ threads=4 ]
--vo=vdpau [ deint=-4 pullup ]
```

Config equivalent uses `[` directly instead of `=` `[`.
