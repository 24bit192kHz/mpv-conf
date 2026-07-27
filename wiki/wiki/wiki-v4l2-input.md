# V4L2 Input

Just use:

```
mpv v4l2:///dev/video0 --demuxer=rawvideo --rawvideo=w=800:h=600:fps=30
mpv /dev/video0 # (needs libquvi-style playlists enabled to work)
```

If V4L2 input does not work properly for you, you may need to make sure your input does not drop frames. This is often a main cause of error'd output.
