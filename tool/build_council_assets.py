#!/usr/bin/env python3
"""Turn the supplied Doc-16 artwork into the runtime council asset set.

The supplied PNGs are flat RGB: what looks like transparency is a painted
checkerboard, and every ornament sits on a dark ground. This script keys the
ink out by luminance, registers the three seat rings against a shared box so
state swaps do not jump, and writes the sizes Doc 15 Part 4 asks for.

    python tool/build_council_assets.py
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image

SRC = r"D:\Al Mafia Markting\Mafia Master Assets"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "images", "online")

# Ink starts here and is solid by here. The painted checkerboard and the dark
# ground both sit under LO on every supplied ornament (measured: 17..40).
LO, HI = 52.0, 178.0

SOURCES = {
    "A1": "A1_—_Seat_ring,_idle_202609070030.png",
    "A2": "A2_—_Seat_ring,_cracked_202609070030.png",
    "A3": "A3_—_Seat_ring,_empty_202609070030.png",
    "A4": "A4_—_Panel_corner_ornament_202609070030.png",
    "A5": "A5_—_Timer_ring_ornament_202609070030.png",
    "A6": "A6_—_Night_backdrop_202609070030.png",
    "A7": "A7_—_Dawn_backdrop_202609070030.png",
    "A8": "A8_—_Day_backdrop_202609070030.png",
    "A9": "A9_—_Verdict_backdrop_202609070030.png",
    "A10": "A10_—_Whisper_seal_202609070030.png",
    "A12": "A12_—_Town_victory_emblem_202609070030.png",
    "A13": "A13_—_Mafia_victory_emblem_202609070030.png",
    "A14": "A14_—_Fog_overlay_(connection_202609070044.png",
}

BACKDROP_FRAME = 24  # px of painted gold frame to crop off every backdrop


def load(key: str) -> np.ndarray:
    return np.asarray(Image.open(os.path.join(SRC, SOURCES[key])).convert("RGB")).astype(np.float32)


def luma(rgb: np.ndarray) -> np.ndarray:
    return rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)


def key_alpha(rgb: np.ndarray, lo: float = LO, hi: float = HI) -> np.ndarray:
    """Smoothstep the ink out of its ground. Returns float alpha in 0..1."""
    t = np.clip((luma(rgb) - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def white_ink(alpha: np.ndarray) -> Image.Image:
    """White RGB + keyed alpha, so runtime tinting is exact."""
    h, w = alpha.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[..., :3] = 255
    out[..., 3] = np.round(alpha * 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def alpha_bbox(alpha: np.ndarray, thresh: float = 0.06):
    ys, xs = np.where(alpha > thresh)
    if len(xs) == 0:
        return (0, 0, alpha.shape[1], alpha.shape[0])
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def square(box, w, h, pad_ratio=0.02):
    """Grow a bbox to a centred square with a small breathing margin."""
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    half = max(x1 - x0, y1 - y0) / 2 * (1 + pad_ratio)
    half = min(half, cx, cy, w - cx, h - cy)
    return (int(cx - half), int(cy - half), int(cx + half), int(cy + half))


def save_png(img: Image.Image, name: str, size: int) -> None:
    img = img.resize((size, size), Image.LANCZOS)
    path = os.path.join(OUT, name)
    img.save(path, "PNG", optimize=True)
    return path


def radial(size: int, falloff: float, gamma: float = 1.0) -> Image.Image:
    """A clean procedural glow. The supplied A11/A15 are glow-on-checkerboard,
    where the checker is brighter than the light itself and cannot be keyed."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2.0
    r = np.sqrt((x - c) ** 2 + (y - c) ** 2) / c
    a = np.exp(-((r / falloff) ** 2)) * (1.0 - np.clip(r, 0, 1) ** 3)
    a = np.clip(a, 0, 1) ** gamma
    return white_ink(a)


