# DESIGN.md

The visual system, and why each number is the number it is.

`register: design`

Companion to `PRODUCT.md`. Where this and `.specify/memory/constitution.md`
disagree, the constitution wins — in particular Article IV, which says every
colour, space, radius, duration and text style reaches a widget through a
`ThemeExtension` and never as a literal.

---

## The one idea

**The artwork is the product; everything else gets out of its way.**

There are four painted role cards. They are shown whole — no crop, no tint, no
overlay, nothing drawn on top — and the entire rest of the app is built from
colours measured out of them. The app should look like it was printed on the
same press.

That is not only an aesthetic position. It is also how the app satisfies its one
hard constraint: a palette sampled from four paintings that share one monochrome
register **cannot vary by role**, so colour is structurally incapable of leaking
one.

---

## Colour

Measured, not chosen. `tool/extract_palette.dart` pools every pixel of all four
shipped faces, sorts by Rec. 709 luminance, and averages the pixels around fixed
percentiles. The results live in `lib/core/theme/app_colors.dart` and are mapped
onto semantic tokens in `lib/ui/theme/design_tokens.dart`.

| Band | Hex | Lum /255 | What it is on the card | What it does in the app |
|---|---|---|---|---|
| `deepestShadow` | `#010201` | 1.7 | inside the hoods | the card box letterbox — **not** the ground |
| `midCharcoal` | `#080808` | 8.0 | coat bodies | raised panels |
| `graphite` | `#141314` | 19.3 | ornament shadows | overlays, pressed states |
| `paleSilver` | `#5A5852` | 88.0 | beadwork highlights | borders and dividers |
| `mutedGrey` | `#908C82` | 140.1 | receding detail | disabled and tertiary text |
| `secondaryGrey` | `#ADA89E` | 168.3 | mid-tone detail | body text |
| `agedParchment` | `#C1BCB1` | 188.3 | the painted border | the single accent — buttons, active states |
| `boneWhite` | `#E9E4D9` | 229.4 | brightest highlights | all primary text, including the role name |

Per-role agreement at each band is within a few levels, which is the check that
this is one palette and not an average of four.

### The four colours that are not measured

`groundBase` — **`#0D0F14`**, luminance 15 — is the ground on every screen, and
it is a product decision rather than a measurement. The 3rd-percentile black is
what the *inside of a hood* looks like; used as the whole UI it leaves no headroom
to lift a panel off the ground. So the ground sits a few levels above it and the
ladder steps up: panels `#161A22`, overlays `#1F2530`, hairlines `#2A3140`. One
hue at four brightnesses.

The hue is **cool** — 13/15/20, blue leading — and that is the point rather than a
preference. Doc 05 rule 3 forbids warm colour at night because a warm cast is
conspicuous on a face across a dark table; blue-leading is the direction *away*
from skin tone, so the ramp is strictly safer than a neutral grey would be.
`role_accent_parity_test.dart` asserts blue ≥ green ≥ red at every rung.

**Previously:** this was warm tanned leather (`#241C14`, luminance 29), logged as
a deliberate deviation from rule 3. It has been reverted and the trade-off entry
removed from `05-zero-leakage-spec.md` §5. A ground that emits seventeen times
more light onto the holder's face is a real cost to Article I, and the only thing
it bought was atmosphere.
What rule 3 actually protects is asserted directly by the byte-comparison
goldens.

**Two notes on honesty.** `boneWhite` is the one value taken from the brief
rather than straight off a percentile; the measured band runs `#E4DED2` to
`#F6EEE3` and it sits inside. The top of that range is skewed by the mafia
painting, which starts darkest and therefore carries the largest normalising
gain, pushing its own highlights toward clipping. And `shadow` (`#8C000000`) is
not measured at all — a painting has no shadow *colour*, only darker paint.

### The rules colour has to obey

- **Every night surface sits on one hue.** The ground is warm now, so
  neutrality is not the test any more; what matters is that the three surfaces
  are one colour at three brightnesses and form a real ladder, plus explicit
  WCAG floors on the ground (7:1 primary, 4.5:1 secondary).
  `role_accent_parity_test.dart`.
- **Role accents exist, and are post-game only.** Four of them, luminance-matched
  to ±2% with saturation capped, used on the result screen and the vote reveal —
  never on anything reachable while the phone is in a hand.
  `handoff_purity_test.dart` fails the build on that.
- **`card_ground` tracks the *art*, not the ground.** The pipeline letterboxes
  each painting against `deepestShadow`, and the test measures the outer edge of
  each shipped face to prove the bars vanish into it. If they drift, the bars
  become a frame — wider on the mafia card, which covers 76% of the box against
  89% for the others — and no luminance budget would catch it, because the
  pipeline gains the ground along with the art.
  `card_ground_matches_surface_test.dart`.

---

## The card

One fixed box, 1024×1536, for every role.

The three finished paintings are aspect 0.7467 and the mafia is 0.8733. "Never
crop" and Article II's "never element dimensions" cannot both hold for the
*painting*, so they hold for the **box**: the painting is scaled whole to fit,
centred, and `card_ground` fills the rest. Coverage is 89.3% for three of them
and 76.4% for the mafia.

