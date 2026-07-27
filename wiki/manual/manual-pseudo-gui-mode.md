# PSEUDO GUI MODE

mpv has no official GUI, other than the OSC ([ON SCREEN CONTROLLER](manual-on-screen-controller-1.md)), which
is not a full GUI and is not meant to be. However, to compensate for the lack
of expected GUI behavior, mpv will in some cases start with some settings
changed to behave slightly more like a GUI mode.

Currently this happens only in the following cases:

- if started using the `mpv.desktop` file on Linux (e.g. started from menus
or file associations provided by desktop environments)

- if started from explorer.exe on Windows (technically, if it was started on
Windows, and all of the stdout/stderr/stdin handles are unset)

- started out of the bundle on macOS

- if you manually use `--player-operation-mode=pseudo-gui` on the command line

This mode applies options from the builtin profile `builtin-pseudo-gui`, but
only if these haven't been set in the user's config file or on the command line,
which is the main difference to using `--profile=builtin-pseudo-gui`.

The profile is currently defined as follows:

```
[builtin-pseudo-gui]
terminal=no
force-window=yes
idle=once
screenshot-directory=~~desktop/
```

The `pseudo-gui` profile exists for compatibility. The options in the
`pseudo-gui` profile are applied unconditionally. In addition, the profile
makes sure to enable the pseudo-GUI mode, so that `--profile=pseudo-gui`
works like in older mpv releases:

```
[pseudo-gui]
player-operation-mode=pseudo-gui
```

Warning

Currently, you can extend the `pseudo-gui` profile in the config file the
normal way. This is deprecated. In future mpv releases, the behavior might
change, and not apply your additional settings, and/or use a different
profile name.
