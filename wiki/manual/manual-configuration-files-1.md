# CONFIGURATION FILES

## Location and Syntax

You can put all of the options in configuration files which will be read every
time mpv is run. The system-wide configuration file 'mpv.conf' is in your
configuration directory (e.g. `/etc/mpv` or `/usr/local/etc/mpv`), the
user-specific one is `~/.config/mpv/mpv.conf`. For details and platform
specifics (in particular Windows paths) see the [FILES](manual-files.md) section.

User-specific options override system-wide options and options given on the
command line override both. The syntax of the configuration files is
`option=value`. Everything after a *#* is considered a comment. Options that
work without values can be enabled by setting them to *yes* and disabled by
setting them to *no*, and if the value is omitted, *yes* is implied. Even
suboptions can be specified in this way.

Example configuration file

```
# Don't allow new windows to be larger than the screen.
autofit-larger=100%x100%
# Enable hardware decoding if available, =yes is implied.
hwdec
# Spaces don't have to be escaped.
osd-playing-msg=File: ${filename}
```

## Escaping special characters

This is done like with command line options. A config entry can be quoted with
`"`, `'`, as well as with the fixed-length syntax (`%n%`) mentioned
before. This is like passing the exact contents of the quoted string as a
command line option. C-style escapes are currently _not_ interpreted on this
level, although some options do this manually (this is a mess and should
probably be changed at some point). The shell is not involved here, so option
values only need to be quoted to escape `#` anywhere in the value, `"`,
`'` or `%` at the beginning of the value, and leading and trailing
whitespace.

## Putting Command Line Options into the Configuration File

Almost all command line options can be put into the configuration file. Here
is a small guide:
| Option | Configuration file entry |
| --- | --- |
| `--flag` | `flag` |
| `-opt val` | `opt=val` |
| `--opt=val` | `opt=val` |
| `-opt "has spaces"` | `opt=has spaces` |

## File-specific Configuration Files

You can also write file-specific configuration files. If you wish to have a
configuration file for a file called 'video.avi', create a file named
'video.avi.conf' with the file-specific options in it and put it in
`~/.config/mpv/`. You can also put the configuration file in the same directory
as the file to be played. Both require you to set the `--use-filedir-conf`
option (either on the command line or in your global config file). If a
file-specific configuration file is found in the same directory, no
file-specific configuration is loaded from `~/.config/mpv`. In addition, the
`--use-filedir-conf` option enables directory-specific configuration files.
For this, mpv first tries to load a mpv.conf from the same directory
as the file played and then tries to load any file-specific configuration.

## Profiles

To ease working with different configurations, profiles can be defined in the
configuration files. A profile starts with its name in square brackets,
e.g. `[my-profile]`. All following options will be part of the profile. A
description (shown by `--profile=help`) can be defined with the
`profile-desc` option. To end the profile, start another one or use the
profile name `default` to continue with normal options.

You can list profiles with `--profile=help`, and show the contents of a
profile with `--show-profile=<name>` (replace `<name>` with the profile
name). You can apply profiles on start with the `--profile=<name>` option,
or at runtime with the `apply-profile <name>` command.

Example mpv config file with profiles

```
# normal top-level option
fullscreen=yes

# a profile that can be enabled with --profile=big-cache
[big-cache]
cache=yes
demuxer-max-bytes=512MiB
demuxer-readahead-secs=20

[network]
profile-desc="profile for content over network"
force-window=immediate
# you can also include other profiles
profile=big-cache

[reduce-judder]
video-sync=display-resample
interpolation=yes

# using a profile again extends it
[network]
demuxer-max-back-bytes=512MiB
# reference a builtin profile
profile=fast
```

## Runtime profiles

Profiles can be set at runtime with `apply-profile` command. Since this
operation is "destructive" (every item in a profile is simply set as an
option, overwriting the previous value), you can't just enable and disable
profiles again.

As a partial remedy, there is a way to make profiles save old option values
before overwriting them with the profile values, and then restoring the old
values at a later point using `apply-profile

 restore`.

This can be enabled with the `profile-restore` option, which takes one of
the following options:

> `default`
>
>
> Does nothing, and nothing can be restored (default).
>
>
> `copy`
>
>
>
>
> When applying a profile, copy the old values of all profile options to a
> backup before setting them from the profile. These options are reset to
> their old values using the backup when restoring.
>
>
> Every profile has its own list of backed up values. If the backup
> already exists (e.g. if `apply-profile name` was called more than
> once in a row), the existing backup is no changed. The restore operation
> will remove the backup.
>
>
> It's important to know that restoring does not "undo" setting an option,
> but simply copies the old option value. Consider for example `vf-add`,
> appends an entry to `vf`. This mechanism will simply copy the entire
> `vf` list, and does _not_ execute the inverse of `vf-add` (that
> would be `vf-remove`) on restoring.
>
>
> Note that if a profile contains recursive profiles (via the `profile`
> option), the options in these recursive profiles are treated as if they
> were part of this profile. The referenced profile's backup list is not
> used when creating or using the backup. Restoring a profile does not
> restore referenced profiles, only the options of referenced profiles (as
> if they were part of the main profile).
>
>
> `copy-equal`
>
>
> Similar to `copy`, but restore an option only if it has the same value
> as the value effectively set by the profile. This tries to deal with
> the situation when the user does not want the option to be reset after
> interactively changing it.

Example

```
[something]
profile-restore=copy-equal
vf-add=rotate=PI/2  # rotate by 90 degrees
```

Then running these commands will result in behavior as commented:

```
set vf vflip
apply-profile something
vf add hflip
apply-profile something
# vf == vflip,rotate=PI/2,hflip,rotate=PI/2
apply-profile something restore
# vf == vflip
```

