#!/usr/bin/env python3
"""Builds the launcher icon and the splash image from one source painting.

    python tool/generate_icons.py

Source: `raw_assets/icon/*.jpe?g|png` — the porcelain mask. One file, and it must
be square; everything below is a crop or a scale of it.

## Why this is a script and not `flutter_launcher_icons`

Same reason `normalise_art.py` exists: adding a package to resize six PNGs buys
a config block and a dependency, and this project's standing rule is no new
packages without asking. Pillow is already here for the art pipeline.

## The three things Android wants, and why they are different files

* **Legacy `ic_launcher.png`** — a square bitmap, shown as-is on API < 26 and by
  some launchers since. Full-bleed source.
* **Adaptive foreground/background** (API 26+) — the launcher masks these to
  whatever shape the device uses (circle, squircle, rounded square) and can
  parallax them independently. The mask can eat the outer ~25% on each edge, so
  the foreground is drawn onto a canvas at 1/0.72 scale with the mask centred in
  the safe zone. Skipping that step is why so many icons ship with their subject
  clipped on Pixel launchers.
* **Round `ic_launcher_round.png`** — pre-26 devices that request a circle.

## The splash

Deliberately not the full painting. A launch screen is on screen for a few
hundred milliseconds at a size nobody can study, so it carries the mask alone at
a size that reads instantly, centred on the app's own ground colour. The
`launch_background.xml` layer-list does the centring, so the bitmap here is just
the mask on a transparent field.
"""

from __future__ import annotations

import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "raw_assets", "icon")
ANDROID_RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IOS_ICONS = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")

SUFFIXES = (".png", ".jpg", ".jpeg", ".webp")

# The app's ground, from `AppColors.groundBase` (#0F0F0F). The splash bitmap is
# seated on this so the launch window, the Flutter first frame and the home
# screen are all the same colour and the handover is invisible.
#
# Keep these two in step with `window_background` in
# `android/app/src/main/res/values/ic_launcher_background.xml`; a drift between
# them is a visible band at the top or bottom of the launch window.
GROUND = (15, 15, 15)

# The adaptive icon's own backdrop, behind the launcher's mask. Now the same
# ground as the app: the icon reads as the app's surface with the cream mark on
# it, rather than as a separate near-black tile that happens to share a logo.
ICON_GROUND = (15, 15, 15)

# Android adaptive icons reserve the outer edges for the launcher's mask. 72% is
# the documented safe zone — content outside it may be cropped on some shapes.
ADAPTIVE_SAFE_FRACTION = 0.72

# Legacy launcher icon sizes, in dp * density.
LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive layers are always 108dp square.
ADAPTIVE = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

# Splash bitmap, in dp * density. Sized so the mask reads at a glance without
# filling a phone screen.
SPLASH = {
    "drawable-mdpi": 160,
    "drawable-hdpi": 240,
    "drawable-xhdpi": 320,
    "drawable-xxhdpi": 480,
    "drawable-xxxhdpi": 640,
}


def _source() -> Image.Image:
    if not os.path.isdir(SRC_DIR):
        sys.exit(f"FAIL: no {os.path.relpath(SRC_DIR, ROOT)} directory")
    hits = [
        os.path.join(SRC_DIR, n)
        for n in sorted(os.listdir(SRC_DIR))
        if os.path.splitext(n)[1].lower() in SUFFIXES
    ]
    if not hits:
        sys.exit(f"FAIL: no image in {os.path.relpath(SRC_DIR, ROOT)}")
    if len(hits) > 1:
        sys.exit(
            "FAIL: more than one candidate icon:\n  "
            + "\n  ".join(os.path.basename(h) for h in hits)
            + "\n\nKeep exactly one — picking silently would ship whichever "
              "sorted first."
        )
    img = Image.open(hits[0]).convert("RGB")
    if img.width != img.height:
        sys.exit(
            f"FAIL: {os.path.basename(hits[0])} is {img.width}x{img.height}. "
            f"A launcher icon is square on every platform; crop it first rather "
            f"than letting this script choose which edge to lose."
        )
    print(f"  source {os.path.basename(hits[0])}  {img.width}x{img.height}")
    return img


def _write(img: Image.Image, folder: str, name: str) -> None:
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name)
    img.save(path, "PNG", optimize=True)
    print(f"  {os.path.relpath(path, ROOT):<58} {os.path.getsize(path):>8,} B")


def _circle_mask(size: int) -> Image.Image:
    from PIL import ImageDraw
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def _subject(img: Image.Image) -> Image.Image:
    """The painting with its dead margin trimmed.

    The source is a mask floating on a large field of near-black. Scaled
    straight down to 48px the subject would occupy a third of the icon and read
    as a smudge, so the empty border is measured and cropped before scaling.
    Measured rather than hardcoded, so re-rendering the source at a different
    zoom does not silently change how big the mask looks on a home screen.

    # Why a projection profile and not `getbbox()`

    A plain threshold-and-bbox is decided by the single brightest stray pixel,
    and generated art is full of them: this source has one 111-level pixel in
    the bottom-right corner, on a ground that measures 13–15 everywhere else.
    That one pixel pushed the "subject" out to the full 2048 square and the mask
    came out a third of the size it should have been.

    So instead of asking "is any pixel here bright", each row and column is asked
    "what fraction of you is bright" — and a row has to clear a small fraction to
    count as part of the subject. A lone pixel cannot move a 2048-wide row.
    """
    import numpy as np

    grey = np.asarray(img.convert("L"), dtype=np.float64)
    h, w = grey.shape

    # Comfortably above the ground (13–15 here) and below the dimmest ornament.
    lit = grey > 34.0

    # A row or column counts as subject if this fraction of it is lit.
    span = 0.004

    def extent(profile: "np.ndarray", length: int) -> tuple[int, int]:
        hits = np.where(profile > length * span)[0]
        return (int(hits[0]), int(hits[-1])) if hits.size else (0, length - 1)

    top, bottom = extent(lit.sum(axis=1), w)
    left, right = extent(lit.sum(axis=0), h)

    # Keep it square and centred on the subject, with a little air around it.
    cx, cy = (left + right) / 2, (top + bottom) / 2
    half = max(right - left, bottom - top) / 2 * 1.10
    half = min(half, cx, cy, w - cx, h - cy)
    box = (round(cx - half), round(cy - half), round(cx + half), round(cy + half))
    print(f"  subject rows {top}..{bottom}, cols {left}..{right} "
          f"-> square crop {box}")
    return img.crop(box)


