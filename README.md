# mpv config

Personal mpv configuration with HDR profiles, Arabic subtitle helpers, uosc, shaders, and CUDA-backed dynamic crop.

Install:

```sh
curl -fSsL https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.sh | sh
```

The installer backs up an existing `~/.config/mpv` directory before copying this config.

Dynamic crop expects `cuda-crop-py` at `/home/btw/mhm/cuda-crop-py`. Edit the `dynamic_crop-project` and `dynamic_crop-binary` lines in `mpv.conf` if your path is different.
