#!/usr/bin/env python3
"""Installs approved Kratos narrator lines into the app (F16).

    python tool/voice/install_kratos.py --approve
    python tool/voice/install_kratos.py --approve --only night_01,morning_none_01

Reads the candidates `tool/voice/generate_kratos.mjs` rendered into
`build/voice/kratos/<id>.mp3`, and for each line of `kratos_lines.json` whose
beat the app speaks:

  * trims leading and trailing silence, so a line lands on its moment;
  * normalises loudness to -16 LUFS integrated, -1.5 dBTP, so every line sits
    at the same level and the player's voice-volume setting means one thing;
  * writes mono Ogg Vorbis to `assets/voice/kratos/<id>.ogg`;
  * rewrites `assets/voice/kratos/manifest.json`, which the app reads at start.

## The gate this does not replace

Nothing is installed without `--approve`, and approving means the F16 gate
has passed: the voice is confirmed designed rather than cloned, a
commercial-use authorisation for the generated audio is on record, the
listener panel passed, and the owner approved tone and pronunciation. The
generator's PROVENANCE.json is copied next to the clips so the batch record
travels with them.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BANK = os.path.join(ROOT, "tool", "voice", "kratos_lines.json")
SRC = os.path.join(ROOT, "build", "voice", "kratos")
OUT = os.path.join(ROOT, "assets", "voice", "kratos")

# The beats the app speaks (NarratorBeat). `brand` lines are for videos only.
APP_BEATS = {"night", "morning", "discussion", "voting", "result", "win"}

FILTER = ",".join([
    "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05",
    "areverse",
    "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08",
    "areverse",
    "loudnorm=I=-16:TP=-1.5:LRA=7",
])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--approve", action="store_true",
                    help="the F16 gate has passed for these lines")
    ap.add_argument("--only", default="", help="comma-separated line ids")
    args = ap.parse_args()

    bank = json.load(open(BANK, encoding="utf8"))
    only = {s.strip() for s in args.only.split(",") if s.strip()}
    lines = [l for l in bank["lines"]
             if l["beat"] in APP_BEATS and (not only or l["id"] in only)]
    missing = [l["id"] for l in lines if not os.path.exists(os.path.join(SRC, l["id"] + ".mp3"))]
    if missing:
        sys.exit("FAIL: not rendered yet (run generate_kratos.mjs): " + ", ".join(missing))
    if not args.approve:
        print(f"{len(lines)} line(s) ready. Nothing installed: pass --approve once the F16 gate has passed.")
        return
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        sys.exit("FAIL: ffmpeg not found")

    os.makedirs(OUT, exist_ok=True)
    manifest_path = os.path.join(OUT, "manifest.json")
    manifest = json.load(open(manifest_path, encoding="utf8")) if os.path.exists(manifest_path) else {}
    clips = {c["id"]: c for c in manifest.get("clips", [])}
    for line in lines:
        dst = os.path.join(OUT, line["id"] + ".ogg")
        r = subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i",
                            os.path.join(SRC, line["id"] + ".mp3"), "-af", FILTER,
                            "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", dst],
                           capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit(f"FAIL {line['id']}: {r.stderr.strip()[:200]}")
        clips[line["id"]] = {
            "id": line["id"], "beat": line["beat"], "when": line["when"],
            "family": bool(line.get("family")), "file": f"voice/kratos/{line['id']}.ogg",
        }
        print(f"  {os.path.relpath(dst, ROOT):<40} {os.path.getsize(dst):>7,} B")

    manifest.update({"voice": "kratos", "voiceId": bank["voice_id"],
                     "clips": sorted(clips.values(), key=lambda c: c["id"])})
    manifest.pop("note", None)
    with open(manifest_path, "w", encoding="utf8", newline="\n") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")
    prov = os.path.join(SRC, "PROVENANCE.json")
    if os.path.exists(prov):
        shutil.copy(prov, os.path.join(OUT, "PROVENANCE.json"))
    print(f"manifest: {len(clips)} clip(s)")


if __name__ == "__main__":
    main()
