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
    hdr-toys.conf \
    fonts \
    script-modules \
    script-opts \
    scripts \
    shaders
do
    if [ -e "$src/$item" ]; then
        cp -R "$src/$item" "$target/"
    fi
done

echo "Installed mpv config to $target"
echo "Dynamic crop expects cuda-crop-py at /home/btw/mhm/cuda-crop-py unless you edit mpv.conf."
