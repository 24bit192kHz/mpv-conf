## input.conf

The input.conf file consists of a list of key bindings, for example:

```
s screenshot      # take a screenshot with the s key
LEFT seek 15      # map the left-arrow key to seeking forward by 15 seconds
```

Each line maps a key to an input command. Keys are specified with their literal
value (upper case if combined with `Shift`), or a name for special keys. For
example, `a` maps to the `a` key without shift, and `A` maps to `a`
with shift.

The file is located in the mpv configuration directory (normally at
`~/.config/mpv/input.conf` depending on platform). The default bindings are
defined here:

```
https://github.com/mpv-player/mpv/blob/master/etc/input.conf
```

A list of special keys can be obtained with

> `mpv --input-keylist`

In general, keys can be combined with `Shift`, `Ctrl` and `Alt`:

```
ctrl+q quit
```

**mpv** can be started in input test mode, which displays key bindings and the
commands they're bound to on the OSD, instead of executing the commands:

```
mpv --input-test --force-window --idle
```

(Only closing the window will make **mpv** exit, pressing normal keys will
merely display the binding, even if mapped to quit.)

Also see [Key names](manual-key-names.md).

## input.conf syntax

`[Shift+][Ctrl+][Alt+][Meta+]<key> [{<section>}] <command> ( ; <command> )*`

Note that by default, the right Alt key can be used to create special
characters, and thus does not register as a modifier. This can be changed
with `--input-right-alt-gr` option.

Newlines always start a new binding. `#` starts a comment (outside of quoted
string arguments). To bind commands to the `#` key, `SHARP` can be used.

`<key>` is either the literal character the key produces (ASCII or Unicode
character), or a symbolic name (as printed by `--input-keylist`).

`<section>` (braced with `{` and `}`) is the input section for this
command.

`<command>` is the command itself. It consists of the command name and
multiple (or none) arguments, all separated by whitespace. String arguments
should be quoted, typically with `"`. See `Flat command syntax`.

You can bind multiple commands to one key. For example:

```
a show-text "command 1" ; show-text "command 2"
```

It's also possible to bind a command to a sequence of keys:

```
a-b-c show-text "command run after a, b, c have been pressed"
```

(This is not shown in the general command syntax.)
