#!/bin/sh
set -eu

repo="${MPV_CONF_REPO:-24bit192kHz/mpv-conf}"
branch="${MPV_CONF_BRANCH:-master}"
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
    cuda-crop-cpp
do
    if [ -e "$src/$item" ]; then
        cp -R "$src/$item" "$target/"
    fi
done

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

echo "Installed mpv config to $target"
