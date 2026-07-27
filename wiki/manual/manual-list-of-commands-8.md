### Scripting Commands

`script-message [<arg1> [<arg2> [...]]]`

Send a message to all clients, and pass it the following list of arguments.
What this message means, how many arguments it takes, and what the arguments
mean is fully up to the receiver and the sender. Every client receives the
message, so be careful about name clashes (or use `script-message-to`).

This command has a variable number of arguments, and cannot be used with
named arguments.

`script-message-to <target> [<arg1> [<arg2> [...]]]`

Same as `script-message`, but send it only to the client named
`<target>`. Each client (scripts etc.) has a unique name. For example,
Lua scripts can get their name via `mp.get_script_name()`. Note that
client names only consist of alphanumeric characters and `_`.

This command has a variable number of arguments, and cannot be used with
named arguments.

`script-binding <name> [<arg>]`

Invoke a script-provided key binding. This can be used to remap key
bindings provided by external Lua scripts.

`<name>` is the name of the binding. `<arg>` is a user-provided
arbitrary string which can be used to provide extra information.

It can optionally be prefixed with the name of the script, using `/` as
separator, e.g. `script-binding scriptname/bindingname`. Note that script
names only consist of alphanumeric characters and `_`.

For completeness, here is how this command works internally. The details
could change any time. On any matching key event, `script-message-to`
or `script-message` is called (depending on whether the script name is
included), with the following arguments in string format:

- The string `key-binding`.

- The name of the binding (as established above).

- The key state as string (see below).

- The key name (since mpv 0.15.0).

- The text the key would produce, or empty string if not applicable.

- The scale of the key, such as the ones produced by `WHEEL_*` keys.
The scale is 1 if the key is nonscalable.

- The user-provided string `<arg>`, or empty string if the argument is
not used.

The 5th argument is only set if no modifiers are present (using the shift
key with a letter is normally not emitted as having a modifier, and results
in upper case text instead, but some backends may mess up).

The key state consists of 3 characters:

- One of `d` (key was pressed down), `u` (was released), `r` (key
is still down, and was repeated; only if key repeat is enabled for this
binding), `p` (key was pressed; happens if up/down can't be tracked).

- Whether the event originates from the mouse, either `m` (mouse button)
or `-` (something else).

- Whether the event results from a cancellation (e.g. the key is logically
released but not physically released), either `c` (canceled) or `-`
(something else). Not all types of cancellations set this flag.

Future versions can add more arguments and more key state characters to
support more input peculiarities.

This is a scalable command. See the documentation of `nonscalable` input
command prefix in [Input Command Prefixes](manual-input-commands-1.md) for details.

`load-script <filename>`

Load a script, similar to the `--script` option. Whether this waits for
the script to finish initialization or not changed multiple times, and the
future behavior is left undefined.

On success, returns a `mpv_node` with a `client_id` field set to the
return value of the `mpv_client_id()` API call of the newly created script
handle.

### Screenshot Commands

`screenshot [<flags>]`

Take a screenshot.

Multiple flags are available (some can be combined with `+`):

<video>

Save the video image in its original resolution, without OSD or
subtitles. This is the default when no flag is specified, and it does
not need to be explicitly added when combined with other flags.

<scaled>

Save the video image in the current playback resolution.

<subtitles> (default)

Save the video image with subtitles.
Some video outputs may still include the OSD in the output under certain
circumstances.

<osd>

Save the video image with OSD.

<window>

Save the contents of the mpv window, with OSD and subtitles.
This is an alias of `scaled+subtitles+osd`.

<each-frame>

Take a screenshot each frame. Issue this command again to stop taking
screenshots. Note that you should disable frame-dropping when using
this mode - or you might receive duplicate images in cases when a
frame was dropped. This flag can be combined with the other flags,
e.g. `video+each-frame`.

The exact behaviors of all flags other than `each-frame` depend on the
selected video output.

Older mpv versions required passing `single` and `each-frame` as
second argument (and did not have flags). This syntax is still understood,
but deprecated and might be removed in the future.

If you combine this command with another one using `;`, you can use the
`async` flag to make encoding/writing the image file asynchronous. For
normal standalone commands, this is always asynchronous, and the flag has
no effect. (This behavior changed with mpv 0.29.0.)

On success, returns a `mpv_node` with a `filename` field set to the
saved screenshot location.

`screenshot-to-file <filename> [<flags>]`

Take a screenshot and save it to a given file. The format of the file will
be guessed by the extension (and `--screenshot-format` is ignored - the
behavior when the extension is missing or unknown is arbitrary).

The second argument is like the first argument to `screenshot` and
supports `subtitles`, `video`, `window`.

If the file already exists, it's overwritten.

Like all input command parameters, the filename is subject to property
expansion as described in [Property Expansion](manual-property-list-1.md).

`screenshot-raw [<flags> [<format>]]`

Return a screenshot in memory. This can be used only through the client API
or from a script using `mp.command_native`. The MPV_FORMAT_NODE_MAP
returned by this command has the `w`, `h`, `stride` fields set to
obvious contents.

The `format` field is set to the format of the screenshot image data.
This can be controlled by the `format` argument. The format can be one of
the following:

bgr0 (default)

This format is organized as `B8G8R8X8` (where `B` is the LSB).
The contents of the padding `X` are undefined.

bgra

This format is organized as `B8G8R8A8` (where `B` is the LSB).

rgba

This format is organized as `R8G8B8A8` (where `R` is the LSB).

rgba64

This format is organized as `R16G16B16A16` (where `R` is the LSB).
Each component occupies 2 bytes per pixel.
When this format is used, the image data will be high bit depth, and
`--screenshot-high-bit-depth` is ignored.

The `data` field is of type MPV_FORMAT_BYTE_ARRAY with the actual image
data. The image is freed as soon as the result mpv_node is freed. As usual
with client API semantics, you are not allowed to write to the image data.

The `stride` is the number of bytes from a pixel at `(x0, y0)` to the
pixel at `(x0, y0 + 1)`. This can be larger than `w * bpp` if the image
