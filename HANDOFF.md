# HANDOFF — read this first

The checkpoint for anyone (human or AI) picking this repo up cold. It is written to
be **cheap to read and sufficient to act on**: everything below is either a fact you
cannot recover from the code quickly, or a decision whose *reasoning* is not obvious
from the diff. Anything you can get from `flutter analyze`, `flutter test`, or a
`grep` is deliberately not repeated here.

Last verified: 2026-08-20 — `flutter analyze lib test tool` clean of errors/warnings
(51 `info`, all pre-existing const/super-parameter hints in `test/` and `lib/engine/`),
`flutter test` **403 passed, 0 failed** — 398 plus the five that fence the card
turn (§7a). Re-run after the ground was neutralised (§2a), the loops were
re-encoded (§9c), the score was replaced (§7a), the swipe became omnidirectional
and names went bold (§9d). Not
re-verified since the 2026-08-03 run: `flutter build apk --release` (then
universal **62.2 MB**) and the `emulator-5554` pass — and note that bundled
assets have grown to **12 MB** since, of which 3.8 MB is the new score and
2.9 MB the ambient loops, so that size number is stale by more than the usual
drift. Onboarding, Home and the score have been looked at only through
`test/preview/` renders and a waveform, never on a device.

---

## 0. The one rule that overrides everything

`specs/001-mafia-master/contracts/leakage-invariants.contract.md` (and the
`05-zero-leakage-spec.md` it encodes) beats any visual decision that conflicts with
it. This is a pass-the-phone social deduction game: **the person opposite you must
not be able to infer your role from the light coming off your screen.** If a design
choice looks better and leaks, it loses.

Concretely, do not "fix" a failing luminance test by widening its budget. That is
the one change that converts a caught leak into a shipped one.

---

## 1. Current state in one paragraph

The Flutter app (engine, screens, persistence, i18n, the leakage test suite) is
complete and green. The visual overhaul has landed: design tokens measured out of
the artwork, the four paintings shipped uncropped, a three-step reveal, six phase
announcements, an ambient icon layer, and a real audio backend. Saved groups (§11) landed on top
of that: a rematch with a known roster now reaches role distribution in three taps.
`PRODUCT.md` says what the app is for; `DESIGN.md` says why each visual number is
what it is. The onboarding deck (§9b) then landed on top: a first launch now opens
six cards rather than Home. What remains is listed in §9 and is mostly *missing
inputs* — no source art for the tier-3 backdrops, no recorded narration.

---

## 2. The card architecture, and why it is the risky part

### What changed

The original design had **one shared monochrome card face**. Parity across roles was
*structural*: there was literally one file, so the Mafia card and the Citizen card
could not differ in brightness. That guarantee was free.

That was reversed. There are now **four distinct role faces** —
`assets/images/card_face_{mafia,doctor,detective,citizen}.webp`. The art is better.
The guarantee is gone.

### What replaces the guarantee

`test/golden/leakage/luminance_budget_test.dart`, group `L-04 card face budget`.
It is **SHIP-BLOCKING**. It is now the *only* thing standing between four separate
paintings and a role tell. It asserts four things:

| Test | Catches |
|---|---|
| shipped faces within ±2% over the whole card box | art replaced without re-running the pipeline |
| rendered cards within ±2% | parity destroyed by the widget composing something on top |
| the faces are four different images | someone "fixing" a drift by copying one face over the others |
| the four faces agree on hue to within 3 levels | one card warmer than the rest — chroma can differ at constant luminance |

The third one exists because a failing tolerance *invites* the copy-paste shortcut,
which would be perfectly leak-free and a broken game.

### The card box — this is the part people get wrong

**The paintings are never cropped, and they are not the same shape.**

Three sources are aspect 0.7467 and the mafia is 0.8733. Article II says element
dimensions may not vary by role; Part 1 of the art brief says nothing may be cropped.
Both cannot hold for the *painting*. They hold for the **card box**: one fixed
1024×1536 rectangle for every role, the painting scaled whole to fit
(`BoxFit.contain`, no pixel lost), centred, and `card_ground` filling the rest.
Coverage comes out at 89.3% for three of them and 76.4% for the mafia.

The consequence that is easy to miss: **the budget must be solved on the composited
box, not on the painting.** Two paintings at identical mean brightness covering
different fractions of a fixed box still emit different amounts of light, and light
on a bystander's retina is the thing Article I is about. `normalise_art.py`
therefore measures the whole box — but it gains **only the art**, holding the
letterbox bars at exactly `card_ground`, for the reasons in §2a. Gaining the bars
too is what made the mafia card's frame a different value from everyone else's.

Which is also why `card_ground` in `tool/manifest.json` **must equal**
`AppColors.groundBase` — the app's ground, which is what the card is seen against.
If they drift, the bars stop matching the screen behind the card and become a
visible frame — deeper on the mafia card than the other three, and invisible to
every luminance check, because the budget is satisfied by construction.
`test/platform/card_ground_matches_surface_test.dart` holds the two together
across the Python/Dart boundary and probes the shipped pixels.

**Superseded:** an earlier version of this file described a *parity window* — a
central 0.53-aspect strip, because `RoleCard` used `BoxFit.cover` and threw the
outer columns away. That machinery is gone along with the crop. `luminance_budget_test.dart`
now measures the whole file, because the whole file now reaches the screen.

### 2a. The ground is near-black and neutral, and the leather experiment has been reverted

`AppColors.groundBase` = **`#0F0F0F`** is the ground on every screen, private and
table alike, with `groundRaised` `#1A1A1A`, `groundOverlay` `#252525` and
`groundBorder` `#313131`. One hue family, four brightness steps, no cast at any
step. Doc 05 rule 3 (no warm colour at night) holds in its original form.

**The ramp used to lean cool and no longer does, and the reason it could be
changed safely is the reason to read this paragraph before changing it again.**
It was 13/15/20 · 22/26/34 · 31/37/48 · 42/49/64, blue ahead of red by 7 levels
at the bottom and 22 at the top, on the argument that cool is the direction away
from skin tone. That argument is sound but it was being applied past the point
where it bought anything: a 22-level spread on a hairline is not subliminal, and
the panels and dividers read plainly as blue-grey against artwork that measures
neutral to within half a level. The interface and the paintings looked like two
different products.

The four rungs above are the **Rec. 709 luminances of the four values they
replaced**, to the nearest level — 15, 26, 37, 49. Nothing about what the screen
emits changed; only the hue did, and only as far as grey. That is what makes it
a safe change rather than a taste change, and it is the test to apply to the
next one: `role_accent_parity_test.dart` asserts `blue >= green >= red` at every
rung, which a neutral ramp satisfies with equality and a warm one cannot satisfy
at all.

**An earlier revision made this ground warm tanned leather (`#241C14`) and logged
the deviation as a trade-off in `05-zero-leakage-spec.md` §5. That entry is gone
and the ground is near-black again.** The argument for it was not silly — a warm
cast is conspicuous rather than informative — but the cost it admitted, a phone
emitting roughly seventeen times more light from its ground onto the holder's
face, is a real weakening of Article I bought with nothing but taste. Do not
reintroduce it, and do not reintroduce a warm/cold register split.

**`card_ground` now follows the ground**, and this is the part worth
understanding. It is `[15, 15, 15]` in `tool/manifest.json` — the same
`#0F0F0F` — so the card box letterboxes against exactly the colour of the screen
behind it and the box edge is invisible. Moving the ground therefore means
re-running `normalise_art.py`, and then `extract_palette.dart`, because the
composited box is what both of them measure. `card_ground_matches_surface_test.dart`
probes the shipped bars against `groundBase` to 2 levels, so forgetting either
step fails the build rather than shipping a frame around every card.

