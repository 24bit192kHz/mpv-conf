# v4l2 drmprime support in mpv

mpv includes support for consuming drmprime dmabufs produced by v4l2 (either v4l2m2m or v4l2-request) to do zero-copy GPU rendering. However, this support relies on there being a source capable of producing these dmabufs. Unfortunately, upstream ffmpeg doesn't have this capability. It only supports v4l2m2m with decoded video frames being copied to system memory first, and doesn't support the v4l2-request API at all. If you try and use hardware decoders via v4l2 with upstream ffmpeg, you will not get zero-copy dmabuf support, and likely won't get working output at all.

## ffmpeg forks with drmprime dmabuf support

At the current time, drmprime dmabuf support is only available in ffmpeg forks. It appears (we are not experts on this ecosystem) that there are two primary forks, one for Raspberry Pi devices (the main v4l2m2m based devices) and one for v4l2-request.

* [jc-kynesim](https://github.com/jc-kynesim/rpi-ffmpeg) (v4l2m2m)
* [jernejsk](https://github.com/jernejsk/ffmpeg/tree/v4l2-request-n6.0) (v4l2-request)

You may also find clearer recommendations on the ffmpeg fork to use from your embedded device's community and documentation. As mpv only cares about being provided dmabufs, we have minimal dependencies on the specifics of how the fork produces them.

## Will we ever see v4l2 drmprime support merged into upstream ffmpeg

It seems unlikely. There isn't really anyone active in upstream ffmpeg that cares about this functionality, and it doesn't appear that anyone involved with the forks is interested in sending patches back - so we're likely to remain in this situation for the indefinite future.
