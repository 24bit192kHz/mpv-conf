
When using this option, mpv will exit after completing the process.
To see a detailed list of operations, run mpv with the `-v` option.

The list of the file extensions to register, can be controlled with the
`--video-exts`, `--audio-exts`, `--image-exts`, `--playlist-exts`
and `--archive-exts` options.

By default, mpv will be registered for the current user. To register it for
all users, run mpv as an administrator with this option. However, this is
not recommended, as registering it per user is generally preferable.

You can unregister mpv from the Windows Settings or by running mpv with the
`--unregister` option.

`--register-rpath=<string>`

(Windows only)

When registering with `--register`, this option allows you to specify the
path(s) to prepend so that mpv can find the necessary DLLs. The specified
string will be prepended to the runtime PATH whenever mpv is executed.

This is useful for setting up paths to external libraries required by mpv
without adding them to the global PATH environment variable.

The format of the string follows the same structure as the PATH environment
variable, a semicolon-separated list of paths.

Note

This sets the `App Paths` for mpv in the Windows registry, which
Windows Shell uses to locate the executable and its dependencies. As a
result, mpv can be launched seamlessly in most cases, but not in every
scenario. Notably, running mpv from the command line does not use
<cite>ShellExecute</cite> under the hood, it uses <cite>CreateProcess</cite>, which does not
handle the `App Paths` registry key.

To work around this, you can create a small wrapper PowerShell script that
runs `Start-Process <mpv path>` and all will work as expected.

`--unregister`

(Windows only) (available also as mpv-unregister helper)

Unregisters mpv as a media player on Windows, undoing all changes made by
the `--register` option. This will not remove mpv binary itself.

You can use any mpv binary that supports this command, to unregister, doesn't
have to be specifically the one that was used to register it.

Windows Settings Application entry is tied to the mpv.exe path. If you
remove the binary, it will not work. However, you can still unregister it
using this command, register it in a new location, or restore mpv to its
original location.

If mpv was previously registered for all users, run this command as an
administrator to remove it for all users.