That required a change to `normalise_art.py`. It used to gain the ground
*together with* the art, so the shipped bars were `card_ground × gain` — and the
gains differ per role, so the mafia's bars were a different value from everyone
else's *and* there are more of them (76.4% coverage against 89.3%, so its bars
are 182px deep against 82px). A frame, thicker on one role's card, invisible to
every luminance check because the budget was satisfied by construction.

Now **only the art is gained** and the bars are held at the constant:

```
target = cover · art + (1 - cover) · ground      # ground fixed
art    = (target - (1 - cover) · ground) / cover
```

The four paintings therefore end up at genuinely different brightnesses, which is
correct — a bystander sees the *box*, and the boxes match to 0.03%. Measured on
the emulator: screen ground `(13,15,20)`, card bars `(14,15,21)` on every role.

**Three leakage tests changed, and none was widened.**
`card_ground_matches_surface_test.dart` asserts `card_ground == groundBase`
again *and* probes the outer 4px of every shipped face against it (tolerance 2
levels), on top of the 12-level painting-edge budget it already had;
`role_accent_parity_test.dart` gained a "no night surface carries a warm cast"
test — blue ≥ green ≥ red at every rung, which is rule 3 as a direction rather
than as a tolerance, because the shipped ramp is deliberately *cooler* than
neutral and a literal ±6-level neutrality bound would fail it for being too safe;
`luminance_budget_test.dart` now feeds the shell Arabic seat names
(`TurnShellHarness.arabicTargets`) — see §2b.

**Superseded:** the warm/cold `AppBackdrop` register. With one ground everywhere
it had nothing left to split.

### 2b. The detective "leak" that was a harness artifact

Reverting the ground made `L-05 … in confirmed` fail: the detective measured
2.35% off the set mean against a ±2% budget. It is worth knowing why, because the
obvious readings are both wrong.

It was not caused by the ground change in the way it looks. The *absolute*
difference barely moved (−0.00243 → −0.00259). The **mean** fell 32% when the
ground darkened, so a constant absolute difference became a larger ratio.

And the difference itself came from the test harness. The detective is the one
role whose post-confirm panel shows something other than the seat name it just
tapped — it shows a verdict, `مافيا`. The harness gave the other three
`Seat 1`: Latin, rendered in Bebas Neue, against Arabic in Cairo. Those two
strings do not carry the same ink. Under Arabic names on all four — which is what
ships, since the app is `locale: ar` — the drift is **0.397%**.

So the fix was to make the stimulus match production, not to touch the budget.
`TurnShellHarness.arabicTargets` exists for suites that measure *light*;
`TurnShellHarness.targets` is still Latin and still correct for the structural
suites, where every role gets the same string.

### Colour is measured and never corrected

The pipeline applies **one scalar gain and nothing else**. No desaturation, no
cast-stripping, no hue shift, no overlay. All four faces are warm by 4–6 levels in
the same direction; that is the artwork, and correcting it would be changing the
artwork.

What replaced the old "no face carries a colour cast" assertion is a test that the
four faces **agree** on hue to within 3 levels. A deck that is uniformly warm tells
nobody anything; one card warmer than the other three is a role tell that no
luminance budget would catch, because chroma can differ at constant Rec. 709
luminance.

### The card back

Exactly one file, shared by every role, so it cannot leak role — but it *can* leak
orientation, and a table that can tell which way up a card was dealt has information
the rules never gave them.

"Symmetrical card back" in a generation prompt buys *approximate* symmetry: the back
that came back from the model measured **22.4 levels** off its own 180° rotation.
`normalise_art.py` now folds it — keeps the top half, stamps the rotated copy into
the bottom half (`_fold_180`, gated on `"rotational_symmetry": true` in the
manifest). Symmetric by construction, not to within a tolerance. Averaging the image
with its rotation was rejected: it closes the gap but ghosts every asymmetric detail
into a double exposure. Half the source art is discarded; that is the price.
`test/golden/leakage/card_back_symmetry_test.dart` measures it from the shipped bytes.

---

## 3. The asset pipeline — the commands, in order

```
raw_assets/*.{png,jpeg}        # source art, matched by manifest "raw_match" substring
  └─ python tool/normalise_art.py         # contain→composite→gain→fold→WebP; WRITES assets/images/
       └─ python tool/generate_asset_constants.py   # regenerates lib/app/asset_constants.dart
            └─ flutter test                          # re-measures the shipped bytes

raw_assets/assets/videos/<slot>.webp      # source loops, matched by slot name exactly
  └─ python tool/normalise_video.py       # resample→soften→close→limit→gain→WebP; WRITES assets/video/
       └─ python tool/generate_asset_constants.py
```

* `python tool/normalise_art.py --check` is a dry run — measures and reports, writes
  nothing. Use it first. `normalise_video.py` has no dry run and is slow — it does
  four full encodes per loop searching for the highest quality that fits (§9c) —
  so expect minutes, not seconds, and run it in the background.
* **Do not run the suite while it is running.** It truncates each file before
  rewriting it, and a test that renders a zero-length asset fails in a way that
  looks like a real regression. Two integration tests were caught out by exactly
  that once.
* `tool/generate_assets.py` owns the **procedural** slots only (`canvas_texture`, the
  four emblems). `normalise_art.py` refuses to touch anything marked
  `generated_only`, and exits if art is supplied for such a slot.
* The face set is **all-or-nothing**: nothing is written unless all four pass ±2%.
  On failure it exits non-zero with "NOTHING WAS WRITTEN… regenerate the outlier —
  do not widen the budget."
* `raw_match` must resolve to exactly one file; two matches is a hard exit. If you
  drop a new source in `raw_assets/` with a different name, update `raw_match` — that
  is how the mafia source changed from `Mafia_figure…` to `Mafia.png`.

### `tool/manifest.json` is the single source of truth

Read by both `normalise_art.py` (which writes the files) and the Dart tests (which
check the shipped bytes). JSON rather than the `manifest.yaml` the prompt pack asks
for, because there is no YAML parser here without a new dependency and `dart:convert`
reads JSON for free. One list, two consumers, nothing to drift.

`tier` drives the treatment: **1** = leakage-critical (luminance-matched across the
set and nothing else; the only images an in-hand surface may show), **2** = gallery
(post-game only, colour allowed),
**3** = public backdrop (gained into `lum_band` so overlaid bone-white text keeps its
contrast ratio), **4** = ornament.

### Emblems are not normalised

`generate_assets.py` solves each emblem's internal stroke weight by bisection so all
four land on identical ink coverage (27.00% ± 0.234%) inside the same bounding box.
Passing them through a crop/gain stage would destroy that property, so they are a
separate list in the manifest. `asset_manifest_test.dart` re-measures it.

---

## 4. Measured luminance, latest run

Rec. 709 over the whole composited card box, out of 255. Target is the set's own mean.

| slot | raw | drift | cast | cover | gain | final | drift |
|---|---|---|---|---|---|---|---|
| card_face_mafia | 38.24 | −35.54% | 4.59 | 76.4% | 1.6123 | 59.35 | +0.041% |
| card_face_doctor | 66.47 | +12.05% | 4.65 | 89.3% | 0.8898 | 59.33 | 0.000% |
| card_face_detective | 70.67 | +19.13% | 5.86 | 89.3% | 0.8357 | 59.33 | 0.000% |
| card_face_citizen | 61.92 | +4.37% | 5.02 | 89.3% | 0.9570 | 59.33 | 0.000% |

