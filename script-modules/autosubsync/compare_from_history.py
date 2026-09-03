#!/usr/bin/env python3
"""Pick recent `mpv /mnt/...` videos from zsh history and run timing_ref compare.

Uses a sibling .ara.srt/.ar.srt if present, else the newest matching file under
~/.cache/mpv/ar_subs/subtitles/. Bounded `--max-cues` keeps the first Argos
install from translating a whole feature.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

HIST = Path.home() / ".config/zsh/.zsh_history"
SCRIPT = Path(__file__).with_name("timing_ref.py")
CACHE_SUBS = Path.home() / ".cache/mpv/ar_subs/subtitles"


def unescape_zsh(s: str) -> str:
    return bytes(s, "utf-8").decode("unicode_escape") if "\\" in s else s.replace("\\", "")


def history_videos(limit: int = 12) -> list[Path]:
    if not HIST.exists():
        return []
    text = HIST.read_bytes().decode("utf-8", errors="replace")
    paths = []
    for m in re.finditer(r"mpv\s+(/mnt[^\n;]+)", text):
        raw = m.group(1).strip().split(" --")[0].strip()
        raw = raw.replace("\\ ", " ").replace("\\(", "(").replace("\\)", ")")
        raw = raw.replace("\\[", "[").replace("\\]", "]")
        p = Path(raw)
        if p.is_dir():
            mkvs = sorted(p.glob("*.mkv")) + sorted(p.glob("*.mp4"))
            p = mkvs[0] if mkvs else p
        if p.is_file() and p not in paths:
            paths.append(p)
    return paths[-limit:]


def find_ar_sub(video: Path) -> Path | None:
    stem = video.with_suffix("")
    for ext in (".ara.srt", ".ar.srt", ".ar.ass", ".ara.ass", ".ar.srt.zst"):
        cand = Path(str(stem) + ext) if not ext.startswith(".") else video.with_name(video.stem + ext)
        # video.stem + .ara.srt
        cand = video.with_name(video.stem + ext)
        if cand.exists():
            return cand
    parent = video.parent
    for pat in ("*.ara.srt", "*.ar.srt", "*Arabic*.ass", "*arabic*.srt"):
        hits = list(parent.glob(pat))
        if hits:
            return hits[0]
    if CACHE_SUBS.exists():
        # newest any subtitle as last resort — caller should prefer siblings
        zsts = sorted(CACHE_SUBS.rglob("*.zst"), key=lambda p: p.stat().st_mtime, reverse=True)
        if zsts:
            return zsts[0]
    return None


def main() -> int:
    vids = history_videos()
    print(f"history videos found: {len(vids)}")
    ran = 0
    for v in reversed(vids):
        sub = find_ar_sub(v)
        print(f"  {v.name[:70]}")
        print(f"    ar-sub: {sub}")
        if not sub:
            continue
        out_dir = Path.home() / ".cache/mpv/autosubsync/timing_ref/compare"
        out_dir.mkdir(parents=True, exist_ok=True)
        out = out_dir / (v.stem[:40] + "_retimed_argos.srt")
        cmd = [
            sys.executable, str(SCRIPT), "compare",
            "--video", str(v), "--ar-sub", str(sub),
            "--out", str(out), "--max-cues", "60",
        ]
        print("    ", " ".join(cmd[:8]), "...")
        r = subprocess.run(cmd)
        ran += 1
        if r.returncode != 0:
            print("    FAILED", r.returncode)
        if ran >= 2:
            break
    if ran == 0:
        print("no video+arabic-sub pair found")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
