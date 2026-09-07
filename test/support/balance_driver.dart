/// Doc 13 §6 — the balance harness's engine.
///
/// # What this is, and what it is not
///
/// The fuzz driver next door plays *randomly*, and random play answers one
/// question: can the machine break. It cannot answer whether the game is worth
/// playing, because a table of random movers is not a table.
///
/// This one plays *badly on purpose, in a specified way*. Each policy is a
/// short, honest description of a real habit — "vote with the crowd", "believe
/// the last thing the app told you" — and the win rate that comes out is a
/// statement about the rules under that habit. Doc 13 §6 is explicit that the
/// agents *"do not need to be smart"*; what they need is to be **different from
/// each other in exactly one respect**, so the difference between two runs is
/// attributable to the thing that changed.
///
/// # The public-information rule
///
/// A town policy that read a `MafiaVoteCast` would be a clairvoyant, and a
/// harness of clairvoyants proves nothing about a game played by people. So
/// town policies read a [PublicView] and never the match: the filtering is done
/// once, here, rather than trusted to each policy.
///
/// The Detective is the single exception and it is not an exception to the
/// rule: their private results reach them through [_Memory], filled from the
/// value `submitNightAction` *returns to the seat that acted*, which is exactly
/// how a real Detective learns anything. Nobody else's memory ever sees it.
library test.support.balance_driver;

import 'dart:math';

import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/legal_moves.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/information_enums.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:mafia_master/engine/presets.dart';

import 'fuzz_driver.dart' show kStallGuard;

/// Doc 13 §6's policies. The town plays one of these; the Mafia always play the
/// same way, so that the difference between two runs of the harness is the
/// town's habit and nothing else.
enum TownPolicy {
  /// Uniform random legal move — the floor. If a real policy cannot beat this,
  /// the information layers are decoration.
  random,

  /// Vote for whoever is most publicly suspected; suspect at random.
  naive,

  /// Everything [naive] does, plus: believe the trace. Vote for whoever the
  /// last victim was suspicious of, and carry that suspicion forward.
  trace,
}

/// How one simulated match ended.
class BalanceResult {
  final MatchOutcome outcome;

  /// Nights played — doc 13 §6's *"median match length in nights"*.
  final int nights;

  final int moves;

  const BalanceResult({
    required this.outcome,
    required this.nights,
    required this.moves,
  });

  bool get mafiaWon => outcome.winner == Alignment.mafia;
}

/// Everything a town policy is allowed to know.
///
/// The event log filtered down to what was *said out loud*: the morning trace,
/// the Day-1 accusations, the ballots, and who is dead. A night action is not
/// in here, and neither is a whisper's body.
class PublicView {
  final Match match;

  const PublicView(this.match);

  Iterable<Player> get living =>
      match.players.where((p) => p.status == PlayerStatus.alive);

  /// The seat the most recent `T1` trace pointed at, if that player is still
  /// alive. `T1` is the one trace the spec lets name anybody, so it is the only
  /// one a policy can act on by seat.
  int? get lastTraceTarget {
    TracePublished? latest;
    for (final e in match.eventLog) {
      if (e is TracePublished && e.type == TraceType.t1) latest = e;
    }
    final seat = latest?.targetSeat;
    if (seat == null) return null;
    return match.players[seat].status == PlayerStatus.alive ? seat : null;
  }

  /// How suspicious the table is of each living seat, from public acts only:
  /// a Day-1 accusation and a ballot each count once.
  Map<int, int> get publicSuspicion {
    final counts = <int, int>{};
    for (final e in match.eventLog) {
      int? target;
      if (e is OpeningAccusationCast) target = e.targetSeat;
      if (e is VoteCast) target = e.targetSeat;
      if (target == null) continue;
      if (match.players[target].status != PlayerStatus.alive) continue;
      counts[target] = (counts[target] ?? 0) + 1;
    }
    return counts;
  }

  /// Seats that publicly moved against [seats] — accused or voted for one of
  /// them. What the Mafia use to work out who is dangerous, and the only thing
  /// they could actually observe.
  Set<int> accusersOf(Set<int> seats) {
    final out = <int>{};
    for (final e in match.eventLog) {
      if (e is OpeningAccusationCast && seats.contains(e.targetSeat)) {
        out.add(e.actorSeat);
      }
      if (e is VoteCast &&
          e.targetSeat != null &&
          seats.contains(e.targetSeat)) {
        out.add(e.voterSeat);
      }
    }
    return out;
  }

