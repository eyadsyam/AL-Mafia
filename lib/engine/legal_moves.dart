/// Every command the engine will accept in a given state, enumerated.
///
/// # Why the engine owns this and not the test suite
///
/// Three things need the same answer to *"what can happen next?"* and they must
/// never disagree:
///
/// 1. **Invariant I3** (`11-edge-cases-and-tests.md` §0) — *every phase has a
///    way out*. Offline play has no phase timers, so the honest reading of I3
///    here is: from any non-terminal state at least one legal move exists. That
///    is [hasLegalMove], and it is the assertion that catches a dead end the
///    instant it is created rather than when a table walks into it.
/// 2. **The fuzz harness** (doc 11 §9) — it drives 10,000 matches by repeatedly
///    picking a random legal move. If its idea of "legal" were written
///    separately it would drift from the engine's, and the harness would then
///    be testing its own copy of the rules.
/// 3. **Timer-expiry defaults** (`10-online-architecture.md` §8.2) — online, a
///    phase that expires with no action submitted needs a deterministic default
///    so *"the match can never stall"*. That default is a legal move chosen by
///    seed, which is [defaultMoveOnExpiry].
///
/// One definition, three consumers.
///
/// # This is not the anti-cheat boundary
///
/// [legalMoves] enumerates moves for *whoever holds the phone*, which offline
/// is everyone in turn. It answers "is this a well-formed transition", not "may
/// this user do this". Online, authority lives in the Edge Functions (doc 10
/// §5) and nothing here is trusted.
library engine.legal_moves;

import 'dart:math';

import 'match_engine.dart';
import 'models/enums.dart';
import 'models/match.dart';
import 'models/timeline_event.dart';
import 'resolver.dart';
import 'seed.dart';
import 'win_check.dart';


/// A single engine command, reified so it can be enumerated, scored and
/// replayed.
sealed class Move {
  const Move();

  /// Applies this move to [engine]. The engine re-checks every precondition
  /// itself — a `Move` is a *request*, never a licence.
  void apply(MatchEngine engine);
}

/// Dismiss the role card and hand the phone on (`distributing`).
class ConfirmRevealedMove extends Move {
  const ConfirmRevealedMove();
  @override
  void apply(MatchEngine engine) => engine.confirmRevealed();
  @override
  String toString() => 'confirmRevealed()';
}

/// Open the night (`preNightLobby`).
class BeginNightMove extends Move {
  const BeginNightMove();
  @override
  void apply(MatchEngine engine) => engine.beginNight();
  @override
  String toString() => 'beginNight()';
}

/// One player's night action (`night`).
class NightActionMove extends Move {
  final int seat;
  final NightActionKind kind;
  final int targetSeat;

  const NightActionMove({
    required this.seat,
    required this.kind,
    required this.targetSeat,
  });

  @override
  void apply(MatchEngine engine) => engine.submitNightAction(
        seat: seat,
        kind: kind,
        targetSeat: targetSeat,
      );

  @override
  String toString() =>
      'submitNightAction(seat: $seat, kind: ${kind.name}, target: $targetSeat)';
}

/// Take a night turn and choose nobody (`night`).
///
/// Legal for every role, which is a doc 05 requirement before it is a game
/// rule — see [MatchEngine.skipNightAction].
class SkipNightActionMove extends Move {
  final int seat;

  const SkipNightActionMove({required this.seat});

  @override
  void apply(MatchEngine engine) => engine.skipNightAction(seat: seat);

  @override
  String toString() => 'skipNightAction(seat: $seat)';
}

/// Tally the night (`nightResolving`).
class ResolveNightMove extends Move {
  const ResolveNightMove();
  @override
  void apply(MatchEngine engine) => engine.resolveNight();
  @override
  String toString() => 'resolveNight()';
}

/// End the match on a night that already decided it (`morning`).
class ConcludeAfterNightMove extends Move {
  const ConcludeAfterNightMove();
  @override
  void apply(MatchEngine engine) => engine.concludeAfterNight();
  @override
  String toString() => 'concludeAfterNight()';
}

