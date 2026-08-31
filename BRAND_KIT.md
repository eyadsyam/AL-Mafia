# BRAND_KIT.md — Mafia Master / سيد المافيا

The brand and design system **as shipped**. One document, so a designer, an
illustrator or a new engineer can produce work that matches the app without
reading the code.

`register: reference`

**Status of the surrounding docs**

| File | What it is | Authority |
|---|---|---|
| `.specify/memory/constitution.md` | the rules the app may not break | **wins over everything here** |
| `05-zero-leakage-spec.md` + `specs/001-mafia-master/contracts/leakage-invariants.contract.md` | the anti-leakage contract | wins over any visual decision |
| `PRODUCT.md` | what the app is for | authoritative on purpose and tone |
| `DESIGN.md` | *why* each visual number is that number | authoritative on rationale |
| **this file** | *what* the values are, in one place | reference; code wins on conflict |
| `01-design-system.md` | the **pre-implementation** proposal (gold `#C9A227`, Cinzel, blue/red role colours) | **superseded** — nothing in it ships as written |

The runtime source of truth is `lib/core/theme/app_colors.dart` (raw tones) and
`lib/ui/theme/design_tokens.dart` (semantic tokens). If this file and those
files disagree, the code is right and this file is stale.

---

## 1. The brand in one page

**Name** — Mafia Master · **سيد المافيا**

**What it is** — the moderator for a face-to-face game of Mafia. One phone,
passed around a table of 6–15 people, in a living room or a café in Egypt. It
deals roles, runs the night in secret, times the day, counts votes, declares a
winner. No account, no network, no telemetry. The phone is a prop on a table.

**The one idea** — *the artwork is the product; everything else gets out of its
way.* There are four painted role cards. They are shown whole — no crop, no
tint, no overlay, nothing drawn on top — and the entire rest of the app is built
from colours measured out of them. The app should look like it was printed on
the same press.

**Personality**

| It is | It is not |
|---|---|
| a deck of hand-painted cards, an oil lamp, a low narrator voice | a cartoon, a kids' app, a nightclub |
| warm about the **story**, cold about the **screen** | warm about the pixels |
| quiet enough to disappear behind the art | decorated |
| adult, cinematic, unhurried | busy, gamified, celebratory |

**Anti-references** — never build toward these:

- **Material Design defaults.** Blue ripples, elevation shadows, stock switches.
  This is printed matter, not a Google product.
- **Neon-on-black "hacker" mafia apps.** The whole category renders itself in
  purple gradients and glow. This one is charcoal, graphite and bone.
- **Anything that celebrates.** No confetti, no fanfare on elimination, one win
  sting for both outcomes. Someone just lost; the table should feel it.
- **Skeuomorphic felt-and-wood board-game chrome.**

---

## 2. The constraint that generates the brand

**Zero information leakage** (Constitution Article I, NON-NEGOTIABLE). The
device must not expose any signal — visual, temporal, acoustic, haptic or
structural — that distinguishes one player's role from another's during play.

The critical user is the person **not** holding the phone. They are watching the
holder's face, the holder's hands, and the light coming off the screen.

This is not a constraint the design works around; it is why the design looks the
way it does. The palette is near-black because a bright phone at a dark table
lights its holder's face. Contrast is bought with **typography, not luminance**.
The palette is sampled from four paintings in one monochrome register, so colour
is *structurally incapable* of varying by role.

**Two vocabularies, and the line between them**

| | In-hand (private) | On-table (public) |
|---|---|---|
| Reached while | the phone is in one player's hand | the phone is face-up for everyone |
| Screens | pass screen, role reveal, night action | home, phase announcements, day, vote tally, result, analytics, onboarding |
| Colour | ground + bone/grey text + parchment accent only | may use role accents, crimson, sage, gallery art |
| Sound / haptics | **none, ever** | cues and narration allowed |
| Motion | identical for every role, token-driven | may be dramatic |
| Brightness | inside the ±2% luminance budget | free |

`handoff_purity_test.dart` fails the build if a handoff-reachable file so much
as references a role accent or a gallery asset.

**The invariants a designer can actually break** (full list in the contract):

| ID | Rule |
|---|---|
| L-01…L-04 | every role renders an identical widget tree; reserved slots exist for all roles and stay empty for most |
| L-05 | mean pixel luminance of any in-hand screen is within **±2%** of the set mean |
| L-06 | no warm/red token on any night or in-hand screen |
| L-07…L-09 | dwell gates, turn floors and transition durations are role-invariant |
| L-10 / L-11 | no haptic and no audio while the phone is in a hand |
| L-17 | `lib/ui/**` contains no hardcoded colour/size/duration literals outside the token files |

> **Never widen a failing luminance budget to make a nicer-looking card pass.**
> That is the one change that converts a caught leak into a shipped one.

---

## 3. Colour

### 3.1 How the palette was made

Measured, not chosen. `tool/extract_palette.dart` pools every pixel of all four
shipped card faces, sorts the pile by Rec. 709 luminance, and averages the
pixels around fixed percentiles. Re-run it after replacing art:

```
flutter test tool/extract_palette.dart
```

A palette invented alongside the paintings drifts from them the first time the
art changes, and the drift reads worse than an obvious mismatch: the eye keeps
trying to reconcile an app that looks *almost* like the cards it is showing.