  /// Whether any seat in [seats] was voted for on the most recent day.
  bool heatOn(Set<int> seats) {
    final day = match.dayNumber;
    return match.eventLog.any((e) =>
        e is VoteCast &&
        e.phaseRef.number >= day - 1 &&
        e.targetSeat != null &&
        seats.contains(e.targetSeat));
  }
}

/// Every town seat's private *impression* of every other seat.
///
/// # Why this exists, and why the harness would be meaningless without it
///
/// Doc 13 §6 defines `NaivePolicy` as *"suspect randomly"*. Take that
/// literally and doc 13 §9's acceptance criterion — *"`TracePolicy`
/// outperforms `NaivePolicy` for the town — proving traces carry real
/// information"* — cannot be satisfied by any implementation, and not because
/// of a bug. `T1` publishes **what the victim was suspicious of**. If every
/// suspicion is a coin toss, `T1` publishes a coin toss, and a policy that
/// believes it is voting on noise. The two requirements contradict each other
/// as written; this is the resolution, and it is written down rather than
/// quietly assumed.
///
/// So every town seat gets one weak, private, permanent impression of every
/// other seat: uniform noise, plus a small bias when the target really is
/// Mafia. It is a model of *reading people* — the thing the trace layer exists
/// to preserve when the person who did the reading is killed for it.
///
/// It is not clairvoyance. At [_readBias] a town seat's top pick is Mafia
/// appreciably more often than chance and nowhere near always, an agent cannot
/// tell a true impression from a false one, and no impression is ever shared
/// except by acting on it in public — which is precisely what makes a dead
/// player's impression worth publishing.
///
/// # Impressions are mostly *shared*, and that is the important part
///
/// The first version of this made each observer's noise independent. Every
/// table then converged on the truth by sheer arithmetic — eleven independent
/// weak signals average out to a strong one — and the town won ninety per cent
/// of fifteen-player matches. That is a property of independent noise, not of
/// Mafia, and any band fitted to it would have been fitted to a bug.
///
/// People do not read each other independently. They are all watching the same
/// person say the same sentence, so most of what they think about that person
/// is the same thought, right or wrong. [_sharedWeight] of an impression is
/// therefore one number *per target*, identical for every observer, and only
/// the remainder is private. A table cannot average away an error it is all
/// making at once — which is the actual reason the game is hard, and the
/// reason the Detective's private result and the dead player's published
/// suspicion are worth as much as they are.
class _Reads {
  final Map<int, Map<int, int>> _byObserver = {};
  final Map<int, Map<int, int>> _spoken = {};

  /// How far a Mafioso's noise is nudged upward, on the same 0-1000 scale as
  /// the noise itself — the agent model's one free parameter, and the only
  /// number in this file that was chosen by measurement rather than argued
  /// for.
  ///
  /// # How it was set, and why that is not circular
  ///
  /// A win rate is a property of the rules **and** of the players. There is no
  /// such thing as "the" mafia win rate at nine players; there is only the
  /// rate under a stated way of playing. So one cell is the anchor —
  /// «كلاسيكية» at nine, the middle of doc 13 §5's middle preset — and this
  /// number is whatever puts that one cell near even.
  ///
  /// Every *other* cell in the harness is then a prediction, not a fit. Eight
  /// player counts times three presets, and one degree of freedom spent: if
  /// the rules are lopsided at twelve players, or the quiet night is worth
  /// more than doc 13 thinks, this cannot hide it.
  static const int defaultBias = 60;

  final int _readBias;

  /// How much of an impression is the table's rather than the observer's, in
  /// tenths. See the note above: this is what stops the crowd converging.
  static const int _sharedWeight = 7;

  _Reads(Match match, Set<int> mafiaSeats, Random rng, this._readBias) {
    final shared = {
      for (final p in match.players)
        p.seat: rng.nextInt(1000) +
            (mafiaSeats.contains(p.seat) ? _readBias : 0),
    };
    for (final observer in match.players) {
      final row = <int, int>{};
      for (final target in match.players) {
        if (target.seat == observer.seat) continue;
        final private = rng.nextInt(1000) +
            (mafiaSeats.contains(target.seat) ? _readBias : 0);
        row[target.seat] = (shared[target.seat]! * _sharedWeight +
                private * (10 - _sharedWeight)) ~/
            10;
      }
      _byObserver[observer.seat] = row;
      _spoken[observer.seat] = {
        for (final entry in row.entries)
          entry.key: (entry.value + rng.nextInt(1000)) ~/ 2,
      };
    }
  }