Set mean 59.331/255 · worst drift 0.0308% · max spread 0.0411% · budget 2%.
`card_back` 77.9 → 81.1 after the fold. The raw column is higher than it was
because the box is now composited on `#0F0F0F` rather than on near-black; the
gain column is the multiplier applied to the **art alone** (§2a). Raw spread across the set is **1.70:1** —
that is the leak the gain closes.

**Three things to be aware of here, none of which is a leak:**

1. The current `Mafia.png` source is much darker than the other three and needs a
   **1.64× gain**. That is aggressive — it lifts sensor/compression noise and leaves
   little highlight headroom, and it is why the mafia painting dominates the top of
   the measured palette. If the cards look muddy on a real device, the fix is a
   brighter mafia source, not a gentler gain.
2. The back (79.7) is ~1.4× brighter than the faces (57.5), so the screen dims
   slightly on reveal. Uniform across roles, so it is not a tell — but it is a
   visual discontinuity worth a decision.
3. The mafia card is **wider and shorter** than the other three, so it letterboxes
   top and bottom while they letterbox left and right. That is visible, it is
   intrinsic to shipping the paintings uncropped, and it is not role-*conditional*
   in the leakage sense only because the bars are the same colour as the screen
   behind them. See §2 on `card_ground`.

### The palette is measured out of these files

`tool/extract_palette.dart` (run it with `flutter test tool/extract_palette.dart`)
pools every pixel of all four shipped faces, sorts by luminance, and averages around
fixed percentiles. The output is pasted into `lib/core/theme/app_colors.dart`, and
`design_tokens.dart` maps those swatches onto semantic tokens. `DESIGN.md` has the
table and the reasoning.

**Re-run the palette after changing the art.** The two are coupled in one direction
only — the pipeline does not read the theme, but `card_ground` does, and the test in
§2 is what notices.

---

## 5. Rules the user set, which still hold

* **Do NOT read image bytes into your own context.** The scripts measure; never use
  the Read tool on an image file.
* **No new dependencies without asking first.** (This is why: JSON not YAML; measured
  WebP emblems not `flutter_svg`.)
* **Report the actual raw test output. Do not summarise pass counts.**
* Strings go through the ARB. No hardcoded UI strings.
* **Roles are singular, always.** "المافيا" is the role, whether there is one
  mafia or three — never a plural, and never "عصابة". Same for المحقق، الدكتور،
  المواطن.
* **No emoji and no Material icons in the UI.** The app's only pictorial
  language is the four painted emblems in `assets/icons/`. Secondary actions are
  words.

### Unresolved question — needs the user's word

The brief says **"Egyptian Arabic only, via ARB"**, but the app ships **bilingual
(ar + en)** and the test suite asserts both. Constitution Article VII also requires
both. Nothing has been changed either way. Ask before acting — dropping `en` is
destructive, would take tests with it, and would need an Article VII amendment.

### A smaller conflict, flagged rather than resolved

**Superseded — `AudioCue.cardFlip` now plays, including in a hand.** This entry
used to say the opposite: the cue existed, had a file, and was never fired,
because the only card flip in the game happens during distribution and Article I
bans sound while a player holds the phone. That was the right call for a cue
fired through the ordinary door. It is now fired through a door of its own,
`AudioDirector.playCardTurn`, and §7a has the argument. Two things about that
worth knowing here: `AudioDirector.play` still throws for **every** cue, this one
included, and the new method takes **no argument**, so the exception cannot be
pointed at anything else. The fence is `audio_gate_test.dart`.

---

## 6. Environment facts that will otherwise waste your time

* **The Flutter SDK path contains a space, and so does the project path.** This
  breaks native-asset build hooks (`google_fonts` is still deferred because of it),
  and it also breaks Kotlin *incremental* compilation: `:audioplayers_android:
  compileReleaseKotlin` fails with "Could not close incremental caches", reproducibly,
  from a clean build directory. `android/gradle.properties` now sets
  `kotlin.incremental=false`, which fixes it. Do not remove that line without
  re-testing a release build.
* **`audioplayers` is in, `just_audio` is out.** The package lives behind
  `lib/platform/audio_backend.dart` and nothing else in `lib/` may name it —
  `test/platform/audio_backend_isolation_test.dart` fails the build if a second file
  does. Swapping the package is a one-file change, by construction and by test.
* **Image generation is not available.** higgsfield: free plan, 0.08 credits, 2
  credits/image. The Gemini key supplied in chat returns HTTP 429 "prepayment credits
  are depleted" on every image *and* text model — the key is valid (ListModels 200),
  the project has no quota. `tool/generate_art_ai.py` is written and correct; it reads
  `GEMINI_API_KEY` from the environment and the key is in no file. **That key is now
  in chat history and should be rotated.**
* Tests that render artwork must call `loadArtwork(tester)` from
  `test/support/artwork.dart`, which waits on real `ImageStream` completions. Fixed
  `pump()` counts pass in isolation and fail under a loaded parallel run — that
  produced a phantom leak once already, and a card that rendered as a flat black
  rectangle (which was the drop shadow showing through a never-decoded image).
* `test/preview/card_preview.dart` writes `tool/preview/role_card_{back,front}.png`
  for eyeballing. It lives outside the `*_test.dart` glob on purpose: a
  `dart_test.yaml` `skip:` tag skips even when you pass `--tags`.

---

## 7. The motion layer, and the one rule it follows

Three pieces landed. They share a constraint that is easy to lose: **an animation
at a handoff boundary must never show two states at once.**

* **`PhaseTransition`** (`lib/ui/widgets/phase_transition.dart`) — the dip between
  game phases. Deliberately *not* an `AnimatedSwitcher`: every stock transition
  cross-fades, and a cross-fade at a phase boundary puts a ghost of one player's
  private night turn on screen at the exact moment the phone is being handed across
  the table. Half-opacity is not unreadable, only faint, and faint is enough if you
  know what to look for. So the outgoing phase fades to charcoal, the tree is swapped
  while only the ground is drawn, and the incoming phase fades up.
  `phase_transition_test.dart` walks the dip frame by frame and fails if any single
  frame contains both phases.

* **Vote-bar cascade** (`vote_bar.dart`) — bars fill from zero, staggered by
  `motion.stagger * index`, so the table lands on the outcome together instead of
  each person reading their own row. Implemented as an `Interval` on one controller
  rather than a delayed `forward()`, so there is no pending `Timer` to leak and
  `pumpAndSettle` settles the whole tally. Safe to be dramatic because it is
  on-table, public and post-vote — the information is already common knowledge.
  The *count* is text from frame one: a number that animates is a number that is
  briefly wrong.

* **`HoldPad` press scale** — the pad dips under the finger and snaps back. Scale
  rather than colour or elevation, because a brightness change on an in-hand surface
  is visible across the table and a 3% geometric change is not.

* **`StaggeredEntrance`** (`lib/ui/widgets/staggered_entrance.dart`) — fade-and-lift,
  delayed by list position. Used by the achievement badges. **Post-game surfaces
  only**, and the doc comment says why: an entrance animation is a moving,
  role-shaped light source, which is fine when the table is reading its own history
  together and is not fine on anything one player holds.

Under Reduce Motion all three degrade to their **final state**, never to their
initial one. The failure mode worth remembering: "start at zero, animate to the real
value" plus "disable the animation" equals a tally that reports nobody voted. An
accessibility setting must not change what the app claims happened.

---

## 7a. The reveal, the announcements, and the sound

### The three-step reveal (`role_card.dart`)

1. **Identity gate** — the player's name and a pad held for
   `MatchSettings.identityHoldSeconds` (host setting, default **20s**, chips at
   10/15/20/30 on the settings screen). This is the turn-length equaliser as much as
   an identity check: everyone's turn starts with the same wait whatever they drew.
