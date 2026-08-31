# ASSET_PLAN.md — every screen, its tone, and every asset it still needs

A walk through the app in the order a new host meets it. For each screen: what it
is **for**, what it should **feel like**, and every image and video that should
exist for it — each with its own prompt and its own reference anchor from
`raw_assets/`.

Companion to `BRAND_KIT.md` (the rules) and `tool/IMAGE_PROMPTS.md` (how the
shipped card art was made). `AI_BRIEF.md` is the *marketing* pack — different
job, no luminance budgets. **This file is in-app art**, and every asset here is
governed by the leakage contract.

**Totals:** 14 images (all of them slots already declared and empty in
`tool/manifest.json`), 7 videos (new). Nothing here is a redesign — it is the
list of holes.

---

## STATUS: delivered and shipped — 2026-08-20

All 21 assets arrived, went through the pipelines and are wired to screens.
`flutter analyze lib` clean of errors/warnings, `flutter test` **398 passed**.

| | Result |
|---|---|
| 14 images | `tool/incoming/` -> `normalise_art.py`. Every tier-3 slot gained into its band. |
| 7 loops | `raw_assets/assets/videos/` -> new `tool/normalise_video.py`. **2.21 MB total**, all inside budget. |
| Wired | onboarding x5, `bg_home` + loop, `bg_day`, and the six announcements in `MatchFlow._Moment` |

**Three things changed against what this file originally said.**

**1. `bg_vote` does NOT go on the voting screen.** `VotingScreen` is "the secret
day ballot" and routes through `PassScreen` — the phone is in one voter's hand,
so it is an **in-hand surface** and this plan was wrong to treat it as public.
`voting_symmetry_test.dart` caught it: an animated WebP sits at whatever frame
wall-clock time says, so two roles rendered a millisecond apart stopped
producing byte-identical ballots. `bg_vote` and its loop now belong only to the
on-table announcement that precedes the ballot (`_Moment.voting`).

**2. The loops did not close, and two of them swept.** Every generated loop
arrived with the same two defects, so both corrections live in the pipeline
rather than in a note asking for a regeneration:

| Loop | As delivered | After |
|---|---|---|
| `bg_vote_loop` | 59 -> 24 -> 59, a 2.4:1 dip mid-loop | 9.0% |
| `outcome_saved_loop` | starts 41.5, ends 56.1 — a 35% blink once a cycle | 8.3% |
| `bg_home_loop` | +45% mid-loop, and a 10% step at the loop point | 8.6% |
| `outcome_death_loop` | 57.7-58.7 across 96 frames | 1.1% — this one was already right |

`close_loop()` cross-dissolves the tail into the head over 8 frames; `limit()`
pulls outlying frames back to ±8% and leaves everything inside alone, so the
drift the loop is *for* survives and only the swing goes.

**3. No `*_still.webp` is shipped.** Every loop already has a still counterpart
in the image manifest at full resolution — `bg_night_loop`/`bg_night`,
`outcome_death_loop`/`outcome_death` — and `AppBackdrop(image:, loop:)` takes
the pair, rendering the still under Reduce Motion. Writing frame 0 as a second
file would have shipped seven lower-resolution duplicates of art already there.

**Two things still open.**

- **`badge_frame` has no alpha.** The manifest declares `alpha: true`; it was
  delivered as JPEG, which cannot carry a transparent centre, so the ring is a
  solid square. It is tier 4, cosmetic, and not yet referenced by any widget —
  but it needs redelivering as PNG with the centre knocked out before the
  analytics screen can use it.
- **`home_backdrop.webp` is still an orphan** — the pre-existing one, unrelated
  to this delivery. `bg_home` replaced its job. Delete it.

---

---

## Read these three things first

### 1. No video, and no art at all, on an in-hand surface

Three screens are reached while the phone is in one player's hand: **PassScreen**,
**RoleCard reveal**, **NightActionScreen**. They get the charcoal ground, the
canvas weave, and the four shipped card faces. Nothing else, ever.

A video is by definition brightness that changes over time. On an in-hand screen
it breaks the ±2% luminance budget (L-05) on almost every frame, and a loop that
is at a different point in its cycle for a fast player than a slow one is a
*timing* channel too (L-08). There is no way to make it safe. **Every video in
this file is on-table only** — home, phase announcements, morning, result.

Marked **🔒 IN-HAND** below wherever it applies. Those screens are finished; do
not generate for them.