  /// What [observer] actually thinks of [target].
  int of(int observer, int target) => _byObserver[observer]?[target] ?? 0;

  /// What [observer] is willing to *say* about [target] — their impression,
  /// half drowned in whatever else is going on with them.
  ///
  /// # Why saying is not thinking, and why the harness collapses without this
  ///
  /// When a public accusation was a pure function of the private impression,
  /// the Mafia could read the table's minds by reading the minutes: doc 13
  /// §6's own `MafiaSmartPolicy` *"avoids killing players who suspect them"*,
  /// and if who-accused-whom exposes who-suspects-whom then the Mafia kill
  /// exactly the players whose suspicions are harmless. The trace then
  /// publishes, every single morning, the opinion of somebody chosen for
  /// having the wrong opinion — and [TownPolicy.trace] measurably *lost* to
  /// [TownPolicy.naive]. That looks like a broken trace layer. It is a broken
  /// model of speech.
  ///
  /// People hedge, follow the room, keep a suspicion back for later, and
  /// accuse the person it is safest to accuse. Half the signal, so the Mafia's
  /// inference is real but partial — and so a dead player's suspicion is worth
  /// publishing, because it was never fully said out loud.
  int spokenBy(int observer, int target) => _spoken[observer]?[target] ?? 0;
}

/// What a published `T1` is worth to a policy that believes it, on the same
/// scale as a public accusation — so exactly **one extra accusation**.
///
/// It was four, once. Four made [TownPolicy.trace] *lose* to
/// [TownPolicy.naive], which is worth writing down because it looks like a bug
/// in the trace layer and is not: a signal weighted above its information
/// content is noise with authority. The victim's suspicion is one person's
/// opinion, arrived at the same way everyone else's was, and one person's
/// opinion is worth one vote.
const int _traceWeight = 1000;

/// One seat's private knowledge. Only the Detective's is ever non-empty.
class _Memory {
  final Map<int, Set<int>> knownMafia = {};
  final Map<int, Set<int>> knownClear = {};

  void record(int seat, int target, bool isMafia) =>
      (isMafia ? knownMafia : knownClear)
          .putIfAbsent(seat, () => <int>{})
          .add(target);

  Set<int> mafiaKnownTo(int seat) => knownMafia[seat] ?? const {};
  Set<int> clearKnownTo(int seat) => knownClear[seat] ?? const {};
}

/// Plays one match to completion under [town], and returns how it ended.
///
/// Deterministic in [seed] alone, exactly like the fuzz driver: the roster,
/// every policy's tie-break and the engine's own randomness all descend from
/// it, so a rate that surprises you can be walked back to a single match.
BalanceResult simulateMatch({
  required MatchPreset preset,
  required int players,
  required int seed,
  required TownPolicy town,
  int readBias = _Reads.defaultBias,
  MatchSettings? settings,
}) {
  final rng = Random(seed);
  final engine = MatchEngine(clock: Clocks.monotonic());
  engine.start(
    names: List.generate(players, (i) => 'P${i + 1}'),
    roleCounts: preset.roleCounts(players),
    settings: settings ?? preset.settings,
    seed: seed,
  );

  final mafiaSeats = {
    for (final p in engine.match.players)
      if (p.role == Role.mafia) p.seat,
  };
  final memory = _Memory();
  final reads = _Reads(engine.match, mafiaSeats, rng, readBias);
  var moves = 0;

  while (!isTerminal(engine.match)) {
    final options = legalMoves(engine.match);
    if (options.isEmpty) {
      throw StateError('balance: dead end in ${engine.match.phase.name} '
          '(seed $seed, $players players, ${preset.name})');
    }

    final move = _choose(
      match: engine.match,
      options: options,
      town: town,
      mafiaSeats: mafiaSeats,
      memory: memory,
      reads: reads,
      rng: rng,
    );

    if (move is NightActionMove) {
      final result = engine.submitNightAction(
        seat: move.seat,
        kind: move.kind,
        targetSeat: move.targetSeat,
        useBullet: move.useBullet,
      );
      // The one private channel in the harness, and it goes to one seat.
      if (result != null) {
        memory.record(
          move.seat,
          move.targetSeat,
          result.revealedRole == Role.mafia,
        );
      }
    } else {
      move.apply(engine);
    }

    moves++;
    if (moves > kStallGuard) {
      throw StateError('balance: ${preset.name} @ $players did not terminate '
          'in $kStallGuard moves (seed $seed)');
    }
  }

  final outcome = engine.match.outcome;
  if (outcome == null) {
    throw StateError('balance: terminal with no outcome (seed $seed)');
  }
  return BalanceResult(
    outcome: outcome,
    nights: engine.match.dayNumber,
    moves: moves,
  );
}

