#!/usr/bin/env python3
"""Generates manifest art with Gemini (Nano Banana Pro) into tool/incoming/.

    export GEMINI_API_KEY=...            # never hardcode it, never commit it
    python tool/generate_art_ai.py card_back
    python tool/generate_art_ai.py card_face_mafia card_face_doctor
    python tool/generate_art_ai.py --list

Output goes to `tool/incoming/<slot>.png`, which is exactly where
`tool/normalise_art.py` expects it. So the whole flow is:

    python tool/generate_art_ai.py card_back
    python tool/normalise_art.py card_back
    flutter test

## Why the prompts live here and not in the markdown

`tool/IMAGE_PROMPTS.md` is the human-facing pack — it explains *why* each block
says what it says, and it is what you paste into a web UI by hand. This file is
the machine-facing copy, and the STYLE_BLOCK / NEGATIVE constants below are
byte-identical to the ones in that document. Keeping them as string constants in
one place is the only way the "keep the style block byte-identical across
generations" rule can actually be enforced rather than hoped for: a per-slot
prompt cannot drift from the shared block if it cannot restate it.

## Reference anchoring

The prompt pack's single most important instruction is to attach a reference
image on *every* generation. Pass `--ref <path>` to do that. Once one card is
right, pass it as the reference for the rest:

    python tool/generate_art_ai.py card_face_doctor --ref tool/incoming/card_face_mafia.png
"""

from __future__ import annotations

import base64
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INCOMING = os.path.join(ROOT, "tool", "incoming")

MODEL = "gemini-3-pro-image"
ENDPOINT = ("https://generativelanguage.googleapis.com/v1beta/"
            "models/{model}:generateContent?key={key}")

# --- byte-identical to tool/IMAGE_PROMPTS.md ---------------------------------

STYLE_BLOCK = """\
Painterly digital illustration for a luxury noir playing-card deck. Semi-realistic
oil-and-gouache rendering with visible brushwork and impasto edges. A single
centred figure, waist-up, three-quarter view, filling the middle third of the
frame with generous margin on all sides. The face is NEVER visible — the head is
turned away, hooded, masked, or dissolved into deep shadow. Ornate black couture:
fine beadwork, embroidery, faceted jewels, lacquered and quilted surfaces,
intricate metal filigree. Heavy aged-canvas texture and a fine halftone print
grain across the entire image. Deep vignette darkening all four edges. Distressed,
worn, slightly faded antique print. One dramatic raking light source from the
upper left, deep falloff into shadow. Adult, restrained, cinematic, symbolic
rather than literal. Flat to the picture plane, no perspective floor, no horizon."""

# The figure sentence, quoted verbatim so the substitutions the prompt pack
# describes ("replace the figure sentence with…") are a real string operation
# rather than a hand-retyped paraphrase.
FIGURE_SENTENCE = """A single
centred figure, waist-up, three-quarter view, filling the middle third of the
frame with generous margin on all sides. The face is NEVER visible — the head is
turned away, hooded, masked, or dissolved into deep shadow."""

NEGATIVE = """\
Do NOT include any of the following: text, letters, numbers, words, watermark,
signature, logo, caption, UI, frame, border, card edge, rounded corners, playing
card mockup, photograph of a card, multiple figures, crowd, visible face, eyes,
mouth, smile, portrait likeness, cartoon, anime, chibi, mascot, cute, comic, cel
shading, neon, glow, lens flare, bokeh, HDR, oversaturated, candy colours,
gradient background, clean vector, flat minimal, 3D render, plastic, glossy CGI,
busy background, scenery, landscape."""

COLD_BLOCK = """\
COLOUR: strictly monochrome cold palette — charcoal #0C0A0B, gunmetal #171416,
graphite #362F2E, slate #717573, bone white #E9E4D9. Desaturated. Absolutely no
red, no orange, no gold, no warm tint anywhere in the image.
COMPOSITION: figure centred, head crown at 22% from the top, waist at 85% from
the top."""


def _no_figure(replacement: str) -> str:
    """STYLE_BLOCK with the figure sentence swapped out."""
    assert FIGURE_SENTENCE in STYLE_BLOCK, "figure sentence drifted from the style block"
    return STYLE_BLOCK.replace(FIGURE_SENTENCE, replacement)


