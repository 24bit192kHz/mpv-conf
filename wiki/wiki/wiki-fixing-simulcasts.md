# HD (720p/1080i) Simulcasts

There are some channels which broadcast an "HD simulcast" of their SD channel. For H.264 they can do this with a fixed resolution for some parts of the program, and lower resolution for the rest. The switching is seamless but some players (like VLC) will show artifacts or even crash. mpv handles it well, but may display the wrong aspect ratio.

To fix this, tell mpv to use the display width/height from container:

```
--aspect=0
```

Or you can set the correct aspect ratio manually. For BBC One HD for example, it's 16:9 in an anamorphic 1440x1080, so you can set:

```
--aspect=16/9
```

Setting the aspect works even when playback has started (press `a` key).
