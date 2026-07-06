# cuda-crop-py

Experimental CUDA crop detector for mpv testing.

It remuxes a short video window with `ffmpeg -c copy`, decodes the segment on NVDEC via
`PyNvVideoCodec`, wraps decoded GPU frames with CuPy, and runs the crop boundary scan on
CUDA arrays.

Run:

```sh
uv run cuda-crop-py /path/to/movie.mkv --start 600 --duration 12 --sample-step 24
```

Expected output:

```json
{
  "crop": "3840:1600:0:280",
  "mpv_filter": "w=3840:h=1600:x=0:y=280",
  "votes": 11,
  "sampled_frames": 13
}
```

mpv test path:

```sh
mpv \
  --script-opts-append=dynamic_crop-enabled=yes \
  --script-opts-append=dynamic_crop-backend=cuda \
  --script-opts-append=dynamic_crop-debug=yes \
  /path/to/movie.mkv
```

Benchmark a segment:

```sh
python benchmarks/bench_analyze.py /path/to/movie.mkv --start 405 --duration 10 --mode timeline
```