### 2. The backdrop slots are not wired up

`AppBackdrop` takes an optional `image`, and **no caller passes one** — all
eighteen call sites use the bare ground. The doc comment saying "Only Result
passes one" is stale; `home_backdrop.webp` ships in the APK and is referenced by
nothing but the generated constants file.

So dropping `bg_home.webp` into `assets/images/` will do nothing on its own.
Each backdrop needs one line at its screen's `AppBackdrop(...)` call. Worth
knowing before you generate four of them. Same for the orphan: either wire
`home_backdrop.webp` up or delete it.

### 3. Use animated WebP, not a video player

`video_player` is not in `pubspec.yaml`, and adding it brings a platform view,
an initialisation race, and a lifecycle to manage — for a three-second ambient
loop behind some text.

Flutter's `Image.asset` plays **animated WebP** natively. No dependency, no
platform view, composites exactly like every other image in the app, and drops
straight into the `AppBackdrop`/`CinematicText` widgets that already exist.

Consequences to design for:

- **Budget: ≤ 600 KB per loop, ≤ 4 MB total.** The release APK is already
  62.2 MB universal. Deliver ProRes/PNG frames; the pipeline encodes.
- **12 fps, 3–5 seconds, seamless.** These are ambient beds, not clips.
- **Reduce Motion needs a static fallback.** An animated WebP has no pause API.
  Ship a stills frame beside every loop (`*_still.webp`) and pick between them —
  the brand rule is that Reduce Motion degrades to the *finished* state and never
  changes how long anything takes (`BRAND_KIT.md` §9.3).
- **Per-frame luminance:** every frame inside the slot's `lum_band`, and no
  frame-to-frame excursion beyond ±10% of the loop mean. No cuts, no flashes, no
  pulse on a beat. The score never reacts to the game and neither may the
  picture.

---

## The reference anchors

**Attach a `raw_assets/` file as an image reference on every single generation** —
not just the first. This matters more than any wording below. The four paintings
are the deck; new art has to look like it came out of the same box.

| Anchor | File | Use it for |
|---|---|---|
| **MAFIA** | `raw_assets/Mafia.png` | night, dark interiors, the lowest key |
| **DOCTOR** | `raw_assets/Doctor_in_archway_frame_202607301230.jpeg` | architecture, arches, morning, rescue |
| **DETECTIVE** | `raw_assets/Detective_with_magnifying_lens_202607301230.jpeg` | investigation, daylight, scrutiny |
| **CITIZEN** | `raw_assets/Painterly_illustration_for_playi…_202607301230.jpeg` | the town, crowds, ordinary life |
| **BACK** | `raw_assets/Symmetrical_card_back_design_abs…_202607301221.jpeg` | ornament, pattern, symmetry, frames, anything abstract |
| **MASK** | `raw_assets/icon/Porcelain_mask_in_shadow_2K_202608030657.jpeg` | the mark, emblems, badges, single objects in shadow |

When an asset names two anchors, attach both — the first for composition, the
second for surface and palette.

---

## SCENE STYLE BLOCK — paste verbatim

The deck's own style block is figure-centric. These are grounds that sit *behind
bone-white type*, so they are scenes, low-contrast, and quiet in the middle.

```
Painterly digital illustration in the same hand as a luxury noir playing-card
deck. Semi-realistic oil-and-gouache rendering, visible brushwork, impasto edges.
Heavy aged-canvas texture and fine halftone print grain across the entire image.
Deep vignette darkening all four edges. Distressed, worn, slightly faded antique
print. One dramatic raking light source, deep falloff into shadow. Low contrast
overall, no bright highlights, nothing catching the eye at the centre of the
frame. Symbolic rather than literal. Adult, restrained, cinematic, still.
```

## COLD BLOCK — append to every prompt in this file

```
COLOUR: desaturated cold palette — charcoal #0D0F14, gunmetal #161A22, graphite
#1F2530, slate #717573, bone white #E9E4D9. No red, no orange, no gold, no warm
tint anywhere in the image.
VALUE: overall very dark and even. Mean brightness low. No area of the image
more than one third as bright as bone white.
```

> Every tier-3 slot is **cold**. The `"register": "warm"` field on `bg_home` and
> `bg_vote` in the manifest is left over from the reverted warm-ground
> experiment (`HANDOFF` §2a). Ignore it; it is being removed.