2. **Swipe to flip, in any direction** — the card follows the finger and
   completes on distance (30% of the card *along the axis that was swiped*) or
   velocity (300 px/s), with a depth shadow that moves with the rotation. One
   duration, one curve, one geometry, for every role.

   It used to be right-only: `onHorizontalDrag*` with the offset clamped
   positive, and a hint underneath that said "swipe right". That is a rule to
   remember at the exact moment nobody wants one — the phone has just been
   handed over, the table is watching, and the thumb goes wherever it was
   already resting. A leftward swipe did nothing at all, which reads as the app
   being stuck rather than as the player having guessed wrong. It is now a pan:
   the dominant axis of the travel picks the rotation axis (Y for sideways, X
   for up and down) and its sign picks the direction, so **the card turns the
   way it was pushed**. The resolved axis is held after the gesture, so the
   automatic conceal five seconds later reverses along the same line rather
   than snapping back through a different one.

   Leak-safe for a reason worth stating: the direction is the player's, and it
   is chosen *before* they have seen anything, because the flip is what shows
   them the card. What a bystander learns from watching it is which way somebody
   was holding their thumb.
3. **Auto-conceal after 5s**, with a progress line, and unlimited re-reveals within
   the turn — each another 5s. Then "سلّم الموبايل".

**The non-obvious bug this flow already produced, and its fix.** The role name and
description below the card originally faded in on `_phase`, which flips the instant
the swipe completes. That put the words on screen, in legible display type, while
the card was still edge-on to the table — a reveal to everyone *except* the person
holding it. They are now gated on `_flipCurve.value >= 0.5`, the same half-turn the
card itself uses to swap faces, so words and painting cross the threshold on the
same frame. `flip_stage_symmetry_test.dart` caught it and now guards it: identical
for all four roles at every sample below the threshold, different for all four
immediately above it.

The pass control is measured, not asserted against a constant —
`reveal_symmetry_test.dart` pumps until the button appears and compares the four
offsets to *each other*.

### Phase announcements (`cinematic_text.dart`)

Six lines, fade up over `motion.dramatic`, hold `timing.phaseHold` (3s), fade out.
Wired in `match_flow.dart` as a `_Moment` enum, which is also where the narrator slot
lives — one enum value per announcement, each carrying an optional `AudioCue`, so
"every transition has a narrator slot" is a property of the type rather than a
convention someone has to remember at the seventh call site.

Same duration every time **including under Reduce Motion**: an accessibility setting
that made the game faster would be a signal of its own.
`test/widget/phase_moment_test.dart` measures all six and both motion modes.

Announcements run *over* the outgoing phase — the engine step is the completion
callback, not something that happens first — so the next player's pass screen is
never behind the text. `_syncPhoneLocation` treats an announcement as on-table
regardless of the engine's phase, which is why its cue is allowed to play.

### Sound (`audio_director.dart` + `audio_backend.dart`)

`AudioDirector` owns the *rules* — the in-hand gate, the master mute, the narration
switch, the cue catalogue. `AudioBackend` owns the *package*, and is the only file in
`lib/` allowed to name `audioplayers`.

Each cue may carry two independent things: an **ambient bed** (`AudioCue.sound`,
synthesised by `tool/generate_audio.py`) and a **recorded narrator line**
(`AudioDirector.narratorLines`, empty until someone records one). They are additive,
not alternatives, and a cue with neither still counts as emitted — the leakage tests
read the emitted log to prove the cue *sequence* is role-independent, and a cue that
vanished because its file was missing would make that sequence depend on which
recordings happen to exist.

`generate_audio.py` writes sound and never speech. That rule is unchanged: a
synthesised Arabic voice sitting in `assets/audio` looking finished is worse than an
obviously missing one. `mafia_wake` has no bed at all and is silent until recorded.

Everything works with sound off, and there are three switches because they answer
different questions: `muteAllAudio` ("the phone should not make noise"),
`narrationEnabled` ("chimes yes, a voice no") and `scoreEnabled` ("no music").

### The card turn, which is the other one

A page turns whenever a card does, anywhere in the app: the home spread, the
onboarding tiles, and — this is the new part — the reveal, in somebody's hand.
`AudioDirector.playCardTurn` is the only way to fire it, `AudioDirector.play`
still throws for every cue including this one, and the method takes no argument
precisely so the exception cannot grow a second case.

**Why this one is allowed when no other cue is.** Article I rule 2 stops a cue
firing during a private turn because the *firing* is the tell: a sound that
arrives partway through a turn reports what stage that turn has reached, and
stages differ by role. This sound reports something that is the same for
everybody:

* it cannot encode the card, because the flip that opens a turn happens
  **before** the holder has seen anything — at the instant it sounds they know
  exactly what the table knows;
* it cannot encode the role: one file, one level, one length, from a code path
  with no branch on anything. All four roles flip, all four conceal after the
  same five seconds, all four sound identical doing it;
* it adds no channel the room did not have. A player who looks again lengthens
  their own turn in full view, and `RoleCard` already documents that as a choice
  rather than a tell (see `_autoFlipBack`). A rustle alongside a choice everyone
  can already watch somebody make is not new information.

The wiring is a callback, not a provider read, and that is load-bearing:
`audio_gate_test.dart` asserts that `role_card.dart` does not so much as mention
the audio layer, so the file cannot trip the gate even by accident. The screen
above it hands the method in.

The cue itself was rewritten to be paper rather than a swoosh — 0.18s, fast
transient, granular rustle, bright crackle dying faster than the body — and it
ships at **−15 dBFS against every other cue's −3**, because it sounds in a hand
and has to be felt rather than heard. `PEAK['card_flip']` in
`tool/generate_audio.py` is the knob, and that script now takes cue names so
re-tuning one sound does not rewrite the other eight.

### The score, which is the one sound allowed in a player's hand

`assets/audio/score_loop.ogg` starts at app launch, plays until the app is
backgrounded, and **is not stopped when the phone is picked up**. Every cue is;
`AudioBackend.stopAll` deliberately cannot reach the loop.

The argument is in the verb of Article I rule 2: a sound that *fires* while a
player is holding the phone marks the moment it fired. A sound that has been
running since before anyone picked anything up marks nothing — it is the same
floor for the mafioso and for the citizen who takes the phone from them, and it
does not change when either of them does anything. It also earns its place: a
steady bed masks the thumb-drag, the held breath and the pause before a
decision, all of which silence broadcasts. There is deliberately **no API** to
swell it, duck it, layer it or stop it at a phase boundary, because each of
those would make it react to the game.

**The music is now supplied rather than synthesised, and it is prepared by
`tool/normalise_score.py`.** Drop a file in `raw_assets/audio/`, run the script,
and it writes `score_loop.ogg`; nothing in `lib/` changes, because the path is
fixed and the properties the app depends on are established by the tool rather
than assumed of the file. Two of them matter:

* **The loop has to close.** Music ends by fading out. `Unresolved Room` as
  supplied ran from −19 dBFS at its head to −58 dBFS across its last half
  second, so looping it raw would take the room to near-silence and then start
  the music again, once every five minutes — the single most conspicuous thing a
  background bed can do. The outro is cut and the new tail is cross-faded into
  the head: **38.80 dB of level step at the seam became 0.64 dB**, and the
  sample-level step across the wrap is −58 dBFS, which is quieter than the
  synthesised bed it replaces managed.
* **The level is a contract.** `AudioDirector.scoreVolume` is 0.5 *because* the
  file is −20 dBFS RMS. The supplied track was −12.5 dBFS and peaked a tenth of
  a decibel over full scale; the script gains it to the target, so swapping music
  cannot quietly double the score's loudness.

