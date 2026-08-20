#!/usr/bin/env python3
"""Regenerates lib/app/asset_constants.dart from the contents of assets/.

Run from the project root:

    python tool/generate_asset_constants.py

Why generate it: an asset path typed by hand is a runtime crash that no compiler
and no analyzer will catch, and in this app the crash would land in the middle of
a game night. Generating the constants means a missing or renamed file breaks the
build instead.

The script is deliberately dumb — it lists what is on disk. It does not know
what a role is, and it must not: mapping a role to an emblem is product logic and
lives in the widget layer, where the zero-leakage rules about role branching are
actually enforced.
"""

from __future__ import annotations

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
TARGET = os.path.join(ROOT, "lib", "app", "asset_constants.dart")

# folder -> (Dart class name, doc line)
GROUPS = [
    ("images", "AppImages", "Full-bleed textures and backdrops."),
    ("images/gallery", "AppGallery",
     "Post-game role art. Full colour, and deliberately NOT luminance-matched "
     "across roles — these must never be referenced from a surface reachable "
     "while the phone is in a player's hand. handoff_purity_test.dart enforces "
     "that."),
    ("icons", "AppIcons", "Tintable alpha masks. These carry no colour of "
                          "their own; the widget layer supplies it."),
    ("audio", "AppAudio", "Table cues. Never played while the phone is in a "
                          "player's hand — see AudioDirector."),
]

SKIP = {".gitkeep", "OFL.txt"}


def _ident(filename: str) -> str:
    """role_detective.webp -> roleDetective"""
    stem = os.path.splitext(filename)[0]
    parts = re.split(r"[^0-9a-zA-Z]+", stem)
    parts = [p for p in parts if p]
    head, *tail = parts
    return head.lower() + "".join(p.capitalize() for p in tail)


def main() -> None:
    out: list[str] = [
        "// GENERATED FILE — DO NOT EDIT BY HAND.",
        "//",
        "// Regenerate with:  python tool/generate_asset_constants.py",
        "//",
        "// Every path below is declared in pubspec.yaml via its parent",
        "// directory, so adding a file to assets/ and re-running this script is",
        "// all that is needed to make it reachable from Dart.",
        "",
    ]

    total = 0
    for folder, cls, doc in GROUPS:
        path = os.path.join(ASSETS, folder)
        if not os.path.isdir(path):
            continue
        # Files only. A subdirectory is either its own group in GROUPS or is not
        # meant to ship; either way, emitting a constant that points at a folder
        # is a runtime failure this script exists to prevent.
        files = sorted(f for f in os.listdir(path)
                       if f not in SKIP
                       and not f.startswith(".")
                       and os.path.isfile(os.path.join(path, f)))
        if not files:
            continue

        out.append(f"/// {doc}")
        out.append(f"abstract final class {cls} {{")
        for f in files:
            out.append(f"  static const String {_ident(f)} = "
                       f"'assets/{folder}/{f}';")
        out.append("")
        out.append("  /// Every asset in this group, for preloading and for "
                   "the manifest test.")
        out.append("  static const List<String> values = <String>[")
        for f in files:
            out.append(f"    {_ident(f)},")
        out.append("  ];")
        out.append("}")
        out.append("")
        total += len(files)
        print(f"  {cls:<10} {len(files)} asset(s) from assets/{folder}/")

    os.makedirs(os.path.dirname(TARGET), exist_ok=True)
    with open(TARGET, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out))

    print(f"\nwrote {os.path.relpath(TARGET, ROOT)} ({total} assets)")


if __name__ == "__main__":
    main()