## NEGATIVE PROMPT — paste verbatim

```
text, letters, numbers, words, arabic script, watermark, signature, logo,
caption, UI, interface, frame, border, card edge, rounded corners, playing card
mockup, visible face, eyes, portrait likeness, cartoon, anime, chibi, mascot,
cute, comic, cel shading, neon, glow, lens flare, bokeh, HDR, oversaturated,
candy colours, teal and orange, clean vector, flat minimal, 3D render, plastic,
glossy CGI, busy centre, high contrast, bright highlight, blown highlights
```

---

# PART 1 — LAUNCH

## S-00 · SplashGate

**What it is** — the veil between the Android launch window and the first Flutter
frame. Same mask, same size, same ground on both sides, then it dissolves over
600ms. No hold, no logo animation, no version string.

**Tone** — *a cloth lifted off something.* Not an intro.

**Assets** — none needed. `splash_mask.webp` ships and works. **Do not animate
this.** The dissolve is the whole effect, and a moving splash adds waiting to a
screen whose entire design goal is adding none.

---

# PART 2 — ONBOARDING (six cards, first launch)

Six panels, dealt one at a time. Each carries a title, two to five lines, and a
large faint numeral behind the type. `OnboardingCard` already takes an optional
`image` that lands as a **band above the type** — these five drop straight in
with no code change.

Square, because they sit inside a panel rather than behind a screen. Dimmer than
a full-bleed backdrop for the same reason.

---

### IMG-01 · `onboarding_story` — card 1, الحكاية

> «بلد صغيرة بتنام كل ليلة، وتصحى الصبح ناقصة واحد.»
> *A small town sleeps every night and wakes up one short.*

**Tone** — *a fairy tale told late.* Wide, quiet, nobody in it yet. This is the
one card that says nothing about the app at all, so it must not look like an app.

**Spec** 1024×1024 · tier 3 · lum band **14–30** · quality 82
**Anchor** CITIZEN (composition) + BACK (surface)

```
[SCENE STYLE BLOCK]
SUBJECT: A small old town at night seen from a low hill — flat rooftops, narrow
lanes, shuttered windows, one or two faint lit panes. No people. No moon. The
town sits in the lower third; the upper two thirds are empty night sky, almost
featureless. Distant, hushed, asleep.
[COLD BLOCK]
```

---

### Card 2 · الأدوار — **no new asset**

**Tone** — *the deck on the table.* The only interactive card: the four paintings
lie face-down and you turn them over.

Uses the four shipped gallery paintings through `OnboardingRoleGrid`. There is no
`onboarding_roles` slot and there should not be — the roles chapter already has
the best art in the app.

---

### IMG-02 · `onboarding_night` — card 3, الليل

> «الموبايل بيلف على الكل واحد واحد.»
> *The phone goes round, one at a time.*

**Tone** — *hush.* The half of the game the app actually runs. Dim, orderly,
slightly tense.

**Spec** 1024×1024 · tier 3 · lum band **14–30**
**Anchor** MAFIA (light and key) + BACK (surface)

```
[SCENE STYLE BLOCK]
SUBJECT: A round table seen from above in near-darkness, ringed by the empty
shoulders and hands of seated figures — no faces, no heads in frame. One small
dark rectangle at the centre of the table catches a sliver of light. Hands rest
on the table, still, waiting their turn. Almost black at the edges.
[COLD BLOCK]
```

> The rectangle is a phone and must read as an *object*, not a screen. No glow —
> a glowing phone contradicts the product. It catches light, it does not give it.

---

### IMG-03 · `onboarding_day` — card 4, النهار

> «الصبح الموبايل بيتحط في نص الترابيزة ويقول مين راح.»
> *In the morning the phone goes in the middle of the table and says who's gone.*

**Tone** — *the argument.* Public, awake, unresolved. The brightest card in the
deck — and still dimmer than `bg_day`, because it sits inside a panel.

**Spec** 1024×1024 · tier 3 · lum band **14–30**
**Anchor** DETECTIVE (light) + CITIZEN (subject)

```
[SCENE STYLE BLOCK]
SUBJECT: A town square in early morning, thin grey light, long shadows. A loose
ring of figures stands facing inward, seen from behind and above, small in the
frame, all of them in silhouette. One empty gap in the ring. Flat facades
behind. Cold overcast light, no sun, no colour in the sky.
[COLD BLOCK]
```