The only processing applied to a face is a single scalar gain, solved on the
**composited box** rather than on the painting — two paintings at equal mean
brightness covering different fractions of a fixed box still throw different
amounts of light at the room, and light on a bystander's retina is what Article I
is about.

Measured result:

```
slot                       raw    drift   cast   cover    gain   final    drift
card_face_mafia          35.10  -38.93%   4.59   76.4%  1.6421   57.46  -0.012%
card_face_doctor         65.04   13.18%   4.65   89.3%  0.8836   57.47   0.000%
card_face_detective      69.25   20.49%   5.86   89.3%  0.8299   57.47   0.000%
card_face_citizen        60.49    5.25%   5.02   89.3%  0.9501   57.47   0.000%

worst drift 0.0090%   budget 2%
```

The raw spread is 1.70:1 — the detective card would throw 70% more light on its
holder's face than the mafia card. That is the leak the gain exists to close.

Colour cast is **measured and reported, never corrected**: all four are warm by
4–6 levels, in the same direction, and correcting that would be changing the
artwork. What is asserted is that the faces *agree* on hue to within 3 levels,
which is the quantity that could actually distinguish one card from another.

### What goes outside the card

The role name and its one-line description are Flutter text *below* the card —
bone white, display face, centred, identical position and size for all four
roles. Only the string differs, and it comes from the ARB. The paintings already
carry the role letter and the corner icon; duplicating them on top would be
drawing on the art.

Both slots are fixed-height and single-line, so a wordier role cannot make its
card taller.

---

## Motion

| Token | Value | Used for |
|---|---|---|
| `instant` | 100ms | press feedback |
| `quick` | 200ms | state changes within a screen |
| `standard` | 300ms | route and phase dips |
| `dramatic` | 600ms | the card flip |
| `phaseHold` | 3s | how long an announcement holds |
| `stagger` | 40ms | per-item delay in post-game lists |

**Reduce Motion degrades to the finished state, never the initial one, and never
changes how long anything takes.** An accessibility setting that made the game
faster would be a signal in its own right.

### The reveal

Three steps, identical for every player:

1. **Identity gate.** Name, and a pad held for `identityHoldSeconds` (host
   setting, default **5**, options 3/5/10/20). This is the turn-length equaliser
   as much as it is an identity check. It was 20; on a real table that is far
   too long, because it multiplies by the size of the table and a hold that
   outlasts the holder's patience gets released early and retried.
2. **Swipe to flip.** The card follows the finger and completes on distance or
   velocity; the flip is one `dramatic`, one curve, one rotation, for everyone.
3. **Auto-conceal after 5s**, with a progress line, and unlimited re-reveals
   within the turn. Then "سلّم الموبايل".

The words under the card are gated on the flip's **own geometry**, not on the
phase — they cross the halfway point on the same frame the painting does. Driving
them off the phase put the role name on screen in legible type while the card was
still edge-on to the table, which is exactly the kind of leak the five-stage
golden exists to find. It found it.

---

## Atmosphere

**Phase announcements.** Six lines of Egyptian Arabic, faded up over the dark
ground, held for `phaseHold`, faded away. Same duration every time, including
under Reduce Motion, because a table learns a rhythm faster than it notices it
has.

**Falling icons.** The four corner icons drift downward at 4–8% opacity, varied
size and speed, seamless loop. Home screen and phase announcements only. Never in
the player grid, never beside a name — they are the icons painted on the card
corners, so one of them near a person reads as that person's role no matter how
randomly it was picked. `ambient_icon_placement_test.dart` enforces the placement
rather than trusting it.

**Score.** One 32-second seamless loop, started at launch and never varied — no
swell, no duck, no stop at a phase boundary, because a bed that reacts to the
game is a channel that reports on it. A bare fifth with no third, a 50 bpm pulse
below resting rate, and filtered air. Normalised to −20 dBFS and played at 0.55,
which lands around −25 dBFS: roughly 22 dB under a cue, so a room can talk over
it. `audio_backend_isolation_test.dart` asserts it starts once, survives a
handoff that silences every cue, and has no phase-shaped API to misuse.

**Sound.** Nine cues behind a single `AudioBackend` seam. Every cue may carry an
ambient bed and, independently, a recorded narrator line; a transition with
neither still works, because the words are on screen. Nothing plays while the
phone is in a hand — the director throws rather than returning quietly, because a
swallowed call would be discovered by a player rather than by a test.

---

## Anti-references

- **Material defaults.** Blue ripples, elevation shadows, stock switches. This is
  printed matter, not a Google product.
- **Neon-on-black mafia apps.** The whole category renders itself in purple
  gradients and glow. This one is charcoal, graphite and bone.
- **Anything that celebrates.** No confetti, no fanfare on elimination, one win
  sting for both outcomes.
- **Skeuomorphic felt-and-wood board-game chrome.** The cards are painted; the
  app around them is quiet enough to disappear.
