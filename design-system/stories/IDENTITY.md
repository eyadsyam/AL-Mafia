# Stories identity — «قصص وتحقيقات»

> **For agents.** This file is complete on its own. Read it once, open
> `img/_contact_sheet.jpg` to see every reference image with its path, and take
> values from `tokens.json` / `tokens.css`. The living page is `index.html`.
> Stories is a **separate identity** from Mafia (owner, 2026-10-09: «كل لعبة ليها
> هويتها»). Nothing from `../mafia/` is used here, and nothing from here is used in Mafia.

Status: draft v1.0, 2026-10-10. Awaiting owner sign-off. Not wired into `lib/` yet.

---

## 0. The ten rules

1. **The room is lit by one brass desk lamp.** Warm dark ground, one radial pool of
   amber light above the content. Nothing else glows.
2. **Paper is the only light surface.** Case files, suspect cards and clue slips are
   manila paper `#E1D0AC` with dark ink. Everything else is lamp-dark.
3. **Ratio 60 / 25 / 10 / 5:** lamp ground, manila paper, amber, accents (velvet, nile).
4. **Amber is the action.** The one primary button, the active tab, the evidence tag.
5. **Velvet is the verdict.** The rubber stamp and «وجّه الاتهام» only.
6. **Nile is time.** The night-window blue marks the clock: the discussion timer,
   the dateline chip. Nothing else is blue.
7. **Aref Ruqaa for case titles and the verdict, nothing else**, never under 22 dp.
   IBM Plex Sans Arabic for all reading.
8. **Every case opens with a dateline**, Eastern digits: the date and time from the
   synopsis when it has one («الخميس ١٥ ديسمبر ١٩٦٦ · ٧:٤٠ الصبح»), otherwise the
   category and place («سرقة · الصاغة»). Game UI numbers (timer, moves) stay Western.
9. **Full-colour art, framed like evidence.** Locations and covers feather into the
   lamp ground; portraits sit on paper like a pinned photo. Never on Mafia screens.
10. **Secret cards are identical for every player.** Same paper, same layout, same
    length slot whether «إنت متورط» or «إنت مش متورط».

---

## 1. Who, where, what it should feel like

**Scene:** a few friends in a café at night, or one player alone in bed, reading a Cairo case:
some are period (Garden City 1966, Shepheard Hotel 1951, Cinema Rivoli 1955), most are
today (the hara, the souq, a dorm, a train to Aswan). The art grades every case the same
way, warm and lamplit, so the identity is the lamp and the paper, not the decade.
Under a warm lamp, in no hurry, reading closely.
→ warm dark, high readability, long-form text, paper you want to touch.

**The metaphor:** the investigator's desk in the prosecutor's office, timeless. A brass
lamp, a manila folder, photographs held by a paperclip, a red rubber stamp, the Nile
at night through the window.

| It is | It is not |
|---|---|
| warm amber lamplight, sepia, polished wood, velvet | Mafia's monochrome cards and slate |
| colour paintings of real Cairo places and people | faceless hooded figures |
| reading-first: paper, ruled lines, datelines | a crime-scene-tape / CSI / neon thriller look |
| period Egyptian, specific | generic "detective" (fedora silhouettes, magnifier icons everywhere) |

---

## 2. Where it applies

From the moment the player taps «قصص وتحقيقات» on Home until they return:
hub «أرشيف القضايا» → case sheet → cast / player count → secret card pass →
investigation (moves, found clues) → discussion → secret vote / accusation
(مين؟ ليه؟ إزاي؟) → reenactment → verdict stamp → back to the archive.

**Entry seam:** crossing from Home (Mafia ash) into Stories is a scene change: the
screen dips to `#0A0402` and the lamp pool fades up over 400 ms. Returning reverses it.

Shared app chrome (coin pill, rewarded-ad sheet, settings) keeps its own look but
may sit on top of a Stories screen; it never re-skins the Stories screen.

---

## 3. Colour

Measured from the stories art (covers, locations, evidence, suspects). Full list: `tokens.json`.

### Lamp (60%) — the room
`night #0A0402` · `ground #150B06` · `panel #20120A` · `raised #2C1A0F` · `line #3D2617` ·
text `#F1E3C8` · text2 `#C9B597` · muted `#8F7A62`

