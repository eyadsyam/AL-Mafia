# HANDOFF — read this first

The checkpoint for anyone (human or AI) picking this repo up cold. It is written to
be **cheap to read and sufficient to act on**: everything below is either a fact you
cannot recover from the code quickly, or a decision whose *reasoning* is not obvious
from the diff. Anything you can get from `flutter analyze`, `flutter test`, or a
`grep` is deliberately not repeated here.

Last verified: 2026-08-20 — `flutter analyze lib test tool` clean of errors/warnings
(51 `info`, all pre-existing const/super-parameter hints in `test/` and `lib/engine/`),
`flutter test` **398 passed, 0 failed**. The 26 new tests are the onboarding deck
(§9b). Not re-verified since the 2026-08-03 run: `flutter build apk --release`
(then universal **62.2 MB**) and the `emulator-5554` pass. Onboarding has been
looked at only through `test/preview/onboarding_preview.dart`, never on a device.

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

### 2a. The ground is near-black, and the leather experiment has been reverted

`AppColors.groundBase` = **`#0D0F14`** is the ground on every screen, private and
table alike, with `groundRaised` `#161A22`, `groundOverlay` `#1F2530` and
`groundBorder` `#2A3140`. One cool hue family, four brightness steps, blue
channel leading at every step. Doc 05 rule 3 (no warm colour at night) holds in
its original form.

**An earlier revision made this ground warm tanned leather (`#241C14`) and logged
the deviation as a trade-off in `05-zero-leakage-spec.md` §5. That entry is gone
and the ground is near-black again.** The argument for it was not silly — a warm
cast is conspicuous rather than informative — but the cost it admitted, a phone
emitting roughly seventeen times more light from its ground onto the holder's
face, is a real weakening of Article I bought with nothing but taste. Do not
reintroduce it, and do not reintroduce a warm/cold register split.

**`card_ground` now follows the ground**, and this is the part worth
understanding. It is `[13, 15, 20]` in `tool/manifest.json` — the same
`#0D0F14` — so the card box letterboxes against exactly the colour of the screen
behind it and the box edge is invisible.

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
  └─ python tool/normalise_art.py         # contain→composite→gain→fold→WebP; WRITES assets/
       └─ python tool/generate_asset_constants.py   # regenerates lib/app/asset_constants.dart
            └─ flutter test                          # re-measures the shipped bytes
```

* `python tool/normalise_art.py --check` is a dry run — measures and reports, writes
  nothing. Use it first.
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
| card_face_mafia | 38.22 | −35.56% | 4.59 | 76.4% | 1.6125 | 59.34 | +0.041% |
| card_face_doctor | 66.46 | +12.05% | 4.65 | 89.3% | 0.8898 | 59.32 | 0.000% |
| card_face_detective | 70.67 | +19.14% | 5.86 | 89.3% | 0.8356 | 59.32 | 0.000% |
| card_face_citizen | 61.91 | +4.37% | 5.02 | 89.3% | 0.9570 | 59.32 | 0.000% |

Set mean 59.323/255 · worst drift 0.0309% · max spread 0.0412% · budget 2%.
`card_back` 77.9 → 81.1 after the fold. The raw column is higher than it was
because the box is now composited on `#0D0F14` rather than on near-black; the
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

`AudioCue.cardFlip` exists, has a sound file, and is **never played**. The brief
lists a card-flip cue; the only card flip in the game happens during distribution,
which is an in-hand phase, and Article I bans any sound while one player holds the
phone. The cue and its file are shipped so the decision is a one-line change if the
rule is ever relaxed for the distribution phase specifically. It is not relaxed.

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
2. **Swipe to flip** — the card follows the finger and completes on distance (30% of
   the card) *or* velocity (300 px/s), with a depth shadow that moves with the
   rotation. One duration, one curve, one rotation, for every role.
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

Everything works with sound off, and there are two switches because they answer
different questions: `muteAllAudio` ("the phone should not make noise") and
`narrationEnabled` ("chimes yes, a voice no").

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

2. **Tier-3 backdrops** (`bg_home`, `bg_night`, `bg_day`, `bg_vote`) — and, since
   the onboarding deck landed, five `onboarding_*` slots alongside them (§9b).
   All of them are art slots with no source. Generators are half-written and blocked on
   image-generation credit. `AppBackdrop` already takes an optional image and every
   screen already passes through it, so these are a drop-in when art exists.

3. **`AppBackdrop`'s `image` parameter is used by exactly one screen** (Home). Once
   the tier-3 art exists, decide which on-table screens get ambient art — doc 05
   forbids it on anything in-hand, so the answer is a subset of the public screens,
   not "all of them".

4. **Recorded narration.** The plumbing is complete and tested; there are no
   recordings. Dropping files into `assets/audio/narrator/` and registering them with
   `AudioDirector.registerNarratorLine` is the whole job — no code change.

5. **`AudioCue.cardFlip` is shipped and unplayed.** See §5.

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

A first launch now opens a deck of six cards instead of Home. The host deals
through them — the story, the roles, the night, the day, the phone, winning — and
the last card puts them into setup.

### Why this is not just a second rules screen

`HowToPlayScreen` already existed and still does. It is a **reference**: six
headings a host skims to settle an argument mid-match. This is a **first read**,
in the order the game happens, one idea at a time. They fail differently — a
reference you have to page through is useless in an argument, and a first read
that opens as six stacked walls of text does not get read. Card 6 links to the
reference, so the deck is also how a new host finds it. Home's help control opens
the deck; the rules are one tap further in.

**Card 5 is the reason the feature exists.** Everything else in the deck is also
in the rules. The etiquette of the pass — hold it tilted, do not look at someone
else's screen, do not change your face, never hand it on with anything open — is
not, because it is not a *rule*. It is the handful of physical habits without
which this game leaks through its players rather than through its pixels, and a
table that has never played pass-the-phone has no way to guess any of them. Doc
05 spends its whole length on what the device must not emit; nothing anywhere
told the humans what *they* must not emit. Card 5 does.

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

## 10. Quick orientation map

| Path | What it is |
|---|---|
| `tool/manifest.json` | asset source of truth; read by Python *and* Dart |
| `tool/normalise_art.py` | the only thing that writes `assets/images/card_face_*` |
| `tool/generate_assets.py` | procedural slots only (texture, emblems) |
| `tool/generate_art_ai.py` | Gemini generation; blocked on credit |
| `tool/IMAGE_PROMPTS.md` | the prompt pack + an IMPLEMENTATION NOTES section listing every deviation |
| `lib/ui/theme/design_tokens.dart` | all `ThemeExtension` tokens; role accents are **post-game only** |
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
| `lib/ui/widgets/card_spread.dart` | the home deck: shuffled each visit, tap to flip, parallax |
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
