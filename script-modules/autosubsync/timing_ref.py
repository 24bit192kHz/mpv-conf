#!/usr/bin/env python3
"""Argos timing-ref sidecar for autosubsync (testing2).

Pipeline:
  1. Default embedded text sub (ffprobe disposition.default, else first text)
     → Argos Translate → Arabic, timestamps kept (the timing oracle).
  2. If the file has no text sub → sherpa-onnx VAD+ASR (whisper-large-v3)
     → Argos EN→AR, timestamps from VAD segments.
  3. Best-score Arabic sub (ar_subs waterfall: local / SubSource / SubDL)
     keeps its text; cue times are rewritten from matched oracle cues.
  4. Optional: run ffsubsync on the same pair and report median |error|
     of each method vs the oracle.

Usage:
  timing_ref.py retime --video FILE --ar-sub FILE --out FILE
  timing_ref.py compare --video FILE --ar-sub FILE
  timing_ref.py selftest
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "mpv" / "autosubsync"
SHERPA_DIR = CACHE / "sherpa-models"
ARGOS_DIR = CACHE / "argos-packages"
WHISPER_TAG = "whisper-large-v3"
WHISPER_URL = (
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/"
    "asr-models/sherpa-onnx-whisper-large-v3.tar.bz2"
)
VAD_URL = (
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/"
    "asr-models/silero_vad.onnx"
)

HARAKAT = dict.fromkeys(map(ord, "ًٌٍَُِّْـ"), None)
ASS_TAG = re.compile(r"\{[^}]*\}")
HTML_TAG = re.compile(r"<[^>]+>")
PUNCT = re.compile(r"[^\w\s\u0600-\u06FF]", re.UNICODE)
TIME_SRT = re.compile(
    r"(\d+):(\d+):(\d+)[,.](\d+)\s*-->\s*(\d+):(\d+):(\d+)[,.](\d+)"
)
SHERPA_SEG = re.compile(
    r"^\s*(\d+(?:\.\d+)?)\s*--\s*(\d+(?:\.\d+)?)\s*:\s*(.*)$"
)


def _hms(h, m, s, frac, frac_len=None) -> float:
    if frac_len is None:
        frac_len = len(frac)
    scale = 10 ** min(frac_len, 3)
    # SRT uses ms (3); ASS uses cs (2). Pad/truncate to seconds.
    f = int(frac[:3].ljust(3, "0"))
    return int(h) * 3600 + int(m) * 60 + int(s) + f / 1000.0


def sec_to_srt(x: float) -> str:
    if x < 0:
        x = 0
    ms = int(round(x * 1000))
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def sec_to_ass(x: float) -> str:
    if x < 0:
        x = 0
    cs = int(round(x * 100))
    h, cs = divmod(cs, 360000)
    m, cs = divmod(cs, 6000)
    s, cs = divmod(cs, 100)
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"


def norm_ar(text: str) -> str:
    text = ASS_TAG.sub(" ", text)
    text = HTML_TAG.sub(" ", text)
    text = text.replace("\\N", " ").replace("\\n", " ").replace("\\h", " ")
    text = text.translate(HARAKAT)
    for a, b in (("ة", "ه"), ("ى", "ي"), ("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ؤ", "و"), ("ئ", "ي")):
        text = text.replace(a, b)
    text = PUNCT.sub(" ", text)
    return " ".join(text.split()).lower()


def tokens(text: str) -> frozenset[str]:
    n = norm_ar(text)
    return frozenset(t for t in n.split() if len(t) > 1)


def jaccard(a: frozenset[str], b: frozenset[str]) -> float:
    if not a or not b:
        return 0.0
    inter = len(a & b)
    if inter == 0:
        return 0.0
    return inter / len(a | b)


class Cue:
    __slots__ = ("start", "end", "text", "raw")

    def __init__(self, start: float, end: float, text: str, raw=None):
        self.start = start
        self.end = end
        self.text = text
        self.raw = raw  # ASS Dialogue rest, or None for SRT


# ASS style prefixes that are signs/songs/OP/ED/title-cards (same idea as
# autosubsync.lua SIGN_PREFIXES). Stripping them before Argos/DTW stops
# Lain's typewriter "Time" cues from stealing dialogue matches.
_SIGN_PREFIXES = (
    "op", "ed", "opl", "opr", "time", "sign", "title", "banner",
    "ts", "typeset", "karaoke", "song", "epi", "eyecatch", "neon",
    "splash", "headline", "instruct", "picture", "abandoned",
    "nextep", "next", "preview", "english", "eng", "romaji",
)


def is_dialogue_cue(c: Cue) -> bool:
    if not c.raw:
        return True
    parts = c.raw[0] if isinstance(c.raw, tuple) else None
    if not parts or len(parts) < 4:
        return True
    style = (parts[3] or "").lower().lstrip(" \t-_")
    first = style.split(" ", 1)[0].split("-", 1)[0].split("_", 1)[0]
    return not any(first.startswith(p) for p in _SIGN_PREFIXES)


def dialogue_only(cues: list[Cue]) -> list[Cue]:
    kept = [c for c in cues if is_dialogue_cue(c)]
    return kept if kept else cues


def read_sub_text(path: Path) -> str:
    """Decode subtitle bytes. Arabic scene releases are often cp1256
    (mpv.conf sub-codepage=cp1256). UTF-8 errors='replace' turns those
    into U+FFFD diamonds on screen."""
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        return raw.decode("utf-8-sig").replace("\r\n", "\n")
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        return raw.decode("utf-16").replace("\r\n", "\n")
    ranked = []
    for enc in ("utf-8", "cp1256", "iso-8859-6"):
        try:
            text = raw.decode(enc)
        except UnicodeDecodeError:
            continue
        arabic = len(re.findall(r"[\u0600-\u06FF]", text))
        ranked.append((arabic, enc, text))
    if not ranked:
        text = raw.decode("utf-8", errors="replace")
    else:
        ranked.sort(key=lambda t: t[0], reverse=True)
        text = ranked[0][2]
        print(f"sub encoding {path.name}: {ranked[0][1]} ({ranked[0][0]} Arabic letters)", file=sys.stderr)
    return text.replace("\r\n", "\n")


def parse_srt(path: Path) -> list[Cue]:
    data = read_sub_text(path)
    cues: list[Cue] = []
    blocks = re.split(r"\n\s*\n", data.strip())
    for block in blocks:
        lines = block.split("\n")
        stamp = next((ln for ln in lines if "-->" in ln), None)
        if not stamp:
            continue
        m = TIME_SRT.search(stamp)
        if not m:
            continue
        text = " ".join(ln for ln in lines if ln is not stamp and not ln.strip().isdigit())
        cues.append(Cue(_hms(*m.group(1, 2, 3, 4)), _hms(*m.group(5, 6, 7, 8)), text))
    return cues


def parse_ass(path: Path) -> tuple[str, list[Cue]]:
    data = read_sub_text(path)
    header_lines = []
    cues: list[Cue] = []
    for line in data.split("\n"):
        if not line.startswith("Dialogue:"):
            header_lines.append(line)
            continue
        rest = line[len("Dialogue:") :]
        parts = []
        cur = rest
        ok = True
        for _ in range(9):
            c = cur.find(",")
            if c < 0:
                ok = False
                break
            parts.append(cur[:c])
            cur = cur[c + 1 :]
        if not ok:
            continue
        # parts[1]=start, parts[2]=end after splitting from "Marked,Start,End,..."
        # Dialogue: Layer, Start, End, Style, Name, M, M, V, Effect, Text
        st = _parse_ass_time(parts[1].strip())
        en = _parse_ass_time(parts[2].strip())
        if st is None or en is None:
            continue
        cues.append(Cue(st, en, cur, raw=(parts, cur)))
    header = "\n".join(header_lines)
    if not header.endswith("\n"):
        header += "\n"
    return header, cues


def _parse_ass_time(t: str) -> float | None:
    m = re.match(r"(\d+):(\d+):(\d+)\.(\d+)", t)
    if not m:
        return None
    h, mi, s, frac = m.groups()
    cs = int(frac.ljust(2, "0")[:2])
    return int(h) * 3600 + int(mi) * 60 + int(s) + cs / 100.0


def parse_sub(path: Path) -> tuple[str, list[Cue], str]:
    ext = path.suffix.lower()
    if ext == ".zst":
        raw = path.with_suffix("")
        subprocess.check_call(["zstd", "-dqfk", "-o", str(raw), str(path)])
        return parse_sub(raw)
    if ext == ".ass":
        header, cues = parse_ass(path)
        return header, cues, "ass"
    return "", parse_srt(path), "srt"


def write_sub(path: Path, header: str, cues: list[Cue], kind: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if kind == "ass":
        lines = [header.rstrip("\n")]
        for c in cues:
            if c.raw:
                parts, text = c.raw
                parts = list(parts)
                parts[1] = sec_to_ass(c.start)
                parts[2] = sec_to_ass(c.end)
                lines.append("Dialogue:" + ",".join(parts) + "," + text)
            else:
                lines.append(
                    f"Dialogue: 0,{sec_to_ass(c.start)},{sec_to_ass(c.end)},"
                    f"Default,,0,0,0,,{c.text}"
                )
        path.write_text("\n".join(lines) + "\n", encoding="utf-8-sig")
        return
    chunks = []
    for i, c in enumerate(cues, 1):
        chunks.append(f"{i}\n{sec_to_srt(c.start)} --> {sec_to_srt(c.end)}\n{c.text}\n")
    path.write_text("\n".join(chunks) + "\n", encoding="utf-8-sig")


def write_srt(path: Path, cues: list[Cue]) -> None:
    write_sub(path, "", cues, "srt")


# --- Argos ---

def ensure_argos(from_code: str, to_code: str) -> None:
    os.environ.setdefault("ARGOS_PACKAGES_DIR", str(ARGOS_DIR))
    ARGOS_DIR.mkdir(parents=True, exist_ok=True)
    from argostranslate import package, translate  # type: ignore

    installed = {(p.from_code, p.to_code) for p in package.get_installed_packages()}
    if (from_code, to_code) in installed:
        return
    try:
        package.update_package_index()
    except Exception as e:
        print(f"argos: package index update failed: {e}", file=sys.stderr)
    available = package.get_available_packages()
    pkg = next((p for p in available if p.from_code == from_code and p.to_code == to_code), None)
    if pkg is None:
        raise SystemExit(f"argos: no package {from_code}->{to_code}")
    print(f"argos: installing {from_code}->{to_code}", file=sys.stderr)
    package.install_from_path(pkg.download())


def translate_cues(cues: list[Cue], src: str, tgt: str = "ar") -> list[Cue]:
    if src == tgt or src.startswith(tgt):
        return cues
    # ja/other: pivot through English when a direct pair is missing.
    chain = [(src, tgt)]
    try:
        ensure_argos(src, tgt)
    except SystemExit:
        if src != "en":
            ensure_argos(src, "en")
            ensure_argos("en", tgt)
            chain = [(src, "en"), ("en", tgt)]
        else:
            raise
    from argostranslate.translate import translate  # type: ignore

    out = []
    for c in cues:
        text = c.text
        for a, b in chain:
            if text.strip():
                text = translate(text, a, b)
        out.append(Cue(c.start, c.end, text, raw=c.raw))
    return out


# --- extract default embedded ---

TEXT_CODECS = {"subrip", "ass", "ssa", "mov_text", "webvtt", "srt"}


def ffprobe_subs(video: Path) -> list[dict]:
    r = subprocess.run(
        [
            "ffprobe", "-v", "quiet", "-print_format", "json",
            "-show_streams", "-select_streams", "s", str(video),
        ],
        capture_output=True, text=True, check=False,
    )
    if r.returncode != 0:
        return []
    data = json.loads(r.stdout or "{}")
    return data.get("streams") or []


def pick_default_stream(streams: list[dict]) -> dict | None:
    text = []
    for s in streams:
        codec = (s.get("codec_name") or "").lower()
        if codec in TEXT_CODECS or codec in {"ass", "ssa", "subrip"}:
            text.append(s)
    if not text:
        return None
    for s in text:
        disp = s.get("disposition") or {}
        if disp.get("default"):
            return s
    for s in text:
        lang = ((s.get("tags") or {}).get("language") or "").lower()
        if lang.startswith("en"):
            return s
    return text[0]


def extract_stream(video: Path, stream: dict, dest: Path) -> Path:
    idx = stream["index"]
    codec = (stream.get("codec_name") or "").lower()
    fmt = "ass" if codec in {"ass", "ssa"} else "srt"
    if dest.suffix.lower() != f".{fmt}":
        dest = dest.with_suffix(f".{fmt}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-nostdin", "-y", "-loglevel", "error",
            "-i", str(video), "-map", f"0:{idx}", "-f", fmt, str(dest),
        ],
        check=True,
    )
    return dest


# --- sherpa ASR fallback ---

def _download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"download {url} -> {dest}", file=sys.stderr)
    urllib.request.urlretrieve(url, dest)


def _pick_onnx(root: Path, role: str) -> Path:
    hits = sorted(root.glob(f"*{role}*.onnx"))
    if not hits:
        raise FileNotFoundError(f"{root}: no {role} onnx")
    int8 = [p for p in hits if "int8" in p.name.lower()]
    return int8[0] if int8 else hits[0]


def ensure_sherpa_models(model_dir: Path) -> dict:
    model_dir.mkdir(parents=True, exist_ok=True)
    vad = model_dir / "silero_vad.onnx"
    if not vad.exists():
        _download(VAD_URL, vad)
    whisper_root = None
    for p in model_dir.glob("sherpa-onnx-whisper-large-v3*"):
        if p.is_dir() and any(p.glob("*encoder*.onnx")):
            whisper_root = p
            break
    if whisper_root is None:
        archive = model_dir / "sherpa-onnx-whisper-large-v3.tar.bz2"
        if not archive.exists():
            _download(WHISPER_URL, archive)
        print(f"extract {archive.name}", file=sys.stderr)
        with tarfile.open(archive, "r:bz2") as tf:
            tf.extractall(model_dir, filter="data")
        for p in model_dir.glob("sherpa-onnx-whisper-large-v3*"):
            if p.is_dir() and any(p.glob("*encoder*.onnx")):
                whisper_root = p
                break
    if whisper_root is None:
        raise SystemExit("sherpa-models: whisper-large-v3 extract failed")
    enc = _pick_onnx(whisper_root, "encoder")
    dec = _pick_onnx(whisper_root, "decoder")
    tok = next(whisper_root.glob("*tokens.txt"))
    print(f"sherpa whisper: {enc.name} + {dec.name}", file=sys.stderr)
    return {"vad": vad, "encoder": enc, "decoder": dec, "tokens": tok}


def ffmpeg_wav(video: Path, wav: Path, max_seconds: float | None) -> None:
    args = [
        "ffmpeg", "-hide_banner", "-nostdin", "-y", "-loglevel", "error",
        "-i", str(video), "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le",
    ]
    if max_seconds:
        args.extend(["-t", str(int(max_seconds))])
    args.append(str(wav))
    subprocess.run(args, check=True)


def asr_cues(video: Path, model_dir: Path, max_seconds: float | None = 1200) -> list[Cue]:
    models = ensure_sherpa_models(model_dir)
    bin_path = shutil.which("sherpa-onnx-vad-with-offline-asr")
    if not bin_path:
        raise SystemExit("sherpa-onnx-vad-with-offline-asr not on PATH")
    with tempfile.TemporaryDirectory(prefix="timing_ref_asr_") as td:
        wav = Path(td) / "audio.wav"
        ffmpeg_wav(video, wav, max_seconds)
        def run(provider: str):
            return subprocess.run(
                [
                    bin_path,
                    f"--silero-vad-model={models['vad']}",
                    f"--whisper-encoder={models['encoder']}",
                    f"--whisper-decoder={models['decoder']}",
                    f"--tokens={models['tokens']}",
                    "--num-threads=4",
                    "--whisper-tail-paddings=300",
                    f"--provider={provider}",
                    str(wav),
                ],
                capture_output=True, text=True, check=False,
            )

        def parse_cues(blob: str) -> list[Cue]:
            cues = []
            for line in blob.splitlines():
                m = SHERPA_SEG.match(line)
                if not m:
                    continue
                text = m.group(3).strip()
                if text:
                    cues.append(Cue(float(m.group(1)), float(m.group(2)), text))
            return cues

        r = run("cuda")
        blob = (r.stdout or "") + "\n" + (r.stderr or "")
        cues = parse_cues(blob)
        if not cues:
            print("sherpa cuda produced no segments; retrying cpu", file=sys.stderr)
            r = run("cpu")
            blob = (r.stdout or "") + "\n" + (r.stderr or "")
            cues = parse_cues(blob)
        if not cues:
            print(blob[-2000:], file=sys.stderr)
            raise SystemExit("sherpa ASR produced no segments")
        return cues


# --- match + retime ---

def dtw_match(target: list[Cue], ref: list[Cue]) -> list[int | None]:
    """Monotonic match: target[i] -> ref[j] or None. Cost = 1 - jaccard."""
    if not target or not ref:
        return [None] * len(target)
    n, m = len(target), len(ref)
    tt = [tokens(c.text) for c in target]
    rt = [tokens(c.text) for c in ref]
    # Banded DTW: allow ±15% index slack plus 40 cues.
    band = max(40, int(0.15 * max(n, m)))
    INF = 1e9
    dp = [[INF] * (m + 1) for _ in range(n + 1)]
    bt = [[(0, 0)] * (m + 1) for _ in range(n + 1)]
    dp[0][0] = 0.0
    for i in range(n + 1):
        j0 = 0 if i == 0 else max(0, int(i * m / max(n, 1)) - band)
        j1 = m if i == 0 else min(m, int(i * m / max(n, 1)) + band)
        for j in range(j0, j1 + 1):
            if i == 0 and j == 0:
                continue
            best, src = INF, (i, j)
            if i and j:
                sim = jaccard(tt[i - 1], rt[j - 1])
                # Position prior so empty-overlap still aligns roughly in order.
                pos = 1.0 - abs((i - 1) / max(n - 1, 1) - (j - 1) / max(m - 1, 1))
                cost = (1.0 - sim) * 0.75 + (1.0 - pos) * 0.25
                val = dp[i - 1][j - 1] + cost
                if val < best:
                    best, src = val, (i - 1, j - 1)
            if i:
                val = dp[i - 1][j] + 0.85  # skip target
                if val < best:
                    best, src = val, (i - 1, j)
            if j:
                val = dp[i][j - 1] + 0.85  # skip ref
                if val < best:
                    best, src = val, (i, j - 1)
            dp[i][j] = best
            bt[i][j] = src
    mapping = [None] * n
    i, j = n, m
    # Walk back from nearest finite cell if the corner is unreachable.
    if dp[n][m] >= INF / 2:
        best_ij, best_v = (n, m), INF
        for ii in range(n + 1):
            for jj in range(m + 1):
                if dp[ii][jj] < best_v:
                    best_v, best_ij = dp[ii][jj], (ii, jj)
        i, j = best_ij
    while i > 0 or j > 0:
        pi, pj = bt[i][j]
        if pi == i - 1 and pj == j - 1 and i > 0 and j > 0:
            mapping[i - 1] = j - 1
        if pi == i and pj == j:
            break
        i, j = pi, pj
    return mapping


def apply_times(target: list[Cue], ref: list[Cue], mapping: list[int | None]) -> list[Cue]:
    out = []
    last_end = 0.0
    for i, c in enumerate(target):
        j = mapping[i]
        if j is not None:
            r = ref[j]
            start, end = r.start, r.end
        else:
            # interpolate from nearest mapped neighbors
            prev = next((k for k in range(i - 1, -1, -1) if mapping[k] is not None), None)
            nxt = next((k for k in range(i + 1, len(target)) if mapping[k] is not None), None)
            if prev is not None and nxt is not None:
                t0, t1 = target[prev].start, target[nxt].start
                r0, r1 = ref[mapping[prev]].start, ref[mapping[nxt]].start
                span = (t1 - t0) or 1.0
                alpha = (c.start - t0) / span
                start = r0 + alpha * (r1 - r0)
                dur = c.end - c.start
                end = start + dur
            elif prev is not None:
                shift = ref[mapping[prev]].start - target[prev].start
                start, end = c.start + shift, c.end + shift
            elif nxt is not None:
                shift = ref[mapping[nxt]].start - target[nxt].start
                start, end = c.start + shift, c.end + shift
            else:
                start, end = c.start, c.end
        if start < last_end:
            start = last_end
        if end <= start:
            end = start + max(0.4, c.end - c.start)
        last_end = end
        out.append(Cue(start, end, c.text, raw=c.raw))
    return out


def affine_from_matches(target, ref, mapping) -> tuple[float, float]:
    xs, ys = [], []
    for i, j in enumerate(mapping):
        if j is None:
            continue
        xs.append(target[i].start)
        ys.append(ref[j].start)
    if len(xs) < 2:
        if xs:
            return ys[0] - xs[0], 1.0
        return 0.0, 1.0
    n = len(xs)
    mx = sum(xs) / n
    my = sum(ys) / n
    var = sum((x - mx) ** 2 for x in xs)
    if var < 1e-6:
        return my - mx, 1.0
    scale = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / var
    offset = my - scale * mx
    # DTW can invent a wild scale when the oracle only covers the opening
    # (PGS/ASR of the first N minutes vs a 2h download). A real PAL/NTSC
    # pull-down lives in ~0.96-1.05; anything outside that is a bad match
    # — fall back to a constant offset (median of y-x).
    if scale < 0.90 or scale > 1.10:
        diffs = sorted(y - x for x, y in zip(xs, ys))
        mid = diffs[len(diffs) // 2]
        return mid, 1.0
    return offset, scale


def apply_affine(target: list[Cue], offset: float, scale: float) -> list[Cue]:
    out = []
    for c in target:
        st = c.start * scale + offset
        en = c.end * scale + offset
        if en <= st:
            en = st + max(0.4, c.end - c.start)
        out.append(Cue(st, en, c.text, raw=c.raw))
    return out


def apply_oracle(target: list[Cue], ref: list[Cue], mapping: list[int | None]) -> tuple[list[Cue], str]:
    """Global affine from DTW pairs. Per-cue copy is a trap: Argos text is
    not the human Arabic file, so DTW is mostly index-shaped; copying those
    times then clamping overlaps can pile cues minutes off, while the same
    pairs still give a stable recap offset (Lain: +119.67s)."""
    offset, scale = affine_from_matches(target, ref, mapping)
    return apply_affine(target, offset, scale), "affine"


def median(xs: list[float]) -> float:
    if not xs:
        return 0.0
    s = sorted(xs)
    mid = len(s) // 2
    if len(s) % 2:
        return s[mid]
    return 0.5 * (s[mid - 1] + s[mid])


def oracle_errors(cues: list[Cue], ref: list[Cue], mapping: list[int | None]) -> dict:
    errs = []
    matched = 0
    for i, j in enumerate(mapping):
        if j is None:
            continue
        matched += 1
        errs.append(abs(cues[i].start - ref[j].start))
    return {
        "matched": matched,
        "total": len(cues),
        "median_abs_err": round(median(errs), 3),
        "p90_abs_err": round(sorted(errs)[int(0.9 * (len(errs) - 1))] if errs else 0.0, 3),
        "mean_abs_err": round(sum(errs) / len(errs), 3) if errs else 0.0,
    }


def run_ffsubsync(ref_srt: Path, ar_sub: Path, out: Path) -> dict:
    bin_path = shutil.which("ffsubsync") or "ffsubsync"
    out.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(
        [bin_path, str(ref_srt), "-i", str(ar_sub), "-o", str(out),
         "--max-offset-seconds", "600"],
        capture_output=True, text=True, check=False,
    )
    stdout = r.stdout or ""
    off = re.search(r"offset seconds:\s*([-\d.]+)", stdout)
    sc = re.search(r"framerate scale factor:\s*([-\d.]+)", stdout)
    return {
        "ok": r.returncode == 0 and out.exists(),
        "offset": float(off.group(1)) if off else None,
        "scale": float(sc.group(1)) if sc else None,
        "stderr_tail": (r.stderr or "")[-400:],
    }


def detect_src_lang(stream: dict | None, cues: list[Cue]) -> str:
    if stream:
        lang = ((stream.get("tags") or {}).get("language") or "").lower()
        if lang.startswith("ar"):
            return "ar"
        if lang.startswith("ja"):
            return "ja"
        if lang.startswith("en"):
            return "en"
        if lang[:2] in {"de", "fr", "es", "it", "pt", "ru", "zh", "ko"}:
            return lang[:2]
    sample = " ".join(c.text for c in cues[:30])
    ar = len(re.findall(r"[\u0600-\u06FF]", sample))
    if ar > 20:
        return "ar"
    return "en"


def video_stamp(video: Path) -> str:
    st = video.stat()
    h = hashlib.sha256(f"{video.resolve()}|{st.st_size}|{int(st.st_mtime)}".encode())
    return h.hexdigest()[:16]


MIN_SHERPA_CUES = 20
MIN_SHERPA_SPAN = 180.0


def sherpa_oracle_ok(cues: list[Cue]) -> bool:
    if not cues or len(cues) < MIN_SHERPA_CUES:
        return False
    return (cues[-1].end - cues[0].start) >= MIN_SHERPA_SPAN


def build_oracle(video: Path, ref_sub: Path | None, model_dir: Path,
                 work: Path, max_cues: int | None = None,
                 asr_seconds: float | None = None) -> tuple[list[Cue], str, str]:
    """Return (arabic_timed_cues, source_kind, src_lang)."""
    stamp = video_stamp(video)
    cache_dir = CACHE / "timing_ref" / stamp
    cache_dir.mkdir(parents=True, exist_ok=True)
    cached = cache_dir / "oracle.srt"
    meta_p = cache_dir / "oracle.json"
    if cached.exists() and meta_p.exists():
        meta = json.loads(meta_p.read_text(encoding="utf-8"))
        stale = (
            (meta.get("kind") == "sherpa" and meta.get("model") != WHISPER_TAG)
            or not meta.get("dialogue_only")
        )
        if not stale:
            cues = parse_srt(cached)
            if max_cues:
                cues = cues[:max_cues]
            if meta.get("kind") == "sherpa" and not sherpa_oracle_ok(cues):
                print("oracle cache too thin; refusing (ffsubsync fallback)", file=sys.stderr)
            else:
                print(f"oracle cache hit ({meta.get('kind')}, {len(cues)} cues)", file=sys.stderr)
            return cues, meta.get("kind", "embedded"), meta.get("src_lang", "en")

    if ref_sub and ref_sub.exists():
        _, cues, _ = parse_sub(ref_sub)
        src = detect_src_lang(None, cues)
        kind = "embedded"
    else:
        streams = ffprobe_subs(video)
        stream = pick_default_stream(streams)
        if stream:
            extracted = extract_stream(video, stream, work / "embedded.srt")
            _, cues, _ = parse_sub(extracted)
            src = detect_src_lang(stream, cues)
            kind = "embedded"
        else:
            print("no default text sub (PGS/image); sherpa ASR for timing oracle", file=sys.stderr)
            cues = asr_cues(video, model_dir, max_seconds=asr_seconds or 1200)
            src = "en"
            kind = "sherpa"
    if not cues:
        raise SystemExit("timing oracle is empty")
    if kind == "embedded":
        before = len(cues)
        cues = dialogue_only(cues)
        if len(cues) != before:
            print(f"oracle dialogue-only {before} -> {len(cues)} cues", file=sys.stderr)
    if max_cues:
        cues = cues[:max_cues]
    ar = translate_cues(cues, src, "ar")
    if not max_cues and not (kind == "sherpa" and not sherpa_oracle_ok(ar)):
        write_srt(cached, ar)
        meta_p.write_text(json.dumps({
            "kind": kind, "src_lang": src, "cues": len(ar),
            "model": WHISPER_TAG if kind == "sherpa" else None,
            "dialogue_only": True,
        }), encoding="utf-8")
    return ar, kind, src


def retime(video: Path, ar_sub: Path, out: Path, ref_sub: Path | None,
           model_dir: Path, compare_ff: Path | None, report: Path | None,
           max_cues: int | None = None, asr_seconds: float | None = None) -> dict:
    with tempfile.TemporaryDirectory(prefix="timing_ref_") as td:
        work = Path(td)
        header, target, tkind = parse_sub(ar_sub)
        target.sort(key=lambda c: c.start)
        if max_cues:
            target = target[:max_cues]
        asr_win = 1200.0
        if target:
            asr_win = min(max(target[-1].end + 30.0, 900.0), 1800.0)
        if asr_seconds is not None:
            asr_win = float(asr_seconds)
        oracle, kind, src_lang = build_oracle(
            video, ref_sub, model_dir, work, max_cues, asr_win)
        oracle = dialogue_only(oracle)
        oracle.sort(key=lambda c: c.start)
        mapping = dtw_match(target, oracle)
        if kind == "sherpa" and not sherpa_oracle_ok(oracle):
            result = {
                "oracle_kind": kind,
                "src_lang": src_lang,
                "oracle_cues": len(oracle),
                "target_cues": len(target),
                "rejected": "sherpa oracle too thin for a global offset; use ffsubsync audio",
            }
            if report:
                report.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
            print(json.dumps(result, ensure_ascii=False, indent=2))
            raise SystemExit(2)
        retimed, how = apply_oracle(target, oracle, mapping)
        write_sub(out, header, retimed, tkind)
        offset, scale = affine_from_matches(target, oracle, mapping)
        result = {
            "oracle_kind": kind,
            "src_lang": src_lang,
            "oracle_cues": len(oracle),
            "target_cues": len(target),
            "argos": {
                "out": str(out),
                "apply": how,
                "implied_offset": round(offset, 3),
                "implied_scale": round(scale, 5),
                **oracle_errors(retimed, oracle, mapping),
            },
        }
        # Unretimed vs oracle (how wrong the download was before).
        result["unsynced"] = oracle_errors(target, oracle, mapping)

        if compare_ff:
            oracle_srt = work / "oracle.srt"
            write_srt(oracle_srt, oracle)
            # ffsubsync against the *timed* oracle (same language), which is
            # equivalent in on/off times to the embedded source.
            ff = run_ffsubsync(oracle_srt, ar_sub, compare_ff)
            result["ffsubsync"] = ff
            if ff.get("ok"):
                _, ff_cues, _ = parse_sub(compare_ff)
                # Same mapping indices: text order unchanged by affine retime.
                n = min(len(ff_cues), len(mapping))
                result["ffsubsync"].update(oracle_errors(ff_cues[:n], oracle, mapping[:n]))

        if report:
            report.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return result


def selftest() -> None:
    ref = [
        Cue(1.0, 2.0, "مرحبا كيف حالك"),
        Cue(3.0, 4.0, "انا بخير شكرا"),
        Cue(10.0, 11.0, "الى اللقاء"),
    ]
    tgt = [
        Cue(5.0, 6.0, "مرحبا كيف حالك اليوم"),
        Cue(7.0, 8.0, "انا بخير"),
        Cue(20.0, 21.0, "الى اللقاء يا صديقي"),
    ]
    m = dtw_match(tgt, ref)
    assert m[0] == 0 and m[2] == 2, m
    out = apply_times(tgt, ref, m)
    assert abs(out[0].start - 1.0) < 0.01, out[0].start
    assert abs(out[2].start - 10.0) < 0.01, out[2].start
    # SRT roundtrip
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "t.srt"
        write_srt(p, ref)
        got = parse_srt(p)
        assert len(got) == 3 and abs(got[1].start - 3.0) < 0.01
    # Wild DTW scale must collapse to offset-only.
    bad_map = [0, 1, 2]
    stretched = [Cue(0, 1, "a"), Cue(100, 101, "b"), Cue(200, 201, "c")]
    tiny = [Cue(0, 1, "a"), Cue(1.5, 2, "b"), Cue(3, 4, "c")]
    off, sc = affine_from_matches(stretched, tiny, bad_map)
    assert sc == 1.0, sc
    # cp1256 Arabic must survive roundtrip (not become U+FFFD).
    sample = "مرحبا".encode("cp1256")
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "ar.srt"
        p.write_bytes(
            b"1\n00:00:01,000 --> 00:00:02,000\n" + sample + b"\n"
        )
        got = parse_srt(p)
        assert "\ufffd" not in got[0].text, got[0].text
        assert "\u0645" in got[0].text  # Arabic meem
        outp = Path(td) / "out.srt"
        write_srt(outp, got)
        assert outp.read_bytes().startswith(b"\xef\xbb\xbf")
        assert "\u0645" in outp.read_text(encoding="utf-8-sig")
    print("selftest ok")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add_io(p):
        p.add_argument("--video", required=True, type=Path)
        p.add_argument("--ar-sub", required=True, type=Path)
        p.add_argument("--out", type=Path)
        p.add_argument("--ref-sub", type=Path, default=None,
                       help="already-extracted default embedded sub (skip ffmpeg/ASR)")
        p.add_argument("--sherpa-models", type=Path, default=SHERPA_DIR)
        p.add_argument("--report", type=Path, default=None)
        p.add_argument("--max-cues", type=int, default=None,
                       help="limit oracle+target cues (smoke tests)")
        p.add_argument("--compare-ffsubsync", type=Path, default=None,
                       help="also run ffsubsync against the oracle; write this path")
        p.add_argument("--asr-seconds", type=float, default=None,
                       help="audio window for sherpa when there is no text sub")

    p_re = sub.add_parser("retime")
    add_io(p_re)

    p_cmp = sub.add_parser("compare")
    add_io(p_cmp)

    sub.add_parser("selftest")

    args = ap.parse_args(argv)
    if args.cmd == "selftest":
        selftest()
        return 0

    out = args.out
    if out is None:
        stem = args.ar_sub.with_suffix("")
        if stem.name.endswith("_retimed"):
            stem = stem.with_name(stem.name[: -len("_retimed")])
        out = stem.with_name(stem.name + "_retimed_argos" + args.ar_sub.suffix)
        if out.suffix == ".zst":
            out = Path(str(out)[:-4])

    compare = args.compare_ffsubsync
    if args.cmd == "compare":
        if compare is None:
            compare = out.with_name(out.name.replace("_retimed_argos", "_retimed_ffsubsync"))
            if compare == out:
                compare = out.with_name(out.stem + "_ffsubsync" + out.suffix)
        if args.report is None:
            args.report = out.with_suffix(".json")

    if not args.video.exists():
        raise SystemExit(f"missing video: {args.video}")
    if not args.ar_sub.exists():
        raise SystemExit(f"missing ar sub: {args.ar_sub}")

    retime(args.video, args.ar_sub, out, args.ref_sub, args.sherpa_models, compare, args.report,
           args.max_cues, args.asr_seconds)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