### Manila (25%) — the paper
`paper #E1D0AC` · `paperDim #CDB98F` (sheet behind) · `paperLine #B49C70` (ruled lines) ·
`ink #2A1A10` · `ink2 #5B4430`

### Amber (10%) — the lamp's light
`amber #B36E2D` (primary fill) · `amberHi #E0A55C` (highlight text, focus, dateline) ·
`amberDeep #7A4519` (pressed) · `onAmber #1A0C04` (label)

### Accents (5%)
`velvet #6E1A16` (stamp, accusation) · `velvetDeep #430D09` · `nile #161C28` (time) · `nileHi #6F86A6`

### Contrast (checked)
text on ground 15.3:1 · text2 on ground 9.7:1 · muted on ground 4.7:1 (meta only) ·
ink on paper 11.0:1 · ink2 on paper 6.0:1 · velvet stamp on paper 7.6:1 ·
onAmber on amber 4.7:1 (18 dp SemiBold only) · lamp text on velvet 9.1:1 ·
amberHi on ground 9.0:1 · nileHi on nile 4.6:1 (timer fill, not text).

---

## 4. Typography

| Voice | Family | Use |
|---|---|---|
| the case | **Aref Ruqaa** Bold | case titles (30 on sheet, 22 in lists), hub title 40, verdict 44 |
| the record | IBM Plex Sans Arabic 400/500/600 | synopsis, clues, buttons, labels |
| the dateline | Plex Medium 13, amberHi | the line under every case title |
| figures | IBM Plex Mono Medium | timer `03:58`, moves `4 / 17` |

