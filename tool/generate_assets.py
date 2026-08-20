#!/usr/bin/env python3
"""Generates every raster asset Mafia Master ships.

Run from the project root:

    python tool/generate_assets.py

The assets are generated rather than drawn by hand for one reason: the
zero-leakage spec (doc 05, rules 3 and 6) requires the four role cards to be
indistinguishable in every respect except the symbol itself. "Indistinguishable"
is a numeric claim, and the only way to actually hold it is to *measure* it.
This script equalises the ink coverage of the four role emblems to within a
fraction of a percent by construction, and prints the measurement so a reviewer
can check the claim instead of trusting it.

Nothing here is random-seeded by accident: the grain uses a fixed seed so that
re-running the script produces byte-identical output and does not churn the
repository.
"""

from __future__ import annotations

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# --- Palette, mirrored from lib/ui/theme/design_tokens.dart -----------------
#
# Sampled from the art-direction reference (a painterly noir playing-card set),
# so the generated surfaces and the Dart tokens come from one source rather than
# two that nearly agree.
SURFACE_BASE = (0x0C, 0x0A, 0x0B)
SURFACE_RAISED = (0x17, 0x14, 0x16)
BORDER_SUBTLE = (0x36, 0x2F, 0x2E)
CANVAS = (0xAF, 0xA1, 0x87)      # aged parchment
RUST = (0xAA, 0x3D, 0x28)        # the reference's one saturated accent
BONE = (0xE9, 0xE4, 0xD9)

# Post-game-only accents, from IMAGE_PROMPTS.md tier 2. These may not appear on
# any in-match surface: a role-conditional colour is a role tell (doc 05 rule 3).
OXBLOOD = (0x72, 0x27, 0x22)
VERDIGRIS = (0x2F, 0x4F, 0x45)
STEEL_BLUE = (0x2C, 0x3D, 0x52)
INDIGO_BLACK = (0x0E, 0x14, 0x24)
AMBER = (0x6B, 0x4A, 0x22)
SEPIA = (0x4A, 0x3A, 0x2A)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES = os.path.join(ROOT, "assets", "images")
ICONS = os.path.join(ROOT, "assets", "icons")
MANIFEST = os.path.join(ROOT, "tool", "manifest.json")

with open(MANIFEST, encoding="utf-8") as _f:
    _MANIFEST = json.load(_f)

_SLOTS = {a["slot"]: a for a in _MANIFEST["assets"]}


def slot_path(slot: str) -> str:
    """Absolute output path for a manifest slot."""
    return os.path.join(ROOT, _SLOTS[slot]["out"])


def slot_size(slot: str) -> tuple[int, int]:
    w, h = _SLOTS[slot]["size"]
    return w, h


def slot_quality(slot: str) -> int:
    return _SLOTS[slot]["quality"]


def slot_band(slot: str) -> tuple[float, float] | None:
    band = _SLOTS[slot].get("lum_band")
    return (band[0], band[1]) if band else None

# Supersampling factor for all vector-ish drawing. PIL has no anti-aliasing of
# its own, so everything is drawn at 4x and box-filtered down.
SS = 4

CARD_W, CARD_H = 1024, 1536   # 2:3, the ratio the card container settles at
EMBLEM = 512


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def _radial_vignette(w: int, h: int, strength: float, power: float = 2.0):
    """Returns a 0..1 multiplier array that darkens towards the corners."""
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    # Normalised radius, 0 at centre, 1 at the mid-edge.
    r = np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2) / math.sqrt(2)
    return 1.0 - strength * np.clip(r, 0, 1) ** power


def _vertical_gradient(w: int, h: int, top, bottom):
    t = np.linspace(0.0, 1.0, h)[:, None]
    out = np.zeros((h, w, 3), dtype=np.float64)
    for c in range(3):
        out[:, :, c] = top[c] * (1 - t) + bottom[c] * t
    return out