PROMPTS: dict[str, tuple[str, str]] = {
    # slot: (prompt, aspect ratio)
    # The four in-match faces. Distinct paintings, but the STYLE BLOCK and the
    # COLD BLOCK are byte-identical across all four and every one is generated at
    # the same aspect. That is what gives `tool/normalise_art.py` a set it can
    # actually bring inside the +/-2% budget — a face generated from a reworded
    # style block or a different aspect ratio usually lands too far out to rescue,
    # and the pipeline will refuse to write any of them.
    "card_face_mafia": ("\n\n".join([
        STYLE_BLOCK,
        "SUBJECT: A figure in a high-collared black overcoat wearing a smooth "
        "featureless porcelain mask that covers the entire face — no eyes, no "
        "mouth, a blank pale oval. Gloved hands at the sides. Faint smoke curls "
        "around the shoulders. A clear unornamented area across the chest, "
        "mid-tone, reserved for an overlaid emblem.",
        COLD_BLOCK,
        NEGATIVE,
    ]), "2:3"),

    "card_face_doctor": ("\n\n".join([
        STYLE_BLOCK,
        "SUBJECT: A figure in a long black surgical coat, head bowed so the face "
        "is entirely lost in shadow beneath it. Hands clasped low in front. The "
        "coat falls in heavy vertical folds, its hem frayed and worn. A clear "
        "unornamented area across the chest, mid-tone, reserved for an overlaid "
        "emblem.",
        COLD_BLOCK,
        NEGATIVE,
    ]), "2:3"),

    "card_face_detective": ("\n\n".join([
        STYLE_BLOCK,
        "SUBJECT: A figure in a long coat and a wide-brimmed hat, the face "
        "completely swallowed by the shadow under the brim. Fine chain and "
        "filigree detail on the coat. Hands at the sides. A clear unornamented "
        "area across the chest, mid-tone, reserved for an overlaid emblem.",
        COLD_BLOCK,
        NEGATIVE,
    ]), "2:3"),

    "card_face_citizen": ("\n\n".join([
        STYLE_BLOCK,
        "SUBJECT: A figure in a plain high-collared coat, head turned fully away "
        "and dissolved into deep shadow. No insignia, no ornament, no jewellery — "
        "deliberately the least decorated of the set. Hands at the sides. A clear "
        "unornamented area across the chest, mid-tone, reserved for an overlaid "
        "emblem.",
        COLD_BLOCK,
        NEGATIVE,
    ]), "2:3"),

    "card_back": ("\n\n".join([
        _no_figure("No figure. No person. An ornamental engraved medallion, "
                   "perfectly symmetrical."),
        "SUBJECT: The back of an antique playing card. A large concentric "
        "guilloche medallion centred in the frame — fine engraved line-work, "
        "rosette geometry, radial symmetry, like banknote intaglio. Aged charcoal "
        "ground with parchment-pale linework. Worn and rubbed at the edges where "
        "the print has faded. Perfectly rotationally symmetric, identical if "
        "turned upside down.",
        "COLOUR: charcoal #0C0A0B ground, aged parchment #AFA187 linework, very "
        "low contrast — the pattern should be felt rather than read.",
        NEGATIVE,
    ]), "2:3"),

    "gallery_mafia": ("\n\n".join([
        STYLE_BLOCK,
        "SUBJECT: A figure in a high-collared black overcoat, wearing a smooth "
        "featureless porcelain mask covering the entire face — no eyes, no mouth, "
        "a blank pale oval. Gloved hands at the sides. Faint smoke curls around "
        "the shoulders and dissolves into the dark ground. The coat is embroidered "
        "with a repeating mask motif in black-on-black thread.",
        "COLOUR: charcoal and gunmetal ground with a single deep oxblood #722722 "
        "accent in the coat lining. Restrained — the red is a whisper, not a shout.",
        NEGATIVE,
    ]), "2:3"),

    "gallery_doctor": ("\n\n".join([
        STYLE_BLOCK,
        "SUBJECT: A figure in a long black surgical coat, head bowed so the face "
        "is entirely lost in shadow beneath it. A single equal-armed cross, "
        "bone-white, embroidered large across the chest. Hands clasped low in "
        "front. The coat falls in heavy vertical folds, hem frayed and worn.",
        "COLOUR: charcoal and graphite with a cold verdigris #2F4F45 accent in the "
        "lining.",
        NEGATIVE,
    ]), "2:3"),

    "gallery_detective": ("\n\n".join([
        STYLE_BLOCK,
        "SUBJECT: A figure in a long coat and wide-brimmed hat, face completely "
        "swallowed by the shadow under the brim. One raised hand holds a round "
        "glass lens at chest height; the lens catches the raking light and is the "
        "brightest object in frame. Fine chain and filigree detail on the coat.",
        "COLOUR: charcoal and gunmetal with a cold steel-blue #2C3D52 accent in "
        "the lens flare and lining.",
        NEGATIVE,
    ]), "2:3"),

    "gallery_citizen": ("\n\n".join([
        STYLE_BLOCK,
        "SUBJECT: A figure in a plain high-collared coat, seen from behind, head "
        "turned fully away. No insignia, no ornament, no jewellery — deliberately "
        "the least decorated of the set. Hands at the sides. The plainness is the "
        "character.",
        "COLOUR: charcoal and slate with a faint aged-parchment #AFA187 warmth in "
        "the fabric. Nothing else.",
        NEGATIVE,
    ]), "2:3"),

    "bg_home": ("\n\n".join([
        _no_figure("No figure. An empty interior."),
        "SUBJECT: An empty, dim interior. Two soft shafts of light rake down from "
        "the upper right as if through a shuttered blind, catching dust in the "
        "air. Deep shadow everywhere else. A low warm ember glow along the bottom "
        "edge. Bare aged plaster suggested rather than described.",
        "COLOUR: warm register — aged terracotta and rust #AA3D28, oxblood "
        "#722722, aged canvas #AFA187 over a near-black warm charcoal ground. "
        "Muted and dusty, never vivid. Dark enough for bone-white text to read on "
        "top.",
        NEGATIVE,
    ]), "9:16"),

    "bg_night": ("\n\n".join([
        _no_figure("No figure. An empty interior."),
        "SUBJECT: An empty circle of worn wooden chairs seen from a low "
        "three-quarter angle, all unoccupied. Long shadows stretch inward. A "
        "single weak hanging bulb above, its light barely reaching the floor.",
        "COLOUR: cold register — indigo-black #0E1424, charcoal #0C0A0B, one dim "
        "amber #6B4A22 point at the bulb only. Dark enough for bone-white text on "
        "top.",
        NEGATIVE,
    ]), "9:16"),

    "bg_day": ("\n\n".join([
        _no_figure("No figure. An empty interior."),
        "SUBJECT: The same circle of worn wooden chairs, now in harsh pale morning "
        "light falling through a tall shuttered window. One chair is overturned. "
        "Dust hangs in the light shafts.",
        "COLOUR: washed bone #E9E4D9 and dusty aged canvas #AFA187 over cold grey. "
        "Bleached, flat, unforgiving. Must still carry dark text or a scrim.",
        NEGATIVE,
    ]), "9:16"),

    "bg_vote": ("\n\n".join([
        _no_figure("No figure. An empty interior."),
        "SUBJECT: A raised wooden platform in an empty hall, a single hard "
        "spotlight cone falling on the bare spot where the accused would stand. "
        "Rows of empty chairs facing it, lost in shadow.",
        "COLOUR: deep sepia #4A3A2A and near-black, one harsh #EDE6D8 light cone. "
        "High contrast, theatrical.",
        NEGATIVE,
    ]), "9:16"),

    "outcome_death": ("\n\n".join([
        _no_figure("No figure. A single still-life object."),
        "SUBJECT: An empty wooden chair with a dark coat draped over its back, a "
        "single faded flower on the seat. Deep shadow behind.",
        "COLOUR: charcoal #0C0A0B, muted oxblood #722722, bone #E9E4D9.",
        NEGATIVE,
    ]), "2:3"),

    "outcome_saved": ("\n\n".join([
        _no_figure("No figure. A single still-life object."),
        "SUBJECT: An empty wooden chair, faintly outlined by a cold pale light, "
        "dust motes suspended in still air.",
        "COLOUR: charcoal #0C0A0B, cold verdigris #2F4F45, bone #E9E4D9.",
        NEGATIVE,
    ]), "2:3"),

    "outcome_mafia_win": ("\n\n".join([
        _no_figure("No figure. A single still-life object."),
        "SUBJECT: A porcelain mask resting face-up on an overturned chair, smoke "
        "dissolving in the dark behind it.",
        "COLOUR: charcoal, gunmetal, one deep oxblood #722722 accent.",
        NEGATIVE,
    ]), "2:3"),

    "outcome_town_win": ("\n\n".join([
        _no_figure("No figure. A single still-life object."),
        "SUBJECT: A shattered porcelain mask lying on worn floorboards in a pool "
        "of pale morning light, fine dust rising.",
        "COLOUR: bone #E9E4D9, aged canvas #AFA187, charcoal #0C0A0B.",
        NEGATIVE,
    ]), "2:3"),

    "badge_frame": ("\n\n".join([
        _no_figure("No figure. A single ornamental emblem, centred."),
        "SUBJECT: An ornate engraved medallion frame — laurel and filigree, "
        "antique intaglio line-work, empty in the centre. Worn metal. Symmetrical.",
        "COLOUR: aged parchment #AFA187 and oxblood #722722 on a plain flat black "
        "background.",
        NEGATIVE,
    ]), "1:1"),
}


