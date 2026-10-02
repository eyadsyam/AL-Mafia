# Mafia Master — Online UI Redesign

> **This document replaces `12-online-experience.md` Part 2 (the elliptical table) entirely.** Everything else in `12` — Witness mode, connection states, sound — still stands.
>
> The elliptical table was wrong for a portrait phone. This is the corrected system.

---

# PART 0 — WHY THE CURRENT SCREEN FAILS

Measured against the actual build:

| # | Failure | Cause |
|---|---|---|
| 1 | ~60% of the screen is empty | An ellipse on a 9:19.5 viewport puts seats at four corners and leaves a dead centre. Noir is **dense shadow with selective light**, never emptiness |
| 2 | The selection line reads as a scratch | A 1px hairline crossing the entire diagonal is a glitch, not a connection |
| 3 | The timer is a naked "0" | No ring, no label, no frame. Enormous and meaningless |
| 4 | Bottom text is stacked, tiny, overlapping | Two strings placed independently with no layout contract between them |
| 5 | Card art is illegible | Ornate engraving rendered at ~60px is noise. **The card back does not work at seat size** |
| 6 | No hierarchy | Phase label, timer, seats, question and action all carry the same visual weight |

**The root error is mine:** I specified a top-down round table, which works on a wide surface and collapses on a tall one.

---

# PART 1 — THE COUNCIL LAYOUT

## 1.1 The principle

Not a table seen from above. **A council seen from your seat.**

The others sit across from you along a shallow arc. You are always at the bottom. The space between you and them is where the game speaks.

```
┌─────────────────────────────────┐
│ ▸ الليل ١              ⏱ 0:38  │  56dp   HEADER
├─────────────────────────────────┤
│      ◉    ◉    ◉    ◉          │
│   ◉                     ◉      │  36%    THE COUNCIL
│                                 │         (shallow arc, dense)
├─────────────────────────────────┤
│                                 │
│      مين عايز تحميه الليلة؟      │  34%    THE VOICE
│                                 │         (phase content)
│         [ selected: أمينة ]      │
├─────────────────────────────────┤
│  ╭───────────────────────────╮  │
│  │          تأكيد            │  │  24%    YOUR HAND
│  ╰───────────────────────────╯  │         (thumb zone)
│           ◈ إياد                │
└─────────────────────────────────┘
```

Four bands. Fixed proportions. **Every online screen uses these four bands** — only the content of each changes. That is what makes it feel like one place instead of a slideshow.

## 1.2 Band specifications

### Band 1 — Header (56dp, fixed)

```
▸ الليل ١                    ⏱ 0:38
────────────────────────────────────  ← 1px hairline, border-subtle
```

- Phase name: `caption` size, `text-secondary`, letterspacing 0 (Arabic)
- Timer: `title` size, tabular figures, `text-primary`. **Under 10s it does not turn red** — the digits gain weight, nothing more
- The hairline is the only divider on the screen. Nothing else is separated by a line

### Band 2 — The Council (36% of height)

Seats arranged on a **shallow downward arc** — a table edge curving away, not a circle.

**Arc formula:**
```dart
// n seats across the band width, arc rises toward the centre
double seatY(int i, int n, double bandH) {
  final t = n == 1 ? 0.5 : i / (n - 1);          // 0..1
  final curve = -math.sin(t * math.pi) * 0.18;   // shallow — 18% of band
  return bandH * (0.5 + curve);
}
```

**Seat sizing and rows:**

| Players | Rows | Seat Ø | Gap |
|---|---|---|---|
| 5–6 | 1 | 72dp | 16dp |
| 7–8 | 2 | 64dp | 14dp |
| 9–11 | 2 | 56dp | 12dp |
| 12–15 | 3 | 48dp | 10dp |

Two rows means the back row sits **higher and 12% smaller** — perspective, not a grid.

### 1.3 The seat — this is the biggest single change

**Stop rendering the card back at seat size.** The ornate engraving is beautiful at 300dp and mud at 60dp.

A seat is:

