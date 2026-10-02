# Mafia Master — Screen Specs (2): Discussion, Voting, Result, Post-Game Analytics

---

## S-11: Discussion Phase (phone on the table)

**Goal:** the phone becomes a "table referee" — timer, bell, and turn order. Nobody holds it.

### Round 1 — Open Statements

```
┌──────────────────────────────┐
│  Day 1 — Round 1: Statements │
│                              │
│         ┌────────┐           │
│         │   45   │           │  ← large circular PhaseTimer
│         └────────┘           │
│                              │
│      Now speaking:           │
│        « Sara »              │  ← display size — readable from afar
│                              │
│      Next: Omar              │
│                              │
│  [⏸ Pause]        [⏭ Next]  │  ← large tap targets
└──────────────────────────────┘
```

- Huge type readable from 1.5m (phone in the table center).
- Neutral chime on every turn change + optional narrator announcing the speaker's name.
- "Next" available to any player (end own turn early) — "Pause" opens the management menu (remove player / end match) behind a long-press.
- Dead players never appear in the speaking order.

### Round 2 — Questions

```
┌──────────────────────────────┐
│  Round 2: Questions          │
│                              │
│  « Youssef »'s turn to ask   │
│  ┌──────────────────────────┐│
│  │ Ask whom?                ││
│  │ (Sara)(Omar)(Laila)(Nour)││  ← target selection — chips
│  └──────────────────────────┘│
│         ┌────────┐           │
│         │   30   │           │  ← answer timer starts after pick
│         └────────┘           │
└──────────────────────────────┘
```

- Exactly one question per player — the app blocks a second.
- The "who asks whom" choice is logged into analytics data (who targeted whom with questions — a valuable social signal).

### Round 3 — Defense

- The app suggests the top accused (optionally the most-questioned in Round 2, or a quick manual pick from the tiles).
- 60 seconds per defender using the Round 1 layout.

---

## S-12: Voting

**Goal:** secret ballot via pass-the-phone — same pattern as night.

```
┌──────────────────────────────┐
│  Voting — Day 1              │
│                              │
│  Who do you eliminate?       │
│                              │
│ ┌──────────┐  ┌──────────┐  │
│ │ ◯ Youssef│  │ ◯ Sara   │  │
│ ├──────────┤  ├──────────┤  │
│ │ ◯ Omar   │  │ ◯ Laila  │  │
│ └──────────┘  └──────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │  Confirm — hold         │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- Passed in seating order (living players only) via the same `PassScreen`.
- A player cannot vote for themselves (their own tile is absent).
- "Abstain" appears only if enabled in settings — rendered as a normal player-tile shape.
- **Design decision:** voting is secret by default (psychologically sharper, bolder votes). Public hand-raising remains a future option.

---

## S-13: Vote Result & Reveal

```
┌──────────────────────────────┐
│  Vote result                 │
│                              │
│  Youssef ████████░░  4 votes │  ← VoteBar
│  Sara    ████░░░░░░  2 votes │
│  Omar    ██░░░░░░░░  1 vote  │
│                              │
│  ┌──────────────────────┐    │
│  │ « Youssef » is       │    │
│  │    eliminated        │    │
│  │   [face-down card]   │    │  ← tap to reveal role — motion-dramatic
│  │  ...and was 🎭 MAFIA │    │
│  └──────────────────────┘    │
│                              │
│  ┌────────────────────────┐  │
│  │   Continue to Night    │  │  ← or "Show Result" if game over
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- Bars fill with staggered motion, then a dramatic pause before the name.
- **Who-voted-for-whom is NOT shown now** — stored and revealed only in post-game analytics (protects ballot secrecy during play).
- Role reveal via card flip + drum hit.

---

## S-14: Final Result Screen

