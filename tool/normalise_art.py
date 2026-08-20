#!/usr/bin/env python3
"""Turns raw AI-generated art into shippable, measured assets.

    # source art goes in raw_assets/ (matched by the manifest's raw_match) or in
    # tool/incoming/ named exactly by manifest slot:
    #   raw_assets/Mafia_figure_in_archway_....jpeg
    #   tool/incoming/bg_night.png
    python tool/normalise_art.py                 # process everything present
    python tool/normalise_art.py bg_night        # one slot
    python tool/normalise_art.py --check         # measure only, write nothing

Everything is driven by `tool/manifest.json`, so adding an asset means editing
the manifest rather than this file.

## Why a generated image is not a shippable image

An image model cannot hold a luminance budget. Ask for four cards in one palette
and you get four that *look* like a set and measure 10-20% apart in mean
brightness — invisible on a monitor, and precisely what doc 05 rule 3 forbids,
because the brightest surface throws the most light onto its holder's face.

So art is generated freely and forced onto the budget here. Nothing downstream
has to trust the generator.

## The face set is the whole reason this script is ship-blocking

The four in-match role faces are four distinct files. Cross-role parity is
therefore **not** structural any more — there is no shared base making divergence
impossible — and this script plus `luminance_budget_test.dart` are the only things
standing between the art and a role tell.

`face_set` slots are handled together, not one at a time:

1. every one is scaled **whole** into the same 1024x1536 card box — never
   cropped, because the painted border, corner letter and corner icon are part
   of the artwork — and centred on the `card_ground` colour;
2. the set mean luminance of the *composited box* is computed, and each face is
   gained onto it;
3. the worst residual drift is measured and the script **exits non-zero** if any
   face is outside +/-2%.

Step 3 is the point. A partial write here would ship a leak, so the four faces are
only written once all four have passed — see [normalise_face_set].

A gain, not an offset: scaling preserves each image's internal contrast ratios,
where adding a constant washes the blacks out of whichever card started darkest,
and flat black is most of what makes these read as noir. A gain is also the only
processing a face gets — no crop, no desaturation, no cast stripping, no overlay.
Colour cast is measured and printed, and nothing corrects it.

## What each tier gets

* **Tier 1** (the four faces, `card_back`) — the only images an in-hand surface
  may show. Letterboxed whole into the card box and luminance-matched.
* **Tier 2** (`gallery/*`) — post-game only. Cropped and re-encoded, colour left
  alone. Nobody sees these until every role is already public.
* **Tier 3** (`bg_*`) — public backdrops. Gained into the manifest's `lum_band`
  so bone-white text keeps its contrast ratio whatever the art does.
* **Tier 4** — outcome plates and the badge frame. Cropped, re-encoded, otherwise
  left as generated.

## What it refuses to do

Anything not in the manifest. A file in `incoming/` with no matching slot is a
hard error, not a warning — an unmanifested asset is one nothing measures.
"""

from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INCOMING = os.path.join(ROOT, "tool", "incoming")
RAW = os.path.join(ROOT, "raw_assets")
MANIFEST = os.path.join(ROOT, "tool", "manifest.json")

SUFFIXES = (".png", ".jpg", ".jpeg", ".webp")

# The same +/-2% the app's own tests enforce. Deliberately not looser here: this
# script is what makes the claim, and a pipeline that signs off at 3% so the test
# can fail at 2% is just a slower way to ship a leak.
FACE_BUDGET = 0.02


def _luminance(a: np.ndarray) -> float:
    """Mean Rec. 709 luminance of an RGB array in 0..255."""
    return float(
        (0.2126 * a[:, :, 0] + 0.7152 * a[:, :, 1] + 0.0722 * a[:, :, 2]).mean()
    )


def _fit(img: Image.Image, w: int, h: int, alpha: bool) -> Image.Image:
    """Centre-crops to the target aspect, then resizes."""
    img = img.convert("RGBA" if alpha else "RGB")
    target = w / h
    sw, sh = img.size
    if sw / sh > target:                       # too wide -> crop sides
        new_w = int(sh * target)
        left = (sw - new_w) // 2
        img = img.crop((left, 0, left + new_w, sh))
    else:                                      # too tall -> crop top/bottom
        new_h = int(sw / target)
        top = (sh - new_h) // 2
        img = img.crop((0, top, sw, top + new_h))
    return img.resize((w, h), Image.LANCZOS)


