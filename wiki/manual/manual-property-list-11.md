
The property can be watched with the property observation mechanism in
the client API and in Lua scripts. (Technically, change notification is
enabled the first time this property is read.)

`audio-device` (RW)

Set the audio device. This directly reads/writes the `--audio-device`
option, but on write accesses, the audio output will be scheduled for
reloading.

Writing this property while no audio output is active will not automatically
enable audio. (This is also true in the case when audio was disabled due to
reinitialization failure after a previous write access to `audio-device`.)

This property also doesn't tell you which audio device is actually in use.

How these details are handled may change in the future.

`current-vo`

Current video output driver (name as used with `--vo`).

`current-gpu-context`

Current GPU context of video output driver (name as used with `--gpu-context`).
Valid for `--vo=gpu` and `--vo=gpu-next`.

`current-ao`

Current audio output driver (name as used with `--ao`).

`user-data` (RW)

This is a recursive key/value map of arbitrary nodes shared between clients for
general use (i.e. scripts, IPC clients, host applications, etc).
The player itself does not use any data in it (although some builtin scripts may).
The property is not preserved across player restarts.

Sub-paths can be accessed directly; e.g. `user-data/my-script/state/a` can be
read, written, or observed.

The top-level object itself cannot be written directly; write to sub-paths instead.

Converting this property or its sub-properties to strings will give a JSON
representation. If converting a leaf-level object (i.e. not a map or array)
and not using raw mode, the underlying content will be given (e.g. strings will be
printed directly, rather than quoted and JSON-escaped).

The following sub-paths are reserved for internal uses or have special semantics:
`user-data/osc`, `user-data/mpv`. Unless noted otherwise, the semantics of
any properties under these sub-paths can change at any time and may not be relied
upon, and writing to these properties may prevent builtin scripts from working
properly.

Currently, the following properties have defined special semantics:

`user-data/osc/margins`

This property is written by an OSC implementation to indicate the margins that it
occupies. Its sub-properties `l`, `r`, `t`, and `b` should all be set to
the left, right, top, and bottom margins respectively.
Values are between 0.0 and 1.0, normalized to window width/height.

`user-data/mpv/ytdl`

Data shared by the builtin ytdl hook script.

`user-data/mpv/ytdl/path`

Path to the ytdl executable, if found, or an empty string otherwise.
The property is not set until the script attempts to find the ytdl
executable, i.e. until an URL is being loaded by the script.

`user-data/mpv/ytdl/json-subprocess-result`

Result of executing ytdl to retrieve the JSON data of the URL being
loaded. The format is the same as `subprocess`'s result, capturing
stdout and stderr.

`user-data/mpv/console/open`

Whether the console is open.

`menu-data` (RW)

This property stores the raw menu definition. See [Context Menu](manual-context-menu-script.md) section for details.

`type`

Menu item type. Can be: `separator`, `submenu`, or empty.

`title`

Menu item title. Required if type is not `separator`.

`cmd`

Command to execute when the menu item is clicked.

`shortcut`

Menu item shortcut key which appears to the right of the menu item.
A shortcut key does not have to be functional; it's just a visual hint.

`state`

Menu item state. Can be: `checked`, `disabled`, `hidden`, or empty.

`submenu`

Submenu items, which is required if type is `submenu`.

When querying the property with the client API using `MPV_FORMAT_NODE`, or with
Lua `mp.get_property_native`, this will return a mpv_node with the following
contents:

```
MPV_FORMAT_NODE_ARRAY
    MPV_FORMAT_NODE_MAP (menu item)
        "type"           MPV_FORMAT_STRING
        "title"          MPV_FORMAT_STRING
        "cmd"            MPV_FORMAT_STRING
        "shortcut"       MPV_FORMAT_STRING
        "state"          MPV_FORMAT_NODE_ARRAY[MPV_FORMAT_STRING]
        "submenu"        MPV_FORMAT_NODE_ARRAY[menu item]
```

Writing to this property with the client API using `MPV_FORMAT_NODE` or with
Lua `mp.set_property_native` will trigger an immediate update of the menu if
mpv video output is currently active. You may observe the `current-vo`
property to check if this is the case.

`working-directory`

The working directory of the mpv process. Can be useful for JSON IPC users,
because the command line player usually works with relative paths.

`current-watch-later-dir`

The directory in which watch later config files are stored. This returns
`--watch-later-dir`, or the default directory if `--watch-later-dir` has
not been modified, with tilde placeholders expanded.

`protocol-list`

List of protocol prefixes potentially recognized by the player. They are
returned without trailing `://` suffix (which is still always required).
In some cases, the protocol will not actually be supported (consider
`https` if ffmpeg is not compiled with TLS support).

`decoder-list`

List of decoders supported. This lists decoders which can be passed to
`--vd` and `--ad`.

`codec`

Canonical codec name, which identifies the format the decoder can
handle.

`driver`

The name of the decoder itself. Often, this is the same as `codec`.
Sometimes it can be different. It is used to distinguish multiple
decoders for the same codec.

`description`

Human readable description of the decoder and codec.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_ARRAY
    MPV_FORMAT_NODE_MAP (for each decoder entry)
        "codec"         MPV_FORMAT_STRING
        "driver"        MPV_FORMAT_STRING
        "description"   MPV_FORMAT_STRING
```

`encoder-list`

List of libavcodec encoders. This has the same format as `decoder-list`.
The encoder names (`driver` entries) can be passed to `--ovc` and
`--oac` (without the `lavc:` prefix required by `--vd` and `--ad`).

`demuxer-lavf-list`

List of available libavformat demuxers' names. This can be used to check
for support for a specific format or use with `--demuxer-lavf-format`.

`input-key-list`