def _fbm(w: int, h: int, beta: float, seed: int, octaves_from: int = 2):
    """Perfectly tileable fractal noise, normalised to 0..1.

    Built in the frequency domain: fill a spectrum whose magnitude falls off as
    1/f**beta, randomise the phases, and inverse-transform. Doing it this way
    rather than by summing scaled random grids gives noise that wraps exactly at
    the edges — the app tiles this over surfaces, and a visible seam repeating
    down a list is worse than no texture at all.

    `beta` sets how the energy is distributed: ~2.4 gives the soft, cloudy
    mottling of a primed canvas, higher values give broader and smoother
    blotches, lower values approach white noise.
    """
    rng = np.random.default_rng(seed)
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt(fx ** 2 + fy ** 2)
    f[0, 0] = 1.0                              # avoid dividing by zero at DC

    amplitude = 1.0 / (f ** beta)
    # Kill the lowest octaves: they would show up as one huge gradient across
    # the tile and fight the deliberate vignette instead of reading as texture.
    amplitude[f < (octaves_from / max(w, h))] = 0.0
    amplitude[0, 0] = 0.0

    phase = rng.uniform(0, 2 * np.pi, size=(h, w))
    field = np.fft.ifft2(amplitude * np.exp(1j * phase)).real

    field -= field.min()
    return field / (field.max() or 1.0)


def _blur(field: np.ndarray, sigma: float) -> np.ndarray:
    """Gaussian-blurs a 0..1 float field. Used for light, not for pixels."""
    img = Image.fromarray(np.clip(field * 255.0, 0, 255).astype(np.uint8))
    return np.asarray(
        img.filter(ImageFilter.GaussianBlur(sigma)), dtype=np.float64) / 255.0


def _halftone(w: int, h: int, period: float, angle_deg: float):
    """A rotated print screen, as a signed -1..1 field.

    The reference is a worn antique print, and what says "printed" more than
    anything is a regular dot screen sitting under the brushwork. Rotated off
    axis so it never aligns with the pixel grid and moires.

    Measured from the image *centre* rather than from the origin, which makes the
    field invariant under a 180 degree rotation: `sin` is odd, so rotating sends
    (u, v) to (-u, -v) and sin(-u)sin(-v) = sin(u)sin(v). That matters for the
    card back, which has to survive being dealt upside down — see [_sym].
    """
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    a = math.radians(angle_deg)
    u = (xx - cx) * math.cos(a) + (yy - cy) * math.sin(a)
    v = -(xx - cx) * math.sin(a) + (yy - cy) * math.cos(a)
    return np.sin(u * math.pi / period) * np.sin(v * math.pi / period)


def _sym(field: np.ndarray) -> np.ndarray:
    """Averages a field with its own 180 degree rotation.

    Makes anything exactly invariant under `rotate(180)`, which is what the card
    back has to be: it is the one image the whole table looks at while a player
    holds their card, and a back that is distinguishable from its own upside-down
    self introduces a visible difference between one player's card and another's
    that has nothing to do with the game. Cheap to guarantee, so guarantee it
    rather than hope no card gets dealt the other way up.

    Averaging halves the variance of a noise field, so callers that pass grain
    should scale it back up.
    """
    return 0.5 * (field + field[::-1, ::-1])


def _grain(w: int, h: int, sigma: float, seed: int):
    rng = np.random.default_rng(seed)
    n = rng.normal(0.0, sigma, size=(h, w))
    # Slight blur so the grain reads as film, not as sensor noise.
    n = np.asarray(
        Image.fromarray(np.clip(n + 128, 0, 255).astype(np.uint8))
        .filter(ImageFilter.GaussianBlur(0.6)),
        dtype=np.float64,
    ) - 128.0
    return n[:, :, None]


def _light_cone(w: int, h: int, x0: float, spread: float, reach: float):
    """A hard theatrical light cone widening downwards from the top edge.

    Returns a 0..1 field. `x0` is the apex in normalised x, `spread` how fast it
    opens, `reach` how far down the beam carries before it dies.
    """
    yy, xx = np.mgrid[0:h, 0:w]
    ny, nx = yy / h, xx / w
    width = 0.02 + spread * ny
    beam = np.exp(-(((nx - x0) / width) ** 2))
    return beam * np.clip(1.0 - ny / reach, 0, 1) ** 1.4


def _point_glow(w: int, h: int, x0: float, y0: float, radius: float,
                power: float = 2.2):
    """A soft radial falloff around a normalised point. 0..1."""
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx / w) - x0) ** 2 + (((yy / h) - y0) * (h / w)) ** 2)
    return np.clip(1.0 - d / radius, 0, 1) ** power