**What was lost and is worth knowing.** The old bed was synthesised with a
literal hole between 1 and 4 kHz — 0.00% of its energy in the band that carries
consonants — and that hole is why a table could talk over it. Real music has no
such hole and cannot be given one without becoming a different piece. The
current score is simply dark: 0.91% of its energy in that band, about −46 dBFS
at the shipped volume, which is the same practical result by a different route.
`normalise_score.py` prints that figure on every run, so a brighter piece
measuring several percent asks the question at the point of the swap rather than
at a table. **A brighter piece would need a notch or a lower `scoreVolume`.**

**Not verified on a device.** `audioplayers` loops via Android `MediaPlayer`'s
own `setLooping`, and whether that wrap is gapless is a platform question this
repo cannot answer from a widget test. The file is now seamless *as a file*; if
a click or a beat of silence is audible once every five minutes on hardware,
that is the loop implementation and not the asset, and the fix is a
ping-pong pair of players — which would be the first thing in this layer that
had to be argued past L-11.

---

## 7b. Things that were broken and are now tested

Six real bugs, found by playing the app on a device rather than by the suite.
Every one has a regression test now; the tests are named so the failure explains
the symptom rather than the mechanism.

| Symptom on the table | Cause | Test |
|---|---|---|
| "the same person dies every morning" | `NightResolver` scanned the **whole** event log, so night 1's votes were still counted on night 2 | `engine/night_isolation_test.dart` |
| after a few nights nobody could die at all | same scan, for `ProtectCast` — every seat ever protected stayed protected forever | same |
| roles felt fixed | `seed ?? 12345` — a literal constant, so seat 0 drew the same role in every match ever played | same |
| the app hangs on a tied vote | a revote narrows the ballot to exactly the tied seats, so a table that split evenly once split evenly again — with no cap | `engine/day_tie_revote_test.dart` |
| "it loops and nothing happens" during dealing | two identical hold gates back to back (`PassScreen` then the identity gate), and the pass control on a 12s floor that outlived the 5s reveal | `golden/reveal_symmetry_test.dart` |
| an empty box on every non-detective night turn | the reserved detail slot was a *filled, bordered* container drawn for all four roles | `golden/reveal_symmetry_test.dart` |

Two of these were only findable by running it: the resolver bug needs two nights,
and the double hold gate looks correct in every screenshot.

## 7c. The win rule

`lib/engine/win_check.dart`, one pure function, and doc 06 is its spec.

```
mafiaAlive == 0             -> town
mafiaAlive >= nonMafiaAlive -> mafia          (parity, not majority)
otherwise                   -> still playing
```

Three things worth knowing:

* **The doctor and detective are irrelevant** and must stay that way. Only
  `Role.mafia` is counted; everything else is a body.
* **Nothing else may re-implement it.** `win_condition_test.dart` greps `lib/`
  for a second parity check and fails the build on one.
* **The night is an evaluation point.** It was not, and the cost was a wasted
  day: a kill that brought the mafia to parity was not noticed until the next
  day's vote reveal, so the table sat through a discussion and a ballot that
  could not matter. `outcomeAfterNight()` / `concludeAfterNight()` fix it —
  deliberately as a *query* plus a separate transition, because doc 06 §4 wants
  the morning announced first and the result second.

**Not done:** a real `draw` outcome for an empty alive set. It is unreachable in
the MVP, and modelling it means widening `Alignment` — which is a *player's*
alignment, not a result — through the codec, the result screen and analytics.
`outcomeFor` returns `town` there with a comment saying so. If a role that kills
several players at once ever lands, model the draw then.

---

## 8. The gallery — one set of paintings, two treatments

The four tier-2 gallery images are **the same source paintings as the in-match
faces**, taken through the pipeline a second time with the tier-1 treatment turned
off. No second generation was needed, and none was possible — see §6.

| | in-match face (tier 1) | gallery (tier 2) |
|---|---|---|
| desaturated | yes, hard | no — full colour |
| luminance | gained onto a shared mean, ±2% enforced | left alone (43.8 / 77.7 / 83.0 / 72.0) |
| where it may appear | any surface | post-game only |

That luminance column is the whole risk. The gallery set spans nearly 2:1 in
brightness, deliberately, because matching it would defeat the point of having a
colour set at all. One of these on an in-hand surface leaks brightness *and* hue,
and would do it while sailing past `luminance_budget_test.dart`, which only measures
`card_face_*`. That is why `handoff_purity_test.dart` bans `AppGallery` from the
handoff import closure, and why the `Role → gallery asset` map lives in exactly one
named widget (`_GalleryThumb` in `result_screen.dart`) rather than inline.

They surface as the leading thumbnail on each result-screen roster row — the payoff
for a whole match of looking at a monochrome back. `cacheHeight: 256` is not
optional there: at source resolution a ten-player roster holds ~60 MB of decoded
bitmaps for thumbnails a centimetre tall.

---

## 9. What is still open