```
    ╭─────────╮
    │  ╭───╮  │   ← ornamental ring (asset, 1 file, tinted per state)
    │  │ إ │  │   ← initial, display weight, cream
    │  ╰───╯  │
    ╰─────────╯
      إياد        ← name, caption, text-secondary
```

- **Ring:** one asset, a thin engraved circle in the app's ornamental language. Tinted by state; never redrawn per state
- **Centre:** the player's first letter in `Cairo Black`, cream. Legible at every size
- **Name:** below, `caption`, truncated with ellipsis past 8 characters

**Seat states:**

| State | Ring | Centre | Extra |
|---|---|---|---|
| Idle | `border-subtle` | cream 80% | — |
| **Selected** | `accent-gold` 2dp + outer glow | cream 100% | Scale 1.08, 200ms `easeOut` |
| Speaking | gold, breathing 1.4s | cream 100% | — |
| Confronted | full opacity while others drop to 25% | — | Spotlight |
| Disconnected | desaturated 40%, slow pulse | 40% | — |
| Dead | ring cracked (second asset), 30% | 30% | Tilted 6° |
| You | thin cream hairline **always** | — | Labelled «انت» under the name |

**The card art returns at full size** for exactly three moments: role reveal, elimination reveal, and the final flip. That is when it is 280dp and gorgeous.

### 1.4 Band 3 — The Voice (34%)

Where the game speaks. One idea at a time, centred, generous.

| Phase | Content |
|---|---|
| Night | Role question, `headline`. Below it, the current selection as a small confirmation chip |
| Morning | Victim line, then a 1.2s beat, then the trace |
| Confrontation | The named player's observation, `title`, and the response timer ring |
| Discussion | Who holds the floor, `display`, and who has raised a hand at `caption` |
| Vote | Live tally bars |
| Result | Winner, `display` |

**Rules:**
- Maximum **two** text elements. If a third is needed, something else is wrong
- Vertically centred within the band — never top-aligned, never crammed to the bottom
- Minimum 24dp horizontal padding
- **Never** two strings stacked without a defined gap. Every gap is a spacing token

**Resolved, 2026-09-07 — the discussion line is a floor, not a queue.**

An earlier draft of this table asked for *"the next two in queue"*. There is no
queue. `micPolicyFor` gives the floor to whoever asks for it and is allowed to
have it; the server records one `active_speaker` and nothing behind it. Printing
«بعدها: عمر · ليلى» would have been the app inventing a fact, which non-negotiable
4 forbids outright, and it would have been a *load-bearing* invention: a player
who believes they are third will wait, and the room will wait with them.

Two things are real, and both are shown:

| Real thing | Where it comes from | How it renders |
|---|---|---|
| Who is speaking now | `room_state.active_speaker` | Band 3 headline, `display`, in guillemets |
| Who has asked to speak | `room_players.hand_raised_at` | Band 3 support, `caption`, names only |

**No position numbers, and no request order.** Raised hands render sorted by
seat, which is the one order that carries no information about who asked first —
because who asked first does not decide who speaks next. A refused claim leaves
a raised hand behind so the room can see the pressure building; the next claim
that lands still wins on its own merits.

The opening round is the exception that proves it: there the order *is* a fact —
it comes off `openingAccusations` — so that phase does print who is up next.

### 1.5 Band 4 — Your Hand (24%)

The thumb zone. Always contains the primary action, always in the same place.

```
  ╭───────────────────────────╮
  │          تأكيد            │   56dp, full width minus 20dp margins
  ╰───────────────────────────╯
            ◈ إياد               ← your own seat, small, always visible
```

- One primary button. Disabled state is 35% opacity, never hidden
- Your own seat sits below it so you always know who you are
- During discussion, this band holds the whisper button and the raise-hand control instead

## 1.6 Selection — replacing the diagonal scratch

**Delete the line across the screen.** Selection is communicated three ways at once, all local:

1. The chosen seat scales to 1.08 with a gold ring and outer glow
2. **Every other seat drops to 45% opacity** — the choice is made by subtraction, which is far more legible than a connector
3. A confirmation chip appears in Band 3: «اخترت: **أمينة**»

