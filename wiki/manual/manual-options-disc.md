## Disc Devices

`--cdda-device=

`

Specify the CD device for CDDA playback. The default device path depends on
the OS. See the [OPTICAL DRIVES](manual-optical-drives.md) section.

`--dvd-device=

`

Specify the DVD device or .iso filename. You can
also specify a directory that contains files previously copied directly
from a DVD (with e.g. vobcopy). The default device path depends on
the OS. See the [OPTICAL DRIVES](manual-optical-drives.md) section.

Example

`mpv dvd:// --dvd-device=/path/to/dvd/`

`--bluray-device=

`

Specify the Blu-ray disc location. Must be a directory with Blu-ray
structure. The default device path depends on the OS. See the
[OPTICAL DRIVES](manual-optical-drives.md) section.

Example

`mpv bd:// --bluray-device=/path/to/bd/`

`--cdda-...`

These options can be used to tune the CD Audio reading feature of mpv.

`--cdda-speed=<value>`

Set CD spin speed.

`--cdda-paranoia=<0-2>`

Set paranoia level. Values other than 0 seem to break playback of
anything but the first track.
| 0: | disable checking (default) |
| --- | --- |
| 1: | overlap checking only |
| 2: | full data correction and verification |

`--cdda-sector-size=<value>`

Set atomic read size.

`--cdda-overlap=<value>`

Force minimum overlap search during verification to <value> sectors.

`--cdda-toc-offset=<value>`

Add `<value>` sectors to the values reported when addressing tracks.
May be negative.

`--cdda-skip=<yes|no>`

(Never) accept imperfect data reconstruction.

`--cdda-cdtext=<yes|no>`

Print CD text. This is disabled by default, because it ruins performance
with CD-ROM drives for unknown reasons.

`--dvd-speed=<speed>`

Try to limit DVD speed (default: 0, no change). DVD base speed is 1385
kB/s, so an 8x drive can read at speeds up to 11080 kB/s. Slower speeds
make the drive more quiet. For watching DVDs, 2700 kB/s should be quiet and
fast enough. mpv resets the speed to the drive default value on close.
Values of at least 100 mean speed in kB/s. Values less than 100 mean
multiples of 1385 kB/s, i.e. `--dvd-speed=8` selects 11080 kB/s.

Note

You need write access to the DVD device to change the speed.

`--dvd-angle=<ID>`

Some DVDs contain scenes that can be viewed from multiple angles.
This option tells mpv which angle to use (default: 1).

`--bluray-angle=<ID>`

Some Blu-ray discs contain scenes that can be viewed from multiple angles.
This option tells mpv which angle to use (default: 1).