1. **60fps profile run on real hardware** (the remaining half of task #7).
   **An emulator is now attached** (`emulator-5554`, Android 16 / API 36), so this is
   no longer blocked on hardware — but a frame-time measurement on an emulator is not
   a measurement of a phone, and none has been taken. Do not read the saved-groups
   emulator pass in §11 as a performance run; it exercised behaviour, not frame times.
   What *was* done: the leakage regression pass (the suite,
   green), and one real frame-budget fix — `_CanvasWeave` used an `Opacity` widget,
   which pushes a `saveLayer` and rasterises its subtree into an offscreen buffer
   every frame. Affordable on two screens; not on all of them, which is what the
   `AppBackdrop` sweep made it. It now uses `Image`'s own `opacity`, which applies
   alpha in the paint call with no offscreen buffer. `luminance_budget_test.dart`
   passing is the evidence that the pixels did not change.

   Sizes, split-per-ABI: arm64-v8a **23.1 MB**, armeabi-v7a 20.4 MB, x86_64 24.6 MB.
   (A universal APK is ~57 MB — all three ABIs in one file, not what ships.) Bundled
   assets are 3.9 MB of that; 2.9 MB is images, of which 1.05 MB is the new gallery.

2. **~~Tier-3 backdrops have no source~~ — they do now.** `bg_home`, `bg_night`,
   `bg_day`, `bg_vote`, the four `outcome_*` and the five `onboarding_*` slots all
   have art in `raw_assets/assets/images/`, and seven ambient loops have sources in
   `raw_assets/assets/videos/` (§9c). What is *still* missing is a painting for the
   `secrecy` onboarding chapter, which prints its numeral instead (§9b).

3. **Which on-table screens get ambient art is now a decision that has been
   partly made.** Home, the day discussion screen and the six phase announcements
   carry backdrops; the ballot deliberately does not, and nothing in-hand may.
   The remaining public screens — setup, roles, history, analytics, result — are
   still on the bare ground, and whether that is deliberate restraint or an
   unfinished sweep has not been decided.

4. **Recorded narration.** The plumbing is complete and tested; there are no
   recordings. Dropping files into `assets/audio/narrator/` and registering them with
   `AudioDirector.registerNarratorLine` is the whole job — no code change.

5. **~~`AudioCue.cardFlip` is shipped and unplayed~~ — it plays now**, on every
   card turn in the app including the in-hand reveal, through its own narrowly
   fenced method. See §7a.

### Recently completed, for orientation

The whole card-presentation brief: the uncropped card box and its composited-box
gain, the measured palette (`tool/extract_palette.dart` →
`lib/core/theme/app_colors.dart`, replacing the old hand-picked `art_palette.dart`),
the three-step reveal and its rewritten goldens, the six phase announcements, the
falling-icon ambient layer with a placement test, `audioplayers` behind a tested
one-file seam, and `PRODUCT.md` / `DESIGN.md`.

Four new ship-blocking tests worth knowing about:
`card_ground_matches_surface_test.dart`, `audio_backend_isolation_test.dart`,
`ambient_icon_placement_test.dart`, `phase_moment_test.dart`.

Then the onboarding deck (§9b): six cards on first launch, an `onboardingSeen`
flag sharing the settings row, and `OnboardingGate` beside `ResumeGate`. It moved
Home's help control off the rules screen and onto the deck.

One new widget worth knowing about: `AmbientMotion` — an inherited opt-out for
motion that *never finishes*. The falling icons run on a bare `Ticker`, so any
`pumpAndSettle` on a screen containing them spins until it times out. Four test
entry points wrap the app in `AmbientMotion(enabled: false)` for that reason.
Bounded animations are deliberately left running, because several of them are
load-bearing for Article I's timing guarantees.

---

## 9a. Saved groups (UX-2), and the two numbers it is built around

Mafia is played with the same people every week. Re-typing eight names before every
match was the app's largest single piece of setup friction, and it landed at the
moment nobody has any patience: everyone seated, phone out, game not started.

### The three-tap budget

**A rematch with a known group reaches role distribution in three taps from launch.**
Home → "مباراة جديدة" → a group row → "ابدأ فوراً". That is the whole feature; the
rest of it exists to make those three taps possible.

It is worth knowing what it replaced. Even with names pre-filled the old flow was
**five** taps, because roles and settings each cost one. So the group remembers the
role distribution and settings it last played with (`recordGroupPlayed`, called at
match start), and "ابدأ فوراً" replays them. Without that memory the picker saves
typing but not taps.

`group_rematch_test.dart` **counts the taps and fails at four**. That looks like a
strange thing to automate until you notice that every plausible addition to this
path — a confirmation, an "are you sure", a settings review — costs exactly one tap
and each one looks harmless on its own.

### Attendance is not deletion, and that is the point

When someone is absent, the roster screen offers a **presence toggle**, not a delete.
Deleting would lose them permanently and they would have to be re-typed next week,
which is precisely the problem this feature exists to solve. Toggled-off players are
dimmed, excluded from tonight's match, and **still in the group**. `recordGroupPlayed`
is documented as never touching `memberNames` for the same reason, and there is a
test named after the failure rather than the mechanism.

Consequence worth knowing: **"ابدأ فوراً" withdraws when the head count changes.** A
distribution for eight does not sum for seven, and rather than silently reshuffling
roles the action disappears and the roles screen takes over — which is where a
decision about who drops belongs. This is deliberate, not a gap.

### Order is the contract

`PlayerGroup.memberNames` order **is** the seating order and therefore the
phone-passing order. Nothing may sort it — not the codec, not the repository, not the
picker. A group whose order drifts hands the phone to the wrong person, which is a
rules failure and not a cosmetic one. `hasRoster` is order-sensitive on purpose (that
is what lets the app offer to save a changed order); `hasSameMembers` is not (that is
what stops it offering to re-save people it already knows).

### What must never be stored here

`playCount` is **group-level**. There is deliberately nowhere to put "Ahmed was mafia
four times" — a per-player role history would survive between evenings and become a
metagame tell that no in-match leakage test could ever catch, because nothing leaks
*during* the match. The defence is that the field does not exist, and
`player_group_codec_test.dart` asserts a member's name appears exactly once in a
stored group.

Otherwise this feature is leak-clean by construction: everything happens before role
distribution, on screens the whole table can see, and the only data is names that
were said out loud while sitting down. None of the new files is in the
`handoff_purity_test.dart` closure.

### The bug the emulator found that the suite did not

Deleting the last group bounced to the roster screen with the **deleted group still
attached to the draft** — its names pre-filled, its attendance toggles, and an
"ابدأ فوراً" offering to play a group that no longer existed. Accepting a match-end
prompt on it would then have `save()`d the id straight back, **resurrecting the
deleted group**, because saving is an upsert.

Fixed in three places, all three now tested: the router's `onEmpty` detaches the
draft, the picker detaches on deleting the drafted group, and `GroupFollowUp` checks
the group still exists before writing. That last check asks the **repository**, not
the cached provider — a cache that has not loaded is indistinguishable from an empty
one, and answering "deleted" to "don't know" would silently drop legitimate saves.

### Where the colour went

The brief asked for cream `#D9CDB4` for text and primary actions. That value is
superseded: it appears nowhere in the repo, and the shipped `accentGold` is the
**measured** `agedParchment` `#C1BCB1` from `tool/extract_palette.dart`. The ground
`#0D0F14` and panels `#161A22` in the brief do match. New colour literals in `lib/ui`
are a build failure (`token_discipline_test.dart`), so these screens use tokens —
which is also what keeps them in step when the art is re-measured.

Digits are Latin, matching every other screen, rather than the Arabic-Indic numerals
in the brief's mockups. No ARB string in this app uses `format`, and one screen
counting differently from the rest would be worse than either choice.

### Not built

The prompt's "add a guest to the group" and "save the new seating order" prompts
**are** built (`group_follow_up.dart`, wrapping the result screen) and covered by
widget tests including the absent-member-keeps-their-slot case. They were **not**
driven on the emulator — that needs a full match played to a result, and the tap
budget for this pass went on the paths above. That is the one gap in the on-device
verification.

---

## 9b. Onboarding (S-19), and the one thing it teaches that nothing else does

A first launch now opens a deck of seven cards instead of Home. The host deals
through them — the story, the roles, the night, the day, the phone, what the app
itself withholds, winning — and the last card puts them into setup.

### Why this is not just a second rules screen

`HowToPlayScreen` already existed and still does. It is a **reference**: six
headings a host skims to settle an argument mid-match. This is a **first read**,
in the order the game happens, one idea at a time. They fail differently — a
reference you have to page through is useless in an argument, and a first read
that opens as six stacked walls of text does not get read. Card 6 links to the
reference, so the deck is also how a new host finds it. Home's help control opens
the deck; the rules are one tap further in.

**Cards 5 and 6 are the reason the feature exists, and they are a pair.**
Everything else in the deck is also in the rules. The etiquette of the pass — hold it tilted, do not look at someone
else's screen, do not change your face, never hand it on with anything open — is
not, because it is not a *rule*. It is the handful of physical habits without
which this game leaks through its players rather than through its pixels, and a
table that has never played pass-the-phone has no way to guess any of them. Doc
05 spends its whole length on what the device must not emit; nothing anywhere
told the humans what *they* must not emit. Card 5 does.

**Card 6 is the other half: what the device withholds.** It was added later, at
the user's request, and the argument for it is the mirror of card 5's. Every
guarantee it lists is invisible when it is working — nobody notices that the four
faces were matched to within 2% of each other's brightness, that the citizen's
night turn is held at the same eight-second dwell as the mafia's so a short turn
cannot be counted from across the table, that the phone is silent in a hand, or
that a saved group has nowhere to record who was what (§9a). A table only
notices the absence of all of it, in the form of a game that stops being worth
playing. The secrecy *is* the product, and a host who does not know it is there
cannot tell their table why to trust it.

Every claim on that card is one the suite actually holds. If one of them stops
being true the copy is a lie rather than merely stale, and the fix is the code,
not the card. It has no painting — there is no source art and none can be
generated (§6) — so it prints its numeral, which is what the whole deck did
before the tier-3 art landed.

### Article I does not reach it, and the reason matters

Onboarding is on-table by definition: nothing has been dealt, nobody is holding a
secret, the whole table is looking at one screen. That is the same argument that
lets Home show all four paintings at once, and it is why the roles chapter may use
the full-colour `AppGallery` art — the set that spans nearly 2:1 in brightness and
would leak both luminance and hue on an in-hand surface.

Nothing about that is promised in prose. `handoff_purity_test.dart` derives the
ban from the **import graph** starting at the handoff roots, so the moment anyone
imports `onboarding_role_grid.dart` from a private surface the suite fails. No new
leakage test was needed and none was written; if you find yourself wanting to add
one, check first whether you are actually about to wire the deck somewhere it does
not belong.

### The storage row now carries two things, and that is a trap

`SettingsRecord` is the app-level singleton. It used to hold only the default
settings; it now also holds `onboardingSeen`. **Every writer of that row must
read-modify-write** — `IsarMatchRepository._updateSettingsRow` is the only writer
for exactly that reason. A `put` of a freshly constructed record silently resets
the field it does not set, and the specific bug that produces is nasty: the host
finishes their first match, the app stores their settings on the way in, the flag
is cleared, and the tutorial is waiting for them the next time they open the app.
`onboarding_flag_test.dart` asserts both directions of that.

`payload` also stopped being `late`. A row can now be created by
`markOnboardingSeen` before any settings have ever been saved, and a `late String`
would throw on the next read. Empty payload means "no settings yet" and
`loadDefaultSettings` treats it exactly like a missing row.

### Resume outranks it

If storage holds an unfinished match, `OnboardingGate` stands down and lets
`ResumeGate` have the launch. A table that is mid-game and has just relaunched
does not want a tutorial, and a route change under a modal prompt would put the
prompt over the wrong screen. The deck is **deferred, not consumed** — the flag is
still false, so it appears on the next clean launch. Both halves of that are
tested; the second half is the one that would rot silently.

The two gates do not know about each other. Both read the same storage, and
`OnboardingGate` asks it directly rather than coordinating, which is what keeps
them from needing to run in a particular order.

### A fresh `MemoryMatchStore` is now a fresh install

This is the part that will waste someone's afternoon. A bare `MemoryMatchStore`
has `onboardingSeen == false`, so any test that boots `MafiaApp` over one gets
redirected to the deck before it can look at Home. Four existing tests were
affected and now build their store through `returningHostStore()` in
`test/support/stores.dart`. If a test about something else suddenly cannot find
Home, that is why.

`onboarding_gate_test.dart` also pumps an empty widget between launches. Without
it, re-pumping `MafiaApp` *updates* the existing elements instead of remounting
them, `OnboardingGate.initState` never runs again, and the test passes while
looking at the screen the previous launch left behind.

### There is no art, and the deck does not need any

No painting exists for "the night" or "the pass", and none can be generated (§6).
The faces are built from what the app already owns: `PaperPanel` stock, the canvas
weave, a short gold rule, and the chapter numeral set large and faint. The numeral
earns its place — a deck needs its cards distinct at a glance and six panels of
identical type are not.

Five `onboarding_*` tier-3 slots are declared in `tool/manifest.json` with no
source, exactly as `bg_*` is. `OnboardingCard` takes an optional `image` and
prints the numeral when it is null, so dropping art in later is one line in the
chapter table and no code change. The roles chapter has no slot — it already has
the four gallery paintings.

Two things to know if you touch the manifest: entries in `assets` **must** have a
`slot`, so commentary goes in a top-level `_*_comment` key (a comment object in
the array is a `KeyError` in `normalise_art.py`), and all five are `cold` register
because §2a's warm-ground experiment is not to be reintroduced.

### Motion, and why `pumpAndSettle` works here

Everything in the deck is bounded and ends. Unlike the home spread there is no
ambient float, so no `AmbientMotion` opt-out is needed. Reduce Motion collapses
the durations to zero, which leaves the deck instantly stepped and fully usable.

Horizontal direction is signed off `Directionality` throughout — nothing hardcodes
a side, so the deck advances the way the text runs in Arabic and mirrors in
English.

### Deliberate duplication

`_RoleTile` re-implements the flip that `_Face` in `card_spread.dart` already
does. Not shared, on purpose: `_Face` is welded to the home spread, which owns
which single card is open and drives the animation externally. The tile owns its
own, so all four can be open at once — which is what a reference wants and a
background does not. Sharing would mean reworking the spread's animation ownership
on a screen whose behaviour is already tested. Forty lines was the cheaper side.

### Not built

* **No dry-run match.** A fake three-player walkthrough was considered and cut.
  It would need throwaway engine state that never touches `MatchRepository`, and
  the deck's job is to get a table playing a *real* first match, not a practice
  one.
* **No live drag.** A swipe is read on release, not tracked under the finger.
  The card does not follow the thumb before it commits. Worth doing; not done.
* **Never run on a device.** The previews in `tool/preview/` are widget-test
  renders with the shipped fonts loaded, which is a fair likeness and not a
  phone. Nobody has held this.

---

## 9c. The ambient loops, and what Home is actually for

Seven animated WebP loops now ship in `assets/video/`, played by an ordinary
`Image.asset` — no `video_player`, no platform view, no lifecycle. They are
declared in the manifest's `videos` list and written by `tool/normalise_video.py`,
which is the only thing that may write that directory.

**On-table only, and the rule is stronger than it looks.** A loop is brightness
that changes frame to frame, so on an in-hand surface it breaks the ±2% budget
on nearly every frame — and a loop at a different point in its cycle for a fast
player than for a slow one is a timing channel on top of that. Home and the six
phase announcements are the whole list. `voting_screen.dart` carries a comment
saying why the ballot does *not* get one, which is worth reading before adding
the eighth call site: it was tried, and byte-identical ballots across roles are
not achievable when the backdrop is at whatever frame wall-clock says.

Every loop has a still counterpart in the image list — `bg_home_loop`/`bg_home`,
`outcome_death_loop`/`outcome_death` — and `AppBackdrop` takes the pair. That is
not an optimisation: an animated WebP has no pause API, so handing the engine a
different file is the only way to honour Reduce Motion at all. **The two must
stay in the same luminance band**, or an accessibility setting becomes a visible
change of art direction.

### The encoder spends the budget, and that is a recent change

`max_bytes` is a budget, not a pass mark. The first version of the script
searched quality *downward from 62* and stopped at the first setting that fit,
so `bg_home` fit immediately at 426 KB against a 600 KB allowance and simply
never spent the rest. What that bought was a backdrop blocking up in its dark
gradients — the first defect a starved WebP shows on near-black — which is what
"it has a lot of pixels" turned out to mean.

It now bisects the quality ladder for the **highest** rung that fits. Four
encodes instead of up to fourteen, and the file lands just under its budget
rather than well under it. The effect is not uniform: `bg_night_loop` went from
18 KB to 372 KB, because a nearly-static near-black loop is exactly the case
where the old search quit earliest and the banding was worst. If the total ever
needs to come down, the honest knob is `max_bytes` in the manifest, one line per
slot — not a return to stopping early.

Two things make that search survivable. It probes at encoder **method 4** and
writes the winner at **method 6** — the search only needs to know which rung
fits, and paying three times over for the slow method on four throwaway passes
buys nothing; the final size is re-checked against the budget rather than
assumed. And the script now takes **slot names**: `python tool/normalise_video.py
outcome_death_loop`. That matters because a run that is interrupted leaves the
slot it was writing zero bytes long, and a zero-length asset fails the widget
suite in a way that looks like a real regression. One run has already been
killed part-way; the recovery is naming the slots, not redoing the lot.

`soften` is the other half, and it is a bitrate decision rather than a look.
Generated loops arrive full of sensor-style grain, which is incompressible by
construction (different in every frame, so inter-frame prediction cannot help)
and eats the bits the gradients need. `bg_home_loop` is the only slot that sets
it. It is off by default because a loop with real detail should not be blurred
to buy a number.

### Home is the four cards, and everything else on it is the table they are on

Two changes landed together and they are the same decision.

**The fifth card is gone.** The spread used to deal the card back above the fan,
on the argument that it is the picture the table stares at for a whole match and
belongs in the deck. On screen it read as an extra card: five objects on a
screen whose entire subject is that there are *four* roles, with the one nobody
may tap sitting highest and taking the eye first. The back has its own screen —
every night turn opens on it. The four faces then moved up into the space it
left and grew from 0.46 to 0.50 of the short edge, because leaving them where
they were would have left a hole in the top of the screen rather than a
composition.

**`bg_home` and `bg_home_loop` were dimmed**, from band `[14, 30]` to `[9, 17]`,
and the loop was softened. Home is the only surface in the app whose backdrop
has foreground art over it, and the four paintings have to be the brightest
thing on it. Both slots moved together, for the Reduce Motion reason above.

Neither of these is a leakage matter — nothing has been dealt, nobody is holding
anything, the whole table is looking at one screen — which is the same argument
that lets Home show all four faces at once in the first place.

`test/preview/home_preview.dart` writes `tool/preview/home.png` and
`home_short.png`. Like the other two previews it lives outside the `*_test.dart`
glob on purpose. It pumps `HomeScreen` directly rather than `MafiaApp`, because
the accelerometer behind the parallax and the audio plugin behind the deal sound
both throw in a widget test the moment anything listens to them.

---

## 9d. Two smaller rules that are easy to undo by accident

### Names and roles are set in the heaviest cut their family ships

`TextStyle.emphasised`, in `lib/ui/theme/mafia_theme.dart`, and it is applied to
exactly two kinds of word: **a player's name** and **a role's name**. Nothing
else. Those are the two things anybody is ever actually looking for on these
screens — whose turn it is, who is being voted for, what the card says — read at
arm's length, in a dim room, usually while somebody is talking. The rule only
works while it is narrow: emphasise a third kind of word and the first two stop
standing out.

It is an extension rather than a token because names appear at four sizes
(`display` on the identity gate and the handoff pad, `title` on the speaker
card, `body` in every list and tally, `bodySmall` in a stored roster). A `name`
token would have to pick one and be wrong on the other three.

**It is not `FontWeight.bold`, and that is not fussiness.** Cairo is a variable
font whose weight the display styles request on the `wght` axis; setting
`fontWeight` instead leaves it at its default instance and invites a synthesised
fake bold that smears at 44pt. IBM Plex Sans Arabic ships 400, 500 and 600 and
nothing above, so `w700` asks for a cut that is not in the bundle. The extension
raises the axis to 900 for the first case and asks for w600 — the real top of
the family — for the second.

**The one place to be careful** is `TurnShell._detailSlot`. That slot holds a
role name for the detective and a player name for everyone else, which is the
app's single most delicate pair of strings — §2b is the story of what happened
last time those two were not comparable. It is emphasised unconditionally, so
both cases get the same treatment and the four roles keep rendering the same
amount of ink. Emphasising only one of them is what would put it over the
luminance budget.

### A tied vote eliminates nobody, by default

`MatchSettings.dayTieRule` now defaults to `DayTieRule.noElimination`. It used to
default to `revote`, which is the more familiar table rule and the worse default
here: a revote narrows the ballot to exactly the seats that tied, so a table that
split evenly once has every reason to split evenly again, and each round costs a
full pass of the phone. The engine caps the rounds so it always ends — in no
elimination anyway, several minutes later.

It is also the outcome that adds no information. A revote asks the same people to
vote again *knowing exactly who tied*, which is a second round of public
signalling the first round did not have. The revote is still one tap away on the
settings screen, and `day_tie_revote_test.dart` passes the rule explicitly, so
the default is not what any of those tests are measuring.

---

## 10. Quick orientation map

| Path | What it is |
|---|---|
| `tool/manifest.json` | asset source of truth; read by Python *and* Dart |
| `tool/normalise_art.py` | the only thing that writes `assets/images/card_face_*` |
| `tool/generate_assets.py` | procedural slots only (texture, emblems) |
| `tool/generate_art_ai.py` | Gemini generation; blocked on credit |
| `tool/IMAGE_PROMPTS.md` | the prompt pack + an IMPLEMENTATION NOTES section listing every deviation |
| `lib/ui/theme/design_tokens.dart` | all `ThemeExtension` tokens; role accents are **post-game only** |
| `lib/ui/theme/mafia_theme.dart` | the `context.*` token getters, and `TextStyle.emphasised` (§9d) |
| `lib/ui/widgets/role_card.dart` | `_face` maps `Role` → face asset; border/emblem are neutral by design |
| `lib/ui/widgets/phase_transition.dart` | the dip between phases — read the doc before "improving" it into a cross-fade |
| `lib/app/asset_constants.dart` | generated; `AppImages` / `AppGallery` / `AppIcons` / `AppAudio` |
| `test/golden/leakage/` | the ship-blocking suite |
| `test/support/artwork.dart` | `loadArtwork` — use it in any test that renders images |
| `test/support/reveal_flow.dart` | the three-step reveal, as tester extensions — four test files share it |
| `lib/engine/win_check.dart` | the only place the win rule exists; doc 06 is its spec |
| `lib/data/player_group.dart` | a saved roster; member order **is** seating order (§9a) |
| `lib/data/player_group_repository.dart` | group storage; separate from `MatchRepository` because groups carry no roles |
| `lib/ui/screens/setup/group_picker_screen.dart` | the picker, and the shared name dialog |
| `lib/ui/screens/setup/group_follow_up.dart` | match-end "add the guest / keep the new order" prompts |
| `test/integration/group_rematch_test.dart` | **counts the taps** and fails at four |
| `lib/ui/widgets/card_spread.dart` | the home deck: **four** cards, shuffled each visit, tap to flip, parallax |
| `tool/normalise_video.py` | the only thing that writes `assets/video/*`; owns the loop budget search |
| `tool/normalise_score.py` | `raw_assets/audio/` -> `score_loop.ogg`: closes the loop, sets the level |
| `test/preview/home_preview.dart` | writes `tool/preview/home.png` — the only way to look at the spread |
| `lib/ui/screens/onboarding/onboarding_chapters.dart` | what onboarding *says*, as data — one screen to read it all |
| `lib/ui/widgets/onboarding_deck.dart` | the deal-through deck; direction is signed off `Directionality` |
| `lib/app/onboarding_gate.dart` | first-run redirect; stands down for a resumable match (§9b) |
| `test/support/stores.dart` | `returningHostStore()` — a boot that is **not** a first run |
| `lib/ui/widgets/textured_surface.dart` | `AppBackdrop` + the warm/cold register — night screens must pass `cold` |
| `lib/platform/tilt_source.dart` | the only file that names `sensors_plus` |
| `lib/platform/frame_report.dart` | `--dart-define=FRAME_REPORT=true`; `dumpsys gfxinfo` is useless for Flutter |
| `tool/generate_icons.py` | launcher icon + splash, from `raw_assets/icon/` |
| `tool/extract_palette.dart` | measures the palette out of the shipped faces; `flutter test` it |
| `lib/core/theme/app_colors.dart` | the measured swatches; the only colour literals in the app |
| `lib/platform/audio_backend.dart` | the only file allowed to name the audio package |
| `lib/ui/widgets/ambient_motion.dart` | opt-out for never-ending motion; why `pumpAndSettle` works |
| `PRODUCT.md` / `DESIGN.md` | what the app is for; why each visual number is what it is |