> The gap in the ring is the whole idea. It should read before the figures do.

---

### IMG-04 · `onboarding_pass` — card 5, الموبايل

> «امسك الموبايل مايل ناحيتك، وخلي ضهره لباقي الترابيزة.»
> *Hold the phone tilted toward you, its back to the rest of the table.*

**Tone** — *instruction, and the reason the deck exists.* The only chapter
teaching something no rulebook covers. Close, physical, disciplined.

**Spec** 1024×1024 · tier 3 · lum band **14–30**
**Anchor** MAFIA (key) + MASK (single object in shadow)

```
[SCENE STYLE BLOCK]
SUBJECT: One pair of hands in close-up, cupped around a small dark rectangular
object and tilted sharply away from the viewer, shielding it. Forearms and cuffs
visible, no face, no body above the elbows. Deep shadow behind the hands. The
object's face is turned entirely away — the viewer sees only its back and the
fingers holding it.
[COLD BLOCK]
```

> Hands are where generators fail. Make six and keep one. Fingers in shadow and
> partly cropped survive far better than fingers splayed in light.

---

### IMG-05 · `onboarding_win` — card 6, الفوز

> «كده إنت عارف كل حاجة — الباقي كلام وشكّ.»
> *Now you know everything — the rest is talk and suspicion.*

**Tone** — *the town at rest.* The card that hands the host to a real match, so it
resolves rather than concludes. Quiet, not triumphant. **Nothing celebrates.**

**Spec** 1024×1024 · tier 3 · lum band **14–30**
**Anchor** CITIZEN + BACK

```
[SCENE STYLE BLOCK]
SUBJECT: The same small town at first light, seen from the same low hill as the
first card — rooftops, lanes, shutters now open. No people. The sky pale grey and
empty across the upper two thirds. Utterly still. A place that has settled, not a
place that has won.
[COLD BLOCK]
```

> **Anchor this one on IMG-01, not on a raw asset.** Cards 1 and 6 are the same
> view at two hours of the day; that rhyme is what closes the deck. Generate
> IMG-01 first, then attach it here.

---

# PART 3 — SETUP

## S-01 · Home

**Tone** — *the lamp is lit and the table is ready.* The only screen a returning
host sees every time. Warm in feeling, cold in pixels.

Already carries the ambient falling icons at 4–8% opacity. That layer is
finished; leave it.

---

### IMG-06 · `bg_home` — the home backdrop

**Spec** 1080×1920 · tier 3 · lum band **14–30**
**Anchor** BACK (primary — this one is ornament, not scene) + MAFIA (palette)

```
[SCENE STYLE BLOCK]
SUBJECT: No figure. No place. A large ornamental engraved medallion, perfectly
symmetrical, centred and enormously enlarged so only its middle third fills the
frame — filigree, fine linework, worn plate. Fading almost entirely into
darkness at every edge. Flat to the picture plane. Extremely low contrast, like a
pattern glimpsed on the back of a card in a dark room.
[COLD BLOCK]
```

> **Requires wiring** — see note 2 at the top. `home_screen.dart:92`.
> The falling icons sit on top of this, so it must stay near-featureless or the
> two ornaments will fight.

---

### VID-01 · `bg_home_loop` — **highest-value video in the app** ⭐

**Tone** — *breathing.* The host sits on this screen while people find chairs.
It should feel like the app is waiting, not idling.

**Spec** 1080×1920 · animated WebP · 12 fps · **5s seamless** · ≤ 600 KB
· every frame inside lum 14–30 · static fallback `bg_home_still.webp`
**Anchor** IMG-06 (generate the still first, animate that)

```
A 5-second seamless looping shot. An enormous ornamental engraved medallion in
near-darkness, filling the frame, extremely low contrast. The only motion is a
single soft raking light drifting very slowly across the filigree from left to
right and back, revealing a little more of the linework as it passes. No cuts, no
flashes, no pulse. The camera does not move. Grain and canvas texture hold still.
Almost imperceptible — a room where a candle moved, not an animation.
```

---

## S-02…S-04 · Groups · Add players · Roles · Settings

**Tone** — *administration, done fast.* Setting the table. A rematch should reach
role distribution in three taps, and every one of these screens is measured by
how quickly it is gone.

