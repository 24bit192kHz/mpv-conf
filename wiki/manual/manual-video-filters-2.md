to force a VO which definitely does not support it, which should
show incorrect colors as confirmation.

Using `--sws-allow-zimg=no` (or disabling zimg at build time)
will use libswscale, which cannot perform this conversion as
of this writing.

`<colormatrix>`

Controls the YUV to RGB color space conversion when playing video. There
are various standards. Normally, BT.601 should be used for SD video, and
BT.709 for HD video. (This is done by default.) Using incorrect color space
results in slightly under or over saturated and shifted colors.

These options are not always supported. Different video outputs provide
varying degrees of support. The `gpu` and `vdpau` video output
drivers usually offer full support. The `xv` output can set the color
space if the system video driver supports it, but not input and output
levels. The `scale` video filter can configure color space and input
levels, but only if the output format is RGB (if the video output driver
supports RGB output, you can force this with `--vf=scale,format=rgba`).

If this option is set to `auto` (which is the default), the video's
color space flag will be used. If that flag is unset, the color space
will be selected automatically. This is done using a simple heuristic that
attempts to distinguish SD and HD video. If the video is larger than
1279x576 pixels, BT.709 (HD) will be used; otherwise BT.601 (SD) is
selected.

Available color spaces are:
| auto: | automatic selection (default) |
| --- | --- |
| bt.601: | ITU-R Rec. BT.601 (SD) |
| bt.709: | ITU-R Rec. BT.709 (HD) |
| bt.2020-ncl: | ITU-R Rec. BT.2020 (non-constant luminance) |
| bt.2020-cl: | ITU-R Rec. BT.2020 (constant luminance) |
| bt.2100-pq: | ITU-R Rec. BT.2100 ICtCp PQ variant |
| bt.2100-hlg: | ITU-R Rec. BT.2100 ICtCp HLG variant |
| dolbyvision: | Dolby Vision |
| smpte-240m: | SMPTE-240M |

`<colorlevels>`

YUV color levels used with YUV to RGB conversion. This option is only
necessary when playing broken files which do not follow standard color
levels or which are flagged wrong. If the video does not specify its
color range, it is assumed to be limited range.

The same limitations as with `<colormatrix>` apply.

Available color ranges are:
| auto: | automatic selection (normally limited range) (default) |
| --- | --- |
| limited: | limited range (16-235 for luma, 16-240 for chroma) |
| full: | full range (0-255 for both luma and chroma) |

`

`

RGB primaries the source file was encoded with. Normally this should be set
in the file header, but when playing broken or mistagged files this can be
used to override the setting.

This option only affects video output drivers that perform color
management, for example `gpu` with the `target-prim` or
`icc-profile` suboptions set.

If this option is set to `auto` (which is the default), the video's
primaries flag will be used. If that flag is unset, the color space will
be selected automatically, using the following heuristics: If the
`<colormatrix>` is set or determined as BT.2020 or BT.709, the
corresponding primaries are used. Otherwise, if the video height is
exactly 576 (PAL), BT.601-625 is used. If it's exactly 480 or 486 (NTSC),
BT.601-525 is used. If the video resolution is anything else, BT.709 is
used.

Available primaries are:
| auto: | automatic selection (default) |
| --- | --- |
| bt.601-525: | ITU-R BT.601 (SD) 525-line systems (NTSC, SMPTE-C) |
| bt.601-625: | ITU-R BT.601 (SD) 625-line systems (PAL, SECAM) |
| bt.709: | ITU-R BT.709 (HD) (same primaries as sRGB) |
| bt.2020: | ITU-R BT.2020 (UHD) |
| apple: | Apple RGB |
| adobe: | Adobe RGB (1998) |
| prophoto: | ProPhoto RGB (ROMM) |
| cie1931: | CIE 1931 RGB |
| dci-p3: | DCI-P3 (Digital Cinema) |
| v-gamut: | Panasonic V-Gamut primaries |

`<transfer>` or `<gamma>`

Transfer function the source file was encoded with. Normally this should be set
in the file header, but when playing broken or mistagged files this can be
used to override the setting.

This option only affects video output drivers that perform color management.

If this option is set to `auto` (which is the default), the gamma will
be set to BT.1886 for YCbCr content, sRGB for RGB content and st428 for
XYZ content.

Available gamma functions are:
| auto: | automatic selection (default) |
| --- | --- |
| bt.1886: | ITU-R BT.1886 (EOTF corresponding to BT.601/BT.709/BT.2020) |
| srgb: | IEC 61966-2-4 (sRGB) |
| linear: | Linear light |
| gamma1.8: | Pure power curve (gamma 1.8) |
| gamma2.0: | Pure power curve (gamma 2.0) |
| gamma2.2: | Pure power curve (gamma 2.2) |
| gamma2.4: | Pure power curve (gamma 2.4) |
| gamma2.6: | Pure power curve (gamma 2.6) |
| gamma2.8: | Pure power curve (gamma 2.8) |
| prophoto: | ProPhoto RGB (ROMM) curve |
| pq: | ITU-R BT.2100 PQ (Perceptual quantizer) curve |
| hlg: | ITU-R BT.2100 HLG (Hybrid Log-gamma) curve |
| v-log: | Panasonic V-Log transfer curve |
| s-log1: | Sony S-Log1 transfer curve |
| s-log2: | Sony S-Log2 transfer curve |
| st428: | Digital Cinema Distribution Master (XYZ) |

`<sig-peak>`

Reference peak illumination for the video file, relative to the
signal's reference white level. This is mostly interesting for HDR, but
it can also be used tone map SDR content to simulate a different
exposure. Normally inferred from tags such as MaxCLL or mastering
metadata.

The default of 0.0 will default to the source's nominal peak luminance.

`<light>`

> Light type of the scene. This is mostly correctly inferred based on the
> gamma function, but it can be useful to override this when viewing raw
> camera footage (e.g. V-Log), which is normally scene-referred instead
> of display-referred.
>
>
> Available light types are:

| auto: | Automatic selection (default) |
| --- | --- |
| display: | Display-referred light (most content) |
| hlg: | Scene-referred using the HLG OOTF (e.g. HLG content) |
| 709-1886: | Scene-referred using the BT709+BT1886 interaction |
| gamma1.2: | Scene-referred using a pure power OOTF (gamma=1.2) |

`<dolbyvision=yes|no>`

Whether or not to include Dolby Vision metadata (default: yes). If
disabled, any Dolby Vision metadata will be stripped from frames.

`<hdr10plus=yes|no>`

Whether or not to include HDR10+ metadata (default: yes). If
disabled, any HDR10+ metadata will be stripped from frames.

`<min-luma>`

Set the minimum luminance value for the mastering display metadata.
This is a float value in nits (cd/m²).

Note

0.0 means undefined, which is the default. To set 0.0 as actual value,
use a very small value like 1e-6.

`<max-luma>`

Set the maximum luminance value for the mastering display metadata.
This is a float value in nits (cd/m²).

`<max_cll>`

Set the maximum content light level for the mastering display
metadata. This is a float value in nits (cd/m²).

`<max_fall>`

Set the maximum frame-average light level for the mastering
display metadata. This is a float value in nits (cd/m²).

`<film-grain=yes|no>`

Whether or not to include film grain metadata (default: yes). If
disabled, any film grain metadata will be stripped from frames.

`<chroma-location>`

Set the chroma loc of the video. Use
`--vf=format:chroma-location=help` to list all available modes.

