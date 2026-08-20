# Contract: Game Engine (pure Dart)

The engine is the UI-facing boundary of all game logic. It has **no Flutter imports**. The UI may
only observe the engine through `PublicMatchView` and drive it through the command methods below.
This is the structural enforcement of Principle I: the UI *cannot* obtain another player's secret
because the engine never hands one out during play.

## Types the UI is allowed to see

```dart
/// Everything the table/host may safely see at any time.
class PublicMatchView {
  final GamePhase phase;
  final int dayNumber;
  final List<PublicPlayer> players;   // name, seat, status ONLY — never role
  final int? currentActorSeat;        // whose pass/turn is active
  final MorningReport? morning;       // victim name OR "saved, unnamed" OR "all survived"
  final VoteTally? lastTally;         // counts only; not who-voted-whom
  final MatchOutcome? outcome;        // null until game over
}

/// The private view handed to EXACTLY ONE actor, only after the identity gate,
/// and only for the duration of their own turn. Never stored, never logged verbatim.
class ActorTurnView {
  final int actorSeat;
  final Role actorRole;               // the holder's OWN role only
  final String questionText;          // localized, role-specific TEXT (structure identical)
  final List<SelectableTarget> targets;
  final List<TeammateHint> teammateVotes; // non-empty ONLY for mafia; reserved slot otherwise
}
```

## Commands (state transitions)

| Method | Precondition | Effect | Leakage guard |
|---|---|---|---|
| `startMatch(players, settings, {seed})` | 5..20 players, valid roles | assigns roles, → `distributing` | seed stored; roles never returned |
| `revealFor(seat)` | phase `distributing`, seat == currentActor | returns that actor's role card data | returns caller's role only |
| `confirmRevealed(seat)` | reveal shown | advances to next actor or `preNightLobby` | fixed post-delay handled in UI |
| `beginNight()` | `preNightLobby` | → `night`, currentActor = first living seat | — |
| `actorView(seat)` | `night`/`voting`, seat==currentActor, identity gate passed | returns `ActorTurnView` | one actor only |
| `submitNightAction(action)` | dwell ≥ 8s elapsed (UI-enforced), valid target | appends event, advances actor | no result returned except Detective's, in-view only, unstored-as-readable |
| `submitVote(vote)` | voting, valid target, no self-vote | appends event, advances actor | tally hidden until all voted |
| `resolveNight()` | all night actors done | Mafia target − Doctor protect; seeded tie-break; → `morning` | victim role NOT in MorningReport |
| `resolveDayVote()` | all votes in | applies tie rule; eliminates; reveals role on reveal screen | who-voted-whom withheld |
| `winCheck()` | after any elimination | town/mafia/continue | — |
| `removePlayer(seat)` | host action | neutral elimination + winCheck | logged in timeline |
| `buildAnalytics()` | phase `result`/`analytics` | pure projection of eventLog | ONLY place secrets surface |

## Invariants (unit-tested — Principle III)

1. `PublicMatchView.players` never contains a `role` field. (compile-time: type has none)
2. `actorView` throws unless `seat == currentActorSeat` and the identity gate flag is set.
3. `submitNightAction(investigate)` returns the four-valued result exactly once; a second call for
   the same turn is rejected; the result never appears in any `PublicMatchView` or query except
   `buildAnalytics()`.
4. Mafia night-vote tie → uniform draw from tied targets using the match seed (reproducible).
5. Doctor cannot protect the same seat on consecutive nights (rejected with a domain error).
6. `resolveNight` produces a `MorningReport` with no role information.
7. `winCheck`: town wins iff living mafia == 0; mafia wins iff living mafia ≥ living town.
8. Replaying `eventLog` from empty reproduces the current `Match` byte-for-byte (resume basis).
9. No engine source imports `package:flutter` or `dart:ui` (enforced by `engine_purity_test`).