**Assets: none, deliberately.** These are forms. The roles screen already shows
the deck through `CardSpread`, which is the right amount of theatre for a screen
whose job is arithmetic. Art here would slow down the one path the design is
optimised to make fast.

---

# PART 4 — THE MATCH

## S-05 · Pre-night lobby

**Tone** — *the table settles.* «ضع الهاتف على الطاولة وانتظر الإشارة» — the last
public moment before the phone starts moving.

**Assets** — reuses `bg_night` (IMG-07). No slot of its own; it is the same room
one minute earlier.

---

## 🔒 S-06 · PassScreen — IN-HAND

**Tone** — *a closed door with a name on it.* One piece of information: whose turn
it is. Nothing that would reward picking the phone up out of turn.

**No assets. Ever.** Ground, weave, name, hold pad.

---

## 🔒 S-07 · RoleCard reveal — IN-HAND

**Tone** — *the only private moment in the game.* Swipe, the card turns, five
seconds, gone.

**No new assets.** The four shipped faces and the one shared back. Adding
anything here means re-solving the ±2% budget across four paintings, and the
pipeline will refuse to write.

---

### IMG-07 · `bg_night` — «الضلمة نزلت على البلد… كله يغمّض»

**Tone** — *the dark comes down.* On-table, everyone watching, three seconds.
The lowest-key image in the app.

**Spec** 1080×1920 · tier 3 · lum band **10–22** — the darkest band in the manifest
**Anchor** MAFIA (both composition and palette)

```
[SCENE STYLE BLOCK]
SUBJECT: A shuttered town street at the moment the last light goes out. Tall dark
facades on both sides converging toward a vanishing point low in the frame. Every
window black. No people, no lamps, no moon. The upper half of the frame is almost
entirely empty darkness. Barely legible — a place you can only just make out.
[COLD BLOCK]
```

---

### VID-02 · `bg_night_loop` ⭐

**Tone** — *the light leaving.* This is the announcement the whole table turns to
watch, six times a game.

**Spec** 1080×1920 · 12 fps · **4s seamless** · ≤ 600 KB · every frame lum 10–22
· fallback `bg_night_still.webp`
**Anchor** IMG-07

```
A 4-second seamless looping shot of a shuttered dark street, tall facades
converging, every window black. The only motion is a very slow drift of thin haze
across the lower third and an almost imperceptible deepening of the shadow in the
upper half, which returns to where it began. No cuts, no flashes, no light
sources appearing. The camera does not move. Painterly, grainy, still.
```

---

## 🔒 S-08 · NightActionScreen — IN-HAND

**Tone** — *do your job and pass it on.* An 8-second dwell gate and a 12-second
turn floor mean a fast player and a slow one look identical from outside.

**No assets.**

---

## S-09 · Morning — two outcomes, two tones

The phone is back on the table. The whole point of this screen is that everyone
hears it at the same time.

---

### IMG-08 · `outcome_death` — «الصبح جه… والبلد صحيت على خبر وحش»

**Tone** — *the empty chair.* Someone lost. **No drama, no blood, no crime
scene** — the mafia here is a card in a fairy tale.

**Spec** 1024×1536 · tier 4 · cold
**Anchor** DOCTOR (architecture) + MASK (the single object)

```
[SCENE STYLE BLOCK]
SUBJECT: A single empty wooden chair in a bare room, seen straight on, lit by
raking light from one high window out of frame. A coat still over its back. Dust
in the light. Nothing else in the room. Absolutely no figure, no body, no blood,
no disorder. Formal, still, and sad.
[COLD BLOCK]
```

---

### IMG-09 · `outcome_saved` — «الصبح جه… ومحدش مات النهارده»

**Tone** — *relief, held.* The Doctor got there. Not a victory — a night survived.

**Spec** 1024×1536 · tier 4 · cold
**Anchor** DOCTOR

```
[SCENE STYLE BLOCK]
SUBJECT: An open doorway in a thick stone wall, seen straight on, with pale grey
morning light coming through it into a dark interior. The threshold is empty.
Nobody in frame. A shallow arch above. Calm, plain, and quietly relieved.
[COLD BLOCK]
```

---

### VID-03 · `outcome_death_loop`

**Spec** 1024×1536 · 12 fps · **4s seamless** · ≤ 500 KB · fallback still
**Anchor** IMG-08

