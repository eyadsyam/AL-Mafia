# Mafia Master — Zero-Leakage UX Specification

> This document is **BINDING** for every screen, component, or animation added to the app.
> Any new feature must pass the checklist in Section 6 before implementation.

---

## 1. Threat Model

Players sit together and watch each other. Possible leakage channels:

| Channel | Attack example |
|---|---|
| **Timing** | "Sara held the phone for 20 seconds, everyone else 8 — she has a special role" |
| **Audio** | A tone that plays only on the Detective's screen |
| **Light** | Red flash reflected on a player's face = they saw a warning |
| **Physical motion** | Audible/visible tap counts, scroll direction, device vibration |
| **UI structure** | An extra button, an extra screen, a differently positioned element |
| **Post-death** | A dead player sees something the living don't |

---

## 2. The Ten Binding Rules

1. **Two steps per role:** every night action = a selection screen + a second screen (result / note / vote state / reminder). No role has one step or three.
2. **Uniform minimum timing:** the Confirm button does not activate before 8 seconds on the action screen. The second screen cannot close before 3 seconds. For every role.
3. **Fixed Luminance Budget:** all night screens share the same average brightness ±2%. Red and warm colors are forbidden at night.
4. **Night silence:** no sound and no haptic fires while an individual player holds the phone. Narrator audio plays only while the phone is on the table.
5. **Identical tap count:** the primary path for every role = long-press (identity) + tap (selection) + tap (second step) + long-press (confirm). Any addition for one role must be mirrored for all.
6. **Single layout tree:** the same widget tree for every role — role-specific content (e.g. Mafia vote indicator) lives in reserved slots that exist for everyone but stay empty.
7. **Identical transitions:** same route transitions and millisecond durations across all roles.
8. **No back navigation inside the night:** back button disabled; the only exit is "End match" from the table screen.
9. **Dead players do not pass:** the dead take no part in the night (fake passes = valueless taps, violating "every tap has value"). The only leak here (pass count = living count) is public information anyway.
10. **Zero memory:** the Detective's result is never shown again. No "your previous actions" screen. Everything a player knows lives in their head — exactly like the physical game.

---

## 3. Design Solutions per Leakage Channel

### 3.1 Timing channel
- The 8-second minimum makes "too fast" impossible.
- No maximum: slowness reveals nothing because anyone may deliberate.
- The "decision locked" screen has a fixed 1-second duration, then the pass screen — no terminal timing difference.

### 3.2 Light channel
- Constant dark vignette + no brightness change between screens.
- The Detective's result renders in standard UI colors (`text-primary` — NOT red for Mafia). The word "Mafia" alone is sufficient.

### 3.3 Audio & haptic channel
- Uniform haptics: light impact on selection only, for every role.
- Keyboard sounds (Citizen note) cannot be force-muted on all devices — solution: the suggestion chips make typing fully optional, and typing itself is available to everyone as "cover noise."

### 3.4 Structure channel
- Mandatory code review rule: any `if (role == ...)` inside the widget layer may change **text content or data only** — never the tree, never the dimensions.
- Golden tests with screenshots for every role — dimensions and positions must match 100%.

### 3.5 Post-death channel
- Analytics unlock only after the match ends — no "partial stats" for the dead during play.
- Dead players are outside every flow entirely.

---

## 4. Acceptance Tests

| # | Test | Pass criterion |
|---|---|---|
| T1 | Video-record four players with different roles using the night phase | An external observer cannot distinguish roles better than chance |
| T2 | Measure per-role screen time across 20 simulations | Differences fall within normal user-behavior variance, no structural gap |
| T3 | Golden tests for all night screens across all four roles | Pixel-perfect structural and dimensional match |
| T4 | Analyze total luminance of all night screens | ±2% maximum deviation |
| T5 | Monitor audio/haptics across every night path | Zero role-distinguishing audio/haptic events |
| T6 | Attempt to open another player's screen | Long-press gate + "Not {name}" prevent any exposure |
| T7 | Kill the app mid-night-action | Resume lands on the pass screen, never the action content |

---

## 5. Trade-off Log (deliberate decisions)

