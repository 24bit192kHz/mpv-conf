# mpv config

Personal mpv configuration with HDR profiles, Arabic subtitle helpers, uosc, shaders, and CUDA-backed dynamic crop.

Install:

```sh
curl -fSsL https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.sh | sh
```

The installer backs up an existing `~/.config/mpv` directory before copying this config.

Dynamic crop includes the Python analyzer in `cuda-crop-py/`. The installer copies it to
`~/.config/mpv/cuda-crop-py` and runs `uv sync` when `uv` is available. Manual setup:

```sh
cd ~/.config/mpv/cuda-crop-py
uv sync
```

SubDL/TMDB keys are intentionally not committed. Copy `.env.example` to `.env` and fill it locally. `script-opts/subdl_ar.conf` is also supported for mpv-style local overrides.