Changing selection: the old seat returns to 100% over 150ms while the new one lifts. No lines, ever.

---

# PART 2 — SCREEN INVENTORY

Every online screen, using the four bands.

## S-O1 — Mode select

```
┌─────────────────────────────────┐
│                                 │
│         سيد المافيا             │
│                                 │
│   ╭───────────────────────────╮ │
│   │  🌙  أوفلاين               │ │
│   │  تليفون واحد، الكل مع بعض  │ │
│   ╰───────────────────────────╯ │
│   ╭───────────────────────────╮ │
│   │  ◈  أونلاين                │ │
│   │  كل واحد على تليفونه       │ │
│   ╰───────────────────────────╯ │
│                                 │
│      المباريات السابقة          │
└─────────────────────────────────┘
```

Two cards, each with a one-line description. **Never two bare buttons.**

## S-O2 — Create / Join

One question at a time, as already built. Keep it.

## S-O3 — Lobby

```
┌─────────────────────────────────┐
│ ▸ الغرفة                   ✕   │
├─────────────────────────────────┤
│      ◉  ◉  ◉  ◉  ◇  ◇         │  seats fill as players join
│         ◉  ◉                    │  ◇ = empty, dashed ring
├─────────────────────────────────┤
│         K 7 M 2 Q P             │  display, LTR-pinned, wide tracking
│      [ نسخ ]    [ مشاركة ]      │
│                                 │
│         ٦ / ١٠ لاعبين            │
│    🎙 الصوت متصل                │
├─────────────────────────────────┤
│  ╭───────────────────────────╮  │
│  │       ابدأ المباراة        │  │
│  ╰───────────────────────────╯  │
└─────────────────────────────────┘
```

Join animation: the dashed ring **draws itself solid** over 500ms, then the initial fades in. Soft chime.

## S-O4 — Role reveal

Full-screen takeover, the one place that breaks the band system.

```
Beat 1 (0–0.5s)   Council fades to 10%.
Beat 2 (0.5–1.2s) Card rises from the bottom, scaling to 280dp.
Beat 3            Face-down. «اضغط مطوّلًا».
Beat 4 (hold)     Ring fills around the card edge, 600ms.
Beat 5 (flip)     3D Y-flip, 600ms, specular sweep at 50%.
Beat 6            Role art at full size. Name. One line.
                  «فهمت» after a fixed 2.0s, identical for every role.
Beat 7            Card shrinks back down, council returns.
```

This is where the ornate art earns its place.

## S-O5 — Night

The reference layout in §1.1. Selection per §1.6.

**After confirming:**

Band 3 becomes «تم. مستنيين الباقي…» — **no count, no progress bar, no names.** A count of who has finished correlates with role complexity.

Band 2 stays live so you can watch the council sit in the dark. Nothing about the seats changes.

## S-O6 — Morning

```
Beat 1  Light sweeps down from the header over 1.4s.
Beat 2  Victim's seat ring CRACKS (asset swap + 400ms shake), tilts 6°, dims.
Beat 3  0.8s of silence.
Beat 4  Band 3: «فقدنا خالد». 
Beat 5  1.2s beat. Then the trace fades up beneath it.
```

## S-O7 — Confrontation

```
┌─────────────────────────────────┐
│ ▸ النهار ٣               ⏱ 0:45│
├─────────────────────────────────┤
│      ·    ·    ◉    ·    ·     │  everyone 25%, أحمد full + spotlight
│                أحمد             │
├─────────────────────────────────┤
│                                 │
│   قلت إنك شاكك في عمر،           │
│   وصوّت لسارة.                   │
│                                 │
│          اشرح.                  │
├─────────────────────────────────┤
│  ╭───────────────────────────╮  │
│  │         خلّصت             │  │  ← only أحمد sees this enabled
│  ╰───────────────────────────╯  │
└─────────────────────────────────┘
```

Spotlight is a radial mask animating in over 700ms.

## S-O8 — Discussion