Line height 1.7 (stories are read, not glanced). Synopsis measure 30–36 Arabic words
per line max on tablet; on phone the paper's padding handles it.
Forbidden here: Cairo, Bebas Neue (Mafia's), typewriter or handwriting fonts.

---

## 5. Signature elements

### 5.1 The dossier (paper)
Manila surface, radius 2, paper shadow `0 1px 0 #B49C70, 0 10px 24px rgba(10,4,2,.55)`.
A second sheet `#CDB98F` peeks 4 dp behind at 1.5° rotation. Ruled lines every
28 dp in `#B49C70` at 35% on long text. Used for: case sheet body, suspect card,
clue slip, secret card. Paper is the only element in the app with a shadow.

### 5.2 The rubber stamp
Velvet ink, Ruqaa or Plex SemiBold, double ring border 2 dp, rotated −6°, 85% opacity
with a grain mask so it looks inked, never vector-clean. Existing copy already names
the stamps: «لسه مفتوحة» · «اتحلّت» · «اتحلّت · {score}» · «اتقفلت» · «سري».
Stamp motion: scale 1.25 → 1, 220 ms, ease-out; no bounce, no shake.

### 5.3 The dateline
`الخميس ١٥ ديسمبر ١٩٦٦ · ٧:٤٠ الصبح` in amberHi under the Ruqaa title, optionally
inside a nile chip. Fallback when the story has no date: category · place
(«نصب · مزاد العربيات»). Only 3 of 24 cases carry a year today (cases 18, 19, 20).

### 5.4 The evidence tag
A small amber label (radius 3, a 6 dp punched hole at the start side, a 1 dp thread
line) carrying «دليل ٠٧». Marks found clues and evidence photos.

### 5.5 The lamp pool
`radial-gradient(ellipse 70% 45% at 50% 0%, rgba(224,165,92,.16), transparent 70%)`
over the ground. Never animated, never flickers.

### 5.6 The pinned photo
Suspect portraits sit on paper with 4 dp white-ish border (`#EFE4CC`), radius 1,
a tiny paperclip glyph at the top end, rotated ±1.5°. Never a circle avatar.

---

## 6. Components

**Primary button.** 56 high, radius 10, amber fill, Plex SemiBold 18 onAmber.
Pressed amberDeep. One per screen: «افتح القضية», «نفّذ التحرك», «شوف النتيجة».

**Accuse button.** Same geometry, velvet fill, lamp text. Only «وجّه الاتهام» /
«ثبّت الاتهام».

**Secondary.** 48 high, 1.5 dp amber border at 60%, amberHi label.

**Case row (archive).** Cover thumb 64×96 radius 8 at the start, Ruqaa 22 title,
dateline 12, meta line (category · difficulty dots · minutes), stamp at the end
(small, −6°). Locked: cover 40%, «الملف مقفول» + reason line.

**Case sheet.** Cover art feathered across the top 45%, then the dossier paper
holding: case number «قضية ٢٠», Ruqaa title, dateline, synopsis, players, minutes;
amber primary pinned to the bottom.

**Moves meter.** Plex Mono «4 / 17» + a row of 17 small tick marks (amber filled,
line empty). No progress bars.

**Discussion timer.** Nile track 4 dp, nileHi fill, Mono 28 time. The only nile
element on the screen.

**Clue slip.** Paper, evidence tag at the top start, Plex 500 title, body 16, ruled.

**Secret card.** Full-width paper, fixed height, identical layout for all players;
the involvement line and objective sit in fixed slots of equal height.

**Accusation.** Three questions «مين عملها؟» «ليه؟» «إزاي؟» as paper tabs; options
as rows; velvet confirm.

**Verdict.** Lamp ground, reenactment art feathered, velvet stamp over the result
(«اتحلّت · 120 نقطة» or «اتقفلت»), Ruqaa 44 headline.

---

## 7. Imagery catalogue

All in `img/` (720 px references). Originals at the app paths shown.

| Reference | App path | Use |
|---|---|---|
| `covers/cover_*.webp` (10 of 24) | `assets/images/stories/covers/cover_01…24.webp` | case covers, portrait 640×960 |
| `locations/loc_*.webp` (14) | `assets/images/stories/locations/` | scene art for moves, 1152×768 |
| `evidence/evidence_*.webp` (8 of 20) | `assets/images/stories/evidence/` | clue photos, 768 square |
| `suspects/suspect_n*.webp` (10 of 30) | `assets/images/stories/suspect_n01…30.webp` | character portraits (transparent edges) |
| `grounds/cafe.webp`, `evidence_desk.webp` | `assets/images/stories/` | hub hero, archive ground |
| `grounds/casebook_header.webp`, `season_zero.webp` | `assets/images/online/casebook_header.webp`, `assets/images/casebook/season_zero_cover.webp` | archive header (photo board) |

### Art direction for new Stories images
> Cinematic painted realism, Cairo (period or present day), interior at night lit by warm brass
> lamps and lanterns, amber and sepia, deep mahogany wood, oxblood velvet, polished
> floors with reflections, the Nile and minarets at night through tall windows,
> objects correct for the case's era. Evidence: still life on a dark wooden desk under a single
> lamp. Portraits: Egyptian characters, three-quarter, warm key light, dark ground,
> transparent or black edges. No text, no modern devices, no hooded faceless figures.

Never: Mafia card faces or hooded avatars, monochrome grading, slate grounds,
playing-card motifs.

---

## 8. Motion

press 140 · sheet 280 · paper slide 320 (paper slides in from the end side with a
1.5° settle) · stamp 220 · clue reveal = paper unfolds (scaleY .96 → 1 + fade, 280).
Ease `cubic-bezier(.22,1,.36,1)`. The lamp never moves. Reduce Motion: 150 ms fades.

---

## 9. Copy voice

Egyptian spoken Arabic, investigator's notebook: precise, concrete, period details.
«كل تفصيلة لها معنى. مفيش معلومة بتتولد من الهوا.» Times and dates in Eastern digits
inside story text. Buttons are verbs. The verdict is never cheered; it is stamped.

---

## 10. Do / don't

**Do:** paper for anything you read closely · one amber action · a dateline on every
case · stamps for status · let the colour art be colourful · ruled lines on long text.

**Don't:** Mafia's ash/slate/oxblood/brass or its fonts · crime-scene tape, fingerprint
patterns, magnifier icons as decoration · fedora silhouettes · neon, glow, gradient text
· identical card grids for the archive (use rows) · circle avatars · bright white `#FFF`.

---

## 11. Ship checklist for any Stories screen

- [ ] Lamp ground with one pool of light, nothing else glowing.
- [ ] Anything read closely is on paper; paper is the only shadow.
- [ ] One amber primary (velvet only for accusation).
- [ ] Ruqaa only on case title / verdict / hub title, ≥ 22 dp.
- [ ] Dateline present on case surfaces; story digits Eastern, UI digits Western.
- [ ] Secret card layout identical for every player.
- [ ] No Mafia art, inks or fonts.
- [ ] 360×640 and 430×932 checked, RTL.