def _seat_on_ground(img: Image.Image, ground: tuple[int, int, int]) -> Image.Image:
    """Maps the painting's own background level onto the app's ground colour.

    The source sits on a near-black field that measures about 15/255. The app's
    ground is `AppColors.deepestShadow`, which is 1/255. Fifteen levels is
    nothing on a colour chart and very obvious on a phone in a dark room: the
    splash showed the mask inside a visible grey disc, and on launchers that
    composite the legacy icon over a themed background the icon had a
    rectangular halo.

    A linear stretch fixes it without touching the subject. The measured
    background maps to the ground, white stays white, and everything between
    moves by less than the amount the background moved — so the mask itself is
    imperceptibly changed while the field it sits on becomes exactly the colour
    the app paints behind it.
    """
    import numpy as np

    a = np.asarray(img, dtype=np.float64)
    # The background is whatever the outer frame is made of. A border sample is
    # immune to the subject's own dark areas in a way a global minimum is not.
    border = np.concatenate([
        a[:8, :, :].reshape(-1, 3),
        a[-8:, :, :].reshape(-1, 3),
        a[:, :8, :].reshape(-1, 3),
        a[:, -8:, :].reshape(-1, 3),
    ])
    src_bg = border.mean(axis=0)
    dst_bg = np.array(ground, dtype=np.float64)

    scale = (255.0 - dst_bg) / np.maximum(255.0 - src_bg, 1e-6)
    out = (a - src_bg) * scale + dst_bg
    print(f"  ground rgb({src_bg.round(1).tolist()}) -> rgb{ground}")
    return Image.fromarray(np.clip(out, 0, 255).astype("uint8"), "RGB")


def main() -> None:
    print("generating launcher icon and splash")
    src = _source()
    subject = _subject(src)
    on_leather = _seat_on_ground(subject, GROUND)
    on_icon_ground = _seat_on_ground(subject, ICON_GROUND)

    print("\n  legacy launcher icons")
    for folder, size in LEGACY.items():
        square = on_icon_ground.resize((size, size), Image.LANCZOS)
        _write(square, os.path.join(ANDROID_RES, folder), "ic_launcher.png")

        round_icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        round_icon.paste(square, (0, 0), _circle_mask(size))
        _write(round_icon, os.path.join(ANDROID_RES, folder),
               "ic_launcher_round.png")

    print("\n  adaptive foreground (subject inside the mask safe zone)")
    for folder, size in ADAPTIVE.items():
        inner = max(1, round(size * ADAPTIVE_SAFE_FRACTION))
        layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        scaled = on_icon_ground.resize((inner, inner), Image.LANCZOS).convert("RGBA")
        offset = (size - inner) // 2
        layer.paste(scaled, (offset, offset))
        _write(layer, os.path.join(ANDROID_RES, folder),
               "ic_launcher_foreground.png")

    print("\n  splash bitmap")
    for folder, size in SPLASH.items():
        layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        layer.paste(on_leather.resize((size, size), Image.LANCZOS).convert("RGBA"))
        _write(layer, os.path.join(ANDROID_RES, folder), "splash.png")

    print("\n  in-app splash asset")
    # The Flutter side of the handover. `SplashGate` draws this at the same size
    # and on the same ground as the native launch window, so the frame the OS
    # tears down and the frame Flutter puts up are the same picture. Without it
    # the mask would pop out of existence the instant the engine started.
    #
    # 640px is the xxxhdpi splash bitmap's size; the widget never draws it
    # larger, so there is nothing to gain from shipping more.
    splash_asset = os.path.join(ROOT, "assets", "images", "splash_mask.webp")
    os.makedirs(os.path.dirname(splash_asset), exist_ok=True)
    on_leather.resize((640, 640), Image.LANCZOS).save(
        splash_asset, "WEBP", quality=88, method=6)
    print(f"  {os.path.relpath(splash_asset, ROOT):<58} "
          f"{os.path.getsize(splash_asset):>8,} B")

    print("\n  ios app icon set")
    if os.path.isdir(IOS_ICONS):
        with open(os.path.join(IOS_ICONS, "Contents.json"), encoding="utf-8") as f:
            contents = json.load(f)
        # iOS icons are opaque and are masked by the OS, so they get the plain
        # square with no safe-zone inset and no alpha — an alpha channel is a
        # hard App Store rejection.
        for entry in contents["images"]:
            name = entry.get("filename")
            if not name:
                continue
            base = float(entry["size"].split("x")[0])
            scale = float(entry["scale"].rstrip("x"))
            px = round(base * scale)
            _write(on_icon_ground.resize((px, px), Image.LANCZOS).convert("RGB"),
                   IOS_ICONS, name)
    else:
        print("  (no ios/ directory — skipped)")

    print("\nNext:")
    print("  flutter build apk --release   # icons are picked up at build time")


if __name__ == "__main__":
    main()