### 3.2 Measured tones — `AppColors`

Darkest to lightest. "What it is on the card" is deliberate: a designer can hold
a printed card next to the screen and see they are the same colours.

| Token | Hex | Lum /255 | On the card | In the app |
|---|---|---|---|---|
| `deepestShadow` | `#010201` | 1.7 | inside the hoods | reference black — **not** the ground, **not** the letterbox any more |
| `midCharcoal` | `#080808` | 8.0 | coat bodies | card interior reference only |
| `graphite` | `#141314` | 19.3 | ornament shadows | reference |
| `paleSilver` | `#5A5852` | 88.0 | beadwork highlights | heavy dividers |
| `mutedGrey` | `#908C82` | 140.1 | receding detail | disabled + tertiary text |
| `secondaryGrey` | `#ADA89E` | 168.3 | mid-tone detail | body text |
| `agedParchment` | `#C1BCB1` | 188.3 | the painted border | **the single accent** — buttons, active states |
| `boneWhite` | `#E9E4D9` | 228.3 | brightest highlights | all primary text, the role name |

Per-role agreement at each band is within a few levels. That agreement *is* the
check that this is one palette and not an average of four.

**Honesty notes.** `boneWhite` is the one value taken from the brief rather than
straight off a percentile — the measured band runs `#E4DED2` to `#F6EEE3` and it
sits inside; the top of the range is skewed by the mafia painting, which starts
darkest and carries the largest normalising gain. `shadow` is not measured at
all: a painting has no shadow *colour*, only darker paint.

### 3.3 The ground — four values that are **not** measured

| Token | Hex | RGB | Lum /255 | Use |
|---|---|---|---|---|
| `groundBase` | `#0F0F0F` | 15, 15, 15 | 15.0 | app background, every screen |
| `groundRaised` | `#1A1A1A` | 26, 26, 26 | 26.0 | panels, tiles, cards |
| `groundOverlay` | `#252525` | 37, 37, 37 | 37.0 | dialogs, sheets, pressed states |
| `groundBorder` | `#313131` | 49, 49, 49 | 49.0 | hairlines and dividers |

One cool hue family at four brightnesses. **The blue channel leads at every
step** — that is the direction *away* from skin tone, and doc 05 rule 3 forbids
warm colour at night because a warm cast is conspicuous on a face across a dark
table. `role_accent_parity_test.dart` asserts `blue ≥ green ≥ red` at every rung.

These are a product decision rather than a measurement: the measured
3rd-percentile black is what the *inside of a hood* looks like, and a UI built on
it has no headroom to lift a panel off the ground.

> **Reverted, do not reintroduce.** An earlier revision made the ground warm
> tanned leather (`#241C14`, luminance 29) and logged the deviation as a
> trade-off. A ground emitting roughly seventeen times more light onto the
> holder's face is a real weakening of Article I bought with nothing but taste.
> The warm/cold *register split* went with it: one ground on every screen,
> private and table alike.

### 3.4 Semantic tokens — `MafiaColors.dark`

This is the layer widgets are allowed to touch.

| Semantic token | Value | Meaning |
|---|---|---|
| `surfaceBase` | `AppColors.groundBase` `#0F0F0F` | the ground |
| `surfaceRaised` | `AppColors.groundRaised` `#1A1A1A` | panels and tiles |
| `surfaceOverlay` | `AppColors.groundOverlay` `#252525` | dialogs, sheets, press overlays |
| `borderSubtle` | `AppColors.groundBorder` `#313131` | hairlines |
| `textPrimary` | `AppColors.boneWhite` `#E9E4D9` | headings, role names, primary content |
| `textSecondary` | `AppColors.secondaryGrey` `#ADA89E` | body, descriptions |
| `textMuted` | `AppColors.mutedGrey` `#908C82` | disabled, placeholders, tertiary |
| `accentGold` | `AppColors.agedParchment` `#C1BCB1` | the one accent — primary buttons, active states |
| `accentGoldPressed` | `#8D8169` | pressed accent |
| `accentCrimson` | `#AA3D28` | elimination / destructive — **post-game and on-table only** |
| `accentSage` | `#6B7A63` | safety / success — **post-game and on-table only** |
| `shadow` | `#8C000000` | cast shadow under raised panels |

`accentGold` is named for what it does, not what it is: it measures close to
neutral because the paintings are close to neutral. The warmth people read into
a parchment border is mostly its brightness against charcoal, not its hue.

### 3.5 Role accents — post-game surfaces only

| Role | Hex | Rec. 709 lum |
|---|---|---|
| `roleMafia` | `#916D66` | 116.1 |
| `roleDoctor` | `#717573` | 116.0 |
| `roleDetective` | `#7D7361` | 115.8 |
| `roleCitizen` | `#767471` | 116.2 |

All four sit at **116 ± 0.2%**, well inside the ±2% budget, with saturation
capped so none reads louder than the others. A saturated crimson for Mafia at
the same *nominal* brightness still throws more light on the holder's face than
a grey; matching the numbers is the only way to actually hold rule 3.

**Legitimate users:** the result screen, the vote reveal (where the role has just
become public to everyone at once), post-game analytics. **Nowhere else.** The
in-match role card uses `textPrimary` and `borderSubtle` for every role, so
parity there is structural rather than balanced.

