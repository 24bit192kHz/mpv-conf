#!/bin/sh
set -eu

repo="${MPV_CONF_REPO:-24bit192kHz/mpv-conf}"
branch="${MPV_CONF_BRANCH:-master}"
: "${HOME:?HOME must be set}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
target="${MPV_CONF_TARGET:-$config_home/mpv}"
archive_url="https://github.com/$repo/archive/refs/heads/$branch.tar.gz"

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "missing required command: $1" >&2
        exit 1
    fi
}

need_cmd curl
need_cmd tar
need_cmd mktemp

tmp="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

echo "Downloading $repo@$branch"
curl -fSsL "$archive_url" -o "$tmp/mpv-conf.tar.gz"
tar -xzf "$tmp/mpv-conf.tar.gz" -C "$tmp"
src="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

if [ -z "$src" ] || [ ! -d "$src" ]; then
    echo "could not unpack config archive" >&2
    exit 1
fi

if [ -e "$target" ]; then
    backup="$target.backup.$(date +%Y%m%d-%H%M%S)"
    echo "Backing up existing $target to $backup"
    mv "$target" "$backup"
fi

mkdir -p "$target"
for item in \
    mpv.conf \
    .env.example \
    input.conf \
    profiles.conf \
    fonts \
    script-modules \
    script-opts \
    scripts \
    shaders \
    cuda-crop-cpp
do
    if [ -e "$src/$item" ]; then
        cp -R "$src/$item" "$target/"
    fi
done

# Reinstalls keep the user's own settings: .env and every script-opts conf
# from the backup win over the freshly copied repo versions (the repo ships
# no ar_subs.conf at all, so edits to it always survive).
if [ -n "${backup:-}" ] && [ -d "$backup" ]; then
    if [ -d "$backup/script-opts" ]; then
        cp -R "$backup/script-opts/." "$target/script-opts/"
    fi
    if [ -f "$backup/.env" ]; then
        cp "$backup/.env" "$target/.env"
    fi
fi

# Per-device screenshot directory: the repo conf hardcodes the maintainer's
# path; point it at this user's Pictures instead.
shots="$HOME/Pictures/mpv"
mkdir -p "$shots"
sed -i.tmp "s|/home/btw/Pictures/mpv|$shots|g" "$target/mpv.conf" && rm -f "$target/mpv.conf.tmp"

# cuda-crop-cpp: native C++ sidecar (ffprobe + ffmpeg cropdetect). Needs cmake,
# a C++17 compiler, and nlohmann_json. Try to build; otherwise print manual steps.
if [ -d "$target/cuda-crop-cpp" ]; then
    if command -v cmake >/dev/null 2>&1 && \
       { command -v c++ >/dev/null 2>&1 || command -v g++ >/dev/null 2>&1 || command -v clang++ >/dev/null 2>&1; }; then
        echo "Building cuda-crop-cpp"
        (cd "$target/cuda-crop-cpp" && cmake -B build && cmake --build build) || \
            echo "Build failed (missing nlohmann_json?). Install it (e.g. apt install nlohmann-json3-dev) then re-run:" \
                 "cd \"$target/cuda-crop-cpp\" && cmake -B build && cmake --build build" >&2
    else
        echo "cmake/C++ compiler not found; dynamic crop needs cuda-crop-cpp built:" >&2
        echo "  install cmake + a C++ compiler + nlohmann_json, then: cd \"$target/cuda-crop-cpp\" && cmake -B build && cmake --build build" >&2
    fi
fi

# Ready-to-use conf from the example (never overwrites: the old target was
# backed up above, so a fresh install has no ar_subs.conf yet).
if [ -f "$target/script-opts/ar_subs.conf.example" ] && \
   [ ! -f "$target/script-opts/ar_subs.conf" ]; then
    cp "$target/script-opts/ar_subs.conf.example" "$target/script-opts/ar_subs.conf"
fi

# Fresh installs get an empty .env (mode 600) to fill in -- API keys live
# here and nowhere else.
if [ ! -f "$target/.env" ] && [ -f "$target/.env.example" ]; then
    cp "$target/.env.example" "$target/.env"
    chmod 600 "$target/.env"
fi

echo "Installed mpv config to $target"
echo "API keys: fill in $target/.env (SUBDL, SUBSOURCE, TMDB, TVDB)."
