> **OBSOLETE**: This page is obviously outdated and uses things that were never part of mainline mpv.

## Lua filter benchmarks

Benchmarks comparing various mpv video filter methods using Big Buck Bunny.

Results on AMD Athlon II X4 620 @ 2.6GHz (LuaJIT 2.0.0-beta10):

| Filter | Time (s) |
|--------|----------|
| No filter | 7.11 |
| eq2 | 7.66 |
| lua-pxy | 40.90 |
| lua-c | 16.51 |
| lua-lut | 7.76 |
| dlopen | 7.09 |
| geq | 333.80 |

Results on Intel Core2 Duo P8700 @ 2.53GHz:

| Filter | Time (s) |
|--------|----------|
| No filter | 12.08 |
| eq2 | 12.88 |
| lua-pxy | 19.75 |
| lua-c | 15.65 |
| lua-lut | 13.41 |
| dlopen | 12.06 |
| geq | 293.17 |

Results on Intel Celeron M @ 900MHz:

| Filter | Time (s) |
|--------|----------|
| No filter | 101.95 |
| eq2 | 111.75 |
| lua-pxy | 192.28 |
| lua-c | 154.78 |
| lua-lut | 111.69 |
| dlopen | 103.11 |
| geq | 2830.33 |

Results on Intel Core2 Duo E6550 @ 2.33GHz:

| Filter | Time (s) |
|--------|----------|
| No filter | 14.42 |
| eq2 | 15.39 |
| lua-pxy | 23.18 |
| lua-c | 19.01 |
| lua-lut | 16.14 |
| dlopen | 14.50 |
| geq | 402.70 |

See source files for the full test script and `invert_y.c` dlopen filter implementation.
