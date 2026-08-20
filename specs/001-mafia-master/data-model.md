# Phase 1 Data Model: Mafia Master

Entities derive from the spec's Key Entities and the design docs. Two representations exist and
must not be confused:

- **Engine domain models** (pure Dart, in-memory, immutable value objects) — the source of truth
  during play.
- **Persistence records** (Isar collections in `lib/data/isar/`) — a serialization of the match
  for crash-safe resume and history.

A critical rule (Principle I / FR-028): **secret results are stored only as append-only event-log
entries consumed after match end.** There is no in-match read path that returns another player's
role or a Detective result.

---

## 1. Match

The aggregate root for one game session.

| Field | Type | Notes |
|---|---|---|
| id | Id | local key |
| createdAt | DateTime | for history sort |
| seed | int | seeds the resolver RNG (R-004); persisted for reproducibility |
| players | List<Player> | in seating order (index = seat) |
| settings | MatchSettings | speech time, discussion mode, tie rule, narration |
| phase | GamePhase | current FSM state (see §9) |
| dayNumber | int | 1-based; increments each cycle |
| currentActorSeat | int? | whose pass/turn is active (drives resume) |
| eventLog | List<TimelineEvent> | append-only; the only record of secret actions |
| outcome | MatchOutcome? | null until the match ends |

**Validation**: `5 ≤ players.length ≤ 20`; seating indices contiguous 0..n-1; `seed` set once.

**State transitions**: owned by the state machine (§9); `Match` is replaced immutably on each step.

---

## 2. Player

| Field | Type | Notes |
|---|---|---|
| seat | int | seating order, 0-based; = pass order |
| name | String | 1–24 chars; duplicates auto-suffixed ("Ahmed 2") |
| role | Role | secret; never exposed via any public view during play |
| status | PlayerStatus | `alive` \| `dead` |
| eliminatedOn | PhaseRef? | when/how they left (Night N / Day N / removed) |

**Validation**: unique display name; exactly one role assigned at distribution.

---

## 3. Role (enum + metadata)

`mafia | doctor | detective | citizen`

| Role | Alignment | Night action | Second step |
|---|---|---|---|
| mafia | mafia | pick elimination target (sees teammates' current votes) | vote-state view |
| doctor | town | protect a player (self allowed; **not same player 2 nights running**) | reminder screen |
| detective | town | investigate a player | one-time four-valued result, then vanishes |
| citizen | town | record a suspicion | optional ≤40-char reason note |

Win alignment: `mafia` vs `town`. A second detective investigating a detective reads `detective`.

---

## 4. MatchSettings

| Field | Type | Values / default |
|---|---|---|
| speechSeconds | int | 45 \| 60 (default) \| 90 |
| discussionMode | enum | `structured` (default) \| `free` |
| dayTieRule | enum | `revote` (default) \| `noElimination` |
| narrationEnabled | bool | default true |
| abstainAllowed | bool | default false |

Persisted separately as **defaults** for the next match (FR-005).

> Note: the Mafia **night**-tie rule is fixed by clarification (uniform random via seed) and is
> NOT user-configurable; `dayTieRule` above governs **day** votes only.

---

## 5. NightAction (event-log entry)

Captured per living player per night. Written to `eventLog`; never re-read during play.

| Field | Type | Notes |
|---|---|---|
| night | int | 1-based |
| actorSeat | int | who acted |
| kind | enum | `mafiaVote` \| `protect` \| `investigate` \| `suspect` |
| targetSeat | int | chosen player |
| result | InvestigateResult? | only for `investigate`; four-valued role; **analytics-only** |
| reason | String? | only for `suspect`; ≤40 chars |

---

## 6. Vote (event-log entry)

| Field | Type | Notes |
|---|---|---|
| day | int | 1-based |
| voterSeat | int | secret during play |
| targetSeat | int? | null = abstain (only if `abstainAllowed`) |

Who-voted-for-whom is revealed **only** in post-game analytics (FR-019, FR-032).

---

## 7. TimelineEvent (append-only)

The unified append-only log powering resume and analytics. Variants:

`roleAssigned` · `nightOpened` · `mafiaVote` · `protect` · `investigate` · `suspect` ·
`nightResolved(victimSeat?, savedSeat?)` · `morningAnnounced` · `discussionRound` ·
`questionAsked(fromSeat,toSeat)` · `voteCast` · `dayResolved(eliminatedSeat,tally)` ·
`playerRemoved(seat)` · `winReached(alignment)`.

Each event carries `at` (DateTime) and a `phaseRef`. Ordering is total and monotonic; replaying
the log reconstructs the exact match state (basis for resume + analytics).

---

## 8. Analytics projections (derived, post-game only)

Built by `analytics_builder` from `eventLog` after `winReached`:

- **SuspicionAccuracy**: per player, correct suspicions / total (a suspicion is "correct" if the
  target's role alignment is `mafia`).
- **SuspicionMatrix**: whoSuspectedWhom counts across nights.
- **Achievement**: `{ code, title, awardedToSeat }` computed from the log (Hawk Eye, Most Accurate
  Citizen, Healing Hands, Master Detective, The Fox, The Survivor).
- **MatchSummary**: winner, duration, night count, per-player fate.

These are **not persisted as secrets** — they are pure functions of the completed log.

---

## 9. GamePhase (state machine)

```
setup → rolesConfigured → distributing → preNightLobby
      → night(actor loop) → nightResolving → morning
      → discussion → voting(actor loop) → voteResolving → reveal
      → winCheck ──(continue)──▶ night
                └─(gameOver)──▶ result → analytics
```

Invariants enforced by the FSM:
- No transition exposes a `Player.role` other than the current actor's own (during reveal/night).
- `currentActorSeat` always references a **living** player during actor loops.
- Entering any in-hand phase first routes through a `PassScreen` for `currentActorSeat`.
- Back transitions inside `night`/`voting`/`distributing` are disallowed (FR-027).
- On resume, the FSM re-enters the current phase at its **PassScreen**, never at action content.

---

## 10. Persistence mapping (Isar collections)

| Collection | Maps | Write trigger |
|---|---|---|
| `MatchRecord` | Match header (id, createdAt, seed, phase, dayNumber, currentActorSeat, settings, outcome) | after every confirmed step |
| `PlayerRecord` | players (seat, name, roleIndex, status, eliminatedOn) | on distribution + status change |
| `EventRecord` | TimelineEvent (append-only) | on each event |

`resume_resolver` reads the latest `MatchRecord` + events and returns the **PassScreen target**
for `currentActorSeat` (FR-030, test T7). Secret fields (roles, investigate results) live in
records but are surfaced to the UI only through post-game analytics queries, never through the
in-play `PublicMatchView`.