def _gain_into_band(base: np.ndarray, band: tuple[float, float]) -> np.ndarray:
    """Scales an image so its mean Rec. 709 luminance lands mid-band.

    Applied to every tier 3 backdrop before it is written, so the shipped file
    already satisfies the band `tool/normalise_art.py` will later hold real
    artwork to. Without this the procedural placeholder and the AI replacement
    would sit at different brightnesses and every screen would shift when the art
    is swapped in.
    """
    lo, hi = band
    mid = (lo + hi) / 2.0
    clipped = np.clip(base, 0, 255)
    lum = float((0.2126 * clipped[:, :, 0] + 0.7152 * clipped[:, :, 1]
                 + 0.0722 * clipped[:, :, 2]).mean())
    if lum <= 0:
        return clipped
    out = np.clip(clipped * (mid / lum), 0, 255)
    actual = float((0.2126 * out[:, :, 0] + 0.7152 * out[:, :, 1]
                    + 0.0722 * out[:, :, 2]).mean())
    if actual > 0:
        out = np.clip(out * (mid / actual), 0, 255)
    return out


def _rec709(a: np.ndarray) -> float:
    return float((0.2126 * a[:, :, 0] + 0.7152 * a[:, :, 1]
                  + 0.0722 * a[:, :, 2]).mean())


def _save(img: Image.Image, path: str, **kw) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, **kw)
    print(f"  {os.path.relpath(path, ROOT):<44} {os.path.getsize(path):>8,} B")


# ---------------------------------------------------------------------------
# card back — one file, used by all four roles, byte-identical by definition
# ---------------------------------------------------------------------------