def generate(slot: str, key: str, ref: str | None) -> str:
    prompt, aspect = PROMPTS[slot]

    parts: list[dict] = [{"text": prompt}]
    if ref:
        mime = mimetypes.guess_type(ref)[0] or "image/png"
        with open(ref, "rb") as f:
            parts.insert(0, {"inline_data": {
                "mime_type": mime,
                "data": base64.b64encode(f.read()).decode("ascii"),
            }})

    body = {
        "contents": [{"parts": parts}],
        "generationConfig": {
            "responseModalities": ["IMAGE"],
            "imageConfig": {"aspectRatio": aspect},
        },
    }

    req = urllib.request.Request(
        ENDPOINT.format(model=MODEL, key=key),
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            payload = json.load(resp)
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:1200]
        sys.exit(f"FAIL: {slot} — HTTP {e.code}\n{detail}")

    candidates = payload.get("candidates") or []
    if not candidates:
        sys.exit(f"FAIL: {slot} — no candidates returned.\n"
                 f"{json.dumps(payload)[:800]}")

    for part in candidates[0].get("content", {}).get("parts", []):
        blob = part.get("inlineData") or part.get("inline_data")
        if blob and blob.get("data"):
            os.makedirs(INCOMING, exist_ok=True)
            path = os.path.join(INCOMING, f"{slot}.png")
            with open(path, "wb") as f:
                f.write(base64.b64decode(blob["data"]))
            return path

    finish = candidates[0].get("finishReason", "?")
    sys.exit(f"FAIL: {slot} — response carried no image (finishReason={finish}).\n"
             f"{json.dumps(payload)[:800]}")


