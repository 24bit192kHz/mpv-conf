## Software Scaler

`--sws-scaler=<name>`

Specify the software scaler algorithm to be used with `--vf=scale`. This
also affects video output drivers which lack hardware acceleration,
e.g. `x11`. See also `--vf=scale`.

To get a list of available scalers, run `--sws-scaler=help`.

Default: `bicubic`.

`--sws-lgb=<0-100>`

Software scaler Gaussian blur filter (luma). See `--sws-scaler`.

`--sws-cgb=<0-100>`

Software scaler Gaussian blur filter (chroma). See `--sws-scaler`.

`--sws-ls=<-100-100>`

Software scaler sharpen filter (luma). See `--sws-scaler`.

`--sws-cs=<-100-100>`

Software scaler sharpen filter (chroma). See `--sws-scaler`.

`--sws-chs=<h>`

Software scaler chroma horizontal shifting. See `--sws-scaler`.

`--sws-cvs=<v>`

Software scaler chroma vertical shifting. See `--sws-scaler`.

`--sws-bitexact=<yes|no>`

Unknown functionality (default: no). Consult libswscale source code. The
primary purpose of this, as far as libswscale API goes), is to produce
exactly the same output for the same input on all platforms (output has the
same "bits" everywhere, thus "bitexact"). Typically disables optimizations.

`--sws-fast=<yes|no>`

Allow optimizations that help with performance, but reduce quality (default:
no).

VOs like `drm` and `x11` will benefit a lot from using `--sws-fast`.
You may need to set other options, like `--sws-scaler`. The builtin
`sws-fast` profile sets this option and some others to gain performance
for reduced quality. Also see `--sws-allow-zimg`.

`--sws-allow-zimg=<yes|no>`

Allow using zimg (if the component using the internal swscale wrapper
explicitly allows so) (default: yes). In this case, zimg *may* be used, if
the internal zimg wrapper supports the input and output formats. It will
silently or noisily fall back to libswscale if one of these conditions does
not apply.

If zimg is used, the other `--sws-` options are ignored, and the
`--zimg-` options are used instead.

If the internal component using the swscale wrapper hooks up logging
correctly, a verbose priority log message will indicate whether zimg is
being used.

Most things which need software conversion can make use of this.

Note

Do note that zimg *may* be slower than libswscale. Usually,
it's faster on x86 platforms, but slower on ARM (due to lack of ARM
specific optimizations). The mpv zimg wrapper uses unoptimized repacking
for some formats, for which zimg cannot be blamed.

`--zimg-scaler=

`

Zimg luma scaler to use (default: lanczos).

`--zimg-scaler-param-a=<default|float>`, `--zimg-scaler-param-b=<default|float>`

Set scaler parameters. By default, these are set to the special string
`default`, which maps to a scaler-specific default value. Ignored if the
scaler is not tunable.

`lanczos`

`--zimg-scaler-param-a` is the number of taps.

`bicubic`

a and b are the bicubic b and c parameters.

`--zimg-scaler-chroma=...`

Same as `--zimg-scaler`, for for chroma interpolation (default: bilinear).

`--zimg-scaler-chroma-param-a`, `--zimg-scaler-chroma-param-b`

Same as `--zimg-scaler-param-a` / `--zimg-scaler-param-b`, for chroma.

`--zimg-dither=<no|ordered|random|error-diffusion>`

Dithering (default: random).

`--zimg-threads=<auto|integer>`

Set the maximum number of threads to use for scaling (default: auto).
`auto` uses the number of logical cores on the current machine. Note that
the scaler may use less threads (or even just 1 thread) depending on stuff.
Passing a value of 1 disables threading and always scales the image in a
single operation. Higher thread counts waste resources, but make it
typically faster.

Note that some zimg git versions had bugs that will corrupt the output if
threads are used.

`--zimg-fast=<yes|no>`

Allow optimizations that help with performance, but reduce quality (default:
yes). Currently, this may simplify gamma conversion operations.