### 3.6 Contrast, measured

WCAG ratios of the shipped tokens. Floors: **7:1** primary, **4.5:1** secondary
(Constitution Article VII).

| Foreground | on `surfaceBase` | on `surfaceRaised` | on `surfaceOverlay` |
|---|---|---|---|
| `textPrimary` `#E9E4D9` | **15.12** | 13.75 | 12.13 |
| `textSecondary` `#ADA89E` | **8.10** | 7.36 | 6.50 |
| `textMuted` `#908C82` | 5.71 | 5.19 | 4.58 |
| `accentGold` `#C1BCB1` | 10.13 | 9.21 | 8.13 |

`textMuted` is for disabled and tertiary content only — it clears 4.5:1 on base
and raised, and lands just above it on overlay. Do not use it for anything a
player has to read to act.

### 3.7 Colour rules

1. **One accent.** `accentGold`. If a screen seems to need a second, it needs
   less on it instead.
2. **No colour is bound to a role during play.** Ever.
3. **No warm colour on a night or in-hand surface.** Enforced as a direction
   (blue ≥ green ≥ red), not a tolerance, because the shipped ramp is
   deliberately *cooler* than neutral and a literal neutrality bound would fail
   it for being too safe.
4. **Screens read tokens, never swatches.** `context.colors.surfaceBase`, never
   `AppColors.groundBase` and never a hex literal. `AppColors` is what the
   tokens are made of, not a second way to reach them (`token_discipline_test`).
5. **There is one theme.** Dark. No light mode, no theme switcher.

---

## 4. Typography

### 4.1 Families — all SIL OFL 1.1, all bundled

| Role | Family | File | Why |
|---|---|---|---|
| Display, Latin | **Bebas Neue** | `BebasNeue-Regular.ttf` | narrow uppercase, poster-like, no Arabic coverage |
| Display, Arabic | **Cairo** (variable) | `Cairo-Variable.ttf` | the RTL fallback for every display style; also carries Latin |
| Body, both scripts | **IBM Plex Sans Arabic** | Regular 400 / Medium 500 / SemiBold 600 | excellent legibility at small sizes on both scripts |
| Figures | **IBM Plex Mono** | Regular 400 / Medium 500 | tabular figures for timers and counters |

Licence text ships in `assets/fonts/OFL.txt` and is registered with the
`LicenseRegistry` in `main.dart`, so it appears in the app's own licence page.

**How the two scripts are handled.** Every display style names Bebas Neue as
`fontFamily` and lists Cairo in `fontFamilyFallback`. Flutter resolves fallbacks
per glyph, so an Arabic heading renders in Cairo and a Latin one in Bebas *from
the same token*. Nothing in the widget layer ever branches on locale.

**Cairo is variable**, so heavy cuts are requested through
`fontVariations: [FontVariation('wght', …)]`. Setting `fontWeight` alone leaves
it at its default instance and lets the platform synthesise a fake bold, which
smears at display sizes. The axis value is ignored by Bebas, which has one static
cut — so one token is correct for both.

### 4.2 The scale — `MafiaTypography.defaults`

| Token | Family | Size | Weight | Height | Use |
|---|---|---|---|---|---|
| `display` | Bebas → Cairo | 44 | `wght 900` | 1.6 | phase announcements, the biggest moment on a screen |
| `headline` | Bebas → Cairo | 32 | `wght 800` | 1.6 | screen titles |
| `title` | Bebas → Cairo | 22 | `wght 700` | 1.6 | card titles, player names |
| `body` | IBM Plex Sans Arabic | 16 | 400 | 1.6 | general content, all button labels |
| `bodySmall` | IBM Plex Sans Arabic | 14 | 400 | 1.6 | descriptions |
| `caption` | IBM Plex Sans Arabic | 12 | 500 | 1.6 | labels, badges, phase banner |
| `timer` | IBM Plex Mono | 48 | 500 | 1.0 | countdowns |

Display sizes run above the doc-01 proposal on purpose: Bebas is narrow uppercase
and reads considerably smaller than its nominal point size, and these headings
are read at arm's length across a dim table.

### 4.3 Type rules — all three are absolute

1. **No letter-spacing, anywhere.** Arabic glyphs *join*; tracking pulls the
   joins apart. It does not look "spaced" to a native reader, it looks broken.
   This is an Arabic-first app, so the rule is per-system rather than per-style —
   even the Latin display face falls back to Cairo, and the fallback is the case
   that matters.
2. **Line height 1.6 on every style that can render Arabic.** Arabic ascenders
   and descenders need more room than Latin at the same size; 1.4 clipped them on
   the display cuts. The one exception is `timer` — digits only, single line, set
   solid on purpose.
3. **Tabular figures everywhere**, applied at the token level. A counter whose
   digits change width makes its whole row twitch as it counts, and that twitch
   is visible from across the table. Applying the feature at the token means a
   new counter cannot be added without it.

Plus: **RTL-first**, LTR supported. **No italics for Arabic.** Minimum size for
any tappable text: 14.

---

## 5. Space, shape and layout

### 5.1 Spacing — `MafiaSpacing.defaults`, 4dp unit