```
├─────────────────────────────────┤
│   ◉  ◉  ◉  ◉  ◉  ◉            │  speaker breathing gold
├─────────────────────────────────┤
│         بيتكلم دلوقتي            │
│           « سارة »              │  display
│                                 │
│      رافعين إيدهم: عمر · ليلى     │  caption, seat order, no numbers
├─────────────────────────────────┤
│   ╭────────╮   ╭────────────╮   │
│   │ ✋ دوري │   │  ✉ همسة    │   │  two actions in this phase only
│   ╰────────╯   ╰────────────╯   │
└─────────────────────────────────┘
```

## S-O9 — Whisper compose

Bottom sheet rising over Band 4, **council stays visible**.

```
├─────────────────────────────────┤
│  ✉ همسة — واحدة النهارده         │
│                                 │
│  لمين؟                          │
│   ◉  ◉  ◉  ◉  ◉                │  other living players only
│                                 │
│  ╭─────────────────────────────╮│
│  │ اكتب…                 ٤٢/١٢٠││
│  ╰─────────────────────────────╯│
│      [ إلغاء ]     [ ابعت ]     │
└─────────────────────────────────┘
```

**Send animation:** the sheet closes, a small light rises from your seat and **arcs to theirs** over 700ms. Everyone sees the light; nobody sees the words.

## S-O10 — Whisper received

Slides down from under the header, **non-blocking**, council and timer still visible.

```
┌─────────────────────────────────┐
│  ✉  همسة من « أحمد »            │
│  "متصوتش لسارة، هي معايا"        │
│                      [ تمام ]   │
└─────────────────────────────────┘
```

400ms slide-in, 12s auto-dismiss, two-note motif. Never a system toast.

## S-O11 — Vote

Band 2: seats. Tap to vote. Selected seat lifts; others drop to 45%.
Band 3: live tally, horizontal bars, staggered fill 80ms apart.
Band 4: «أكّد صوتك» — changeable until the timer ends.

## S-O12 — Elimination reveal

```
Beat 1  Tally bars pulse once, converge on the eliminated seat.
Beat 2  That seat's card RISES to 280dp, centre screen.
Beat 3  0.8s hold.
Beat 4  Flip. Role revealed.
Beat 5  Card shrinks back, ring cracks, seat dims.
```

## S-O13 — Result

```
Beat 1  Council freezes. 1.0s.
Beat 2  ALL SEAT RINGS flip SIMULTANEOUSLY — 600ms, no stagger. Each ring
        turns edge-on and comes back carrying its occupant's role glyph.
        Simultaneity is the drama, and the seat is what carries it.
Beat 3  Winners' rings warm to cream; losers dim to 30%.
Beat 4  Band 3: «فاز المواطنون», display.
Beat 5  1.2s, then Band 4 holds «شوف الأدوار» — a roster that shows the
        full card art one player at a time, at 280dp.
```

**Resolved, 2026-09-07 — simultaneity moved from the card to the seat.**

The beat this replaces asked for all fifteen cards to rise and flip at once. It
could not be built, and not for want of trying: §1.3 of this document retired
the card at seat size precisely because *"the ornate engraving is beautiful at
300dp and mud at 60dp"*, and §5 turned that into a hard floor — **card art never
renders below 200dp**. Fifteen cards at 200dp need 3000dp of width. The screen
has 412. Any layout that satisfied beat 2 as written broke the floor, and any
layout that kept the floor could not show more than one card.

So the drama and the art were separated, because they were never the same
requirement:

- **The drama is simultaneity**, and simultaneity belongs to the seats. Fifteen
  rings turning over on the same frame is the beat the room feels, and rings
  already exist at every player count without a size floor to violate.
- **The art is legibility**, and legibility belongs to the roster. Full card art
  at 280dp, one player at a time, behind a control the player opens when they
  want it — which is also when they will actually look at it.

A **role glyph** — not the card — appears inside each ring at the halfway point
of the flip. It is a mark, not a painting: it survives at 44dp, which is the
smallest a ring gets at fifteen players.

