/// The four invariants of `11-edge-cases-and-tests.md` §0, asserted after every
/// state mutation.
///
/// # Why these are worth more than the tests around them
///
/// A hand-written test asserts something about *one* path. These assert
/// something about *every* state the engine can ever reach, and the fuzz
/// harness then walks 10,000 matches through them. Doc 11 is blunt about it:
/// *"This one harness catches more than any hand-written suite."*
///
/// # How the spec's wording maps onto this codebase
///
/// Doc 11 writes the invariants against a `GameState` with fields this engine
/// does not have — `aliveCount`, `phaseEndsAt`, `awaitingAction`, `roleCounts`.
/// Transcribing them literally would produce four assertions that are all
/// trivially true and catch nothing, which is the worst possible outcome: a
/// safety net that reads as if it works. So each is re-expressed against what
/// this engine actually holds, keeping the *property* and dropping the field
/// names.
///
/// | Doc 11 | Here | Why |
/// |---|---|---|
/// | I1 `alive.length == aliveCount` | roster coherence: seats contiguous, `dead ⟺ eliminatedOn`, the actor is alive | There is no denormalised `aliveCount` to disagree with. The real risk is a roster that contradicts *itself* |
/// | I2 `inProgress ⟹ aliveCount >= 2` | a live match is either playable or already won, and a decided match sits in `result` | Stated literally it fires in `morning`, where a decided night has not been applied yet — a false positive that would get the assertion deleted |
/// | I3 `phaseEndsAt != null \|\| awaitingAction` | [hasLegalMove] | Offline play has no timers. The way out of a phase *is* a legal move |
/// | I4 `roleCounts.sum == players.length` | the role multiset matches the `RoleAssigned` events | Roles live on players here, so the sum is tautological. Conservation is not |
///
/// # Cost
///
/// [assertMatchInvariants] is wrapped in `assert`, so it compiles out of a
/// release build entirely — doc 11's "assert-only in release". The fuzz harness
/// calls [checkMatchInvariants] directly instead, because it wants the list of
/// what broke, not a boolean.
library engine.invariants;

import 'legal_moves.dart';
import 'models/enums.dart';
import 'models/match.dart';
import 'models/timeline_event.dart';
import 'win_check.dart';


/// Every invariant violation in [match], as human-readable lines. Empty means
/// the state is sound.
///
/// Pure, total, and never throws — a violation must be *reported*, not raised,
/// or the fuzz harness cannot tell an invariant break apart from a crash.
List<String> checkMatchInvariants(Match match) {
  final violations = <String>[];
  _checkI1Roster(match, violations);
  _checkI2Resolvable(match, violations);
  _checkI3WayOut(match, violations);
  _checkI4RolesConserved(match, violations);
  return violations;
}

/// Asserts [checkMatchInvariants] is empty. Compiled out in release.
///
/// Called at the end of every `MatchEngine` command — the end, not the middle,
/// because a command that kills a player and then runs the win check passes
/// through a state that is legitimately inconsistent between the two.
void assertMatchInvariants(Match match, String after) {
  assert(() {
    final violations = checkMatchInvariants(match);
    if (violations.isEmpty) return true;
    throw MatchInvariantViolation(after: after, violations: violations);
  }());
}

/// Thrown by [assertMatchInvariants]. Carries the command that produced the bad
/// state, because "which invariant broke" is far less useful than "after what".
class MatchInvariantViolation implements Exception {
  final String after;
  final List<String> violations;

  const MatchInvariantViolation({required this.after, required this.violations});

  @override
  String toString() => 'MatchInvariantViolation after $after:\n'
      '${violations.map((v) => '  - $v').join('\n')}';
}

// ---------------------------------------------------------------------------
// I1 — the alive set is coherent
// ---------------------------------------------------------------------------

