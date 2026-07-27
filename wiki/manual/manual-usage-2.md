## Per-File Options

When playing multiple files, any option given on the command line usually
affects all files. Example:

```
mpv --a file1.mkv --b file2.mkv --c
```

| File | Active options |
| --- | --- |
| file1.mkv | `--a --b --c` |
| file2.mkv | `--a --b --c` |

(This is different from MPlayer and mplayer2.)

Also, if any option is changed at runtime (via input commands), they are not
reset when a new file is played.

Sometimes, it is useful to change options per-file. This can be achieved by
adding the special per-file markers `--{` and `--}`. (Note that you must
escape these on some shells.) Example:

```
mpv --a file1.mkv --b --\{ --c file2.mkv --d file3.mkv --e --\} file4.mkv --f
```

| File | Active options |
| --- | --- |
| file1.mkv | `--a --b --f` |
| file2.mkv | `--a --b --f --c --d --e` |
| file3.mkv | `--a --b --f --c --d --e` |
| file4.mkv | `--a --b --f` |

Additionally, any file-local option changed at runtime is reset when the current
file stops playing. If option `--c` is changed during playback of
`file2.mkv`, it is reset when advancing to `file3.mkv`. This only affects
file-local options. The option `--a` is never reset here.

## List Options

Some options which store lists of option values can have action suffixes. For
example, the `--display-tags` option takes a `,`-separated list of tags, but
the option also allows you to append a single tag with `--display-tags-append`,
and the tag name can for example contain a literal `,` without the need for
escaping.

### String list and path list options

String lists are separated by `,`. The strings are not parsed or interpreted
by the option system itself. However, most path or file list options use `:`
(Unix) or `;` (Windows) as separator, instead of `,`.

They support the following operations:
| Suffix | Meaning |
| --- | --- |
| -set | Set a list of items (using the list separator, escaped with backslash) |
| -append | Append single item (does not interpret escapes) |
| -add | Append 1 or more items (same syntax as -set) |
| -pre | Prepend 1 or more items (same syntax as -set) |
| -clr | Clear the option (remove all items) |
| -del | Delete 1 or more items if present (same syntax as -set) |
| -remove | Delete item if present (does not interpret escapes) |
| -toggle | Append an item, or remove it if it already exists (no escapes) |

`-append` is meant as a simple way to append a single item without having
to escape the argument (you may still need to escape on the shell level).

### Key/value list options

A key/value list is a list of key/value string pairs. In programming languages,
this type of data structure is often called a map or a dictionary. The order
normally does not matter, although in some cases the order might matter.

They support the following operations:
| Suffix | Meaning |
| --- | --- |
| -set | Set a list of items (using `,` as separator) |
| -append | Append a single item (escapes for the key, no escapes for the value) |
| -add | Append 1 or more items (same syntax as -set) |
| -clr | Clear the option (remove all items) |
| -del | Delete 1 or more keys if present (same syntax as -set) |
| -remove | Delete item by key if present (does not interpret escapes) |

Keys are unique within the list. If an already present key is set, the existing
key is removed before the new value is appended.

If you want to pass a value without interpreting it for escapes or `,`, it is
recommended to use the `-append` variant. When using libmpv, prefer using
`MPV_FORMAT_NODE_MAP`; when using a scripting backend or the JSON IPC, use an
appropriate structured data type.

Prior to mpv 0.33, `:` was also recognized as separator by `-set`.

### Object settings list options

This is a very complex option type for some options, such as `--af` and `--vf`.
They often require complicated escaping. See [VIDEO FILTERS](manual-video-filters-1.md) for details.

They support the following operations:
| Suffix | Meaning |
| --- | --- |
| -set | Set a list of items (using `,` as separator) |
| -append | Append single item |
| -add | Append 1 or more items (same syntax as -set) |
| -pre | Prepend 1 or more items (same syntax as -set) |
| -clr | Clear the option (remove all items) |
| -remove | Delete 1 or items if present (same syntax as -set) |
| -toggle | Append an item, or remove it if it already exists |
| -help | Pseudo operation that prints a help text to the terminal |

### General

Without suffix, the operation used is normally `-set`.

Some operations like `-add` and `-pre` specify multiple items, but be
aware that you may need to escape the arguments. `-append` accepts a single,
unescaped item only (so the `,` separator will not be interpreted and
is passed on as part of the value).

Some options (like `--sub-file`, `--audio-file`, `--glsl-shader`) are
aliases for the proper option with `-append` action. For example,
`--sub-file` is an alias for `--sub-files-append`.

Options of this type can be changed at runtime using the `change-list`
command, which takes the suffix (without the `-`) as separate operation
parameter.

An object settings list can hold up to 100 elements.
