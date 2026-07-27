# Use `vo_gpu`

There is some confusion with regards to the different VOs that mpv has to offer. Unless you ***really*** know what you're doing, **you should be using `vo_gpu`**.

## But I want hardware decoding!

And you can get that by just setting `hwdec`. The `vo_vaapi` and `vo_vdpau` video outputs are separate parts of the vaapi and vdpau APIs which don't tie into hardware decoding at all. They should not be used.

## But `vo_gpu` is slow for me!

There's a couple of reasons why that could be, ranging from a weak GPU to broken drivers that fall back to software rendering, but there is a good reason as to why `vo_gpu` requires more power than some of the "dumber" video outputs.

`vo_gpu` uses your GPU's shader pipeline to do the video rendering itself, so mpv can control scaling, dithering and other things in detail. With other VOs such as `vo_vaapi` and `vo_vdpau`, mpv just feeds data into a black box. It has very little control over how the video is rendered, which means none of the `gpu-hq` settings apply.

## But `vo_gpu` is broken for me!

This can happen if your drivers are broken or if your GPU is very old. Check that you even get any OpenGL acceleration at all; on Linux with X11 you could do this with `glxinfo`. If it contains the word "llvmpipe", chances are your driver is broken.

If you have recently upgraded your version of Mesa, especially on a rolling-release distribution, try rebooting your computer first. Mesa updates can occasionally break OpenGL acceleration until the system is restarted.

## But all I have is `vo_opengl`!

Stop using an outdated version of mpv.