def _fold_180(a: np.ndarray) -> np.ndarray:
    """Makes an image *exactly* identical to its own 180-degree rotation.

    The card back is the one image the table looks at all game, and a player who
    can tell which way up it was dealt can read something the rules never gave
    them. "Symmetrical" in a generation prompt buys approximate symmetry: the
    back that came back from the model measured 22.4 levels off its own rotation,
    which is plainly visible.

    Averaging the image with its rotation would close the gap but ghost every
    asymmetric detail into a double exposure. Instead this does what a real
    playing card does — it keeps the top half and stamps the rotated copy of it
    into the bottom half. The seam falls on the centre line, where a
    point-symmetric design already has one, and the result is symmetric by
    construction rather than to within a tolerance. Half the source art is
    discarded; that is the price of the guarantee.

    Odd heights keep their middle row untouched, so it must be symmetric on its
    own to survive the test. Even heights (the manifest ships 1536) have no such
    row.
    """
    h = a.shape[0]
    half = h // 2
    out = a.copy()
    out[h - half:] = a[:half][::-1, ::-1]
    return out


def _gain_to(a: np.ndarray, target: float) -> np.ndarray:
    """Scales `a` so its mean luminance is `target`, re-solving after clipping."""
    current = _luminance(a)
    if current <= 0:
        return a
    out = np.clip(a * (target / current), 0, 255)
    # Clipping at 255 loses energy on the brightest pixels, so solve once more
    # against the clipped result rather than trusting the first ratio.
    actual = _luminance(out)
    if actual > 0:
        out = np.clip(out * (target / actual), 0, 255)
    return out


def _source_path(entry: dict) -> str | None:
    """Finds the source file for a slot.

    Two places, in priority order:

    * `tool/incoming/<slot>.<ext>` — the canonical drop, named by slot. What
      `generate_art_ai.py` writes and what a re-run should use.
    * `raw_assets/*<raw_match>*` — art delivered under whatever name the tool that
      made it chose. The manifest carries the substring rather than this script,
      so the filename-to-role mapping is reviewable data instead of buried logic.

    A `raw_match` that hits more than one file is an error, not a coin toss:
    picking the wrong one silently maps the wrong art to a role.
    """
    slot = entry["slot"]
    for ext in SUFFIXES:
        p = os.path.join(INCOMING, slot + ext)
        if os.path.exists(p):
            return p

    match = entry.get("raw_match")
    if match and os.path.isdir(RAW):
        hits = [
            os.path.join(RAW, n) for n in sorted(os.listdir(RAW))
            if match.lower() in n.lower()
            and os.path.splitext(n)[1].lower() in SUFFIXES
        ]
        if len(hits) > 1:
            sys.exit(
                f"FAIL: raw_match '{match}' for slot {slot} matches "
                f"{len(hits)} files:\n  " + "\n  ".join(
                    os.path.basename(h) for h in hits)
                + "\n\nMake it unambiguous — an accidental match would put the "
                  "wrong artwork on a role."
            )
        if hits:
            return hits[0]
    return None


def _load(entry: dict) -> tuple[Image.Image, str] | tuple[None, None]:
    p = _source_path(entry)
    if p is None:
        return None, None
    return Image.open(p), p