def card_back() -> float:
    """The one shared card back (manifest tier 1, slot `card_back`).

    The single most leakage-critical asset in the app: it is what the table looks
    at for the whole time a player is holding their card. There is exactly one
    file, so a per-role back cannot drift into existence, and
    `asset_manifest_test.dart` fails the build if a second one appears.

    ## Rotationally symmetric, and provably so

    The prompt pack requires this image to be "identical if turned upside down".
    Rather than eyeball it, everything here is either symmetric by construction
    (rings and rosettes measured from the centre; even angular harmonics; a
    centred halftone screen) or run through [_sym], which averages a field with
    its own 180 degree rotation. `card_back_symmetry_test.dart` re-measures the
    property from the shipped bytes.

    ## Why it pairs with the face rather than matching it

    The face is a shaft of light with arcs struck from a centre above the frame —
    directional, asymmetric, lit. The back is its opposite: a closed concentric
    medallion, evenly lit, going nowhere. Same ground, same parchment linework,
    same halftone and grain, opposite geometry. Two faces of one card, which is
    what the reference deck does.

    Ornament is kept inside a centred circle of radius 0.40 x the short edge. The
    widget draws this with `BoxFit.cover` into a box of unknown aspect, so
    anything further out than that can be cropped off on a narrow phone.
    """
    w, h = slot_size("card_back")

    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    theta = np.arctan2(yy - cy, xx - cx)
    short = min(w, h)

    # Radial ground rather than a vertical gradient. A gradient would make the
    # top lighter than the bottom, which is exactly the asymmetry the upside-down
    # requirement forbids.
    base = np.zeros((h, w, 3), dtype=np.float64)
    ground = 0x22 - 0x12 * np.clip(r / (0.62 * short), 0, 1) ** 1.5
    base += ground[:, :, None] * np.array([1.0, 0.94, 0.95])

    # Painterly ground: the mottling is most of why this reads as a painted
    # surface rather than as UI fill. Symmetrised so it cannot betray an
    # orientation.
    base += _sym(_fbm(w, h, 2.4, seed=11) - 0.5)[:, :, None] * 24.0

    parchment = np.array(CANVAS) / 255.0

    # Concentric rings. Two tight pairs, as engraved rules on a banknote.
    ring = np.zeros((h, w), dtype=np.float64)
    for radius, weight, width in (
        (0.150 * short, 13.0, 0.0030 * short),
        (0.172 * short, 6.0, 0.0018 * short),
        (0.293 * short, 18.0, 0.0032 * short),
        (0.315 * short, 8.0, 0.0018 * short),
        (0.392 * short, 10.0, 0.0022 * short),
    ):
        ring += weight * np.exp(-((r - radius) ** 2) / (2 * width ** 2))
    base += ring[:, :, None] * parchment

    # The rosette, in the annulus between the ring pairs. `cos(theta * 12)` has
    # twelve lobes — an even count, so it maps onto itself under a half turn.
    #
    # The radial term is deliberately fine (~23px period): the petals should be
    # built out of engraved lines the way intaglio builds a tone, not painted as
    # twelve solid blobs.
    petal_window = (_smoothstep((r - 0.176 * short) / (0.028 * short))
                    * (1.0 - _smoothstep((r - 0.268 * short) / (0.028 * short))))
    rosette = np.sin(r / (0.0036 * short)) * np.cos(theta * 12.0) * 11.0
    base += (rosette * petal_window)[:, :, None] * parchment

    # Radial ticks just inside the outer rule — 48 of them, again even.
    tick_window = (_smoothstep((r - 0.330 * short) / (0.014 * short))
                   * (1.0 - _smoothstep((r - 0.382 * short) / (0.014 * short))))
    ticks = np.clip(np.cos(theta * 48.0), 0, 1) ** 7 * 13.0
    base += (ticks * tick_window)[:, :, None] * parchment

    # Fine concentric hatching over the whole medallion, near the resolution
    # limit so it reads as engraving rather than as pattern — the same treatment
    # the face uses inside its beam.
    medallion = 1.0 - _smoothstep((r - 0.400 * short) / (0.040 * short))
    base += (np.sin(r / 1.75) * 2.2 * medallion)[:, :, None]

    # A dark seat under the medallion, so the ornament sits in something rather
    # than floating on the ground.
    base -= (_point_glow(w, h, 0.5, 0.5, 0.46, power=1.3) * 5.0)[:, :, None]

    # Distressed edge: worn where the print has rubbed off the border.
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy]).astype(float)
    wear = np.clip(1.0 - edge / 46.0, 0, 1) ** 2 * _sym(_fbm(w, h, 1.6, seed=12))
    base += (wear * 15.0)[:, :, None] * parchment

    base *= _radial_vignette(w, h, 0.45)[:, :, None]
    base += _halftone(w, h, period=2.4, angle_deg=24.0)[:, :, None] * 1.5
    # Scaled up by sqrt(2) because symmetrising halves a noise field's variance.
    base += _sym(_grain(w, h, 3.2, seed=101)[:, :, 0])[:, :, None] * math.sqrt(2)

    out = np.clip(base, 0, 255)
    img = Image.fromarray(out.astype(np.uint8), "RGB")
    _save(img, slot_path("card_back"), quality=slot_quality("card_back"),
          method=6)
    _save(img, os.path.join(ROOT, "tool", "preview", "card_back.png"),
          optimize=True)
    return _rec709(out)


# ---------------------------------------------------------------------------
# card face base — also shared; the role only ever adds an emblem on top
# ---------------------------------------------------------------------------

