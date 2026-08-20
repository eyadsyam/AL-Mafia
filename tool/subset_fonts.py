#!/usr/bin/env python3
"""Subsets the bundled fonts to the scripts this app actually renders.

    python tool/fetch_fonts.py      # get the full upstream faces
    python tool/subset_fonts.py     # then trim them in place

## Why

The app ships Arabic and English only, but the upstream faces carry far more
than that. Cairo alone is 586 KB of which most is coverage no screen will ever
ask for. Because the app is offline-first the fonts cannot be fetched lazily, so
every unused glyph is permanent APK weight on a phone that is going to be passed
around a table all evening.

## The thing that must not break

Arabic is a joining script: a letter's shape depends on its neighbours, and that
substitution lives in the font's GSUB/GPOS tables, not in the text. A subsetter
that drops those tables produces a font that still renders every character and
renders all of them wrong — disconnected, isolated letterforms. `--layout-features='*'`
keeps the whole feature set, and the ranges below deliberately include the
presentation-forms blocks and the joiner controls.

Verify visually after running this. A shaping regression is obvious to anyone who
reads Arabic and invisible to a byte-size check.
"""

from __future__ import annotations

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, "assets", "fonts")

LATIN = [
    "U+0000-00FF",       # Basic Latin + Latin-1 Supplement
    "U+2010-2027",       # dashes, quotes, ellipsis
    "U+2030-205E",       # per-mille, primes, bullets
    "U+20AC",            # euro
    "U+2212",            # minus
]

ARABIC = [
    "U+0600-06FF",       # Arabic (incl. Arabic-Indic digits ٠-٩ and ؟)
    "U+0750-077F",       # Arabic Supplement
    "U+08A0-08FF",       # Arabic Extended-A
    "U+FB50-FDFF",       # Arabic Presentation Forms-A
    "U+FE70-FEFF",       # Arabic Presentation Forms-B
    "U+200C-200F",       # ZWNJ, ZWJ, LRM, RLM — joining and direction control
    "U+2066-2069",       # isolate controls
]

# file -> unicode ranges it needs to keep
PLAN = {
    "Cairo-Variable.ttf": LATIN + ARABIC,
    "IBMPlexSansArabic-Regular.ttf": LATIN + ARABIC,
    "IBMPlexSansArabic-Medium.ttf": LATIN + ARABIC,
    "IBMPlexSansArabic-SemiBold.ttf": LATIN + ARABIC,
    # Latin-only faces: Bebas has no Arabic at all, and the mono face is only
    # ever used for figures and timers.
    "BebasNeue-Regular.ttf": LATIN,
    "IBMPlexMono-Regular.ttf": LATIN,
    "IBMPlexMono-Medium.ttf": LATIN,
}


def main() -> None:
    total_before = total_after = 0
    print(f"  {'font':<34}{'before':>10}{'after':>10}{'saved':>9}")

    for name, ranges in PLAN.items():
        path = os.path.join(FONTS, name)
        if not os.path.exists(path):
            print(f"  {name:<34}  missing — run tool/fetch_fonts.py")
            continue

        before = os.path.getsize(path)
        tmp = path + ".subset"

        result = subprocess.run(
            [sys.executable, "-m", "fontTools.subset", path,
             f"--output-file={tmp}",
             f"--unicodes={','.join(ranges)}",
             # Keep every OpenType layout feature. For Arabic these are not
             # optional polish: init/medi/fina/isol/rlig/mark drive the joining.
             "--layout-features=*",
             # Variable fonts: keep the axes so FontVariation still works.
             "--drop-tables=",
             "--name-IDs=*",
             "--notdef-outline",
             "--recommended-glyphs"],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            print(f"  {name:<34}  FAILED: {result.stderr.strip()[:120]}")
            if os.path.exists(tmp):
                os.remove(tmp)
            continue

        after = os.path.getsize(tmp)
        os.replace(tmp, path)
        total_before += before
        total_after += after
        pct = (1 - after / before) * 100
        print(f"  {name:<34}{before:>10,}{after:>10,}{pct:>8.1f}%")

    if total_before:
        pct = (1 - total_after / total_before) * 100
        print(f"\n  {'TOTAL':<34}{total_before:>10,}{total_after:>10,}"
              f"{pct:>8.1f}%")
    print("\nNow verify Arabic shaping on a device — letters must still join.")


if __name__ == "__main__":
    main()