```
A 4-second seamless looping shot of a single empty wooden chair in a bare room, a
coat over its back, lit by raking light from one high window. The only motion is
dust drifting slowly through the shaft of light and the faintest movement at the
hem of the coat. The chair does not move. The camera does not move. No cuts, no
change in the light.
```

---

### VID-04 · `outcome_saved_loop`

**Spec** 1024×1536 · 12 fps · **4s seamless** · ≤ 500 KB · fallback still
**Anchor** IMG-09

```
A 4-second seamless looping shot of an empty stone doorway with pale grey morning
light coming through into a dark interior. The only motion is a very slow
brightening and settling of the light in the doorway, returning to where it
began, and faint dust in the air. No figure enters. The camera does not move.
```

> Keep VID-03 and VID-04 the same length and the same overall brightness. The
> table learns the rhythm of these two announcements fast, and a "someone died"
> that runs longer than a "nobody died" tells them the answer before the words do.

---

## S-10 · Discussion

**Tone** — *the clock is running.* The timer is the screen. Structured or free,
the app's only job is to be visible from every seat.

---

### IMG-10 · `bg_day`

**Tone** — *the one bright surface in the app.* Public by definition — nobody is
holding the phone.

**Spec** 1080×1920 · tier 3 · lum band **26–46** — the brightest band shipped
**Anchor** DETECTIVE (light) + CITIZEN (subject)

```
[SCENE STYLE BLOCK]
SUBJECT: An empty town square under flat overcast morning light. Shuttered
facades on three sides, worn paving, a dry fountain off to one side. No people at
all. Long soft shadows, no sun in frame, no sky colour. The centre of the square
is empty and even. Wide, plain, and waiting.
[COLD BLOCK — but allow the overall value to sit at the top of the stated band]
```

> This one is *supposed* to be brighter. Do not fight the band down out of habit —
> the contrast between this and `bg_night` is what makes a day feel like a day.

---

## S-11 · Voting

**Tone** — *no going back.* «الشعب هيقرر… ومفيش رجوع».

---

### IMG-11 · `bg_vote`

**Spec** 1080×1920 · tier 3 · lum band **16–32**
**Anchor** CITIZEN + BACK

```
[SCENE STYLE BLOCK]
SUBJECT: A worn wooden table surface seen from directly above, filling the whole
frame, scarred and ringed with use. Nothing on it. Raking light from the upper
left across the grain. Almost abstract — a surface, not a place. Deep vignette
into black at all four edges.
[COLD BLOCK]
```

> Flat and empty on purpose: the vote tally bars are drawn on top of this and
> must be the only thing anyone reads.

---

### VID-05 · `bg_vote_loop`

**Tone** — *pressure.* The one moment the app is allowed to tighten.

**Spec** 1080×1920 · 12 fps · **3s seamless** · ≤ 500 KB · fallback still
**Anchor** IMG-11

```
A 3-second seamless looping shot of a scarred wooden table surface from directly
above, filling the frame, nothing on it. The only motion is a single hard shadow
edge creeping very slowly across the grain from left to right and returning. No
objects, no hands, no cuts, no flashes. The camera does not move.
```

---

## S-12 · Vote result

**Tone** — *the tally lands together.* Bars fill from zero in order so the whole
table arrives at the outcome at the same moment; the eliminated row is last, and
that pause is the point.

**Assets: none.** `VoteBar` is finished and the timing is doing the work. A
backdrop here would compete with the one thing everyone is reading.

---

## S-13 · Result — «المافيا خلصت على البلد» / «الشعب انتصر»

**Tone** — *someone just lost; the table should feel it.* One win sting for both
outcomes. **No confetti, no fanfare.** The screen where the four gallery
paintings finally come out.

---

### IMG-12 · `outcome_mafia_win`

**Spec** 1024×1536 · tier 4 · cold
**Anchor** MAFIA + BACK

```
[SCENE STYLE BLOCK]
SUBJECT: A town seen from a high window at night, every street dark, not one lit
pane anywhere. Heavy curtain edges framing the left and right of the view. The
town small and far below. Nobody in frame. Cold, quiet, and completely settled —
an ending, not a triumph.
[COLD BLOCK]
```

---

### IMG-13 · `outcome_town_win`

**Spec** 1024×1536 · tier 4 · cold
**Anchor** CITIZEN + DOCTOR

