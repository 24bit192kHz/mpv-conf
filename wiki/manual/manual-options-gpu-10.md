hint, while the negotiated swapchain format is used for rendering output.
This ensures correct results, since downstream processing depends on the
signaled colorspace. When disabled, the swapchain colorspace will be
overridden to match the `--target-*` options. (Only for `--vo=gpu-next`)

`--target-prim=<value>`

Specifies the primaries of the display. Video colors will be adapted to
this colorspace when ICC color management is not being used. Valid values
are:

auto

Disable any adaptation, except for atypical color spaces. Specifically,
wide/unusual gamuts get automatically adapted to BT.709, while standard
gamut (i.e. BT.601 and BT.709) content is not touched. (default)

bt.470m

ITU-R BT.470 M

bt.601-525

ITU-R BT.601 (525-line SD systems, eg. NTSC), SMPTE 170M/240M

bt.601-625

ITU-R BT.601 (625-line SD systems, eg. PAL/SECAM), ITU-R BT.470 B/G

bt.709

ITU-R BT.709 (HD), IEC 61966-2-4 (sRGB), SMPTE RP177 Annex B

bt.2020

ITU-R BT.2020 (UHD)

apple

Apple RGB

adobe

Adobe RGB (1998)

prophoto

ProPhoto RGB (ROMM)

cie1931

CIE 1931 RGB (not to be confused with CIE XYZ)

dci-p3

DCI-P3 (Digital Cinema Colorspace), SMPTE RP431-2

display-p3

DCI-P3 with a D65 white point

v-gamut

Panasonic V-Gamut (VARICAM) primaries

s-gamut

Sony S-Gamut (S-Log) primaries

`--target-trc=<value>`

Specifies the transfer characteristics (gamma) of the display. Video colors
will be adjusted to this curve when ICC color management is not being used.
Valid values are:

auto

Disable any adaptation, except for atypical transfers. Specifically,
HDR or linear light source material gets automatically converted to
gamma 2.2, while SDR content is not touched. (default)

bt.1886

ITU-R BT.1886 curve (assuming infinite contrast)

srgb

IEC 61966-2-4 (sRGB)

linear

Linear light output

gamma1.8

Pure power curve (gamma 1.8), also used for Apple RGB

gamma2.0

Pure power curve (gamma 2.0)

gamma2.2

Pure power curve (gamma 2.2)

gamma2.4

Pure power curve (gamma 2.4)

gamma2.6

Pure power curve (gamma 2.6)

gamma2.8

Pure power curve (gamma 2.8), also used for BT.470-BG

prophoto

ProPhoto RGB (ROMM)

pq

ITU-R BT.2100 PQ (Perceptual quantizer) curve, aka SMPTE ST2084

hlg

ITU-R BT.2100 HLG (Hybrid Log-gamma) curve, aka ARIB STD-B67

v-log

Panasonic V-Log (VARICAM) curve

s-log1

Sony S-Log1 curve

s-log2

Sony S-Log2 curve

Note

When using HDR output formats, mpv will encode to the specified
curve but it will not set any HDMI flags or other signalling that might
be required for the target device to correctly display the HDR signal.
The user should independently guarantee this before using these signal
formats for display.

`--target-peak=<auto|nits>`

Specifies the measured peak brightness of the output display, in cd/m^2
(AKA nits). The interpretation of this brightness depends on the configured
`--target-trc`. In all cases, it imposes a limit on the signal values
that will be sent to the display. If the source exceeds this brightness
level, a tone mapping filter will be inserted. For HLG, it has the
additional effect of parametrizing the inverse OOTF, in order to get
colorimetrically consistent results with the mastering display. For SDR, or
when using an ICC (profile (`--icc-profile`), setting this to a value
above 203 essentially causes the display to be treated as if it were an HDR
display in disguise. (See the note below)

In `auto` mode (the default), the chosen peak is an appropriate value
based on the TRC in use. For SDR curves, it uses 203. For HDR curves, it
uses 203 * the transfer function's nominal peak. If available, it will use
the target display's peak brightness as reported by the display.

Note

When using an SDR transfer function, this is normally not needed, and
setting it may lead to very unexpected results. The one time it *is*
useful is if you want to calibrate a HDR display using traditional
transfer functions and calibration equipment. In such cases, you can
set your HDR display to a high brightness such as 800 cd/m^2, and then
calibrate it to a standard curve like gamma2.8. Setting this value to
800 would then instruct mpv to essentially treat it as an HDR display
with the given peak. This may be a good alternative in environments
where PQ or HLG input to the display is not possible, and makes it
possible to use HDR displays with mpv regardless of operating system
support for HDMI HDR metadata.

In such a configuration, we highly recommend setting `--tone-mapping`
to `mobius` or even `clip`.

`--target-contrast=<auto|10-1000000|inf>`

Specifies the measured contrast of the output display. `--target-contrast`
in conjunction with `--target-peak` value is used to calculate display
black point. Used in black point compensation during HDR tone-mapping.
`auto` is the default and assumes 1000:1 contrast as a typical SDR display
would have or an infinite contrast when HDR `--target-trc` is used.
If supported by the API, display contrast will be used as reported.
`inf` contrast specifies display with perfect black level, in practice OLED.
(Only for `--vo=gpu-next`)

