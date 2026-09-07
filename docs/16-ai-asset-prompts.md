# Mafia Master — AI Asset Generation Prompts

> Copy-paste prompts for Nano Banana Pro / Midjourney / Flux.
> Every asset in `15-online-ui-redesign.md` Part 4.
>
> **Post-process every output** per Part 3 before shipping. Raw generations are never ship-ready.

---

## 0. THE STYLE ANCHOR — paste this into every prompt

```
STYLE: dark noir, 1930s Middle Eastern engraving, monochrome charcoal and
bone-white with a faint aged-parchment warmth. Hand-etched linework, fine
crosshatching, aged plate texture. Deep near-black background #0D0F14. Highlight
tone is warm cream #D9CDB4. Restrained, adult, cinematic. No colour beyond
the cream and charcoal range. No modern UI styling, no gradients, no glow
effects, no 3D render look, no cartoon, no cel shading.
```

**Universal negative prompt:**
```
NEGATIVE: colour, saturation, neon, glow, gradient mesh, 3D render, cartoon,
anime, cel shading, plastic, glossy, watermark, signature, text, letters,
numbers, logo, UI chrome, drop shadow, bevel, emboss, photorealistic skin,
modern typography, blur, bokeh, lens flare
```

---

# PART 1 — SEAT ASSETS (the most important)

These render at 48–72dp. **They must read at 48px.** Test every candidate by shrinking it to 48px before accepting it.

## A1 — Seat ring, idle

```
A single ornate circular frame, viewed perfectly flat-on and centred.
An engraved ring of interlocking Islamic geometric motifs — eight-point
stars and interlaced bands — forming one continuous circular border.
The centre is completely empty and transparent.
The ring is thin: its band occupies only the outer 18% of the circle's
radius, leaving a large clear centre.
Bone-white line art on pure transparent background. Flat, no shading,
no depth, no perspective. Perfectly symmetrical.
Must remain legible when scaled down to 48 pixels — so: bold simple
strokes, no fine detail, no thin hairlines, high contrast.

[STYLE ANCHOR]
[NEGATIVE] + filled centre, thick border, busy detail, text, portrait, face
```

**Output:** 512×512 PNG, transparent. Then in post: threshold to pure white on transparent so it can be tinted at runtime.

## A2 — Seat ring, cracked (dead player)

```
The same ornate circular frame as before — identical geometry, identical
proportions — but broken. A single jagged fracture runs through the ring
from the upper-left to the lower-right, splitting the band. Two or three
small fragments have come loose and sit slightly displaced from the ring,
as if it shattered a moment ago and froze.
The centre remains completely empty and transparent.
Bone-white line art, transparent background, flat, no shading.
Must read clearly at 48 pixels.

[STYLE ANCHOR]
[NEGATIVE] + blood, gore, colour, filled centre, smoke, particles
```

> **Critical:** generate A2 **from A1 as an image reference** so the geometry matches exactly. A different ornament between alive and dead states makes the crack read as a different object rather than the same seat breaking.

## A3 — Seat ring, empty slot (lobby)

```
The same ornate circular frame, but rendered as a faint dashed outline —
the ornament suggested rather than drawn, as if sketched and unfinished.
Roughly 40% of the linework is missing, broken into evenly spaced dashes
that follow the same circular path.
The centre is completely empty and transparent.
Bone-white, transparent background, flat.

[STYLE ANCHOR]
[NEGATIVE] + solid line, complete ring, filled centre
```

---

# PART 2 — ORNAMENTS & UI FURNITURE

## A4 — Panel corner ornament

```
A single decorative corner ornament for a rectangular frame — the top-left
corner only. An engraved arabesque flourish: an interlaced vine-and-geometry
motif that extends about 30% along the top edge and 30% down the left edge,
then terminates cleanly.
Bone-white line art on transparent background. Flat, no shading.
Designed to be mirrored and rotated to produce all four corners of a frame.

[STYLE ANCHOR]
[NEGATIVE] + full frame, closed rectangle, text, filled shape
```

**Post:** mirror horizontally and vertically in code to build all four corners. **Generate one, not four** — four separately generated corners will never match.

## A5 — Timer ring ornament