| Token | Value | Use |
|---|---|---|
| `xs` | 4 | icon-to-text gap |
| `sm` | 8 | inside a component |
| `md` | 16 | default panel padding |
| `lg` | 24 | between sections |
| `xl` | 32 | vertical screen margins |
| `xxl` | 48 | dramatic separation (phase screens) |
| `screenMargin` | 20 | horizontal screen margin |
| `maxContentWidth` | 480 | content column, auto-centred on wider screens |

### 5.2 Radii — `MafiaRadii.defaults`

| Token | Value |
|---|---|
| `card` | 16 |
| `button` | 14 |
| `dialog` | 20 |

`PaperPanel` defaults to the **card** radius so panels and cards agree.

### 5.3 Layout rules

- One dominant element per screen. **Exactly one primary action per screen.**
- Minimum touch target **48×48dp**, inherited from the button themes rather than
  remembered per call site.
- Generous vertical rhythm — the app is read across a table, not held close.

---

## 6. Light, elevation and material

### 6.1 One lamp — `MafiaElevation`

Inconsistent light direction is the most common tell of an amateur interface.
Nobody can name it, but everyone feels it: one panel lit from above, one card lit
from the left, and the screen stops reading as a single physical space.

So there is **one lamp** — above and slightly to the left, consistent with a light
over a table — and elevation is expressed by shadow **size only**. Direction never
varies; the offset-to-blur ratio is fixed.

| Level | Offset | Blur | Alpha | Use |
|---|---|---|---|---|
| `level1` | (0.7, 2) | 8 | 0.20 | panels and tiles resting on the surface |
| `level2` | (1.4, 4) | 16 | 0.28 | selected tiles, lifted buttons |
| `level3` | (4.2, 12) | 32 | 0.40 | cards and dialogs, clearly held above everything |

`lightSkew = 0.35` — the horizontal component as a fraction of the vertical.
Shadows fall down and to the right because the lamp is up and to the left.

The shadow colour is opaque-ish black (`#8C000000`), not a tinted shade: on a
near-black ground a Material-style light elevation model has no headroom, so
depth has to come from something that genuinely darkens what is behind the panel.

### 6.2 The material — canvas weave

What makes painted artwork read as painted is the ground it sits on. Every
surface therefore carries the same 192px canvas weave tile
(`assets/images/canvas_texture.webp`) over the same charcoal, at the same
strength:

| Surface | Widget | Weave opacity |
|---|---|---|
| Screen ground | `AppBackdrop` | **0.24** |
| Raised panel | `PaperPanel` | **0.22** |

Panel weave is *slightly* lower so the two read as the same material rather than
as a panel with a pattern on it. The hairline is what actually separates them —
the tonal step from `surfaceBase` to `surfaceRaised` is about ten levels, enough
to feel and not enough to see an edge by.

These exist as widgets, not as a `BoxDecoration` helper, precisely so the
strength cannot drift screen to screen. The weave uses `Image`'s own opacity
rather than an `Opacity` widget, so there is no offscreen `saveLayer` — it is
behind every screen in the app, including the night turns where frame budget is
tightest.

`AppBackdrop`'s backdrop *image* is optional and is the expensive part. Night and
in-hand screens pass nothing and get charcoal plus weave, which is all doc 05
allows them anyway.

---

## 7. Imagery

### 7.1 The card box — the part people get wrong

One fixed box, **1024 × 1536**, for every role.

The three finished paintings are aspect 0.7467 and the mafia is 0.8733.
"Never crop" and Article II's "element dimensions may not vary by role" cannot
both hold for the *painting*, so they hold for the **box**: the painting is
scaled whole to fit (`BoxFit.contain`, no pixel lost), centred, and `card_ground`
fills the rest. Coverage is **89.3%** for three of them and **76.4%** for the
mafia.

`card_ground` = `[13, 15, 20]` in `tool/manifest.json` and **must equal**
`AppColors.groundBase`. The letterbox bars then match the screen behind the card
exactly and the box edge is invisible. If they drift, the bars become a visible
frame — deeper on the mafia card than the other three, and invisible to every
luminance check because the budget is satisfied by construction.
`card_ground_matches_surface_test.dart` holds the two together across the
Python/Dart boundary and probes the outer 4px of every shipped face.

**Luminance is solved on the composited box, not on the painting.** Two paintings
at identical mean brightness covering different fractions of a fixed box still
emit different amounts of light, and light on a bystander's retina is what
Article I is about. The pipeline gains **only the art** and holds the bars at the
constant:

```
target = cover · art + (1 - cover) · ground      # ground fixed
art    = (target - (1 - cover) · ground) / cover
```

Measured result:

```
slot                       raw    drift   cast   cover    gain   final    drift
card_face_mafia          35.10  -38.93%   4.59   76.4%  1.6421   57.46  -0.012%
card_face_doctor         65.04   13.18%   4.65   89.3%  0.8836   57.47   0.000%
card_face_detective      69.25   20.49%   5.86   89.3%  0.8299   57.47   0.000%
card_face_citizen        60.49    5.25%   5.02   89.3%  0.9501   57.47   0.000%

worst drift 0.0090%   budget 2%
```

The raw spread is **1.70:1** — the detective card would throw 70% more light on
its holder's face than the mafia card. That is the leak the gain exists to close.

