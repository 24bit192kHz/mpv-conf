# EMBEDDING INTO OTHER PROGRAMS (LIBMPV)

mpv can be embedded into other programs as video/audio playback backend. The
recommended way to do so is using libmpv. See `include/mpv/client.h` in the mpv
source code repository. This provides a C API. Bindings for other languages
might be available (see wiki).

Since libmpv merely allows access to underlying mechanisms that can control
mpv, further documentation is spread over a few places:

- [https://github.com/mpv-player/mpv/blob/master/include/mpv/client.h](https://github.com/mpv-player/mpv/blob/master/include/mpv/client.h)

- [https://mpv.io/manual/master/#options](https://mpv.io/manual/master/#options)

- [https://mpv.io/manual/master/#list-of-input-commands](https://mpv.io/manual/master/#list-of-input-commands)

- [https://mpv.io/manual/master/#properties](https://mpv.io/manual/master/#properties)

- [https://github.com/mpv-player/mpv-examples/tree/master/libmpv](https://github.com/mpv-player/mpv-examples/tree/master/libmpv)