/// Open the day (`morning`).
///
/// Which sub-phase this lands in — the Day-1 opener, a confrontation, or
/// straight to discussion — is the engine's decision. See
/// [MatchEngine.beginDay].
class BeginDayMove extends Move {
  const BeginDayMove();
  @override
  void apply(MatchEngine engine) => engine.beginDay();
  @override
  String toString() => 'beginDay()';
}

/// One player's public accusation in the «اسم واحد» round (`openingRound`).
class OpeningAccusationMove extends Move {
  final int seat;
  final int targetSeat;

  const OpeningAccusationMove({required this.seat, required this.targetSeat});

  @override
  void apply(MatchEngine engine) =>
      engine.submitOpeningAccusation(seat: seat, targetSeat: targetSeat);

  @override
  String toString() =>
      'submitOpeningAccusation(seat: $seat, target: $targetSeat)';
}

/// Close the confrontation window (`confrontation`).
class EndConfrontationMove extends Move {
  final bool silent;

  const EndConfrontationMove({this.silent = false});

  @override
  void apply(MatchEngine engine) => engine.endConfrontation(silent: silent);

  @override
  String toString() => 'endConfrontation(silent: $silent)';
}

/// Write one whisper (`discussion`), when the layer is on.
class SendWhisperMove extends Move {
  final int fromSeat;
  final int toSeat;
  final String body;

  const SendWhisperMove({
    required this.fromSeat,
    required this.toSeat,
    this.body = 'x',
  });

  @override
  void apply(MatchEngine engine) =>
      engine.sendWhisper(fromSeat: fromSeat, toSeat: toSeat, body: body);

  @override
  String toString() => 'sendWhisper($fromSeat -> $toSeat)';
}

/// Open the ballot (`discussion`).
class BeginVotingMove extends Move {
  const BeginVotingMove();
  @override
  void apply(MatchEngine engine) => engine.beginVoting();
  @override
  String toString() => 'beginVoting()';
}

/// One player's ballot (`voting`). A null [targetSeat] is an abstention.
class VoteMove extends Move {
  final int seat;
  final int? targetSeat;

  const VoteMove({required this.seat, required this.targetSeat});

  @override
  void apply(MatchEngine engine) => engine.submitVote(
        seat: seat,
        voterSeat: seat,
        targetSeat: targetSeat,
      );

  @override
  String toString() => 'submitVote(seat: $seat, target: ${targetSeat ?? '—'})';
}

/// Tally the ballot (`voteResolving`).
class ResolveDayVoteMove extends Move {
  const ResolveDayVoteMove();
  @override
  void apply(MatchEngine engine) => engine.resolveDayVote();
  @override
  String toString() => 'resolveDayVote()';
}

/// Advance past the elimination reveal (`reveal` / `winCheck`).
class WinCheckMove extends Move {
  const WinCheckMove();
  @override
  void apply(MatchEngine engine) => engine.winCheck();
  @override
  String toString() => 'winCheck()';
}

/// Every move the engine would accept right now, in a stable order.
///
/// Stable because the fuzz harness indexes into this list with a seeded RNG:
/// if the order shifted between runs, a reported failing seed would not
/// reproduce, and an irreproducible fuzz failure is barely worth having.
///
/// Returns empty only for a genuinely terminal state (`result`, `analytics`) —
/// anything else is a dead end and a bug, which is what I3 asserts.
List<Move> legalMoves(Match match) {
  switch (match.phase) {
    case GamePhase.setup:
    case GamePhase.rolesConfigured:
      // Pre-match. `MatchEngine.start` lands directly in `distributing`, so a
      // live match is never in either of these; they exist for the setup
      // screens' own state, which the engine does not drive.
      return const [];

    case GamePhase.distributing:
      return const [ConfirmRevealedMove()];

    case GamePhase.preNightLobby:
      return const [BeginNightMove()];

    case GamePhase.night:
      return _nightMoves(match);

    case GamePhase.nightResolving:
      return const [ResolveNightMove()];

    case GamePhase.morning:
      // Exactly one of these is legal, never both. A night that reached parity
      // must end the match; a night that did not must open the day. Offering
      // both would let a caller play on past a decided game — which is how
      // W8/D11 get violated, and `beginDay` refuses it outright.
      return WinChecker.checkWin(match) != null
          ? const [ConcludeAfterNightMove()]
          : const [BeginDayMove()];

    case GamePhase.openingRound:
      return _openingMoves(match);

    case GamePhase.confrontation:
      // Both endings are legal and they are not the same event: the named
      // player either used their window or let it pass, and C-E5 says the
      // difference is recorded because silence is itself information.
      return const [
        EndConfrontationMove(),
        EndConfrontationMove(silent: true),
      ];

    case GamePhase.discussion:
      return [const BeginVotingMove(), ..._whisperMoves(match)];

    case GamePhase.voting:
      return _voteMoves(match);

    case GamePhase.voteResolving:
      return const [ResolveDayVoteMove()];

    case GamePhase.reveal:
    case GamePhase.winCheck:
      return const [WinCheckMove()];

    case GamePhase.result:
    case GamePhase.analytics:
      // Terminal, and the only states for which empty is the right answer.
      return const [];
  }
}