**The only processing applied to a face is one scalar gain.** No crop, no
desaturation, no cast-stripping, no hue shift, no overlay. All four faces are
warm by 4–6 levels in the same direction; that is the artwork, and correcting it
would be changing the artwork. What is asserted instead is that the four faces
**agree** on hue to within 3 levels — a deck that is uniformly warm tells nobody
anything, while one card warmer than the other three is a role tell no luminance
budget catches, because chroma can differ at constant Rec. 709 luminance.

### 7.2 The card back

Exactly one file, shared by every role, so it cannot leak role — but it *can*
leak orientation, and a table that can tell which way up a card was dealt has
information the rules never gave it. `card_back_symmetry_test.dart` measures the
shipped bytes against their own 180° rotation.

### 7.3 What goes outside the card

The role name and its one-line description are Flutter text **below** the card —
bone white, display face, centred, identical position and size for all four
roles. Only the string differs, and it comes from the ARB. Both slots are
fixed-height and single-line, so a wordier role cannot make its card taller.

The paintings already carry the role letter and the corner icon; duplicating them
on top would be drawing on the art.

### 7.4 Asset tiers — `tool/manifest.json`

Every generated image is declared in one manifest, read by both
`tool/normalise_art.py` (writes the files) and `test/platform/asset_manifest_test.dart`
(checks the shipped bytes). One list, two consumers, nothing to drift.

| Tier | What | Treatment | May appear in-hand? |
|---|---|---|---|
| **1** | the four card faces + the card back | luminance-matched across the set, nothing else | **yes — only these** |
| **2** | gallery paintings (`assets/images/gallery/`) | full colour, deliberately *not* matched | **never** |
| **3** | public backdrops, onboarding chapter art | gained into a declared `lum_band` so overlaid bone-white text keeps its contrast | never |
| **4** | outcome plates, badge frame, canvas texture | cosmetic | on-table only |

Shipped today: tier 1 (5 files), tier 2 (4 files), `canvas_texture`,
`home_backdrop`, `splash_mask`, four tintable role icon masks. The tier-3
backdrops (`bg_home`, `bg_night`, `bg_day`, `bg_vote`) and the five
`onboarding_*` slots are **declared but have no source art** — the slots are
named, sized and banded so art can be dropped in without a code change.
`OnboardingCard` takes a null image and prints its chapter numeral instead.

> The `"register": "warm" | "cold"` field on the tier-3 slots is vestigial from
> the reverted register split. New tier-3 art is cold. See §3.3.

### 7.5 New-art checklist

- [ ] Source is uncropped and lands in `raw_assets/` with a name the manifest's
      `raw_match` will find.
- [ ] Slot declared in `tool/manifest.json` with `tier`, `out`, `size`, `quality`.
- [ ] Tier 1 → added to `face_set`; expect the pipeline to **refuse to write** if
      any face lands outside ±2%.
- [ ] `python tool/normalise_art.py` re-run, and `tool/extract_palette.dart`
      re-run if a *face* changed (the palette is measured from them).
- [ ] `flutter test test/golden/leakage/` green. No tolerance widened.

---

## 8. Iconography

**There is no icon set.** The emblems are paintings, and icons exist only as
navigation chrome — a scoped exception recorded in `05-zero-leakage-spec.md`,
because back / settings / history / help are universally understood, appear only
on public screens, and render identically whatever anyone drew.

| System | What | Where |
|---|---|---|
| **Material icons** (`NavIconButton`, `back_action.dart`) | back, settings, history, help, add, remove, close, delete | navigation chrome, public screens only |
| **The four card icons, redrawn as paths** (`icon_painters.dart`) | pistol (Mafia), cross (Doctor), lens (Detective), spade (Citizen) | ambient falling layer only |
| **Tintable alpha masks** (`assets/icons/role_*.webp`) | the same four as bitmaps, carrying no colour of their own | post-game surfaces; the widget supplies the colour |

> **`phosphor_flutter` is in `pubspec.yaml` and is not used.** The brief asked
> for Phosphor Regular; its `PhosphorIconData extends IconData`, and `IconData`
> is a `final class` in this Flutter version, so importing the package fails the
> build outright. 2.1.0 is the newest release and it has not been fixed. Material
> icons ship with the framework and — the part that actually matters — declare
> `matchTextDirection`, which is what makes the back arrow point the right way in
> Arabic without a manual transform.

**Chrome glyph 24dp inside a 48dp target.** One value for every navigation
control. The target is twice the glyph because these sit in screen corners where
a thumb is least accurate and there is no longer a box drawn to make them look
tappable — the target has to carry that on its own. Every one takes a required
Arabic `semanticLabel`: removing the visible word is only acceptable if the word
is still there for anyone who needs it.

Stroke on the painted icons scales with the glyph —
`(size.shortestSide * 0.06).clamp(0.6, 2.0)` — because they are drawn anywhere
from 16 to 40 logical pixels and a fixed 2px line makes the small ones look
bolder than the large ones, which is the opposite of the depth the varied sizes
suggest.

**Forbidden:** cartoon icons, emoji anywhere in gameplay UI.