```
A circular progress-ring frame. Two concentric bone-white circles with a
narrow channel between them; the channel is decorated with fine engraved
tick marks radiating inward, evenly spaced, sixty in total.
The centre is completely empty and transparent.
The outer edge carries a subtle engraved rope-twist border.
Flat, symmetrical, transparent background.

[STYLE ANCHOR]
[NEGATIVE] + filled centre, numerals, clock hands, digital display, colour
```

## A10 — Whisper seal

```
A small wax seal, viewed flat-on. The wax has been pressed with an engraved
stamp bearing a simple abstract mark — an interlaced knot with a crescent
suggestion, no letters. The wax edge is irregular and organic, as real
sealing wax is.
Rendered as bone-white engraving on transparent background. Flat line art,
no shading, no depth.
Must read at 32 pixels.

[STYLE ANCHOR]
[NEGATIVE] + letters, initials, colour, red wax, gloss, 3D, shadow
```

## A11 — Light mote

```
A single small point of warm light with a soft radial falloff — brightest
at the exact centre, fading smoothly to fully transparent at the edge.
No shape, no edges, no rays, no star points, no lens flare.
Warm cream light on a fully transparent background.
Simply a soft glowing dot.

[NEGATIVE] + star, rays, flare, sparkle, cross, hexagon, colour, sharp edge
```

---

# PART 3 — BACKDROPS

These sit behind the UI at **12% opacity**. They must be **quiet**. A busy backdrop destroys legibility.

**Composition rule for all four:** the centre 60% must be near-empty and low-contrast. All detail belongs at the edges. Text will sit on top of the centre.

## A6 — Night backdrop

```
A vertical composition, portrait orientation. A dark, empty stone room at
night, seen from a low angle. Faint moonlight enters from the upper edge
and dies before reaching the floor. Heavy shadow occupies the lower two
thirds. There is nothing in the room — no furniture, no people, no objects.
The centre of the frame is almost entirely dark and featureless.
Extremely low contrast. Very dark overall. Monochrome charcoal.
Atmospheric emptiness, not a scene.

[STYLE ANCHOR]
[NEGATIVE] + people, faces, furniture, objects, text, bright areas,
high contrast, centre detail, symmetry, doorway in centre
```

## A7 — Dawn backdrop

```
A vertical composition, portrait orientation. The same empty stone room,
now with pale early light entering from the top edge in soft diffused
shafts. Dust drifts in the light. The lower half remains in shadow.
Still completely empty — no furniture, no people, no objects.
The centre of the frame is soft, hazy and low-contrast.
Monochrome, slightly warmer than the night version. Gentle, quiet.

[STYLE ANCHOR]
[NEGATIVE] + sun, sky, landscape, people, objects, high contrast,
centre detail, colour
```

## A8 — Day backdrop

```
A vertical composition, portrait orientation. The same empty stone room in
flat daylight. Even, shadowless, slightly overexposed toward the top.
The walls show aged plaster texture and faint water staining.
Completely empty — no furniture, no people, no objects.
The centre is flat and featureless.
Monochrome, low contrast, neutral, almost clinical.

[STYLE ANCHOR]
[NEGATIVE] + windows in centre, people, furniture, strong shadows,
texture in centre, colour
```

## A9 — Verdict backdrop

```
A vertical composition, portrait orientation. The same empty stone room,
now with a single strong shaft of light falling from directly above onto
the floor, forming a bright pool. Everything outside the pool falls into
deep shadow. The room is empty — nothing stands in the light.
The pool of light sits in the LOWER third of the frame, not the centre.
Monochrome, high contrast, theatrical, final.

[STYLE ANCHOR]
[NEGATIVE] + people, figures, silhouettes, objects in the light,
centre brightness, colour
```

---

# PART 4 — OVERLAYS

## A14 — Fog overlay (connection states)

```
A soft, formless fog texture filling the entire frame evenly. Wispy,
low-contrast, drifting mist with no distinct shapes, no edges, no
recognisable forms. Uniform density across the whole image so that
tiling it produces no visible seam.
Pale grey-white on a fully transparent background.
Extremely subtle — barely there.

[NEGATIVE] + clouds, smoke plumes, distinct shapes, faces, figures,
dense areas, hard edges, colour, vignette
```

**Post:** verify tiling. Offset the image by 50% in both axes; if a seam appears, blur the boundary or regenerate.

## A15 — Spotlight cone

