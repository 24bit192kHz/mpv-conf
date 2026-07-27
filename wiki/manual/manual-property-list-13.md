this binding.

`section`

Name of the section this binding is part of. This is a rarely used
mechanism. This entry may be removed or change meaning in the future.

`priority`

A number. Bindings with a higher value are preferred over bindings
with a lower value. If the value is negative, this binding is inactive
and will not be triggered by input. Note that mpv does not use this
value internally, and matching of bindings may work slightly differently
in some cases. In addition, this value is dynamic and can change around
at runtime.

`comment`

If available, the comment following the command on the same line. (For
example, the input.conf entry `f cycle bla # toggle bla` would
result in an entry with `comment = "toggle bla", cmd = "cycle bla"`.)

This property is read-only, and change notification is not supported.

`clipboard`

The clipboard contents. Only works when native clipboard is supported on the
platform.
Depending on the platform, some sub-properties, writing to properties,
or change notifications are not currently functional.

This has a number of sub-properties:

`clipboard/text` (RW)

The text content in the clipboard.
Writing to this property sets the text clipboard content

`clipboard/text-primary` (RW)

The text content in the primary selection (X11 and Wayland only).

Note

On Wayland with the `vo` clipboard backend, the clipboard content is
only updated when the compositor sends a selection data offer
(typically when VO window is focused). The `wayland` backend typically
does not have this limitation.
See `current-clipboard-backend` property for more details.

`current-clipboard-backend`

A string containing the currently active clipboard backend.
See `--clipboard-backends` option for the list of available backends.

`clock`

The current local time in hour:minutes format.

## Inconsistencies between options and properties

You can access (almost) all options as properties, though there are some
caveats with some properties (due to historical reasons):

`vid`, `aid`, `sid`

While playback is active, these return the actually active tracks. For
example, if you set `aid=5`, and the currently played file contains no
audio track with ID 5, the `aid` property will return `no`.

Before mpv 0.31.0, you could set existing tracks at runtime only.

`display-fps`

This inconsistent behavior is deprecated. Post-deprecation, the reported
value and the option value are cleanly separated (`override-display-fps`
for the option value).

`vf`, `af`

If you set the properties during playback, and the filter chain fails to
reinitialize, the option will be set, but the runtime filter chain does not
change. On the other hand, the next video to be played will fail, because
the initial filter chain cannot be created.

This behavior changed in mpv 0.31.0. Before this, the new value was rejected
*iff* a video (for `vf`) or an audio (for `af`) track was active. If
playback was not active, the behavior was the same as the current one.

`playlist`

The property is read-only and returns the current internal playlist. The
option is for loading playlist during command line parsing. For client API
uses, you should use the `loadlist` command instead.

`profile`, `include`

These are write-only, and will perform actions as they are written to,
exactly as if they were used on the mpv CLI commandline. Their only use is
when using libmpv before `mpv_initialize()`, which in turn is probably
only useful in encoding mode. Normal libmpv users should use other
mechanisms, such as the `apply-profile` command, and the
`mpv_load_config_file` API function. Avoid these properties.

## Property Expansion

All string arguments to input commands as well as certain options (like
`--term-playing-msg`) are subject to property expansion. Note that property
expansion does not work in places where e.g. numeric parameters are expected.
(For example, the `add` command does not do property expansion. The `set`
command is an exception and not a general rule.)

Example for input.conf

`i show-text "Filename: ${filename}"`

shows the filename of the current file when pressing the `i` key

Whether property expansion is enabled by default depends on which API is used
(see [Flat command syntax](manual-input-commands-1.md), [Commands specified as arrays](manual-input-commands-1.md) and [Named
arguments](manual-input-commands-1.md)), but it can always be enabled with the `expand-properties`
prefix or disabled with the `raw` prefix, as described in [Input Command
Prefixes](manual-input-commands-1.md).

The following expansions are supported:

`${NAME}`

Expands to the value of the property `NAME`. If retrieving the property
fails, expand to an error string. (Use `${NAME:}` with a trailing
`:` to expand to an empty string instead.)
If `NAME` is prefixed with `=`, expand to the raw value of the property
(see section below).

`${NAME:STR}`

Expands to the value of the property `NAME`, or `STR` if the
property cannot be retrieved. `STR` is expanded recursively.

`${?NAME:STR}`

Expands to `STR` (recursively) if the property `NAME` is available.

`${!NAME:STR}`

Expands to `STR` (recursively) if the property `NAME` cannot be
retrieved.

`${?NAME==VALUE:STR}`

Expands to `STR` (recursively) if the property `NAME` expands to a
string equal to `VALUE`. You can prefix `NAME` with `=` in order to
compare the raw value of a property (see section below). If the property
is unavailable, or other errors happen when retrieving it, the value is
never considered equal.
Note that `VALUE` can't contain any of the characters `:` or `}`.
Also, it is possible that escaping with `"` or `%` might be added in
the future, should the need arise.

`${!NAME==VALUE:STR}`

Same as with the `?` variant, but `STR` is expanded if the value is
not equal. (Using the same semantics as with `?`.)

`$$`

Expands to `$`.

`$}`

Expands to `}`. (To produce this character inside recursive
expansion.)

`$>`

Disable property expansion and special handling of `$` for the rest
of the string.

In places where property expansion is allowed, C-style escapes are often
accepted as well. Example:

> - `\n` becomes a newline character
>
> - `\\` expands to `\`

