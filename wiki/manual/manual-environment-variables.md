# ENVIRONMENT VARIABLES

There are a number of environment variables that can be used to control the
behavior of mpv.

`HOME`, `XDG_CONFIG_HOME`

Used to determine mpv config directory. If `XDG_CONFIG_HOME` is not set,
`$HOME/.config/mpv` is used.

`$HOME/.mpv` is always added to the list of config search paths with a
lower priority.

`MPV_HOME`

Directory where mpv looks for user settings. Overrides `HOME`, and mpv
will try to load the config file as `$MPV_HOME/mpv.conf`.

`MPV_VERBOSE` (see also `-v` and `--msg-level`)

Set the initial verbosity level across all message modules (default: 0).
This is an integer, and the resulting verbosity corresponds to the number
of `--v` options passed to the command line.

`MPV_LEAK_REPORT`

If set to `1`, enable internal talloc leak reporting. If set to another
value, disable leak reporting.

`LADSPA_PATH`

Specifies the search path for LADSPA plugins. If it is unset, fully
qualified path names must be used.

`DISPLAY`

Standard X11 display name to use.

FFmpeg:

This library accesses various environment variables. However, they are not
centrally documented, and documenting them is not our job. Therefore, this
list is incomplete.

Notable environment variables:

`http_proxy`

URL to proxy for `http://` and `https://` URLs.

`no_proxy`

List of domain patterns for which no proxy should be used.
List entries are separated by `,`. Patterns can include `*`.

libdvdcss:

`DVDCSS_CACHE`

Specify a directory in which to store title key values. This will
speed up descrambling of DVDs which are in the cache. The
`DVDCSS_CACHE` directory is created if it does not exist, and a
subdirectory is created named after the DVD's title or manufacturing
date. If `DVDCSS_CACHE` is not set or is empty, libdvdcss will use
the default value which is `${HOME}/.dvdcss/` under Unix and
the roaming application data directory (`%APPDATA%`) under
Windows. The special value "off" disables caching.

`DVDCSS_METHOD`

Sets the authentication and decryption method that libdvdcss will use
to read scrambled discs. Can be one of `title`, `key` or `disc`.

key

is the default method. libdvdcss will use a set of calculated
player keys to try to get the disc key. This can fail if the drive
does not recognize any of the player keys.

disc

is a fallback method when key has failed. Instead of using player
keys, libdvdcss will crack the disc key using a brute force
algorithm. This process is CPU intensive and requires 64 MB of
memory to store temporary data.

title

is the fallback when all other methods have failed. It does not
rely on a key exchange with the DVD drive, but rather uses a crypto
attack to guess the title key. On rare cases this may fail because
there is not enough encrypted data on the disc to perform a
statistical attack, but on the other hand it is the only way to
decrypt a DVD stored on a hard disc, or a DVD with the wrong region
on an RPC2 drive.

`DVDCSS_RAW_DEVICE`

Specify the raw device to use. Exact usage will depend on your
operating system, the Linux utility to set up raw devices is raw(8)
for instance. Please note that on most operating systems, using a raw
device requires highly aligned buffers: Linux requires a 2048 bytes
alignment (which is the size of a DVD sector).

`DVDCSS_VERBOSE`

Sets the libdvdcss verbosity level.
| 0: | Outputs no messages at all. |
| --- | --- |
| 1: | Outputs error messages to stderr. |
| 2: | Outputs error messages and debug messages to stderr. |

`DVDREAD_NOKEYS`

Skip retrieving all keys on startup. Currently disabled.

`HOME`

FIXME: Document this.