```
┌──────────────────────────────┐
│                              │
│      CITIZENS WIN 🏆         │  ← or "THE MAFIA PREVAILS 🎭"
│                              │
│  ┌──────────────────────────┐│
│  │ Role reveal              ││
│  │ 🎭 Youssef — Mafia ✝ N1  ││
│  │ 🎭 Omar — Mafia    ✝ D2  ││  ← ✝ = when they left (Night/Day + #)
│  │ ⚕ Sara — Doctor         ││
│  │ 🔍 Laila — Detective     ││
│  │ 👤 Ahmed — Citizen       ││
│  └──────────────────────────┘│
│                              │
│  ┌────────────────────────┐  │
│  │   View Analytics 📊     │  │
│  └────────────────────────┘  │
│     Replay with same group   │
└──────────────────────────────┘
```

- The ONLY place visual celebration is allowed: rising gold glow (Citizens win) or deep crimson (Mafia win). No cartoon confetti.
- Short cinematic closing sting (≤ 5s).

---

## S-15: Post-Game Analytics (Post-Game Intelligence)

**Goal:** turn every meaningful tap into a story that makes players want another round.

### Four-tab structure

```
┌──────────────────────────────┐
│  Match Analytics             │
│ (Timeline)(Players)          │
│ (Suspicions)(Achievements)   │  ← Tabs
└──────────────────────────────┘
```

### Tab 1 — Timeline

```
│  Night 1                     │
│  🎭 Mafia targeted Khaled    │
│  ⚕ Doctor protected Sara    │
│  🔍 Detective checked Omar   │
│     → Mafia                  │
│  ☠ Khaled left the game     │
│  ─────────────              │
│  Day 1                       │
│  🗳 Youssef eliminated       │
│     (4 votes)                │
│     Voted by: Ahmed, Sara... │  ← revealed only now
```

### Tab 2 — Player Card

```
│  ◯ Ahmed — Citizen           │
│  Suspicion accuracy:         │
│    2 / 3  (66%) ★            │
│  ─────────────              │
│  Night 1 → suspected:        │
│    Youssef ✓                 │
│    Reason: "too nervous"     │
│  Night 2 → suspected: Sara ✗ │
│    Reason: "defending        │
│    Youssef"                  │
│  Night 3 → suspected: Omar ✓ │
│  ─────────────              │
│  Questions: asked Youssef ×2 │
│  Votes: correct 2 of 3       │
```

### Tab 3 — Suspicion Map

- Simple matrix: who suspected whom, how often, across nights — correct suspicions highlighted.
- "Most suspected player" and "Least suspected player" (often the successful Mafia!).

### Tab 4 — Achievements

| Achievement | Condition |
|---|---|
| 🎯 Hawk Eye | First to suspect the Mafia leader |
| 🧠 Most Accurate Citizen | Highest correct-suspicion rate |
| ⚕ Healing Hands | Doctor — most effective save (actually blocked a kill) |
| 🔍 Master Detective | Identified all Mafia before the end |
| 🎭 The Fox | Mafia who survived to the end with fewest suspicions |
| 🛡 The Survivor | Longest survival across multiple matches |

- Each `AchievementBadge` animates in with a staggered entrance.
- "Share summary" generates a summary image (future — outside MVP).

---

## S-16: Match History

```
┌──────────────────────────────┐
│ ←  Match History             │
│ ┌──────────────────────────┐ │
│ │ Fri, Jul 24 — 7 players  │ │
│ │ Citizens won • 3 nights  │ │
│ ├──────────────────────────┤ │
│ │ Thu, Jul 23 — 9 players  │ │
│ │ Mafia won • 4 nights     │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

- Each row opens the full match analytics (S-15).
- Swipe-to-delete with confirmation.

---

## S-17: System Dialogs

| Dialog | Content | Note |
|---|---|---|
| End match | "You will lose the current match progress" + danger button | The only use of `DangerButton` |
| Remove player | Living players list → confirm → treated as neutral elimination | Logged in the timeline |
| Resume match | On app open with an unfinished match: "Resume / End" | Restored from Isar |
| Wrong pass | "This screen is not yours" + return to pass screen | Exposes zero game content |