/// Whether any move exists — I3's predicate.
///
/// Short-circuits rather than materialising the list, because this runs inside
/// an `assert` after every single mutation and the night/vote branches are
/// O(players).
bool hasLegalMove(Match match) {
  switch (match.phase) {
    case GamePhase.setup:
    case GamePhase.rolesConfigured:
    case GamePhase.result:
    case GamePhase.analytics:
      return false;
    case GamePhase.night:
      return _nightMoves(match).isNotEmpty;
    case GamePhase.openingRound:
      return _openingMoves(match).isNotEmpty;
    case GamePhase.voting:
      return _voteMoves(match).isNotEmpty;
    default:
      return true;
  }
}

/// Whether [match] is in a state from which no further play is expected.
bool isTerminal(Match match) =>
    match.phase == GamePhase.result || match.phase == GamePhase.analytics;

/// The move the server applies when a phase timer expires with nothing
/// submitted (doc 10 §8.2).
///
/// Seeded from the match seed and the phase index, never from `Random()`, so
/// every client that replays the log lands on the same default. Returns null
/// only in a terminal state.
///
/// Doc 10 §8.2 asks for a *specific* default per phase — "no protection", "no
/// investigation", "recorded as skipped", "abstain". Those are actions this
/// engine cannot express yet: it has no null-action, so a doctor who does
/// nothing simply has no event. Wiring the real defaults is Phase 7 work
/// against a model that can hold them. Until then this picks a legal move by
/// seed, which keeps the *"a phase can never stall"* guarantee that §8.2 exists
/// to provide, and the fuzz harness proves it holds.
Move? defaultMoveOnExpiry(Match match, {required int phaseIndex}) {
  final moves = legalMoves(match);
  if (moves.isEmpty) return null;
  if (moves.length == 1) return moves.first;
  final rng = Random(deriveSeed(match.seed, SeedSalt.timerDefault, phaseIndex));
  return moves[rng.nextInt(moves.length)];
}

// ---------------------------------------------------------------------------
// Phase enumerators
// ---------------------------------------------------------------------------

List<Move> _nightMoves(Match match) {
  final seat = match.currentActorSeat;
  if (seat == null) return const [];

  final actor = match.players[seat];
  if (actor.status != PlayerStatus.alive) return const [];

  final kind = actor.role.nightAction;

  // A detective gets one investigation a night (L-14). Once it is spent the
  // engine rejects a second, so the seat would have no way to pass the phone —
  // a real dead end if it ever became reachable. It is not: the engine advances
  // the actor the moment an action lands. The guard stays because I3 is only
  // worth asserting if it is asserted honestly.
  if (kind == NightActionKind.investigate && hasInvestigatedTonight(match, seat)) {
    return const [];
  }

  // Choosing nobody is always available, to every role. It is listed first so
  // that a seat with no legal target — a Doctor whose only living neighbour is
  // the one they covered last night — still has a way to pass the phone.
  final moves = <Move>[SkipNightActionMove(seat: seat)];
  for (final target in match.players) {
    if (target.seat == seat) continue;
    if (target.status != PlayerStatus.alive) continue;

    // The doctor may not repeat last night's target, so those tiles are not
    // legal moves — they are rendered disabled (N4), not merely rejected.
    if (kind == NightActionKind.protect &&
        NightResolver.wouldViolateDoctorNoRepeat(
          match: match,
          doctorSeat: seat,
          targetSeat: target.seat,
        )) {
      continue;
    }

    moves.add(
      NightActionMove(seat: seat, kind: kind, targetSeat: target.seat),
    );
  }
  return moves;
}