```
[SCENE STYLE BLOCK]
SUBJECT: A town square at dawn with the shutters open along every facade and thin
grey light reaching the paving for the first time. Empty of people. A single
banner or cloth hanging still from a window. Plain, cool, and unhurried. Relief
rather than celebration.
[COLD BLOCK]
```

---

### VID-06 · `outcome_mafia_win_loop` · VID-07 · `outcome_town_win_loop`

**Spec (each)** 1024×1536 · 12 fps · **5s seamless** · ≤ 600 KB · fallback still
**Anchor** IMG-12 / IMG-13 respectively

```
VID-06: A 5-second seamless looping shot of a dark town seen from a high window
at night, no lit windows, curtain edges framing the view. The only motion is the
slowest possible drift of the curtain edge and a faint haze over the rooftops. No
lights come on. The camera does not move. No cuts.
```

```
VID-07: A 5-second seamless looping shot of an empty town square at dawn, open
shutters, thin grey light on the paving, a single cloth hanging from a window.
The only motion is that cloth stirring very slightly and the light settling. No
people appear. The camera does not move. No cuts.
```

> **Same length for both.** A longer, richer animation for one outcome than the
> other tells the table who won before the words do — same failure mode as
> VID-03/04, one screen later.

---

# PART 5 — POST-GAME

## S-14 · Analytics

**Tone** — *the post-mortem, and the best part of the evening.* Who voted for
whom, finally public. Colour is allowed here; the role accents are legal on this
screen and nowhere reachable in a hand.

---

### IMG-14 · `badge_frame`

**Tone** — *a small award, seriously made.* Achievement rings on the analytics
timeline.

**Spec** 1024×1024 · tier 4 · **alpha channel required** · cold
**Anchor** BACK (primary) + MASK

```
[SCENE STYLE BLOCK]
SUBJECT: No figure, no scene. A single circular engraved ring — a medallion
border only, with the centre completely empty and transparent. Fine filigree,
worn plate, perfectly symmetrical, flat to the picture plane. Nothing inside the
ring. Isolated on a plain background for cutting out.
[COLD BLOCK]
```

> Deliver with a real alpha channel, centre fully transparent. The role emblem
> and the achievement are composited inside it by the widget.

---

## S-15 · History

**Tone** — *the ledger.* A list of nights that happened. Utilitarian.

**Assets: none.** A backdrop behind a scrolling list of dates is decoration for
its own sake.

---

# Production order

Ranked by how much each changes the app per unit of effort.

| # | Assets | Why first |
|---|---|---|
| 1 | **IMG-01 → IMG-05** (onboarding) | Zero wiring — `OnboardingCard` already takes the image. Five files and one line each in the chapter table. Highest ratio in the file. |
| 2 | **IMG-07 `bg_night`, IMG-10 `bg_day`** | The two phase announcements the table watches most. Needs the `AppBackdrop` wiring (note 2). |
| 3 | **IMG-08, IMG-09** (morning outcomes) | The screen that carries the most feeling per second. |
| 4 | **VID-01 `bg_home_loop`** | The screen with the longest dwell time. Prove the animated-WebP path here. |
| 5 | **IMG-06, IMG-11, IMG-12, IMG-13, IMG-14** | Fills every remaining declared slot. |
| 6 | **VID-02 → VID-07** | Only after the stills exist — every loop is animated *from* its still, so a still that is not right yet is a video generated twice. |

**Do not generate a video before its still exists and is approved.** Six of the
seven are animations of an image in this file, and the still is also the Reduce
Motion fallback, so it has to be made either way.

---

# Delivery checklist

For every asset, before it lands:

- [ ] Generated at **2× target** and downscaled — detail survives, artefacts average out.
- [ ] The `raw_assets/` anchor was attached to **every** generation in the set, not just the first.
- [ ] The style block was **byte-identical** across the whole set; only SUBJECT changed.
- [ ] **No text of any kind** in the image. All copy is Flutter text from the ARB.
- [ ] Slot declared in `tool/manifest.json` with `tier`, `out`, `size`, `quality`, `lum_band`.
- [ ] `python tool/normalise_art.py` run — it gains tier 3 into the band for you.
- [ ] Videos: seamless at the loop point, ≤ budget, static fallback shipped beside it.
- [ ] `flutter test test/golden/leakage/` **green, with no tolerance widened.**
- [ ] Nothing in this file was referenced from a screen reachable while the phone
      is in a hand — `handoff_purity_test.dart` will tell you, but know it first.
