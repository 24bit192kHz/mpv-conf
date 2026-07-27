
List of [Key names](manual-key-names.md), same as output by `--input-keylist`.

`mpv-version`

The mpv version/copyright string. Depending on how the binary was built, it
might contain either a release version, or just a git hash.

`mpv-configuration`

The configuration arguments that were passed to the build system. If the
meson version used to compile mpv is older than 1.1.0, then a hardcoded
string of a few, arbitrary options is displayed instead.

`ffmpeg-version`

The contents of the `av_version_info()` API call. This is a string which
identifies the build in some way, either through a release version number,
or a git hash. This property is unavailable if mpv is linked against older
FFmpeg versions.

`libass-version`

The value of `ass_library_version()`. This is an integer, encoded in a
somewhat weird form (apparently "hex BCD"), indicating the release version
of the libass library linked to mpv.

`platform`

Returns a string describing what target platform mpv was built for. The value
of this is dependent on what the underlying build system detects. Some of the
most common values are: `windows`, `darwin` (macos or ios), `linux`,
`android`, and `freebsd`. Note that this is not a complete listing.

`options/<name>` (RW)

The value of option `--<name>`. Most options can be changed at runtime by
writing to this property. Note that many options require reloading the file
for changes to take effect. If there is an equivalent property, prefer
setting the property instead.

There shouldn't be any reason to access `options/<name>` instead of
`<name>`, except in situations in which the properties have different
behavior or conflicting semantics.

`file-local-options/<name>` (RW)

Similar to `options/<name>`, but when setting an option through this
property, the option is reset to its old value once the current file has
stopped playing. Trying to write an option while no file is playing (or
is being loaded) results in an error.

(Note that if an option is marked as file-local, even `options/` will
access the local value, and the `old` value, which will be restored on
end of playback, cannot be read or written until end of playback.)

`option-info/<name>`

Additional per-option information.

This has a number of sub-properties. Replace `<name>` with the name of
a top-level option. No guarantee of stability is given to any of these
sub-properties - they may change radically in the future.

`option-info/<name>/name`

The name of the option.

`option-info/<name>/type`

The name of the option type, like `String` or `Integer`. For many
complex types, this isn't very accurate.

`option-info/<name>/set-from-commandline`

Whether the option was set from the mpv command line. What this is set
to if the option is e.g. changed at runtime is left undefined (meaning
it could change in the future).

`option-info/<name>/set-locally`

Whether the option was set per-file. This is the case with
automatically loaded profiles, file-dir configs, and other cases. It
means the option value will be restored to the value before playback
start when playback ends.

`option-info/<name>/expects-file`

Whether the option takes file paths as arguments.

`option-info/<name>/default-value`

The default value of the option. May not always be available.

`option-info/<name>/min`, `option-info/<name>/max`

Integer minimum and maximum values allowed for the option. Only
available if the options are numeric, and the minimum/maximum has been
set internally. It's also possible that only one of these is set.

`option-info/<name>/choices`

If the option is a choice option, the possible choices. Choices that
are integers may or may not be included (they can be implied by `min`
and `max`). Note that options which behave like choice options, but
are not actual choice options internally, may not have this info
available.

`property-list`

The list of top-level properties.

`profile-list`

The list of profiles and their contents. This is highly
implementation-specific, and may change any time. Currently, it returns an
array of options for each profile. Each option has a name and a value, with
the value currently always being a string. Note that the options array is
not a map, as order matters and duplicate entries are possible. Recursive
profiles are not expanded, and show up as special `profile` options.

The `profile-restore` field is currently missing if it holds the default
value (either because it was not set, or set explicitly to `default`),
but in the future it might hold the value `default`.

`command-list`

The list of input commands. This returns an array of maps, where each map
node represents a command. This map has the following entries:

`name`

The name of the command.

`vararg`

Whether the command accepts a variable number of arguments.

`args`

An array of maps, where each map node represents an argument with the
following entries:

`name`

The name of the argument.

`type`

The name of the argument type, like `String` or `Integer`.

`optional`

Whether the argument is optional.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_ARRAY
    MPV_FORMAT_NODE_MAP (for each command entry)
        "name"    MPV_FORMAT_STRING
        "vararg"  MPV_FORMAT_FLAG
        "args"    MPV_FORMAT_NODE_ARRAY
            MPV_FORMAT_NODE_MAP
                "name"     MPV_FORMAT_STRING
                "type"     MPV_FORMAT_STRING
                "optional" MPV_FORMAT_FLAG
```

`input-bindings`

The list of current input key bindings. This returns an array of maps,
where each map node represents a binding for a single key/command. This map
has the following entries:

`key`

The key name. This is normalized and may look slightly different from
how it was specified in the source (e.g. in input.conf).

`cmd`

The command mapped to the key. (Currently, this is exactly the same
string as specified in the source, other than stripping whitespace and
comments. It's possible that it will be normalized in the future.)

`is_weak`

If set to true, any existing and active user bindings will take priority.

`owner`

If this entry exists, the name of the script (or similar) which added