def main() -> None:
    args = sys.argv[1:]

    if "--list" in args:
        for slot, (_p, aspect) in PROMPTS.items():
            print(f"  {slot:<20} {aspect}")
        return

    ref = None
    if "--ref" in args:
        i = args.index("--ref")
        ref = args[i + 1]
        del args[i:i + 2]
        if not os.path.exists(ref):
            sys.exit(f"FAIL: reference image not found: {ref}")

    slots = [a for a in args if not a.startswith("-")]
    if not slots:
        sys.exit("usage: generate_art_ai.py <slot>... [--ref path] [--list]")

    unknown = [s for s in slots if s not in PROMPTS]
    if unknown:
        sys.exit(f"FAIL: no prompt for {', '.join(unknown)}. "
                 f"Try --list.")

    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        sys.exit("FAIL: set GEMINI_API_KEY in the environment. Do not put the "
                 "key in this file — it would end up in version control.")

    print(f"generating with {MODEL}"
          + (f", anchored on {os.path.relpath(ref, ROOT)}" if ref else ""))
    for slot in slots:
        path = generate(slot, key, ref)
        print(f"  {slot:<20} {os.path.getsize(path):>10,} B  "
              f"-> {os.path.relpath(path, ROOT)}")

    print("\nNext:  python tool/normalise_art.py " + " ".join(slots))


if __name__ == "__main__":
    main()
