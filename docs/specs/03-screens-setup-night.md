# Mafia Master — Screen Specs (1): Setup, Role Distribution, Night Phase

> Each screen documents: goal, text wireframe, elements, behavior, and anti-leakage notes.
> The app is RTL-first; wireframes below show structure, not direction.

---

## S-01: Home

**Goal:** one clear entry point — start a match.

```
┌──────────────────────────────┐
│                              │
│        [faint logo]          │
│        MAFIA MASTER          │
│    "The smart Game Master"   │
│                              │
│  ┌────────────────────────┐  │
│  │       New Match        │  │  ← PrimaryButton
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │      Match History     │  │  ← SecondaryButton
│  └────────────────────────┘  │
│                              │
│   How to play?  •  Settings  │  ← TextButtons
└──────────────────────────────┘
```

- `surface-base` background with a faint top vignette.
- "Match History" opens locally stored analytics.
- No login, no long splash (≤ 1.5s).

---

## S-02: Add Players

**Goal:** enter 5–20 names as fast as possible.

```
┌──────────────────────────────┐
│ ←  Players             (7)   │
│ ┌──────────────────────────┐ │
│ │ + Type a name, press ⏎   │ │  ← quick-add field pinned on top
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ ◯ Ahmed             ✕   │ │
│ │ ◯ Youssef           ✕   │ │
│ │ ◯ Sara              ✕   │ │
│ │ ...                      │ │  ← drag to reorder (= seating order)
│ └──────────────────────────┘ │
│ ⓘ Order the names by seating │
│ ┌────────────────────────┐   │
│ │         Next           │   │  ← disabled until 5 players
│ └────────────────────────┘   │
└──────────────────────────────┘
```

- Field stays on top with persistent focus — rapid sequential entry.
- Name suggestions from previous matches (chips under the field).
- Duplicate names blocked (auto-suffix: "Ahmed 2").
- **List order = phone passing order** — hence the ⓘ hint.

---

## S-03: Role Configuration

**Goal:** balanced distribution in seconds, with freedom to adjust.

```
┌──────────────────────────────┐
│ ←  Roles — 7 players         │
│                              │
│  Suggested distribution ⚡    │
│ ┌──────────────────────────┐ │
│ │ 🎭 Mafia        [−] 2 [+]│ │
│ │ ⚕ Doctor       [−] 1 [+]│ │
│ │ 🔍 Detective   [−] 1 [+]│ │
│ │ 👤 Citizens         3    │ │  ← auto-computed
│ └──────────────────────────┘ │
│                              │
│ ✓ Balanced distribution      │  ← balance status bar
│                              │
│ ┌────────────────────────┐   │
│ │    Match Settings →     │   │
│ └────────────────────────┘   │
└──────────────────────────────┘
```

- Auto-suggestion: Mafia ≈ player count / 4 (floor), Doctor 1, Detective 1.
- Status bar changes text only: "Balanced" / "Too many Mafia — game ends fast" / "Invalid".
- Role icons are acceptable here — this screen is public (pre-distribution, everyone sees it).

---

## S-04: Match Settings

```
┌──────────────────────────────┐
│ ←  Match Settings            │
│                              │
│  Speech time                 │
│  ( 45s ) ( 60s ) ( 90s )     │  ← Segmented
│                              │
│  Discussion mode             │
│  ( Structured — recommended )│
│  ( Free )                    │
│                              │
│  Vote tie rule               │
│  ( Revote ) ( No elimination)│
│                              │
│  Voice narrator        [ON]  │  ← Switch
│                              │
│ ┌────────────────────────┐   │
│ │ Start Role Distribution │   │
│ └────────────────────────┘   │
└──────────────────────────────┘
```

- Every setting persists as the default for future matches.
- "Start" shows a quick summary (bottom sheet) then a final confirmation.

---

## S-05: Pass Screen — used in distribution, night, and voting

**Goal:** safe interstitial between two players. The single most important anti-leakage screen.

```
┌──────────────────────────────┐
│                              │
│                              │
│        [faint glyph]         │
│                              │
│       Pass the phone to      │
│          « Ahmed »           │
│                              │
│  ┌────────────────────────┐  │
│  │ I am Ahmed — hold to    │  │  ← 600ms long-press with progress ring
│  │        confirm          │  │
│  └────────────────────────┘  │
│                              │
│        Not Ahmed?            │  ← TextButton, reroutes without revealing
└──────────────────────────────┘
```

- Uniform brightness, no sound, no haptic on open.
- Long-press blocks accidental opening in front of the table.
- "Not Ahmed?" opens the name list for correction (wrong-pass case) — zero game content exposed.

---

## S-06: Role Reveal

