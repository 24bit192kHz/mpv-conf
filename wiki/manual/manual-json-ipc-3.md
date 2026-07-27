## JSON extensions

The following non-standard extensions are supported:

> - a list or object item can have a trailing ","
>
> - object syntax accepts "=" in addition of ":"
>
> - object keys can be unquoted, if they start with a character in "A-Za-z_"
> and contain only characters in "A-Za-z0-9_"
>
> - byte escapes with "xAB" are allowed (with AB being a 2 digit hex number)

Example:

```
{ objkey = "value\x0A" }
```

Is equivalent to:

```
{ "objkey": "value\n" }
```

## Alternative ways of starting clients

You can create an anonymous IPC connection without having to set
`--input-ipc-server`. This is achieved through a mpv pseudo scripting backend
that starts processes.

You can put `.run` file extension in the mpv scripts directory in its  config
directory (see the [FILES](manual-files.md) section for details), or load them through other
means (see [Script location](manual-lua-scripting-1.md)). These scripts are simply executed with the OS
native mechanism (as if you ran them in the shell). They must have a proper
shebang and have the executable bit set.

When executed, a socket (the IPC connection) is passed to them through file
descriptor inheritance. The file descriptor is indicated as the special command
line argument `--mpv-ipc-fd=N`, where `N` is the numeric file descriptor.

The rest is the same as with a normal `--input-ipc-server` IPC connection. mpv
does not attempt to observe or other interact with the started script process.

This does not work in Windows yet.