void _checkI1Roster(Match match, List<String> out) {
  if (!match.isSeatingValid) {
    out.add('I1: seats are not contiguous 0..n-1 '
        '(${match.players.map((p) => p.seat).toList()})');
  }

  for (final p in match.players) {
    // Death and its cause are written together or not at all. A dead player
    // with no `eliminatedOn` breaks the post-game timeline silently — analytics
    // reads that field to say *when* someone went — so it is worth catching at
    // the mutation that did it rather than on the results screen.
    final dead = p.status == PlayerStatus.dead;
    if (dead && p.eliminatedOn == null) {
      out.add('I1: seat ${p.seat} is dead with no eliminatedOn');
    }
    if (!dead && p.eliminatedOn != null) {
      out.add('I1: seat ${p.seat} is alive but carries '
          'eliminatedOn=${p.eliminatedOn}');
    }
  }

  // The phone is never handed to a dead player. Rule 9 of doc 05 — *"the dead
  // take no part in the night"* — is a leakage rule, not just a tidiness one:
  // a fake pass is a tap with no value, and the count of passes is public
  // information the table can read.
  final actor = match.currentActorSeat;
  if (actor != null) {
    if (actor < 0 || actor >= match.players.length) {
      out.add('I1: currentActorSeat $actor is off the roster');
    } else if (match.players[actor].status != PlayerStatus.alive &&
        match.phase != GamePhase.distributing) {
      out.add('I1: currentActorSeat $actor is dead in phase ${match.phase.name}');
    }
  }
}

// ---------------------------------------------------------------------------
// I2 — the game is never in an unresolvable state
// ---------------------------------------------------------------------------

void _checkI2Resolvable(Match match, List<String> out) {
  final aliveCount =
      match.players.where((p) => p.status == PlayerStatus.alive).length;
  final decided = WinChecker.checkWin(match);

  if (match.outcome != null) {
    // A recorded outcome and a phase that is still playing is the state that
    // strands a table on a screen with no forward button.
    if (match.phase != GamePhase.result && match.phase != GamePhase.analytics) {
      out.add('I2: outcome ${match.outcome!.winner.name} recorded but phase is '
          '${match.phase.name}');
    }
    return;
  }

  // No outcome yet. That is only sound if the match is genuinely still live, or
  // is one already-pending transition away from ending. Anything else is a
  // match that can neither continue nor conclude.
  if (decided == null && aliveCount < 3) {
    out.add('I2: no winner is detectable but only $aliveCount players are alive '
        '— a live match needs at least one mafia and two others');
  }

  // Doc 11 N14: *"Every living player is Mafia → win check fires before the
  // night begins."* A night that opens on a decided match spends a whole pass
  // of the phone on a game that is already over.
  //
  // The same applies to every phase of the day the match has no business
  // opening: an «اسم واحد» round, a confrontation and a discussion are each a
  // stretch of table time spent on a game whose winner is already fixed.
  // `morning` is deliberately absent — a decided night *sits* in `morning`
  // until `concludeAfterNight` applies it, and that is the point of the beat
  // doc 06 §4 asks for.
  const playingOn = {
    GamePhase.night,
    GamePhase.openingRound,
    GamePhase.confrontation,
    GamePhase.discussion,
  };
  if (decided != null && playingOn.contains(match.phase)) {
    out.add('I2: ${match.phase.name} opened with ${decided.name} '
        'already winning');
  }
}

// ---------------------------------------------------------------------------
// I3 — every phase has a way out
// ---------------------------------------------------------------------------

void _checkI3WayOut(Match match, List<String> out) {
  if (isTerminal(match)) return;
  if (!hasLegalMove(match)) {
    out.add('I3: phase ${match.phase.name} has no legal move '
        '(actor=${match.currentActorSeat}, day=${match.dayNumber}) — dead end');
  }
}

// ---------------------------------------------------------------------------
// I4 — the roles dealt at the start are the roles in play
// ---------------------------------------------------------------------------

void _checkI4RolesConserved(Match match, List<String> out) {
  final dealt = <Role, int>{};
  for (final e in match.eventLog) {
    if (e is RoleAssigned) {
      dealt[e.role] = (dealt[e.role] ?? 0) + 1;
    }
  }
  // An adopted match whose log predates role logging has nothing to compare
  // against; absence of evidence is not a violation.
  if (dealt.isEmpty) return;

  final held = <Role, int>{};
  for (final p in match.players) {
    held[p.role] = (held[p.role] ?? 0) + 1;
  }

  final total = dealt.values.fold<int>(0, (a, b) => a + b);
  if (total != match.players.length) {
    out.add('I4: $total roles were dealt to ${match.players.length} players');
  }

  for (final role in Role.values) {
    final d = dealt[role] ?? 0;
    final h = held[role] ?? 0;
    if (d != h) {
      out.add('I4: ${role.name} was dealt $d times but $h players hold it — '
          'a role changed mid-match');
    }
  }
}