| Decision | Rejected alternative | Rationale |
|---|---|---|
| Night passes in seating order for ALL players | Classic role call-outs | Calling roles reveals who has an action; universal passing makes everyone identical |
| Citizen action = recording a suspicion | Fake dummy screen | Honors "every tap has value" + feeds analytics |
| Mafia tie resolved automatically | Extra passing round | An extra pass instantly leaks the Mafia count |
| Night victim's role NOT revealed | Immediate reveal | Preserves mystery, prevents rapid deduction chains; toggleable in settings |
| Detective result vanishes forever | Investigation log | A log turns the phone into physical evidence that can be socially extorted ("show me your screen!") |
| One near-black ground (`#0D0F14`) on every screen, private and table alike | A warm ground on public screens, near-black on private ones | A register that switches makes the switch itself an event the table can see; one ground is both simpler and what rule 3 asks for |

### On the ground, and rule 3

The ground is `#0D0F14` — 13/15/20, blue channel leading — with panels at
`#161A22`, overlays at `#1F2530` and hairlines at `#2A3140`. One hue family,
four brightness steps, no warm cast at any step. Rule 3 holds in its original
form: **no warm colour at night**, and the neutrality test is the plain one.

**A previous revision bent this rule and the bend has been reverted.** That
revision made the ground warm tanned leather (`#241C14`, 36/28/20, luminance
29/255) and logged it here as a deliberate trade-off, on the argument that a
warm cast is conspicuous rather than informative. The argument was sound as far
as it went, but the cost it named — a phone emitting roughly seventeen times
more light from its ground, lighting the holder's face and reading more easily
over a shoulder — is a real weakening of Article I for a purely aesthetic gain.
The ground is near-black again on every screen. **Do not reintroduce a warm
ground, and do not reintroduce a warm/cold register split.**

**What is checked rather than assumed.** The card box letterboxes against the
same ground the screen behind it uses, so the bars cannot become a visible frame.
The four paintings cover different fractions of the box — 76.4% for the mafia
against 89.3% for the other three — so bars that contrasted with the screen would
draw a frame that is visibly thicker on one role's card, which is a role tell no
luminance budget catches (the pipeline gains bars and art together).
`card_ground_matches_surface_test.dart` measures the outer edge of each shipped
painting and fails if the bars drift more than 12 levels from it.

**Superseded:** the warm/cold `AppBackdrop` register, which held public screens
warm and night screens near-black. With one ground everywhere it had nothing left
to distinguish, and a split that no longer splits anything is just a parameter
people get wrong.

### Icons in navigation chrome — a scoped exception, not a repeal

The no-icons rule stands. It is narrowed, once, and only here.

| | |
|---|---|
| ✅ **Allowed** | Standard navigation chrome on public screens: settings, history, help, back. 24dp glyph, 48dp touch target, cream at 80% opacity, no surrounding box, and an Arabic `Semantics` label on every one. |
| ❌ **Still forbidden** | Any icon carrying game meaning, anywhere inside a match. Role actions, confirm, player tiles, delete (`حذف`) and reorder stay **words**. |

**Why the line is where it is.** A gear is not role-informative — it renders the
same whatever anyone drew, and it only ever appears on a screen the whole table
can see. A glyph standing in for *"kill"*, *"protect"* or *"investigate"* is the
opposite on both counts: it appears on an in-hand surface, and it is the one
thing on that surface that differs by role. Icons also fail first-time players
under social pressure, which is most of the table on most nights.

**The back arrow points right.** The app is RTL and back means forward-in-Arabic.
Both `Icons.arrow_back` and `Icons.arrow_forward` are declared
`matchTextDirection: true`, so Flutter mirrors them: `arrow_back` is the one that
renders pointing right. Verified on a device, not reasoned about.

**Implementation note.** The brief specified Phosphor Icons. `phosphor_flutter`
2.1.0 does not compile against this Flutter version — `PhosphorIconData extends
IconData` and `IconData` is now a `final class` — and there is no fixed release.
The four glyphs are Material's, which ship with the framework and carry the
text-direction metadata the back arrow needs.

---

## 6. New-Feature Checklist (pre-merge)

- [ ] Does it add a step/screen for one role but not the others? → mirror it or reject it
- [ ] Does it emit sound or haptics while one player holds the phone?
- [ ] Does it change brightness or introduce a warm color at night?
- [ ] Does it alter the widget tree based on role?
- [ ] Does it display historical information about secret actions during play?
- [ ] Does it pass tests T1–T7?

**If any item fails: the feature does not ship.**