**The placement rule.** The four corner icons may appear only in the ambient
falling layer (home screen and phase announcements) — **never in the player grid
and never beside a name.** They are the icons painted on the card corners, so one
of them near a person reads as that person's role no matter how randomly it was
picked. `ambient_icon_placement_test.dart` enforces the placement rather than
trusting it.

**Ambient falling icons:** downward drift, opacity **4–8%**, varied size and
speed, seamless loop.

### The mark

There is no wordmark lockup. The app's mark is `splash_mask.webp`, generated at
640px by `tool/generate_icons.py` and drawn at **160dp** on `surfaceBase` by both
the Android launch window (`launch_background.xml`) and `SplashGate`. The bitmap,
the ground colour and the size come from one place; if any of the three drift the
handover seam becomes visible. `SplashGate` dissolves the mask over one
`motion.dramatic` with no hold, no logo animation, no version string — a veil
coming off, not a gate. Skipped entirely under Reduce Motion.

---

## 9. Motion

### 9.1 Tokens — `MafiaMotion.defaults`

| Token | Duration | Curve | Use |
|---|---|---|---|
| `instant` | 100ms | linear | press feedback |
| `quick` | 200ms | easeOut | state changes within a screen |
| `standard` | 300ms | easeInOut | route and phase dips |
| `dramatic` | 600ms | easeInOut | the card flip |

| Constant | Value | Note |
|---|---|---|
| `pressScale` | **0.97** | deliberately shallow — a press on an in-hand surface is watched by the people either side of the holder, and a big squash is a visible event they can count |
| `perspective` | **0.0012** | `Matrix4` entry (3,2) for the flip; lives in the token so the one 3D effect in the app cannot acquire a second, differently-warped copy |
| `stagger` | **40ms** | per-item delay, **public lists only** — the vote tally and post-game rows. Staggering anything role-derived would turn list position into a timing channel |

### 9.2 Timing gates — `MafiaTiming.defaults`

The **only** source of truth for the anti-leakage timing gates. Global and
role-agnostic by construction; nothing in the widget layer may derive a duration
from a `Role`. `MafiaTiming.lerp` deliberately returns `this` — a half-applied
gate is a leak.

| Token | Value | Invariant |
|---|---|---|
| `holdToReveal` | 600ms | the hold that opens a turn |
| `dwellGate` | **8s** | Confirm stays disabled this long after reveal (L-07) |
| `turnFloor` | **12s** | pass unlocks at exactly this offset from reveal, whenever the action was confirmed, so a fast actor and a slow actor produce the same observable turn length (L-08) |
| `passTransition` | 300ms | handoff transition (L-09) |
| `revealFloor` | 5s | minimum face-up time before the dismiss control activates |
| `autoRevealDuration` | 5s | how long the card stays face-up before auto-concealing; unlimited re-reveals within the turn |
| `phaseHold` | 3s | how long an announcement holds at full opacity |

The identity hold is a **host setting** (default 5s; 3/5/10/20). It is the
turn-length equaliser as much as an identity check. It was 20s; on a real table
that multiplies by the size of the table, and a hold that outlasts the holder's
patience gets released early and retried.

### 9.3 Motion rules

1. **Uniform transitions for every player.** Timing differences are leaks.
2. **Reduce Motion degrades to the *finished* state, never the initial one, and
   never changes how long anything takes.** An accessibility setting that made
   the game faster would be a signal in its own right.
3. No confetti, no celebratory haptics during gameplay.
4. Haptics: light impact on select and confirm only, identical for every role,
   and **never on an in-hand screen** (L-10).
5. Decoration is never load-bearing for a timing invariant. The hold pad
   completes on a `Timer`, not on its progress ring finishing — a `Timer` is
   exactly as long for every player regardless of frame rate or device.

### 9.4 The reveal — three steps, identical for everyone

1. **Identity gate** — the name, and a pad held for the host's `identityHoldSeconds`.
2. **Swipe to flip** — the card follows the finger and completes on distance or
   velocity. One `dramatic`, one curve, one rotation, for everyone.
3. **Auto-conceal after 5s** with a progress line and unlimited re-reveals, then
   *«سلّم الموبايل»*.

The words under the card are gated on the flip's **own geometry**, not on the
phase — they cross the halfway point on the same frame the painting does. Driving
them off the phase put the role name on screen in legible type while the card was
still edge-on to the table. The five-stage golden found it.

---

## 10. Sound

Nine cues behind a single `AudioBackend` seam. Every cue may carry an ambient bed
and, independently, a recorded narrator line; a transition with neither still
works, because the words are on screen.

| Cue | File | Design |
|---|---|---|
| Night falls | `night_falls.ogg` | deep calm narrator + faint ambient (wind, night silence) |
| Morning | `morning.ogg` | gradual rise in the ambient layer |
| Speaker change | `speaker_change.ogg` | short neutral chime, < 1s |
| Timer warning / end | `timer_warning.ogg` / `timer_end.ogg` | two ascending tones |
| Elimination reveal | `elimination_reveal.ogg` | single deep drum hit |
| Card flip | `card_flip.ogg` | on-table only |
| Win | `win.ogg` | one sting, **both outcomes** |
| Score bed | `score_loop.ogg` | see below |