/// Every living player the current accuser may name.
///
/// The «اسم واحد» round is a *forced* choice (doc 09 §2.2) — there is no skip
/// here and no abstain, which is the whole point of the mechanic. A seat with
/// no legal target cannot happen: the round only opens with two or more players
/// alive, and I3 would catch it if it ever did.
List<Move> _openingMoves(Match match) {
  final seat = match.currentActorSeat;
  if (seat == null) return const [];
  if (match.players[seat].status != PlayerStatus.alive) return const [];

  return [
    for (final target in match.players)
      if (target.seat != seat && target.status == PlayerStatus.alive)
        OpeningAccusationMove(seat: seat, targetSeat: target.seat),
  ];
}

/// The whispers that could still be written today.
///
/// Never the only move in `discussion` — [BeginVotingMove] is always there, so
/// a table that writes nothing still gets to a ballot.
List<Move> _whisperMoves(Match match) {
  if (!match.settings.whisperEnabled) return const [];

  final moves = <Move>[];
  for (final from in match.players) {
    if (from.status != PlayerStatus.alive) continue;
    // One per living player per day, non-cumulative (doc 09 §3.3).
    final sent = match.eventLog
        .whereType<WhisperSent>()
        .where((e) =>
            e.fromSeat == from.seat && e.phaseRef.number == match.dayNumber)
        .length;
    if (sent >= 1) continue;
    for (final to in match.players) {
      if (to.seat == from.seat) continue;
      if (to.status != PlayerStatus.alive) continue;
      moves.add(SendWhisperMove(fromSeat: from.seat, toSeat: to.seat));
    }
  }
  return moves;
}

List<Move> _voteMoves(Match match) {
  final seat = match.currentActorSeat;
  if (seat == null) return const [];
  if (match.players[seat].status != PlayerStatus.alive) return const [];

  // On a revote the ballot is exactly the tied seats (FR-020); on the opening
  // ballot it is every other living player.
  final candidates = voteCandidatesFor(match);

  final moves = <Move>[];
  for (final target in match.players) {
    if (target.seat == seat) continue;
    if (target.status != PlayerStatus.alive) continue;
    if (candidates != null && !candidates.contains(target.seat)) continue;
    moves.add(VoteMove(seat: seat, targetSeat: target.seat));
  }

  if (match.settings.abstainAllowed) {
    moves.add(VoteMove(seat: seat, targetSeat: null));
  }
  return moves;
}

/// Whether [seat] has already investigated on the current night.
///
/// Derived from the event log rather than held in a field, so a match rebuilt
/// from storage after a force-quit enforces the same one-shot rule (L-14,
/// repository contract inv. 2). `MatchEngine` delegates to this so the rule the
/// engine enforces and the rule this file enumerates cannot drift apart.
bool hasInvestigatedTonight(Match match, int seat) => match.eventLog.any(
      (e) =>
          e is InvestigateCast &&
          e.actorSeat == seat &&
          e.phaseRef.phase == GamePhase.night &&
          e.phaseRef.number == match.dayNumber,
    );

/// Which balloting round of the current day is open.
///
/// Round 1 is the opening ballot; each tie under [DayTieRule.revote] appends a
/// [DayRevoteCalled] and opens the next round. Deriving it from the log keeps a
/// resumed match on the round it was actually interrupted in.
int voteRoundFor(Match match) =>
    1 +
    match.eventLog
        .where((e) =>
            e is DayRevoteCalled && e.phaseRef.number == match.dayNumber)
        .length;

/// Seats that may legally be voted for right now, or null when every living
/// player other than the voter is a legal target (the opening ballot).
///
/// On a revote this is exactly the tied set — a revote is "among tied players
/// only" (FR-020).
List<int>? voteCandidatesFor(Match match) {
  DayRevoteCalled? last;
  for (final e in match.eventLog) {
    if (e is DayRevoteCalled && e.phaseRef.number == match.dayNumber) {
      last = e;
    }
  }
  return last?.tiedSeats;
}