```
    (back face)                   (after flip)
┌──────────────────┐         ┌──────────────────┐
│                  │         │                  │
│   ┌──────────┐   │         │   ┌──────────┐   │
│   │          │   │         │   │  🎭      │   │
│   │  [logo]  │   │  ═══>   │   │  MAFIA   │   │
│   │          │   │ long-   │   │          │   │
│   └──────────┘   │ press   │   └──────────┘   │
│                  │         │ "Pick a target   │
│  Hold to flip    │         │ each night with  │
│   the card       │         │ your partners"   │
│                  │         │  ┌────────────┐  │
│                  │         │  │  Got it    │  │ ← appears after fixed 2s
└──────────────────┘         └──────────────────┘
```

- 3D flip using `motion-dramatic` (600ms) — identical motion for all roles.
- Role description is one line only. Multiple Mafia: teammates' **names are shown directly on the card** (design decision: simplest, closest to the physical game). Screen duration is player-controlled for ALL roles, so read-length is not a signal.
- "Got it" requires a long-press — prevents accidental dismissal.
- After dismissal: instant blackout, then the pass screen for the next player.

---

## S-07: Pre-Night Lobby

```
┌──────────────────────────────┐
│                              │
│   Everyone knows their role ✓│
│                              │
│  Place the phone in the      │
│      center of the table     │
│                              │
│  ┌────────────────────────┐  │
│  │     Start Night 1      │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- On tap: gradual dim + narrator "Night falls...".

---

## S-08: Night Action — THE most important screen

**Goal:** all roles render the exact same structure. Only the header text and internal logic differ.

### Uniform structure

```
┌──────────────────────────────┐
│  Night 1                     │  ← PhaseBanner (uniform)
│                              │
│  {role question}             │  ← one line, same position & size
│                              │
│ ┌──────────┐  ┌──────────┐  │
│ │ ◯ Youssef│  │ ◯ Sara   │  │
│ ├──────────┤  ├──────────┤  │  ← 2×N PlayerTile grid
│ │ ◯ Omar   │  │ ◯ Laila  │  │     identical elements for all
│ ├──────────┤  ├──────────┤  │
│ │ ◯ Khaled │  │ ◯ Nour   │  │
│ └──────────┘  └──────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │  Confirm — hold to      │  │  ← disabled until selection
│  │       confirm           │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

### Role question (visible only to the role holder)

| Role | Question |
|---|---|
| Mafia | "Who is tonight's target?" |
| Doctor | "Who do you protect tonight?" |
| Detective | "Whose identity do you investigate?" |
| Citizen | "Who do you suspect is Mafia?" |

### Role-specific behavior (inside the same structure)

**Mafia (multiple):**
- On a tile already picked by a previous Mafia: small gold dot + subtle count ("2") next to the name.
- The indicator occupies a reserved slot that exists in the tile for ALL roles (empty for others) — zero dimensional difference.

**Detective:**
- After confirm, the result replaces the grid area in-place: "Youssef: **Mafia**" with a "Hide — hold" button.
- The result is never stored and never retrievable. After hiding → blackout screen directly.

**Citizen:**
- After selection, the `SuspicionNote` sheet slides up: "Reason? (optional)" + quick chips + 40-char field.
- "Skip" and "Confirm" identical in size and position.

**Doctor:**
- Optional rule in settings: "No protecting the same player two nights in a row" — the tile renders disabled with a hint.

### Uniform timing rule (critical)

- Minimum screen dwell before "Confirm" activates: **8 seconds** for every role (kills the "fast Citizen" tell).
- No maximum — everyone has the same freedom.
- Step parity: Detective has two steps (pick + result); Citizen has two (pick + note); Mafia has two (pick + vote state); Doctor has two (pick + reminder screen: "Remember: never reveal who you protected") — **every role = exactly two steps.**

---

## S-09: Post-Action Confirmation

```
┌──────────────────────────────┐
│                              │
│            ✓                 │
│    Your decision is locked   │
│                              │
│   (auto-advances after 1s)   │
└──────────────────────────────┘
```

- Literally the same screen for every role — then the pass screen for the next player.

---

## S-10: Morning Announcement

```
┌──────────────────────────────┐
│                              │
│      Morning has come ☀      │
│                              │
│   ┌──────────────────────┐   │
│   │   Last night...      │   │
│   │                      │   │
│   │  We lost « Khaled »  │   │  ← or: "Everyone survived the night"
│   │                      │   │
│   └──────────────────────┘   │
│                              │
│  ┌────────────────────────┐  │
│  │   Start Discussion     │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- **The night victim's role is NOT revealed** (design decision: roles are revealed only on day-vote elimination — configurable in settings).
- If the Doctor saved the target: "Someone was attacked last night... but survived" — no name (protects the Doctor's pattern).
- Narrator voice + single drum hit on the name reveal.