def _save(img: Image.Image, out_rel: str, quality: int) -> int:
    path = os.path.join(ROOT, out_rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    kwargs = {"quality": quality, "method": 6}
    if img.mode == "RGBA":
        kwargs["alpha_quality"] = 90
    img.save(path, **kwargs)
    return os.path.getsize(path)


def load_manifest() -> dict:
    with open(MANIFEST, encoding="utf-8") as f:
        return json.load(f)


def check_incoming(manifest: dict) -> list[str]:
    """Fails loudly on anything in incoming/ with no manifest slot."""
    slots = {a["slot"] for a in manifest["assets"]}
    slots |= {e["slot"] for e in manifest["emblems"]}

    if not os.path.isdir(INCOMING):
        return []

    orphans = []
    for name in sorted(os.listdir(INCOMING)):
        stem, ext = os.path.splitext(name)
        if ext.lower() not in SUFFIXES:
            continue
        if stem not in slots:
            orphans.append(name)
    return orphans


def _contain(img: Image.Image, w: int, h: int) -> Image.Image:
    """Resizes to fit *inside* w x h without cropping a single pixel.

    The counterpart of `_fit`, which crops. The four paintings are finished
    artwork: the painted card border, the corner letter and the corner icon are
    part of the picture, and a centre-crop to 2:3 removes them. So the art is
    scaled to fit and the frame absorbs the difference.
    """
    sw, sh = img.size
    scale = min(w / sw, h / sh)
    return img.convert("RGB").resize(
        (max(1, round(sw * scale)), max(1, round(sh * scale))), Image.LANCZOS)


def _composite(art: np.ndarray, frame: tuple[int, int],
               ground: tuple[int, int, int]) -> np.ndarray:
    """Centres `art` on a `ground`-filled frame. This is what the card emits.

    Luminance has to be solved on this, not on the painting alone. The three
    finished paintings are 0.7467 aspect and the mafia is 0.8733; letterboxed into
    one fixed card box they cover different fractions of it, so two paintings at
    identical mean brightness still throw different amounts of light at the room.
    Matching the composited box is matching what a person across the table
    actually sees.
    """
    w, h = frame
    canvas = np.empty((h, w, 3), dtype=np.float64)
    canvas[:, :] = ground
    ah, aw = art.shape[:2]
    top, left = (h - ah) // 2, (w - aw) // 2
    canvas[top:top + ah, left:left + aw] = art
    return canvas


def normalise_face_set(entries: list[dict], dry_run: bool) -> list[tuple[str, int]]:
    """Luminance-matches the four in-match role faces. Nothing else.

    # What this deliberately does NOT do

    The four paintings are the product. They are not cropped, not desaturated, not
    hue-shifted, not cast-stripped, and nothing is drawn on them. The whole
    picture ships, including its painted border, corner letter and corner icon.

    The single processing step is a **scalar gain** — one multiplier per image,
    every pixel, every channel. It changes exposure and nothing else: hue is
    untouched by construction, and contrast ratios are preserved because a ratio
    survives multiplication.

    # Why that one step is not optional

    Constitution Article I caps night-screen brightness spread at +/-2%. Measured
    raw, these four span 1.70:1 — the detective card throws 70% more light onto
    its holder's face than the mafia card does. At a dark table the phone is the
    only light source, and that is the leak Article I names.

    # Two consequences of solving it as a set

    **Nothing is written until every face passes.** A partial write leaves a mix
    of matched and unmatched faces, which is worse than not running at all: the
    set looks deliberate and measures broken.

    **The gain is re-solved after clipping.** Scaling up pushes highlights past
    255 and loses energy there, so the first ratio overshoots; solving once more
    against the clipped result is what actually lands on the mean.
    """
    missing = [e["slot"] for e in entries if _source_path(e) is None]
    if missing:
        print(f"  face set incomplete — missing {', '.join(missing)}; skipping")
        return []

    frame = tuple(entries[0]["size"])
    for e in entries:
        if tuple(e["size"]) != frame:
            sys.exit(
                f"FAIL: {e['slot']} declares size {e['size']} but the face set "
                f"frame is {list(frame)}. Every face must land in the same frame "
                f"or one card is composed tighter than another."
            )

    ground = tuple(load_manifest().get("card_ground", [12, 10, 11]))

    art: dict[str, np.ndarray] = {}
    sources: dict[str, str] = {}
    raw_lum: dict[str, float] = {}
    raw_cast: dict[str, float] = {}
    coverage: dict[str, float] = {}

    for e in entries:
        img, path = _load(e)
        assert img is not None and path is not None
        sources[e["slot"]] = path
        a = np.asarray(_contain(img, frame[0], frame[1]), dtype=np.float64)
        art[e["slot"]] = a
        raw_lum[e["slot"]] = _luminance(_composite(a, frame, ground))
        # Channel-mean spread: how far from neutral the painting is. Reported
        # only. Nothing corrects it — these are monochrome by hand, and a
        # correction would be a colour change.
        means = [a[:, :, c].mean() for c in range(3)]
        raw_cast[e["slot"]] = max(means) - min(means)
        coverage[e["slot"]] = (a.shape[0] * a.shape[1]) / (frame[0] * frame[1])

    target = sum(raw_lum.values()) / len(raw_lum)

    print(f"\n  face set — {len(entries)} faces, card box {frame[0]}x{frame[1]}")
    print("  uncropped: each painting is scaled to fit and centred; the box "
          "supplies the rest")
    print(f"  ground rgb{ground}, luminance solved on the composited box")
    print(f"  target luminance {target:.3f}/255 (the set's own mean)\n")
    print(f"  {'slot':<22}{'raw':>8}{'drift':>9}{'cast':>7}{'cover':>8}"
          f"{'gain':>8}{'final':>8}{'drift':>9}")

    out: dict[str, np.ndarray] = {}
    for e in entries:
        slot = e["slot"]
        a = art[slot]
        # # The bars are held at exactly `card_ground` and only the art is gained
        #
        # The previous version gained the ground along with the art, so the
        # whole box scaled together. That kept the bars matched to the
        # *painting's* dark edge, but it also meant the shipped bars were
        # `ground * gain` — and the gains differ per role, so the mafia card's
        # bars came out at a different value from everyone else's. Against a
        # screen painted `surface-base` that is a frame, and because the mafia
        # painting covers 76.4% of the box against 89.3% for the other three,
        # its frame is the thick one. A role tell that no luminance budget
        # catches, because the budget is satisfied by construction.
        #
        # So the ground is now a constant. The bars ship as literally
        # `card_ground`, which is `MafiaColors.surfaceBase`, which is the colour
        # of the screen behind the card — so there is nothing to see at the card
        # edge at all, on any role, at any point in the flip.
        #
        # The gain is therefore solved on the art *alone*, against the luminance
        # the art has to carry for the whole box to land on `target`:
        #
        #     target = cover · art + (1 - cover) · ground
        #     art    = (target - (1 - cover) · ground) / cover
        #
        # Coverage differs by role, so the four paintings end up at genuinely
        # different brightnesses — which is correct and is the point. What a
        # bystander sees is the *box*, and the boxes match.
        cover = coverage[slot]
        ground_lum = _luminance(np.array([[list(ground)]], dtype=np.float64))
        art_target = (target - (1.0 - cover) * ground_lum) / max(cover, 1e-9)
        pre = _luminance(a)
        gain = art_target / max(pre, 1e-9)
        adjusted = np.clip(a * gain, 0, 255)
        # Clipping at 255 loses energy on the brightest pixels, so the first
        # ratio overshoots. Solve once more against the clipped result — on the
        # composited box, which is the quantity that actually has to match.
        actual = _luminance(_composite(adjusted, frame, ground))
        if actual > 0:
            correction = target / actual
            # Only the art moves. Re-scaling the bars is the bug above.
            art_scale = 1.0 + (correction - 1.0) / max(cover, 1e-9)
            adjusted = np.clip(adjusted * art_scale, 0, 255)
            gain *= art_scale
        post = _luminance(_composite(adjusted, frame, ground))
        out[slot] = _composite(adjusted, frame, ground)
        print(f"  {slot:<22}{raw_lum[slot]:>8.2f}"
              f"{(raw_lum[slot] - target) / target * 100:>8.2f}%"
              f"{raw_cast[slot]:>7.2f}{coverage[slot] * 100:>7.1f}%"
              f"{gain:>8.4f}{post:>8.2f}"
              f"{(post - target) / target * 100:>8.3f}%")

    finals = {k: _luminance(v) for k, v in out.items()}
    mean = sum(finals.values()) / len(finals)
    worst_slot, worst = max(
        ((k, abs(v - mean) / mean) for k, v in finals.items()),
        key=lambda kv: kv[1])
    spread = (max(finals.values()) - min(finals.values())) / mean

    print(f"\n  set mean {mean:.3f}/255")
    print(f"  worst drift  {worst * 100:.4f}%  ({worst_slot})   "
          f"budget {FACE_BUDGET * 100:.0f}%")
    print(f"  max spread   {spread * 100:.4f}%  (brightest vs darkest)")

    if worst > FACE_BUDGET:
        sys.exit(
            f"\nFAIL: {worst_slot} is {worst * 100:.3f}% off the set mean, "
            f"outside the {FACE_BUDGET * 100:.0f}% budget. NOTHING WAS WRITTEN.\n"
            f"The four faces are the only role-conditional artwork in the app, so "
            f"this is a leak, not a cosmetic miss. Regenerate the outlier — do not "
            f"widen the budget."
        )

    if dry_run:
        print("\n  (dry run — nothing written)")
        return []

    written: list[tuple[str, int]] = []
    for e in entries:
        slot = e["slot"]
        img = Image.fromarray(out[slot].astype(np.uint8), "RGB")
        size = _save(img, e["out"], e["quality"])
        written.append((e["out"], size))
        print(f"  wrote {e['out']:<40} {size:>9,} B   "
              f"<- {os.path.basename(sources[slot])[:38]}")
    return written


def process(entry: dict, dry_run: bool) -> tuple[str, int, float] | None:
    """Runs one manifest entry. Returns (out path, bytes, luminance) or None."""
    slot = entry["slot"]

    if entry.get("generated_only"):
        img, _ = _load(entry)
        if img is not None:
            sys.exit(
                f"FAIL: {slot} is owned by tool/generate_assets.py and must not "
                f"be supplied as art.\n{entry.get('note', '')}"
            )
        return None

    img, _path = _load(entry)
    if img is None:
        return None

    w, h = entry["size"]
    alpha = bool(entry.get("alpha"))
    tier = entry["tier"]

    if entry.get("uncropped"):
        # Same treatment the face set gets: the painting is scaled whole into the
        # card box and the ground fills what is left. The card back carries the
        # same painted border as the faces and losing its edges to a centre-crop
        # would make it the odd one out in the deck.
        ground = tuple(load_manifest().get("card_ground", [12, 10, 11]))
        art = np.asarray(_contain(img, w, h), dtype=np.float64)
        rgb = _composite(art, (w, h), ground)
        a_channel = None
    else:
        fitted = _fit(img, w, h, alpha)
        rgb = np.asarray(fitted, dtype=np.float64)
        a_channel = rgb[:, :, 3:4] if alpha else None
        rgb = rgb[:, :, :3]

    raw_lum = _luminance(rgb)

    if tier == 3:
        lo, hi = entry["lum_band"]
        mid = (lo + hi) / 2
        if not (lo <= _luminance(rgb) <= hi):
            rgb = _gain_to(rgb, mid)

    if entry.get("rotational_symmetry"):
        rgb = _fold_180(rgb)
        if a_channel is not None:
            a_channel = _fold_180(a_channel)

    out_lum = _luminance(rgb)

    if tier == 3:
        lo, hi = entry["lum_band"]
        if not (lo - 0.5 <= out_lum <= hi + 0.5):
            sys.exit(
                f"FAIL: {slot} could not be brought into its luminance band "
                f"[{lo}, {hi}] — landed at {out_lum:.1f}. The art is probably "
                f"blown out or crushed; regenerate it rather than widening the "
                f"band."
            )

    stacked = np.concatenate([rgb, a_channel], axis=2) if alpha else rgb
    out_img = Image.fromarray(stacked.astype(np.uint8), "RGBA" if alpha else "RGB")

    size = 0 if dry_run else _save(out_img, entry["out"], entry["quality"])
    print(f"  {slot:<20} tier {tier}  lum {raw_lum:6.1f} -> {out_lum:6.1f}  "
          f"{'(dry run)' if dry_run else f'{size:,} B'}")
    return entry["out"], size, out_lum


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    dry_run = "--check" in sys.argv[1:]

    manifest = load_manifest()

    orphans = check_incoming(manifest)
    if orphans:
        sys.exit(
            "FAIL: files in tool/incoming with no manifest slot:\n  "
            + "\n  ".join(orphans)
            + "\n\nAn unmanifested asset is one nothing measures. Add it to "
              "tool/manifest.json or rename it to an existing slot."
        )

    entries = manifest["assets"]
    if args:
        wanted = set(args)
        entries = [e for e in entries if e["slot"] in wanted]
        missing = wanted - {e["slot"] for e in entries}
        if missing:
            sys.exit(f"FAIL: no such slot(s): {', '.join(sorted(missing))}")

    print("normalising art" + (" (dry run)" if dry_run else ""))

    written: list[str] = []
    total = 0

    # The face set first and together — see normalise_face_set.
    faces = [e for e in entries if e.get("face_set")]
    if faces:
        for out, size in normalise_face_set(faces, dry_run):
            written.append(out)
            total += size

    others = [e for e in entries if not e.get("face_set")]
    if others:
        print("\n  other surfaces")
    for entry in others:
        result = process(entry, dry_run)
        if result is None:
            continue
        out, size, _lum = result
        written.append(out)
        total += size

    if not written:
        print("\n  nothing written — no matching source files found")
        return

    print(f"\n  {len(written)} file(s), {total:,} B")
    print("\nNext:")
    print("  python tool/generate_asset_constants.py")
    print("  flutter test          # re-measures the shipped bytes")


if __name__ == "__main__":
    main()
