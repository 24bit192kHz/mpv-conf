## mp.options functions

mpv comes with a built-in module to manage options from config-files and the
command-line. All you have to do is to supply a table with default options to
the read_options function. The function will overwrite the default values
with values found in the config-file and the command-line (in that order).

`options.read_options(table [, identifier [, on_update]])`

A `table` with key-value pairs. The type of the default values is
important for converting the values read from the config file or
command-line back. Do not use `nil` as a default value!

The `identifier` is used to identify the config-file and the command-line
options. These needs to unique to avoid collisions with other scripts.
Defaults to `mp.get_script_name()` if the parameter is `nil` or missing.

The `on_update` parameter enables run-time updates of all matching option
values via the `script-opts` option/property. If any of the matching
options changes, the values in the `table` (which was originally passed to
the function) are changed, and `on_update(list)` is called. `list` is
a table where each updated option has a `list[option_name] = true` entry.
There is no initial `on_update()` call. This never re-reads the config file.
`script-opts` is always applied on the original config file, ignoring
previous `script-opts` values (for example, if an option is removed from
`script-opts` at runtime, the option will have the value in the config
file). `table` entries are only written for option values whose values
effectively change (this is important if the script changes `table`
entries independently).

Example implementation:

```
local options = {
    optionA = "defaultvalueA",
    optionB = -0.5,
    optionC = true,
}

require "mp.options".read_options(options, "myscript")
print(options.optionA)
```

The config file will be stored in `script-opts/identifier.conf` in mpv's user
folder. Comment lines can be started with # and stray spaces are not removed.
Boolean values will be represented with yes/no.

Example config:

```
# comment
optionA=Hello World
optionB=9999
optionC=no
```

Command-line options are read from the `--script-opts` parameter. To avoid
collisions, all keys have to be prefixed with `identifier-`.

Example command-line:

```
--script-opts=myscript-optionA=TEST,myscript-optionB=0,myscript-optionC=yes
```

## mp.utils functions

This built-in module provides generic helper functions for Lua, and have
strictly speaking nothing to do with mpv or video/audio playback. They are
provided for convenience. Most compensate for Lua's scarce standard library.

Be warned that any of these functions might disappear any time. They are not
strictly part of the guaranteed API.

`utils.getcwd()`

Returns the directory that mpv was launched from. On error, `nil, error`
is returned.

`utils.readdir(path [, filter])`

Enumerate all entries at the given path on the filesystem, and return them
as array. Each entry is a directory entry (without the path).
The list is unsorted (in whatever order the operating system returns it).

If the `filter` argument is given, it must be one of the following
strings:

> `files`
>
>
> List regular files only. This excludes directories, special files
> (like UNIX device files or FIFOs), and dead symlinks. It includes
> UNIX symlinks to regular files.
>
>
> `dirs`
>
>
> List directories only, or symlinks to directories. `.` and `..`
> are not included.
>
>
> `normal`
>
>
> Include the results of both `files` and `dirs`. (This is the
> default.)
>
>
> `all`
>
>
> List all entries, even device files, dead symlinks, FIFOs, and the
> `.` and `..` entries.

On error, `nil, error` is returned.

`utils.file_info(path)`

Stats the given path for information and returns a table with the
following entries:

> `mode`
>
>
> protection bits (on Windows, always 755 (octal) for directories
> and 644 (octal) for files)
>
>
> `size`
>
>
> size in bytes
>
>
> `atime`
>
>
> time of last access
>
>
> `mtime`
>
>
> time of last modification
>
>
> `ctime`
>
>
> time of last metadata change
>
>
> `is_file`
>
>
> Whether `path` is a regular file (boolean)
>
>
> `is_dir`
>
>
> Whether `path` is a directory (boolean)

`mode` and `size` are integers.
Timestamps (`atime`, `mtime` and `ctime`) are integer seconds since
the Unix epoch (Unix time).
The booleans `is_file` and `is_dir` are provided as a convenience;
they can be and are derived from `mode`.

On error (e.g. path does not exist), `nil, error` is returned.

`utils.split_path(path)`

Split a path into directory component and filename component, and return
them. The first return value is always the directory. The second return
value is the trailing part of the path, the directory entry.

`utils.join_path(p1, p2)`

Return the concatenation of the 2 paths. Tries to be clever. For example,
if `p2` is an absolute path, `p2` is returned without change.

`utils.subprocess(t)`

Runs an external process and waits until it exits. Returns process status
and the captured output. This is a legacy wrapper around calling the
`subprocess` command with `mp.command_native`. It does the following
things:

- copy the table `t`

- rename `cancellable` field to `playback_only`

