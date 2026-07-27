## Scripts

_mpv_ has a [large variety of scripts](https://github.com/mpv-player/mpv/wiki/User-Scripts) that extend the functionality of the player. To this end, it has internal bindings for both Lua and JavaScript.

Scripts are typically installed by putting them in the `~/.config/mpv/scripts/` directory (you may have to create it first). After that they will be automatically loaded when mpv starts (this behavior can be altered with other _mpv_ options). Some scripts come with their own installation and configuration instructions, so make sure to have a look. In addition some scripts are old, broken, and unmaintained.

### JavaScript

JavaScript (ES5 via [MuJS](https://mujs.com/)) has been supported as an mpv scripting language since 2014. Currently only [a few scripts](https://github.com/mpv-player/mpv/wiki/User-Scripts#javascript) are available, but documentation exists at `man mpv` (JAVASCRIPT section) for anyone interested in making their own.

To get started, create a script with a `.js` extension in the mpv `scripts` directory, e.g. `~/.config/mpv/scripts/fullscreen-off-on-pause.js`:

```
function onPauseChange (prop, enabled) {
    if (enabled) {
        mp.set_property('fullscreen', 'no')
    }
}

mp.observe_property('pause', 'bool', onPauseChange)
```

For more details, e.g. on using `require` to load CommonJS modules, see `man mpv` (CommonJS modules and require(id) section).

### Lua

The development of _mpv_'s Lua scripts is documented in `man mpv` (LUA SCRIPTING section) with examples in [TOOLS/lua](https://github.com/mpv-player/mpv/tree/master/TOOLS/lua), which are installed to `/usr/share/mpv/scripts`.

For example, you can enable the builtin script to automatically crop videos with black bars:

```
$ ln -s /usr/share/mpv/scripts/autocrop.lua ~/.config/mpv/scripts
```

#### mpv-ytdlAutoFormat

[mpv-ytdlautoformat](https://github.com/Samillion/mpv-ytdlautoformat) is a Lua script to auto change ytdl-format for Youtube and Twitch or the domains you desire, to 480p or the quality you desire.

#### mpv-webm

[mpv-webm](https://github.com/ekisu/mpv-webm) (or simply _webm_) is a very easy to use Lua script that allows one to create WebM files while watching videos. It includes several features and does not have any extra dependencies (relies entirely on mpv).

#### ytdl-preload

[ytdl-preload](https://gist.github.com/bitingsock/17d90e3deeb35b5f75e55adb19098f58) is a Lua script to preload the next ytdl-link in your playlist.

**Note:** The script is still in active development.

### C

#### mpv-mpris

The C plugin [mpv-mpris](https://github.com/hoyon/mpv-mpris) allows other applications to integrate with _mpv_ via the [MPRIS](https://wiki.archlinux.org/title/MPRIS) protocol. For example, with _mpv-mpris_ installed, `kdeconnect` can automatically pause video playback in _mpv_ when a phone call arrives. Another example is buttons (play/pause etc) on bluetooth audio-devices.

To use the plugin, install `mpv-mpris`.