**The score.** One 32-second seamless loop, started at launch and never varied —
no swell, no duck, no stop at a phase boundary, because a bed that reacts to the
game is a channel that reports on it. A bare fifth with no third, a 50 bpm pulse
below resting rate, and filtered air. Normalised to −20 dBFS and played at 0.55,
landing around −25 dBFS: roughly 22 dB under a cue, so a room can talk over it.

**Rules.** No cartoon sounds, whistles or laughter. No tension music on a night
cue — that would hint. **Nothing plays while the phone is in a hand**: the
director *throws* rather than returning quietly, because a swallowed call would
be discovered by a player rather than by a test (L-11).

---

## 11. Voice and copy

**Egyptian Arabic, spoken register.** Not Modern Standard.

> «الضلمة نزلت على البلد» — not «حل الظلام على القرية»

The game is a fairy tale about a village that goes to sleep and wakes up with
someone missing. The app is the storyteller: it is **warm about the story and
cold about the screen**. The copy can be theatrical; the pixels cannot.

Shipped examples: `سيد المافيا` (title) · `توزيع الأدوار` · `ضع الهاتف على الطاولة وانتظر الإشارة` ·
`ابدأ الليل` · `لازم يكون في مافيا واحد على الأقل` · `سلّم الموبايل`.

**Rules**

- All strings live in the ARB and reach widgets through `context.l10n`. No
  literal user-facing text in a widget.
- English exists as a fallback, not a default.
- A pass screen shows exactly **one** piece of information: the name of the
  person the phone is for. No phase content, no counts, nothing that would reward
  picking the phone up out of turn (L-12).
- Any neutral subtitle on a handoff screen must be the **same for every
  recipient**.

---

## 12. Components

Every button in the app is a stock `FilledButton`, `OutlinedButton` or
`TextButton`, styled once in `MafiaTheme.dark`. There is no custom button widget
and there should not be one: the accessibility work — 48dp targets, focus rings,
Dynamic Type, semantics — is already correct in the Material ones and would have
to be rebuilt to the same standard by hand.

### 12.1 Buttons — the full state matrix

| | Resting | Pressed | Disabled |
|---|---|---|---|
| **Filled** (primary) | `accentGold` bg, `surfaceBase` label | `accentGoldPressed` bg | `surfaceRaised` bg, `textMuted` label |
| **Outlined** (secondary) | `borderSubtle` side, `textPrimary` label | `textSecondary` side | `surfaceRaised` side, `textMuted` label |
| **Text** (marginal) | `textSecondary` label | `textPrimary` label | `textMuted` label |

All three: `body` text style, `radii.button`, overlay `surfaceOverlay`, minimum
size 48dp high, horizontal padding `spacing.lg`, zero Material elevation.

Disabled text sits on `surfaceRaised`, so it needs a **lighter** colour to stay
readable — the opposite of the dark-on-parchment the enabled button uses.
Material's single "disabled" colour cannot express that, which is why it looks
wrong out of the box.

**Switches** are themed centrally too. Material's stock Switch draws a pure-white
thumb on a grey track when *off*, which on this ground is the brightest element
on the Settings screen. Thumb: `accentGold` selected / `textSecondary` resting /
`textMuted` disabled. Track: `accentGoldPressed` / `surfaceRaised` / `surfaceBase`,
with a `borderSubtle` outline only when unlit.

Rule: **exactly one primary button per screen.**

### 12.2 The inventory

| Component | File | Notes |
|---|---|---|
| `AppBackdrop` | `textured_surface.dart` | screen ground + weave; optional backdrop art |
| `PaperPanel` | `textured_surface.dart` | raised stock every panel is cut from |
| `PlayerTile` | `player_tile.dart` | the most important component — see below |
| `HoldPad` | `hold_pad.dart` | the press-and-hold identity pad, `Timer`-driven |
| `PassScreen` | `pass_screen.dart` | the handoff gate, S-05 |
| `RoleCard` | `role_card.dart` | swipe-to-flip, geometry-gated caption |
| `CardSpread` | `card_spread.dart` | the deck |
| `PhaseTimer` | `phase_timer.dart` | mm:ss in tabular mono + progress ring; parent owns the tick |
| `PhaseTransition` | `phase_transition.dart` | full-screen announcement, `phaseHold` |
| `VoteBar` | `vote_bar.dart` | tally row; fills from zero, staggered |
| `CinematicText` | `cinematic_text.dart` | the announcement type treatment |
| `FallingIcons` / `IconPainters` | `falling_icons.dart` | ambient layer, 4–8% opacity |
| `StaggeredEntrance` | `staggered_entrance.dart` | public lists only |
| `AmbientMotion` / `RoomAtmosphere` | | on-table atmosphere |
| `OnboardingDeck` / `OnboardingCard` / `OnboardingRoleGrid` | `onboarding_*.dart` | six chapters, first launch |
| `SplashGate` | `splash_gate.dart` | the launch veil |
| `TurnShell` | `turn_shell.dart` | the frame every in-hand turn is built in |
| `NavIconButton` / back action | `back_action.dart` | the app's only icons; 24dp glyph, 48dp target; back is suppressed in-night (L-15) |

### 12.3 `PlayerTile` and the reserved-slot pattern

The pattern worth copying. Every tile lays out an indicator box of **exactly the
same size, in the same place, for every role**. Only the box's *contents* vary:
for a Mafia actor it shows how many teammates have already voted for this seat;
for everyone else it is empty. Because the box is laid out unconditionally, a
bystander cannot infer anything from the tile's width, height or text position
(L-02).