def _smoothstep(x: np.ndarray) -> np.ndarray:
    t = np.clip(x, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------------------
# role emblems
# ---------------------------------------------------------------------------
#
# Each emblem is drawn as an alpha mask on a transparent canvas at a given
# scale about the canvas centre. The scale is then solved so that all four
# emblems lay down the same amount of ink. See `equalise()`.

def _blank():
    return Image.new("L", (EMBLEM * SS, EMBLEM * SS), 0)


def _pt(x: float, y: float, s: float):
    """Scales a design-space point about the centre, into supersampled space."""
    c = EMBLEM / 2.0
    return ((c + (x - c) * s) * SS, (c + (y - c) * s) * SS)


def _box(x0, y0, x1, y1, s):
    a = _pt(x0, y0, s)
    b = _pt(x1, y1, s)
    return [a[0], a[1], b[0], b[1]]


# Every emblem is drawn inside the same nominal 344x364 box, centred. Only its
# internal weight varies, which is what the solver below tunes.
INK_TARGET = 0.27


def emblem_mafia(w: float) -> Image.Image:
    """A theatrical mask: rounded brow tapering to a chin, with cut openings.

    [w] scales the eye and mouth openings, so ink *decreases* as w grows.
    """
    img = _blank()
    d = ImageDraw.Draw(img)

    # Body: superellipse, wider at the brow than at the chin.
    pts = []
    for i in range(721):
        t = i * math.pi / 360.0
        ct, st = math.cos(t), math.sin(t)
        # Exponent < 2 squares the brow off slightly; the y radius grows below
        # the midline to pull the shape down into a chin.
        rx = 172.0 * math.copysign(abs(ct) ** 0.86, ct)
        ry = (152.0 if st < 0 else 210.0) * math.copysign(abs(st) ** 0.94, st)
        pts.append(_pt(256 + rx, 248 + ry, 1.0))
    d.polygon(pts, fill=255)

    # Eye holes: almond, angled inwards.
    for sign in (-1, 1):
        eye = _blank()
        ImageDraw.Draw(eye).ellipse(
            _box(256 + sign * 84 - 56 * w, 224 - 38 * w,
                 256 + sign * 84 + 56 * w, 224 + 38 * w, 1.0), fill=255)
        eye = eye.rotate(-sign * 12.0, center=_pt(256 + sign * 84, 224, 1.0),
                         resample=Image.BILINEAR)
        img = Image.composite(Image.new("L", img.size, 0), img, eye)

    # Mouth: a narrow slit, which also stops the chin reading as a blank egg.
    mouth = _blank()
    ImageDraw.Draw(mouth).ellipse(
        _box(256 - 66 * w, 356 - 15 * w, 256 + 66 * w, 356 + 15 * w, 1.0),
        fill=255)
    img = Image.composite(Image.new("L", img.size, 0), img, mouth)
    return img


def emblem_doctor(w: float) -> Image.Image:
    """A minimal medical cross. [w] is the arm half-thickness in design px."""
    img = _blank()
    d = ImageDraw.Draw(img)
    half = 172.0
    r = min(22.0, w * 0.3) * SS
    d.rounded_rectangle(_box(256 - half, 248 - w, 256 + half, 248 + w, 1.0),
                        radius=r, fill=255)
    d.rounded_rectangle(_box(256 - w, 248 - half, 256 + w, 248 + half, 1.0),
                        radius=r, fill=255)
    return img


def emblem_detective(w: float) -> Image.Image:
    """A magnifier. [w] is the ring thickness; the handle scales with it."""
    img = _blank()
    cx, cy, outer = 234.0, 208.0, 170.0

    ImageDraw.Draw(img).ellipse(
        _box(cx - outer, cy - outer, cx + outer, cy + outer, 1.0), fill=255)
    hole = _blank()
    ImageDraw.Draw(hole).ellipse(
        _box(cx - outer + w, cy - outer + w,
             cx + outer - w, cy + outer - w, 1.0), fill=255)
    img = Image.composite(Image.new("L", img.size, 0), img, hole)

    # Handle, drawn axis-aligned then rotated about the lens centre.
    handle = _blank()
    hw = w * 0.62
    ImageDraw.Draw(handle).rounded_rectangle(
        _box(cx - hw, cy + outer - w * 0.5, cx + hw, cy + outer + 150, 1.0),
        radius=hw * SS, fill=255)
    handle = handle.rotate(-45.0, center=_pt(cx, cy, 1.0),
                           resample=Image.BILINEAR)
    img = Image.composite(Image.new("L", img.size, 255), img, handle)
    return img


def emblem_citizen(w: float) -> Image.Image:
    """A bust silhouette. [w] scales head and shoulders about the centre."""
    img = _blank()
    ImageDraw.Draw(img).ellipse(
        _box(256 - 86 * w, 146 - 86 * w, 256 + 86 * w, 146 + 86 * w, 1.0),
        fill=255)

    shoulders = _blank()
    ImageDraw.Draw(shoulders).ellipse(
        _box(256 - 172 * w, 296, 256 + 172 * w, 296 + 300 * w, 1.0), fill=255)
    # Flat cut at the base so the bust reads as a silhouette rather than an egg,
    # and so the emblem stays inside the shared bounding box.
    ImageDraw.Draw(shoulders).rectangle(
        [0, _pt(0, 430, 1.0)[1], EMBLEM * SS, EMBLEM * SS], fill=0)
    img = Image.composite(Image.new("L", img.size, 255), img, shoulders)
    return img


# role -> (draw fn, weight search range, does ink rise with w?)
EMBLEMS = {
    "mafia": (emblem_mafia, (0.55, 1.95), False),
    "doctor": (emblem_doctor, (30.0, 120.0), True),
    "detective": (emblem_detective, (24.0, 130.0), True),
    "citizen": (emblem_citizen, (0.60, 1.45), True),
}


def _coverage(img: Image.Image) -> float:
    """Mean alpha of the downsampled emblem, 0..1. This is the 'ink'."""
    small = img.resize((EMBLEM, EMBLEM), Image.LANCZOS)
    return float(np.asarray(small, dtype=np.float64).mean() / 255.0)


def equalise() -> dict[str, float]:
    """Solves each emblem's internal weight so all four lay down equal ink.

    An earlier version of this solved a uniform *scale* instead. It hit the ink
    budget just as precisely and looked wrong: matching a solid mask to a thin
    outlined magnifier by area forces the mask to shrink and the magnifier to
    grow, so the four cards read as four different sizes. Holding the bounding
    box fixed and varying stroke weight instead keeps the set optically even,
    which is what a player actually perceives, while still hitting the budget.

    Bisection rather than Newton: each emblem is monotone in its weight but the
    relationship is piecewise (rounded joins, rotated overlaps), and bisection
    cannot overshoot into a degenerate shape.
    """
    print(f"\n  emblem ink coverage — target {INK_TARGET * 100:.3f}%")
    print(f"  {'role':<11}{'weight':>10}{'final ink':>12}{'drift':>9}")

    solved: dict[str, float] = {}
    for role, (fn, (lo, hi), rising) in EMBLEMS.items():
        for _ in range(40):
            mid = (lo + hi) / 2.0
            c = _coverage(fn(mid))
            if (c < INK_TARGET) == rising:
                lo = mid
            else:
                hi = mid
            if abs(c - INK_TARGET) / INK_TARGET < 1e-5:
                break
        solved[role] = mid

        drift = (c - INK_TARGET) / INK_TARGET * 100.0
        print(f"  {role:<11}{mid:>10.4f}{c * 100:>11.4f}%{drift:>8.3f}%")
        if abs(drift) > 0.5:
            sys.exit(f"FAIL: {role} is {drift:.3f}% off the ink budget")

    return solved


def write_emblems(weights: dict[str, float]) -> None:
    print()
    for k, (fn, _range, _rising) in EMBLEMS.items():
        mask = fn(weights[k]).resize((EMBLEM, EMBLEM), Image.LANCZOS)
        # Pure white, shaped by alpha: the widget layer tints it, so the file
        # itself carries no colour and cannot leak one.
        out = Image.merge("RGBA", (
            Image.new("L", mask.size, 255),
            Image.new("L", mask.size, 255),
            Image.new("L", mask.size, 255),
            mask,
        ))
        _save(out, os.path.join(ICONS, f"role_{k}.webp"),
              lossless=True, quality=100, method=6)


# ---------------------------------------------------------------------------
# ambient textures
# ---------------------------------------------------------------------------

def canvas_texture() -> None:
    """The tileable canvas sheet laid over app surfaces.

    This is the single asset that carries the reference's painterly feel across
    the whole app rather than only onto the cards. It is deliberately one
    texture doing two jobs at two scales: broad cloudy mottling (the primed
    ground) plus fine tooth (the weave). Shipping them as two overlays would
    mean two draws over every surface for an effect nobody could separate.

    Tiles seamlessly because [_fbm] is built in the frequency domain, so it can
    be repeated behind a long scrolling list without a visible grid.
    """
    # Fine tooth only, and small.
    #
    # Noise is close to incompressible, so a 512px sheet carrying both the broad
    # mottling and the weave cost ~190 KB — more than every other image in the
    # app combined, for a decorative overlay. The broad mottling is therefore
    # baked into the large surfaces that need it (card back, card face, home
    # backdrop), where it rides along in an image those screens already load,
    # and this tile carries only the high-frequency weave. Fine grain has no
    # structure to recognise, so it tiles invisibly at a fraction of the size.
    n = 192
    # beta ~1.7 rather than near-white-noise: a woven ground has some
    # correlation between neighbouring threads, and pure white noise reads as
    # digital speckle — "snow" — instead of cloth.
    tooth = _fbm(n, n, 1.7, seed=32, octaves_from=5)
    field = tooth - 0.5

    # Signed field -> alpha. The texture is applied as an overlay, so what
    # matters is the *deviation* from neutral, not the level.
    #
    # These multipliers are deliberately low. The tile is baked subtle rather
    # than left strong and dialled back with an opacity in Dart, because the
    # opacity is a number someone will eventually raise "to see the texture
    # better" — and the point of this sheet is to be felt, not noticed.
    alpha = np.clip(np.abs(field) * 170.0, 0, 190).astype(np.uint8)
    grey = np.clip(128 + field * 120.0, 0, 255).astype(np.uint8)

    img = Image.merge("RGBA", (
        Image.fromarray(grey), Image.fromarray(grey),
        Image.fromarray(grey), Image.fromarray(alpha)))
    # Lossy: this is a low-opacity overlay, so per-pixel fidelity buys nothing
    # and lossless RGBA costs ~250 KB for one decorative sheet.
    _save(img, os.path.join(IMAGES, "canvas_texture.webp"),
          quality=72, alpha_quality=90, method=6)


def home_backdrop() -> None:
    """The one ambient image, behind Home and Result only.

    This is the *warm* register of the reference — its rust-and-parchment card
    rather than its monochrome one. Home and Result are public surfaces: the
    phone is flat on the table with nothing secret on screen, so the palette
    restriction that governs night screens does not apply, and this is where the
    app gets to state its identity in colour.
    """
    w, h = 1080, 1920
    base = _vertical_gradient(w, h, (0x30, 0x23, 0x1E), (0x0A, 0x08, 0x08))

    base += (_fbm(w, h, 2.6, seed=41) - 0.5)[:, :, None] * 22.0

    yy, xx = np.mgrid[0:h, 0:w]
    # Light shafts raking down from the upper right, as if through a blind.
    # Warmed towards the reference's rust. Low amplitude — this sits behind the
    # wordmark and the primary action and must never compete with them.
    for x0, width, amp, tint in (
        (0.62, 0.085, 46.0, RUST),
        (0.80, 0.055, 26.0, CANVAS),
    ):
        band = np.exp(-(((xx / w - x0) - (yy / h) * 0.16) ** 2) / (2 * width ** 2))
        falloff = np.clip(1.0 - yy / h, 0, 1) ** 1.5
        base += (band * falloff * amp)[:, :, None] * (np.array(tint) / 255.0)

    # A low ember glow along the bottom edge, so the screen is not uniformly
    # dark behind the buttons.
    ember = np.clip((yy / h - 0.72) / 0.28, 0, 1) ** 2
    base += (ember * 26.0)[:, :, None] * (np.array(RUST) / 255.0)

    base *= _radial_vignette(w, h, 0.42, power=1.6)[:, :, None]
    base += _grain(w, h, 2.4, seed=303)

    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB")
    _save(img, os.path.join(IMAGES, "home_backdrop.webp"), quality=84, method=6)


# ---------------------------------------------------------------------------

def main() -> None:
    only = sys.argv[1:]
    targets = {"card_back": card_back}

    if only:
        unknown = [t for t in only if t not in targets]
        if unknown:
            sys.exit(f"unknown target(s): {' '.join(unknown)}\n"
                     f"usage: generate_assets.py [{' | '.join(targets)}]")
        print("card surfaces")
        for t in only:
            lum = targets[t]()
            print(f"  {t} mean luminance {lum:6.2f}/255")
        return

    print("card surfaces")
    back_l = card_back()

    scales = equalise()
    write_emblems(scales)

    print("\nambient")
    canvas_texture()
    home_backdrop()

    print(f"\n  card back mean luminance  {back_l:6.2f}/255")
    print(f"  card face mean luminance  {face_l:6.2f}/255")
    print("\ndone.")


if __name__ == "__main__":
    main()
