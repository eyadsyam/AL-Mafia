#!/usr/bin/env python3
"""Downloads the bundled typefaces into assets/fonts/.

    python tool/fetch_fonts.py          # the shipping set
    python tool/fetch_fonts.py --all    # + the pairing candidates, to re-compare

## Why the fonts are vendored instead of fetched at runtime

`google_fonts` downloads its faces over the network on first use. This app
declares no INTERNET permission at all (see the offline test in
test/platform/offline_and_manifest_test.dart) because a group has to be able to
play in a basement with no signal — so a runtime font loader would silently fall
back to the system face forever. Vendoring is not a workaround here; it is the
only option consistent with the offline guarantee.

## Why this script exists

The pairing candidates are deleted from the repository once a display face is
chosen, so that the APK does not carry three unused display families. This file
is what makes that deletion safe: the exact upstream of every candidate is
recorded, so re-running with --all restores the comparison exactly.
"""

from __future__ import annotations

import argparse
import os
import sys
import urllib.request

BASE = "https://raw.githubusercontent.com/google/fonts/main"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fonts")

# local filename -> upstream path under google/fonts
SHIPPING = {
    # Display, Latin. Uppercase-only and strongly condensed.
    "BebasNeue-Regular.ttf": "ofl/bebasneue/BebasNeue-Regular.ttf",
    # Display, Arabic — and the Latin display's fallback for Arabic glyphs.
    # Variable (wght 200..1000); tokens pick a cut with FontVariation.
    "Cairo-Variable.ttf": "ofl/cairo/Cairo%5Bslnt,wght%5D.ttf",
    # Body, both scripts from one family.
    "IBMPlexSansArabic-Regular.ttf":
        "ofl/ibmplexsansarabic/IBMPlexSansArabic-Regular.ttf",
    "IBMPlexSansArabic-Medium.ttf":
        "ofl/ibmplexsansarabic/IBMPlexSansArabic-Medium.ttf",
    "IBMPlexSansArabic-SemiBold.ttf":
        "ofl/ibmplexsansarabic/IBMPlexSansArabic-SemiBold.ttf",
    # Numerals, tabular.
    "IBMPlexMono-Regular.ttf": "ofl/ibmplexmono/IBMPlexMono-Regular.ttf",
    "IBMPlexMono-Medium.ttf": "ofl/ibmplexmono/IBMPlexMono-Medium.ttf",
}

# Kept only so the Phase-1 type specimen can be reconstructed.
CANDIDATES = {
    "Anton-Regular.ttf": "ofl/anton/Anton-Regular.ttf",
    "Cinzel-Variable.ttf": "ofl/cinzel/Cinzel%5Bwght%5D.ttf",
    "Oswald-Variable.ttf": "ofl/oswald/Oswald%5Bwght%5D.ttf",
    "Tajawal-Bold.ttf": "ofl/tajawal/Tajawal-Bold.ttf",
    "Tajawal-Black.ttf": "ofl/tajawal/Tajawal-Black.ttf",
}

LICENCE = "ofl/ibmplexsansarabic/OFL.txt"


def fetch(name: str, path: str) -> None:
    dest = os.path.join(OUT, name)
    url = f"{BASE}/{path}"
    try:
        with urllib.request.urlopen(url, timeout=60) as r:
            data = r.read()
    except Exception as exc:                       # noqa: BLE001
        sys.exit(f"FAILED {name}: {exc}\n  {url}")
    with open(dest, "wb") as fh:
        fh.write(data)
    print(f"  {name:<34}{len(data):>9,} B")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true",
                    help="also fetch the pairing candidates")
    args = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)

    print("shipping set")
    for name, path in SHIPPING.items():
        fetch(name, path)

    if args.all:
        print("\npairing candidates")
        for name, path in CANDIDATES.items():
            fetch(name, path)

    print("\nNote: assets/fonts/OFL.txt is hand-assembled — it lists the "
          "copyright holder\nof every bundled family above the shared SIL OFL "
          "1.1 text. Update it by hand\nif the set of families changes.")


if __name__ == "__main__":
    main()