def backdrop(key: str, name: str, quality: int = 66) -> None:
    rgb = load(key)
    h, w, _ = rgb.shape
    f = BACKDROP_FRAME
    crop = rgb[f:h - f, f:w - f]
    img = Image.fromarray(crop.astype(np.uint8), "RGB")
    # Cover-fit 1080x1920 without distorting.
    tw, th = 1080, 1920
    scale = max(tw / img.width, th / img.height)
    img = img.resize((math.ceil(img.width * scale), math.ceil(img.height * scale)), Image.LANCZOS)
    left = (img.width - tw) // 2
    top = (img.height - th) // 2
    img = img.crop((left, top, left + tw, top + th))
    img.save(os.path.join(OUT, name), "WEBP", quality=quality, method=6)


def main() -> int:
    os.makedirs(OUT, exist_ok=True)

    # --- Seat rings: one shared registration box across all three states -----
    ring_alpha = {k: key_alpha(load(k)) for k in ("A1", "A2", "A3")}
    boxes = [alpha_bbox(a) for a in ring_alpha.values()]
    union = (min(b[0] for b in boxes), min(b[1] for b in boxes),
             max(b[2] for b in boxes), max(b[3] for b in boxes))
    h, w = ring_alpha["A1"].shape
    box = square(union, w, h, pad_ratio=0.03)
    for key, name in (("A1", "seat_ring_idle.png"),
                      ("A2", "seat_ring_cracked.png"),
                      ("A3", "seat_ring_empty.png")):
        img = white_ink(ring_alpha[key]).crop(box)
        save_png(img, name, 512)

    # --- Single ornaments ---------------------------------------------------
    for key, name, size in (("A4", "panel_corner.png", 256),
                            ("A5", "timer_ring.png", 512),
                            ("A10", "whisper_seal.png", 128)):
        a = key_alpha(load(key))
        img = white_ink(a)
        b = alpha_bbox(a)
        if key == "A4":
            img = img.crop(square(b, a.shape[1], a.shape[0], pad_ratio=0.06))
        else:
            img = img.crop(square(b, a.shape[1], a.shape[0], pad_ratio=0.03))
        save_png(img, name, size)

    # --- Victory emblems: shared registration so the swap does not jump -----
    em_alpha = {k: key_alpha(load(k)) for k in ("A12", "A13")}
    boxes = [alpha_bbox(a) for a in em_alpha.values()]
    union = (min(b[0] for b in boxes), min(b[1] for b in boxes),
             max(b[2] for b in boxes), max(b[3] for b in boxes))
    h, w = em_alpha["A12"].shape
    box = square(union, w, h, pad_ratio=0.03)
    save_png(white_ink(em_alpha["A12"]).crop(box), "victory_town.png", 512)
    save_png(white_ink(em_alpha["A13"]).crop(box), "victory_mafia.png", 512)

    # --- Procedural light ---------------------------------------------------
    save_png(radial(64, 0.42, gamma=1.15), "light_mote.png", 64)
    save_png(radial(1024, 0.55, gamma=1.6), "spotlight.png", 1024)

    # --- Fog: keyed from the supplied wisps, stretched full-screen ----------
    fog = key_alpha(load("A14"), lo=26.0, hi=132.0)
    fog_img = white_ink(fog * 0.85).resize((720, 1280), Image.LANCZOS)
    fog_img.save(os.path.join(OUT, "fog_overlay.webp"), "WEBP",
                 quality=70, alpha_quality=42, method=6)

    # --- Backdrops ----------------------------------------------------------
    backdrop("A6", "backdrop_night.webp")
    backdrop("A7", "backdrop_dawn.webp")
    backdrop("A8", "backdrop_day.webp")
    backdrop("A9", "backdrop_verdict.webp")

    total = 0
    for f in sorted(os.listdir(OUT)):
        n = os.path.getsize(os.path.join(OUT, f))
        total += n
        print(f"{f:26} {n:>9,}")
    print(f"{'TOTAL':26} {total:>9,}  ({total / 1048576:.2f} MB)")
    if total > 2 * 1024 * 1024:
        print("OVER the Doc 15 2 MB budget", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