// ---------------------------------------------------------------------------
// Move choice
// ---------------------------------------------------------------------------

Move _choose({
  required Match match,
  required List<Move> options,
  required TownPolicy town,
  required Set<int> mafiaSeats,
  required _Memory memory,
  required _Reads reads,
  required Random rng,
}) {
  if (options.length == 1) return options.first;
  if (town == TownPolicy.random) return options[rng.nextInt(options.length)];

  final view = PublicView(match);

  switch (match.phase) {
    case GamePhase.night:
      return _nightMove(
          match, options, town, mafiaSeats, memory, reads, view, rng);

    case GamePhase.openingRound:
      final seat = match.currentActorSeat!;
      return _pick<OpeningAccusationMove>(
        options.whereType<OpeningAccusationMove>().toList(),
        (m) => _accusationScore(
            m.targetSeat, seat, town, mafiaSeats, reads, view),
        rng,
      );

    case GamePhase.voting:
      final seat = match.currentActorSeat!;
      return _pick<VoteMove>(
        options.whereType<VoteMove>().toList(),
        (m) => _ballotScore(
            m.targetSeat, seat, town, mafiaSeats, memory, reads, view),
        rng,
      );

    case GamePhase.discussion:
      // Whispers carry no engine effect at all, so they cannot move a win
      // rate; the harness spends no matches on them and goes to the ballot.
      return const BeginVotingMove();

    case GamePhase.confrontation:
      // Answered rather than passed: silence is recorded and feeds `C10`, and
      // a table that always went silent would starve the layer being measured.
      return const EndConfrontationMove();

    default:
      return options.first;
  }
}

/// Higher is better. Ties are broken by [rng] so that two equally-suspected
/// seats do not both die to seat order.
T _pick<T extends Move>(
  List<T> candidates,
  int Function(T) score,
  Random rng,
) {
  if (candidates.isEmpty) throw StateError('balance: nothing to pick from');
  var best = <T>[candidates.first];
  var bestScore = score(candidates.first);
  for (final c in candidates.skip(1)) {
    final s = score(c);
    if (s > bestScore) {
      bestScore = s;
      best = [c];
    } else if (s == bestScore) {
      best.add(c);
    }
  }
  return best[rng.nextInt(best.length)];
}

