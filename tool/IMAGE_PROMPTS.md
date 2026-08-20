# Mafia Master — IMAGE_PROMPTS (Merged & Corrected)

> **This file supersedes both earlier versions.** It merges the Claude Code
> `IMAGE_PROMPTS.md` (correct on colour safety and card-frame handling) with the
> broader asset coverage from the art-direction pack, and resolves the
> architectural tension both files left open.

---

## THE ARCHITECTURAL DECISION (read this first)

The existing app composites **one shared face base + one emblem**, which makes
role-card divergence *structurally impossible*. Four full-art faces would trade
that guarantee for better art, leaving `luminance_budget_test.dart` as the only
thing preventing a leak.

**Do neither. Split by surface:**

| Surface | Art strategy | Why |
|---|---|---|
| **In-match role reveal** (private, 3 seconds, phone in someone's face) | **ONE shared monochrome face base** + bone-white emblem + role name | Structural parity preserved. Player needs to *know* their role, not admire it. |
| **Post-game gallery / result screens** (all roles already revealed) | **Four full-art cards**, richly differentiated | Zero leakage risk here. This is where collectibility pays off. |

This gets you the beautiful deck *and* keeps parity a property of the filesystem
rather than of a test you might one day relax to make a nice card pass.

Consequence: `card_base.png` is now the leakage-critical asset. The four full-art
cards move to `assets/images/gallery/` and are **never** referenced by any widget
that can render during a handoff. Add a lint/test asserting that.

---

## HOW TO GENERATE SO THE SET ACTUALLY MATCHES

Consistency comes from process, not wording. In order of importance:

1. **Attach a reference image on every single generation** — not just the first.
   Once image #1 is right, attach *it* as the anchor for everything after.
2. **Generate each set back-to-back in one session** without touching the style block.
3. **Keep the STYLE BLOCK byte-identical.** Only the SUBJECT line changes.
4. **Generate at 2× target size and downscale.** Detail survives, artefacts average out.

---

## STYLE BLOCK — paste verbatim

```
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
rather than literal. Flat to the picture plane, no perspective floor, no horizon.
```

## NEGATIVE PROMPT — paste verbatim

```
text, letters, numbers, words, watermark, signature, logo, caption, UI, frame,
border, card edge, rounded corners, playing card mockup, photograph of a card,
multiple figures, crowd, visible face, eyes, mouth, smile, portrait likeness,
cartoon, anime, chibi, mascot, cute, comic, cel shading, neon, glow, lens flare,
bokeh, HDR, oversaturated, candy colours, gradient background, clean vector,
flat minimal, 3D render, plastic, glossy CGI, busy background, scenery, landscape
```

> **Why no card edge / corners / mockup:** you are generating *artwork*, not a
> picture of a card. Flutter draws the card, its corners, border and shadow. A
> card-shaped object inside the image gives you a card on a card.

---

## COLD BLOCK — append to every leakage-critical prompt

```
COLOUR: strictly monochrome cold palette — charcoal #0C0A0B, gunmetal #171416,
graphite #362F2E, slate #717573, bone white #E9E4D9. Desaturated. Absolutely no
red, no orange, no gold, no warm tint anywhere in the image.
COMPOSITION: figure centred, head crown at 22% from the top, waist at 85% from
the top.
```

---

# TIER 1 — LEAKAGE-CRITICAL (only 2 files)

## 1. `card_base.png` — the shared in-match card face
**Generate 2048×3072 → deliver 1024×1536 (2:3)**

This is the face every player sees at reveal, regardless of role. The emblem and
role name are composited on top in Flutter, in bone white, at a fixed position.

```
[STYLE BLOCK]
SUBJECT: A figure in a high-collared black coat, head turned fully away and
dissolved into deep shadow — no mask, no hat, no insignia, no held object, no
identifying garment detail. Ornate black-on-black embroidery across the shoulders
in an abstract geometric motif that suggests nothing in particular. Hands at the
sides. A clear unornamented area across the chest, mid-tone, reserved for an
overlaid emblem.
[COLD BLOCK]
```

> The reserved chest area matters — generate 3 variants and pick the one with the
> flattest, least-busy chest region so the composited emblem reads cleanly.

## 2. `card_back.png` — what the table sees
**Generate 2048×3072 → deliver 1024×1536 (2:3)**

Exactly **one** file. No figure, no role symbol of any kind.

```
[STYLE BLOCK — replace "A single centred figure..." through "...dissolved into
deep shadow." with: "No figure. No person. An ornamental engraved medallion,
perfectly symmetrical."]

SUBJECT: The back of an antique playing card. A large concentric guilloche
medallion centred in the frame — fine engraved line-work, rosette geometry,
radial symmetry, like banknote intaglio. Aged charcoal ground with parchment-pale
linework. Worn and rubbed at the edges where the print has faded. Perfectly
rotationally symmetric, identical if turned upside down.

COLOUR: charcoal #0C0A0B ground, aged parchment #AFA187 linework, very low
contrast — the pattern should be felt rather than read.
```

---

# TIER 2 — GALLERY CARDS (post-game only, ×4)

**Generate 2048×3072 → deliver 1024×1536 (2:3)**
**Path: `assets/images/gallery/` — never rendered during a handoff.**

These are allowed to be gorgeous and distinct. They may use warm colour, because
nobody sees them until every role is already public.

### `gallery_mafia.png`
```
[STYLE BLOCK]
SUBJECT: A figure in a high-collared black overcoat, wearing a smooth featureless
porcelain mask covering the entire face — no eyes, no mouth, a blank pale oval.
Gloved hands at the sides. Faint smoke curls around the shoulders and dissolves
into the dark ground. The coat is embroidered with a repeating mask motif in
black-on-black thread.
COLOUR: charcoal and gunmetal ground with a single deep oxblood #722722 accent in
the coat lining. Restrained — the red is a whisper, not a shout.
```

### `gallery_doctor.png`
```
[STYLE BLOCK]
SUBJECT: A figure in a long black surgical coat, head bowed so the face is
entirely lost in shadow beneath it. A single equal-armed cross, bone-white,
embroidered large across the chest. Hands clasped low in front. The coat falls in
heavy vertical folds, hem frayed and worn.
COLOUR: charcoal and graphite with a cold verdigris #2F4F45 accent in the lining.
```

### `gallery_detective.png`
```
[STYLE BLOCK]
SUBJECT: A figure in a long coat and wide-brimmed hat, face completely swallowed
by the shadow under the brim. One raised hand holds a round glass lens at chest
height; the lens catches the raking light and is the brightest object in frame.
Fine chain and filigree detail on the coat.
COLOUR: charcoal and gunmetal with a cold steel-blue #2C3D52 accent in the lens
flare and lining.
```

### `gallery_citizen.png`
```
[STYLE BLOCK]
SUBJECT: A figure in a plain high-collared coat, seen from behind, head turned
fully away. No insignia, no ornament, no jewellery — deliberately the least
decorated of the set. Hands at the sides. The plainness is the character.
COLOUR: charcoal and slate with a faint aged-parchment #AFA187 warmth in the
fabric. Nothing else.
```

---

# TIER 3 — PUBLIC SURFACES (phone flat on table, no secrets on screen)

**Generate 2160×3840 → deliver 1080×1920 (9:16)**
No figures — text and buttons sit on top and a face fights them.

## `bg_home.png` — the warm register
```
[STYLE BLOCK — replace the figure sentence with: "No figure. An empty interior."]
SUBJECT: An empty, dim interior. Two soft shafts of light rake down from the upper
right as if through a shuttered blind, catching dust in the air. Deep shadow
everywhere else. A low warm ember glow along the bottom edge. Bare aged plaster
suggested rather than described.
COLOUR: warm register — aged terracotta and rust #AA3D28, oxblood #722722, aged
canvas #AFA187 over a near-black warm charcoal ground. Muted and dusty, never
vivid. Dark enough for bone-white text to read on top.
```

## `bg_night.png`
```
[STYLE BLOCK — replace the figure sentence with: "No figure. An empty interior."]
SUBJECT: An empty circle of worn wooden chairs seen from a low three-quarter
angle, all unoccupied. Long shadows stretch inward. A single weak hanging bulb
above, its light barely reaching the floor.
COLOUR: cold register — indigo-black #0E1424, charcoal #0C0A0B, one dim amber
#6B4A22 point at the bulb only. Dark enough for bone-white text on top.
```

## `bg_day.png`
```
[STYLE BLOCK — replace the figure sentence with: "No figure. An empty interior."]
SUBJECT: The same circle of worn wooden chairs, now in harsh pale morning light
falling through a tall shuttered window. One chair is overturned. Dust hangs in
the light shafts.
COLOUR: washed bone #E9E4D9 and dusty aged canvas #AFA187 over cold grey. Bleached,
flat, unforgiving. Must still carry dark text or a scrim.
```

## `bg_vote.png`
```
[STYLE BLOCK — replace the figure sentence with: "No figure. An empty interior."]
SUBJECT: A raised wooden platform in an empty hall, a single hard spotlight cone
falling on the bare spot where the accused would stand. Rows of empty chairs
facing it, lost in shadow.
COLOUR: deep sepia #4A3A2A and near-black, one harsh #EDE6D8 light cone. High
contrast, theatrical.
```

---

# TIER 4 — OUTCOME PLATES (1024×1536)

## `outcome_death.png`
```
[STYLE BLOCK — replace the figure sentence with: "No figure. A single still-life
object."]
SUBJECT: An empty wooden chair with a dark coat draped over its back, a single
faded flower on the seat. Deep shadow behind.
COLOUR: charcoal #0C0A0B, muted oxblood #722722, bone #E9E4D9.
```

## `outcome_saved.png`
```
[STYLE BLOCK — replace the figure sentence with: "No figure. A single still-life
object."]
SUBJECT: An empty wooden chair, faintly outlined by a cold pale light, dust motes
suspended in still air.
COLOUR: charcoal #0C0A0B, cold verdigris #2F4F45, bone #E9E4D9.
```

## `outcome_mafia_win.png`
```
[STYLE BLOCK — replace the figure sentence with: "No figure. A single still-life
object."]
SUBJECT: A porcelain mask resting face-up on an overturned chair, smoke dissolving
in the dark behind it.
COLOUR: charcoal, gunmetal, one deep oxblood #722722 accent.
```

## `outcome_town_win.png`
```
[STYLE BLOCK — replace the figure sentence with: "No figure. A single still-life
object."]
SUBJECT: A shattered porcelain mask lying on worn floorboards in a pool of pale
morning light, fine dust rising.
COLOUR: bone #E9E4D9, aged canvas #AFA187, charcoal #0C0A0B.
```

## `badge_frame.png` (1024×1024, transparent)
```
[STYLE BLOCK — replace the figure sentence with: "No figure. A single ornamental
emblem, centred."]
SUBJECT: An ornate engraved medallion frame — laurel and filigree, antique
intaglio line-work, empty in the centre. Worn metal. Symmetrical.
COLOUR: aged parchment #AFA187 and oxblood #722722 on transparent.
```

---

# NOT GENERATED BY AI

| Asset | Instead |
|---|---|
| Role emblems (mask / cross / lens / hand) | **SVG**, drawn in Flutter, always bone white in-match. Tintable in post-game only. |
| All UI icons (hold, pass, dead, timer, ghost) | **SVG** — lighter, theme-tinted, no extra files |
| Player avatars | **Generated from name**: palette circle + first letter in the display font. Player count varies 5–20, so pre-made art is impossible — and varied avatars are visual noise in the selection grid. |

---

# FINAL ASSET COUNT

| Tier | Files | Priority |
|---|---|---|
| 1 — Leakage-critical | `card_base`, `card_back` | 🔴 Ship-blocking |
| 2 — Gallery | 4 role cards | 🟡 Post-game |
| 3 — Backdrops | `bg_home`, `bg_night`, `bg_day`, `bg_vote` | 🟡 |
| 4 — Outcomes | 4 plates + `badge_frame` | 🟢 Polish |

**15 files.** Start with Tier 1 only — two images. If `card_base` doesn't feel
right, nothing downstream matters.

---

# NORMALISATION (still required, even with the hybrid)

Tier 1 is now two files instead of five, so the luminance-parity risk is largely
designed out. But keep the pipeline anyway — Tier 3 backdrops still need to sit
in a predictable brightness band for text contrast.

`tool/normalise_art.py` should:
1. Centre-crop and resize each file to its manifest target
2. For Tier 3: measure Rec. 709 luminance, apply per-image gain to hit a target band
3. Strip residual colour cast on Tier 1 assets — a stray warm pixel must not survive
4. Re-encode to WebP at project quality
5. **Fail loudly** on any file missing from `manifest.yaml`

Then keep `asset_manifest_test.dart` green. And do not raise a tolerance to make
a good-looking image pass.

---

# IMPLEMENTATION NOTES — how this landed in the repo

Three places where the shipped code deviates from the plan above. Each is a
deliberate call, not drift.

**1. The manifest is `tool/manifest.json`, not `manifest.yaml`.**
There is no YAML parser in this environment and the pipeline is meant to run
without adding one. JSON buys something on top of that: `dart:convert` reads it
too, so `asset_manifest_test.dart` validates against the *same* file the Python
pipeline writes from, instead of a second hand-maintained list that can drift.

**2. Emblems stay as measured WebP, not SVG.**
Drawing them in Flutter would need `flutter_svg` — a new dependency, and the
brief says ask first. The existing emblems already deliver what the SVG route was
for: identical bounding boxes and ink coverage equalised to ±0.234% by bisection
on internal stroke weight (see `tool/generate_assets.py`). That parity is
*measured from the shipped bytes* by `asset_manifest_test.dart`. Re-drawing them
as paths would discard a verified property to gain tintability the in-match card
is no longer allowed to use anyway. The tint change from the plan **is** applied:
the emblem renders in bone white during a handoff, and role colour appears only
post-game.

**3. Tier 1–4 art currently ships as procedural placeholder.**
`tool/generate_assets.py` synthesises every slot in the manifest — gradients,
FFT-domain fractal noise, guilloche, vignette, grain. It is honest noir texture,
not painterly figure work, and it is there so the widget paths, the manifest, the
normaliser and the whole test suite are green *before* any AI art exists. Drop
real generations into `tool/incoming/` and `tool/normalise_art.py` replaces the
placeholders slot for slot. Nothing downstream changes.

**Still open:** the app ships Arabic **and** English. The task prompt below says
Egyptian Arabic only; the original visual-overhaul brief required both scripts
render without layout breakage, and the display type set is built around that
(Bebas Neue with Cairo as a per-glyph fallback). Dropping `en` would delete
working, tested localisation, so it has not been done. Say the word if the
bilingual requirement is genuinely retired.

---

# CLAUDE CODE TASK PROMPT

```
# Task: Visual theme integration — hybrid card architecture

## Read first
`.specify/memory/constitution.md`, Article I. This task is constrained by it.

## Architecture change to implement
Role cards split into two surfaces:
  - IN-MATCH: one shared `card_base.webp` + SVG emblem + role name, composited
    in Flutter. Emblem is ALWAYS bone white during a handoff. Parity is
    structural — there is physically one face asset.
  - POST-GAME: four full-art cards in `assets/images/gallery/`, used only by
    result and gallery screens.
Add a test asserting no widget reachable from a handoff state references any
path under `assets/images/gallery/`.

## Step 1 — Asset pipeline (do this before anything else)
Write and run `tool/normalise_art.py` per the spec in IMAGE_PROMPTS.md.
Do NOT read image bytes into your own context — the script does the work.
Report only the output file list and total size. Target under 4 MB.

## Step 2 — Design tokens
`lib/core/theme/`: app_colors.dart (ThemeExtension), app_typography.dart
(local font files in assets/fonts/, NOT google_fonts — native-assets issue
already documented), app_theme.dart (Material 3 dark, RTL-first).
Role accent colours exist ONLY as post-game tokens. Annotate each with a
comment stating it must not be used on any handoff-reachable widget.

## Step 3 — RoleCard widget
`lib/core/widgets/role_card.dart`. Takes a Role enum. Renders card_base +
emblem + name. Fixed 2:3. Flip animation card_back -> face.
Flip duration, curve, and every visual property are identical for all roles —
the ONLY difference is which SVG emblem and which localized string.
Expose no role-conditional parameters.

## Step 4 — Wire into TurnShell; apply Tier 3 backdrops per phase.

## Step 5 — Golden symmetry tests (non-negotiable)
Render RoleCard for all four roles at back / 25% / 50% / 75% / revealed.
Assert pixel-identical output outside the emblem bounding box.
Assert flip duration is byte-identical across roles.
Assert no role accent colour token appears in any handoff-state render.

## Constraints
- Egyptian Arabic only, via ARB. No hardcoded strings.
- No new dependencies without asking me first.
- Run `flutter analyze` and the full suite before reporting done.
- Report the ACTUAL raw test output. Do not summarise pass counts.
```
