# PRODUCT.md

Derived from `.specify/memory/constitution.md` and `specs/001-mafia-master/spec.md`,
which remain authoritative. If this file and the constitution disagree, the
constitution wins.

register: product

## Product purpose

Mafia Master is the moderator for a face-to-face game of Mafia. One phone is passed
around a table of 6–15 people. It deals roles, runs the night in secret, times the
day, counts the votes, and declares a winner — the jobs a human moderator does badly
and cannot do without also knowing everything.

It is not a social app. There is no account, no network, no telemetry. The phone is a
prop on a table.

## Users

Egyptian Arabic speakers playing in a living room, a café, or a dorm. RTL-first;
English exists as a fallback, not a default. Group sizes 6–15. Most have played
Mafia before and are impatient with setup.

The **critical** user is the one who is *not* holding the phone. They are watching
the holder's face, the holder's hands, and the light coming off the screen. Every
design decision in this app is really a decision about what that person can see.

## The one hard constraint

**Zero information leakage.** The device must not expose any signal — visual,
temporal, acoustic, haptic, or structural — that distinguishes one player's role from
another's during play. Constitution Article I, marked NON-NEGOTIABLE.

In practice this bans, on any surface reachable while the phone is in a hand:

- role-conditional colour, brightness, or artwork brightness (±2% luminance budget)
- role-conditional layout, element size, or presence of a slot
- role-conditional timing, tap count, or transition duration
- any sound or haptic at all
- back navigation, and any resume that lands on secret content

"Leakage is not a bug severity — it is a product failure."

## Tone

The game is a fairy tale about a village that goes to sleep and wakes up with someone
missing. The app is the storyteller: a deck of hand-painted cards, an oil lamp, a
narrator with a low voice. It is warm about the *story* and cold about the *screen* —
the copy can be theatrical, the pixels cannot.

Egyptian Arabic, spoken register, not Modern Standard. "الضلمة نزلت على البلد" not
"حل الظلام على القرية".

## Anti-references

- **Material Design defaults.** Blue ripples, elevation shadows, stock switches. The
  app is printed matter, not a Google product.
- **Neon-on-black "hacker" mafia apps.** The whole category renders itself in purple
  gradients and glow. This one is charcoal, graphite, and bone.
- **Anything that celebrates.** No confetti, no fanfare on elimination. Someone just
  lost; the table should feel it.
- **Skeuomorphic felt-and-wood board-game chrome.** The cards are painted; the app
  around them is quiet enough to disappear.

## Strategic principles

1. **The artwork is the product.** Four painted role cards, shown whole, uncropped,
   untinted, undrawn-on. Everything else on screen exists to not compete with them.
2. **Symmetry is the mechanism.** Every role renders from one widget tree. Sameness is
   not a style choice, it is how Article I is made verifiable.
3. **Machine-verify the invariants.** `test/golden/leakage/` is ship-blocking. A
   guarantee that is not measured will rot.
4. **The dark is not decoration.** Near-black is the ground because a bright phone at
   a dark table lights its holder's face. Contrast is bought with typography, not with
   luminance.
5. **Nothing is stored that could be looked up later.** Secret results are shown once.