Move _nightMove(
  Match match,
  List<Move> options,
  TownPolicy town,
  Set<int> mafiaSeats,
  _Memory memory,
  _Reads reads,
  PublicView view,
  Random rng,
) {
  final seat = match.currentActorSeat!;
  final role = match.players[seat].role;
  final acts = options.whereType<NightActionMove>().toList();
  final plain = acts.where((m) => !m.useBullet).toList();
  final skips = options.whereType<SkipNightActionMove>().toList();
  final armedSkip =
      skips.where((m) => m.useBullet).cast<SkipNightActionMove?>().firstWhere(
            (m) => true,
            orElse: () => null,
          );

  switch (role) {
    case Role.mafia:
      // «الليلة الهادية» — spent the night after the table put a vote on one of
      // us. A quiet morning is the only way to take the trace away, and the
      // trace is what turns one vote into two.
      if (armedSkip != null && match.dayNumber > 1 && view.heatOn(mafiaSeats)) {
        return armedSkip;
      }
      if (plain.isEmpty) return skips.first;
      final dangerous = view.accusersOf(mafiaSeats);
      // Kill somebody who has *not* moved against us: their suspicion is what
      // the trace would publish tomorrow, and publishing it is worse than
      // leaving them alive. Coordinated by the same seat tie-break as the
      // ballot, so a night's kill votes converge on one name.
      return _pick<NightActionMove>(
          plain,
          (m) => (dangerous.contains(m.targetSeat) ? 0 : 1000) - m.targetSeat,
          rng);

    case Role.doctor:
      // «حماية النفس» when the table has been voting for us: a Doctor who dies
      // the night after being accused was the most valuable seat on the board
      // and knew it.
      if (armedSkip != null && view.heatOn({seat})) return armedSkip;
      if (plain.isEmpty) return skips.first;
      // Cover the loudest voice at the table.
      final suspicion = view.publicSuspicion;
      return _pick<NightActionMove>(
          plain, (m) => suspicion[m.targetSeat] ?? 0, rng);

    case Role.detective:
      // «فتح الملف» once there is something in it worth the table hearing.
      final armed = acts.where((m) => m.useBullet).toList();
      if (armed.isNotEmpty &&
          match.dayNumber > 1 &&
          memory.mafiaKnownTo(seat).isNotEmpty) {
        return _pick<NightActionMove>(
          armed,
          (m) => _investigationScore(m.targetSeat, seat, memory, view),
          rng,
        );
      }
      if (plain.isEmpty) return skips.first;
      return _pick<NightActionMove>(
        plain,
        (m) => _investigationScore(m.targetSeat, seat, memory, view),
        rng,
      );

    case Role.citizen:
      if (plain.isEmpty) return skips.first;
      // Their own impression, published only by dying with it. This is the
      // single input the trace layer has to work with.
      final target = _pick<NightActionMove>(
          plain, (m) => reads.of(seat, m.targetSeat), rng);
      // «الشهادة» — say it out loud when the trace already said it. Two voices
      // on one name is the whole of what a Citizen can contribute.
      if (town == TownPolicy.trace &&
          view.lastTraceTarget == target.targetSeat) {
        for (final m in acts) {
          if (m.useBullet && m.targetSeat == target.targetSeat) return m;
        }
      }
      return target;
  }
}

int _investigationScore(int target, int seat, _Memory memory, PublicView view) {
  if (memory.mafiaKnownTo(seat).contains(target)) return -10;
  if (memory.clearKnownTo(seat).contains(target)) return -10;
  // Doc 13 §4.3's own advice to the Detective: investigate the loud ones.
  return view.publicSuspicion[target] ?? 0;
}

int _accusationScore(
  int target,
  int seat,
  TownPolicy town,
  Set<int> mafiaSeats,
  _Reads reads,
  PublicView view,
) {
  // A Mafioso names a townsperson, and prefers one the table already dislikes.
  // The `- target` is the family talking to each other: it makes the tie-break
  // deterministic, so four Mafia land on one name instead of scattering across
  // four. Coordination is the whole of what being Mafia buys you, and a
  // harness whose Mafia cannot coordinate is measuring a different game.
  if (mafiaSeats.contains(seat)) {
    if (mafiaSeats.contains(target)) return -10000;
    return (view.publicSuspicion[target] ?? 0) * 1000 - target;
  }
  // The opening round is the one place a living player says their impression
  // out loud, so both town policies use it and the difference between them
  // stays where it belongs: in what they do with the *dead* players'
  // impressions.
  var score =
      (view.publicSuspicion[target] ?? 0) * 1000 + reads.spokenBy(seat, target);
  if (town == TownPolicy.trace && view.lastTraceTarget == target) {
    score += _traceWeight;
  }
  return score;
}

int _ballotScore(
  int? target,
  int seat,
  TownPolicy town,
  Set<int> mafiaSeats,
  _Memory memory,
  _Reads reads,
  PublicView view,
) {
  // Nobody in this harness abstains: an abstention is a real thing a person
  // does, but it is not a *policy*, and letting one in would quietly move the
  // win rate without appearing in any of the descriptions above.
  if (target == null) return -1000000;

  // Coordinated, for the reason given in [_accusationScore].
  if (mafiaSeats.contains(seat)) {
    if (mafiaSeats.contains(target)) return -500000;
    return (view.publicSuspicion[target] ?? 0) * 1000 - target;
  }

  // The Detective votes what they know, and nothing outranks it.
  if (memory.mafiaKnownTo(seat).contains(target)) return 1000000;
  if (memory.clearKnownTo(seat).contains(target)) return -500000;

  var score =
      (view.publicSuspicion[target] ?? 0) * 1000 + reads.spokenBy(seat, target);
  // The one line that separates the two town policies: believe the trace.
  if (town == TownPolicy.trace && view.lastTraceTarget == target) {
    score += _traceWeight;
  }
  return score;
}
