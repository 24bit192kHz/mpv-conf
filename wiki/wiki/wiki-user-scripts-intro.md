# User Scripts

Here is a list of scripts that users of mpv have published, adding functionality that is not part of the core mpv player. Most of these scripts are **unofficial 3rd party scripts**. Anyone can add their own script by editing this wiki. On GitHub mpv scripts are tagged as [mpv-script](https://github.com/topics/mpv-script).

Scripts are usually placed in:

| OS | Location |
| --- | --- |
| Unix-ish (Linux, BSD, macOS, ...) | `~/.config/mpv/scripts/` |
| Windows | `C:/Users/Username/AppData/Roaming/mpv/scripts/` |

## Sections

- [Lists of mpv scripts](#Lists-of-mpv-scripts)
- [JavaScript scripts](#JavaScript)
- [Lua Scripts](wiki-user-scripts-lua-1)
- [User Shaders](wiki-user-scripts-shaders)
- [VapourSynth Scripts](wiki-user-scripts-vapoursynth-c-other)
- [C Plugins](wiki-user-scripts-vapoursynth-c-other)
- [Other](wiki-user-scripts-vapoursynth-c-other)

## Lists of mpv scripts

* **[Awesome-mpv](https://github.com/stax76/awesome-mpv)** — Categorized list, updated 1-2 times per year.

## JavaScript

* **[Auto Load Fonts](https://github.com/Hill-98/mpv-config/blob/main/scripts/auto-load-fonts.js)** — Auto load font files in the fonts folder under the play file path.
* **[copyTime](https://github.com/Arieleg/mpv-copyTime)** — Get the current time of the video and copy it to the clipboard with format HH:MM:SS.MS.
* **[gallery-dl-view](https://github.com/noctuid/gallery-dl-view)** — Load image galleries directly in mpv like gallery-dl_hook but with extra functionality.
* **[mpv-assrt](https://github.com/AssrtOSS/mpv-assrt)** — Download subtitles from assrt.net, with interactive OSD menu.
* **[mpv-chapters](https://github.com/zxhzxhz/mpv-chapters)** — Display chapters and allow you to jump to them with mouse click.
* **[mpvDLNA](https://github.com/chachmu/mpvDLNA)** — Browse and watch content hosted on DLNA servers.
* **[mpv-javascript-http](https://github.com/Hill-98/mpv-javascript-http)** — HTTP client for mpv javascript scripts (based on curl).
* **[mpv-remote-node](https://github.com/husudosu/mpv-remote-node)** — Node.js server to control mpv remotely from an Android app.
* **[mpvcontextmenu](https://gitlab.com/carmanaught/mpvcontextmenu)** — Comprehensive context-menu forked from Tcl/Tk.
* **[mpvselectmenu](https://gitlab.com/carmanaught/mpvselectmenu)** — Context-menu inspired by select.lua.
* **[mute-on-specific-subtitle-words](https://github.com/jtaala/mpv-mute-on-specific-subtitle-words)** — Mutes & hides subtitles that contain specified words.
* **[PureMPV](https://github.com/4ndrs/PureMPV)** — Get file path, timestamps, and cropping coordinates for ffmpeg.
* **[screenshot-mosaic](https://github.com/noaione/mpv-js-scripts)** — Create a mosaic of images like MPC-HC.
* **[screenshot-to-clipboard](https://github.com/zc62/mpv-scripts)** — Generates temp screenshot file then copies to clipboard (Windows).
* **[seek-show-position-v2](https://github.com/someonelike-u/mpv.net)** — Shows position and duration when seeking.
* **[btime](https://github.com/butterw/bShaders)** — Shows shorter time format when seeking.
* **[bstat](https://github.com/butterw/bShaders)** — Calculates new user-data properties (avg-bitrate, file-size, aspect ratio).
* **[store-shaders](https://github.com/butterw/bShaders)** — Store current glsl-shaders config for restoration.
* **[switch-shader](https://github.com/butterw/bShaders)** — Provide a switch to disable/restore shaders and vf filters.
* **[takeSsSequence](https://github.com/Arieleg/mpv-takeSsSequence)** — Take sequence of equispaced screenshots.
* **[toggle-shuffle](https://github.com/NaiveInvestigator/toggle-shuffle)** — Toggle shuffle on/off during playback.
* **[webtorrent-mpv-hook](https://github.com/mrxdst/webtorrent-mpv-hook)** — Stream torrents with OSD overlay.
* **[writeedits](https://github.com/paradox460/mpv-scripts)** — Write filter selections to a file for batch processing.

**NPM packages (for developers):**

* **[@types/mpv-script](https://www.npmjs.com/package/@types/mpv-script)** — TypeScript definitions for builtin mp modules.
* **[mpv.d.ts](https://www.npmjs.com/package/mpv.d.ts)** — Another TypeScript definitions for mpv JavaScript API.
* **[mpv-promise](https://www.npmjs.com/package/mpv-promise)** — Promise polyfill for mpv JavaScript runtime.
* **[mpv-assdraw](https://www.npmjs.com/package/mpv-assdraw)** — mpv assdraw module for JavaScript.

**VideoPlayerCode scripts:** [Blackbox](https://github.com/VideoPlayerCode/mpv-tools/) (media browser), [Colorbox](https://github.com/VideoPlayerCode/mpv-tools/) (color correction), [Gallerizer](https://github.com/VideoPlayerCode/mpv-tools/) (image gallery), [Leapfrog](https://github.com/VideoPlayerCode/mpv-tools/) (playlist jumping), [JS Modules](https://github.com/VideoPlayerCode/mpv-tools/) (pre-written modules for script authors).

* **[mpv-easy](https://github.com/mpv-easy/mpv-easy)** — TS and React toolkit for mpv script.
* **[mpsm](https://github.com/mpv-easy/mpv-easy)** — mpv script manager.