States are *game* states, never role states: `normal`, `selected`, `dead`
(shown, not selectable), `disabled` (alive but not a legal target now).

**Generalised:** when one role needs something on screen that the others do not,
give the slot to **all** roles and leave it empty for most. Never make its
presence conditional.

### 12.4 `OnboardingCard`, and designing without art

There is no painting for "the night" or "the pass". Rather than invent a visual
language for six cards, the face is built from what the app already owns: the
`PaperPanel` stock, its weave, a short gold rule, and the chapter's own **numeral
set large and faint behind the type** at 3.2× the display size — a ratio, so if
the type scale moves the ornament moves with it.

The numeral does a specific job: a deck needs its cards distinct at a glance —
that is what makes "there are two left" legible — and six panels of text in the
same type are not. A numeral is the cheapest mark that differs on every card, and
the one piece of ornament that cannot be mistaken for game information.

---

## 13. Accessibility

| Requirement | Value |
|---|---|
| Primary text contrast on ground | ≥ 7:1 (ships at **15.12:1**) |
| Secondary text contrast | ≥ 4.5:1 (ships at **8.10:1**) |
| Touch targets | ≥ 48×48dp, inherited from the button themes |
| Dynamic Type | to 130% without layout breakage |
| State encoding | never colour alone — border + icon + text |
| Reduce Motion | respected; degrades to the finished state, never changes duration |

---

## 14. Governance

### 14.1 Token discipline

```
AppColors  (raw measured tones)
    ↓  consumed only by
design_tokens.dart  (MafiaColors / Spacing / Radii / Motion / Timing / Typography / Elevation)
    ↓  reached only through
context.colors · context.spacing · context.radii · context.motion · context.timing · context.typography · context.elevation
    ↓
widgets and screens
```

Constitution Article IV: every colour, space, radius, duration and text style
reaches a widget through a `ThemeExtension` and **never as a literal**.
`token_discipline_test` (L-17) fails the build on a hardcoded colour, size or
duration anywhere in `lib/ui/**` outside the token files.

### 14.2 The tests that hold the brand up

Ship-blocking. A guarantee that is not measured will rot.

| Test | Holds |
|---|---|
| `golden/leakage/luminance_budget_test.dart` | the four faces and the four rendered cards within ±2%; the faces are four *different* images; they agree on hue within 3 levels |
| `card_ground_matches_surface_test.dart` | `card_ground` == `groundBase` across the Python/Dart boundary, plus the outer 4px ring of every shipped face |
| `role_accent_parity_test.dart` | role accents luminance-matched; no night surface carries a warm cast (blue ≥ green ≥ red) |
| `handoff_purity_test.dart` | no handoff-reachable file references a role accent or gallery asset |
| `card_back_symmetry_test.dart` | the back is identical upside down |
| `ambient_icon_placement_test.dart` | corner icons never appear near a name |
| `asset_manifest_test.dart` | shipped bytes match the manifest |
| `token_discipline_test` | no literals in `lib/ui/**` |
| `golden/*_symmetry_test` | identical widget trees across all four roles |
| `accessibility_test.dart` | 48dp targets on every interactive control in a turn |

### 14.3 Decision rules, in priority order

1. If it leaks, it loses — however good it looks.
2. Do not widen a tolerance to make something pass.
3. Measure the palette off the art; do not invent alongside it.
4. One accent, one lamp, one ground, one weave strength.
5. Give a conditional element to every role and leave it empty.
6. Reach values through tokens.
7. When a screen needs a second accent, it needs less on it instead.

---

## 15. Quick reference

```dart
// Colour
context.colors.surfaceBase      // #0F0F0F  ground
context.colors.surfaceRaised    // #1A1A1A  panels
context.colors.surfaceOverlay   // #252525  dialogs, pressed
context.colors.borderSubtle     // #313131  hairlines
context.colors.textPrimary      // #E9E4D9  bone white
context.colors.textSecondary    // #ADA89E
context.colors.textMuted        // #908C82
context.colors.accentGold       // #C1BCB1  the one accent
context.colors.accentCrimson    // #AA3D28  post-game only
context.colors.accentSage       // #6B7A63  post-game only

// Type      44 / 32 / 22  Bebas→Cairo   ·   16 / 14 / 12  Plex Arabic   ·   48  Plex Mono
context.typography.display / headline / title / body / bodySmall / caption / timer

// Space     4 · 8 · 16 · 24 · 32 · 48   margin 20   max width 480
context.spacing.xs / sm / md / lg / xl / xxl / screenMargin / maxContentWidth

// Shape     card 16 · button 14 · dialog 20
context.radii.card / button / dialog

// Light     level1 · level2 · level3   (one lamp, up and left)
context.elevation.level1 / level2 / level3

// Motion    100 · 200 · 300 · 600 ms   press 0.97   stagger 40ms
context.motion.instant / quick / standard / dramatic

// Gates     hold 600ms · dwell 8s · floor 12s · pass 300ms · reveal 5s · phase 3s
context.timing.holdToReveal / dwellGate / turnFloor / passTransition /
               revealFloor / autoRevealDuration / phaseHold
```