```
A soft radial light gradient: brightest at the exact centre, falling off
smoothly and evenly to fully transparent at the edges. Perfectly circular,
perfectly symmetrical, no visible banding, no edge, no rim.
Warm cream light on a fully transparent background.
Nothing else in the frame.

[NEGATIVE] + cone shape, rays, beams, dust, particles, edges, banding,
shapes, colour
```

---

# PART 5 — EMBLEMS

## A12 — Town victory emblem

```
A single engraved emblem, centred, flat-on. An open human hand, palm
forward, fingers together, rendered as a protective gesture — the
traditional khamsa form, but restrained and severe rather than decorative.
Surrounded by a thin circular border of simple geometric interlace.
Bone-white engraving on transparent background. Flat, symmetrical,
no shading, no depth.

[STYLE ANCHOR]
[NEGATIVE] + eye in the palm, jewellery, colour, gold, ornate excess,
text, filled background
```

## A13 — Mafia victory emblem

```
A single engraved emblem, centred, flat-on. A featureless hood — the
shape of a raised cowl with the face entirely in shadow, no features,
no eyes, nothing inside. Rendered as pure silhouette with fine engraved
linework describing the fabric folds.
Surrounded by the same thin circular border of geometric interlace.
Bone-white engraving on transparent background. Flat, symmetrical.

[STYLE ANCHOR]
[NEGATIVE] + face, eyes, mouth, skull, blood, weapon, colour, gore, text
```

> **Generate A13 with A12 as a reference** so both emblems share the identical circular border. Two differently-bordered emblems side by side on the result screen will look like a mistake.

---

# PART 6 — MOTION (optional, if you generate video)

These are **not** required. Ship without them if time is short — the coded animations in `15` Part 3 carry the experience.

## V1 — Night transition sting (1.5s loop-out)

```
A slow vertical wipe: darkness rising from the bottom of the frame to the
top, swallowing a dim stone room. Nothing moves except the darkness itself.
No people, no objects, no camera movement. Locked-off camera.
Monochrome, extremely dark. 1.5 seconds. Ends fully black.

[NEGATIVE] + people, objects, camera movement, colour, fast motion,
particles, text
```

## V2 — Dawn transition sting (1.5s)

```
A slow vertical wipe in reverse: pale light descending from the top of the
frame, gradually revealing an empty stone room. Dust drifts faintly in the
light. Nothing else moves. Locked-off camera.
Monochrome, soft. 1.5 seconds. Begins black, ends dimly lit.

[NEGATIVE] + people, objects, camera movement, colour, sun, sky, text
```

**Format:** WebM VP9, alpha where possible, under 400KB each. If they exceed that, cut them — a coded fade is better than a heavy video.

---

# PART 7 — POST-PROCESSING (mandatory)

Nothing ships raw. For every asset:

| Step | Rings & ornaments | Backdrops | Overlays |
|---|---|---|---|
| 1 | Remove background → true alpha | — | Remove background |
| 2 | Threshold to pure white | Desaturate to full monochrome | Threshold alpha only |
| 3 | Trim to content bounds, then re-pad symmetrically | Crush blacks to `#0D0F14` floor | — |
| 4 | **Check at 48px** — illegible means regenerate, not sharpen | Lift highlights toward `#D9CDB4` | Verify tiling (A14 only) |
| 5 | Export PNG-8 with alpha | Export WebP q80, 1080px longest edge | PNG-8 |

**Budget check:** all fifteen assets together must come in **under 2 MB**. If they do not, the backdrops are too large — reduce quality before removing assets.

**The 48px test is the one that matters.** Most ornate AI output looks superb at 1024px and turns to grey mush at 48px. Shrink first, judge second, then decide whether to keep it.

---

# PART 8 — GENERATION ORDER

Do not generate all fifteen at once. Order matters because later assets reference earlier ones.

1. **A1** (seat ring, idle) — everything else is judged against it. Iterate until it reads at 48px
2. **A2, A3** — generated *from A1 as reference* so the geometry matches
3. **A4, A5, A10** — ornaments, matched to A1's linework weight
4. **A6** (night backdrop) — the tone reference for the other three
5. **A7, A8, A9** — generated *from A6 as reference* for consistent room and lighting language
6. **A11, A14, A15** — pure gradients, trivial, do them last
7. **A12, A13** — emblems, A13 referencing A12

**If only one asset gets made properly, make it A1.** It renders more times than every other asset in the app combined.