This is the only moment in the match when a ring carries a role. It exists after
`GamePhase.result`, when there is nothing left to leak.

## S-O14 — Witness mode

Entire UI shifts to **full monochrome**. Everything else keeps working. Band 4 holds the ghost-chat and prediction controls. Per `12` §4.

---

# PART 3 — MOTION SYSTEM

| Token | ms | Curve | Use |
|---|---|---|---|
| `m-tap` | 120 | easeOut | Seat select, button press |
| `m-shift` | 200 | easeOut | Opacity changes across seats |
| `m-band` | 350 | easeInOut | Band 3 content swap |
| `m-phase` | 700 | easeInOut | Whole-screen phase morph, spotlight |
| `m-card` | 600 | easeInOut | Card flip |
| `m-rise` | 500 | easeOutBack | Card rising to 280dp |
| `m-crack` | 400 | easeIn | Ring crack + shake |
| `m-sweep` | 1400 | easeOut | Morning light |
| `m-travel` | 700 | easeInOut | Whisper light arc |
| `m-breathe` | 1400 | sine loop | Speaking glow |

**Performance:**
- Band 2 is **one `CustomPainter`** for rings and glows. Seats do not each own a widget with its own animation controller
- Never more than 3 seats animating at once, except the result flip (one batched transform)
- **Zero `BackdropFilter`** in any per-frame path
- 60fps with 15 seats, verified in profile mode

**Reduce Motion:** every animation cross-fades instead. Dramatic holds remain — they are pacing, not motion.

---

# PART 4 — ASSETS REQUIRED

Generation prompts are in `16-ai-asset-prompts.md`.

| # | Asset | Size | Use |
|---|---|---|---|
| A1 | Seat ring — idle | 512² PNG, transparent | Every seat, tinted at runtime |
| A2 | Seat ring — cracked | 512² PNG | Dead seats |
| A3 | Seat ring — empty/dashed | 512² PNG | Lobby empty slots |
| A4 | Panel corner ornament | 256² PNG ×1 (mirrored) | Band dividers, sheets |
| A5 | Timer ring ornament | 512² PNG | Confrontation timer |
| A6 | Night backdrop | 1080×1920 WebP | Behind bands, 12% opacity |
| A7 | Dawn backdrop | 1080×1920 WebP | Morning |
| A8 | Day backdrop | 1080×1920 WebP | Discussion, vote |
| A9 | Verdict backdrop | 1080×1920 WebP | Result |
| A10 | Whisper seal | 128² PNG | Whisper button + notification |
| A11 | Light mote sprite | 64² PNG | Whisper travel animation |
| A12 | Victory emblem — town | 512² PNG | Result |
| A13 | Victory emblem — mafia | 512² PNG | Result |
| A14 | Fog overlay | 1080×1920 WebP, tileable | Connection states |
| A15 | Spotlight cone | 1024² PNG, radial alpha | Confrontation |

**Total budget: under 2 MB.** All backdrops at quality 80 WebP, 1080px longest edge.

---

# PART 5 — ACCEPTANCE

**Layout**
- [ ] Four bands on every online screen, same proportions
- [ ] No screen is more than 25% empty at any player count
- [ ] All seats visible without scrolling at 5, 8, 11, and 15 players
- [ ] No seat rectangle overlaps another at any size — every pair tested
- [ ] Zero connector lines across the screen
- [ ] Card art never renders below 200dp

**Hierarchy**
- [ ] Exactly one primary action per screen, always in Band 4
- [ ] Band 3 never holds more than two text elements
- [ ] Timer never turns red; weight change only
- [ ] Every gap is a spacing token — no magic numbers

**Motion**
- [ ] 60fps with 15 seats in profile mode
- [ ] Band 2 is a single CustomPainter
- [ ] No BackdropFilter per frame
- [ ] Reduce Motion verified on every screen

**Leakage**
- [ ] Night: all seats render identically, no status of any kind
- [ ] Waiting state shows no count and no names
- [ ] Golden tests: all four roles produce identical night layouts
