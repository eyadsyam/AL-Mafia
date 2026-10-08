/// «العب ضد البوتات» — the computer players at a one-human table.
///
/// A bot reads the table the way the balance harness's `trace` town does
/// (test/support/balance_driver.dart): public acts only, plus one weak,
/// private, permanent impression of every other seat — mostly shared with the
/// rest of the table — and, for a Detective bot, what its own investigations
/// told it. Mafia bots know their family, which is what every Mafioso knows.
///
/// Pure: no Flutter, no clock, randomness only from the seed.
library;

import 'dart:math';

import '../legal_moves.dart';
import '../models/enums.dart';
import '../models/information_enums.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../models/timeline_event.dart';

/// The phases in which a bot acts on its own turn.
const _botPhases = {
  GamePhase.distributing,
  GamePhase.night,
  GamePhase.openingRound,
  GamePhase.voting,
};

class BotBrain {
  final Set<int> botSeats;
  final Random _rng;
  final Set<int> _mafia;
  final Map<int, Map<int, int>> _reads = {};
  final Map<int, Map<int, int>> _spoken = {};
  final Map<int, Set<int>> _knownMafia = {};
  final Map<int, Set<int>> _knownClear = {};

  /// How far a Mafioso's impression is nudged upward (0-1000 scale), as in
  /// the balance harness: a top pick is Mafia more often than chance, and
  /// nowhere near always.
  static const int readBias = 60;
  static const int _sharedWeight = 7;
  static const int _traceWeight = 1000;

  BotBrain({required Match match, required this.botSeats, required int seed})
    : _rng = Random(seed),
      _mafia = {
        for (final p in match.players)
          if (p.role.alignment == Alignment.mafia) p.seat,
      } {
    final shared = {
      for (final p in match.players)
        p.seat: _rng.nextInt(1000) + (_mafia.contains(p.seat) ? readBias : 0),
    };
    for (final observer in match.players) {
      final row = <int, int>{};
      for (final target in match.players) {
        if (target.seat == observer.seat) continue;
        final private =
            _rng.nextInt(1000) + (_mafia.contains(target.seat) ? readBias : 0);
        row[target.seat] =
            (shared[target.seat]! * _sharedWeight +
                private * (10 - _sharedWeight)) ~/
            10;
      }
      _reads[observer.seat] = row;
      _spoken[observer.seat] = {
        for (final e in row.entries) e.key: (e.value + _rng.nextInt(1000)) ~/ 2,
      };
    }
  }

  /// Whether the seat whose turn it is now is a bot.
  bool controls(Match match) {
    final seat = match.currentActorSeat;
    return seat != null &&
        botSeats.contains(seat) &&
        _botPhases.contains(match.phase);
  }

  /// A Detective bot's own result, from the value its night action returned.
  void observe(int seat, InvestigateResult result) {
    if (result.obscured != null) return;
    final into = result.revealedRole.alignment == Alignment.mafia
        ? _knownMafia
        : _knownClear;
    into.putIfAbsent(seat, () => <int>{}).add(result.targetSeat);
  }

  /// The bot's move for the current turn. Only call when [controls].
  Move choose(Match match) {
    final seat = match.currentActorSeat!;
    final options = [
      for (final m in legalMoves(match))
        if (_seatOf(m) == seat || m is ConfirmRevealedMove) m,
    ];
    if (options.isEmpty) throw StateError('bot: no move for seat $seat');
    if (options.length == 1) return options.first;
    final view = _View(match);
    return switch (match.phase) {
      GamePhase.night => _night(match, seat, options, view),
      GamePhase.openingRound => _pick<OpeningAccusationMove>(
        options.whereType<OpeningAccusationMove>().toList(),
        (m) => _accusation(m.targetSeat, seat, view),
      ),
      GamePhase.voting => _vote(seat, options, view),
      _ => options.first,
    };
  }

  /// Who this bot would name out loud right now (its strongest public
  /// suspicion), for the discussion's spoken lines. Never a fact, an opinion.
  int? suspectOf(Match match, int seat) {
    final view = _View(match);
    int? best;
    var bestScore = -1 << 30;
    for (final p in view.living) {
      if (p.seat == seat) continue;
      final s = _accusation(p.seat, seat, view);
      if (s > bestScore) {
        bestScore = s;
        best = p.seat;
      }
    }
    return best;
  }

  static int? _seatOf(Move m) => switch (m) {
    NightActionMove() => m.seat,
    SkipNightActionMove() => m.seat,
    OpeningAccusationMove() => m.seat,
    VoteMove() => m.seat,
    SkipSilencedVoteMove() => m.seat,
    _ => null,
  };

  T _pick<T extends Move>(List<T> candidates, int Function(T) score) {
    if (candidates.isEmpty) throw StateError('bot: nothing to pick from');
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
    return best[_rng.nextInt(best.length)];
  }

  Move _vote(int seat, List<Move> options, _View view) {
    final skip = options.whereType<SkipSilencedVoteMove>();
    if (skip.isNotEmpty) return skip.first;
    final ballots = options.whereType<VoteMove>().toList();
    if (ballots.isEmpty) return options.first;
    return _pick<VoteMove>(ballots, (m) => _ballot(m.targetSeat, seat, view));
  }

  Move _night(Match match, int seat, List<Move> options, _View view) {
    final role = match.players[seat].role;
    final acts = options.whereType<NightActionMove>().toList();
    final plain = acts.where((m) => !m.useBullet).toList();
    final skips = options.whereType<SkipNightActionMove>().toList();
    final armedSkip = skips.where((m) => m.useBullet).firstOrNull;
    Move skip() => skips.firstWhere((m) => !m.useBullet, orElse: () => skips.first);

    switch (role) {
      case Role.mafia || Role.silencer:
        if (role == Role.mafia &&
            armedSkip != null &&
            match.dayNumber > 1 &&
            view.heatOn(_mafia)) {
          return armedSkip;
        }
        if (plain.isEmpty) return skip();
        final dangerous = view.accusersOf(_mafia);
        return _pick<NightActionMove>(
          plain,
          (m) =>
              (_mafia.contains(m.targetSeat) ? -100000 : 0) +
              (dangerous.contains(m.targetSeat) ? 0 : 1000) -
              m.targetSeat,
        );
      case Role.doctor:
        if (armedSkip != null && view.heatOn({seat})) return armedSkip;
        if (plain.isEmpty) return skip();
        final suspicion = view.publicSuspicion;
        return _pick<NightActionMove>(
          plain,
          (m) => suspicion[m.targetSeat] ?? 0,
        );
      case Role.detective:
        final armed = acts.where((m) => m.useBullet).toList();
        if (armed.isNotEmpty &&
            match.dayNumber > 1 &&
            (_knownMafia[seat] ?? const {}).isNotEmpty) {
          return _pick<NightActionMove>(
            armed,
            (m) => _investigation(m.targetSeat, seat, view),
          );
        }
        if (plain.isEmpty) return skip();
        return _pick<NightActionMove>(
          plain,
          (m) => _investigation(m.targetSeat, seat, view),
        );
      case Role.sniper:
        // One bullet for the match: only when the table and this bot's own
        // read both point at the same seat.
        final shots = acts.where((m) => m.useBullet).toList();
        final trace = view.lastTraceTarget;
        if (shots.isNotEmpty && match.dayNumber > 1 && trace != null) {
          final suspect = suspectOf(match, seat);
          for (final m in shots) {
            if (m.targetSeat == trace && m.targetSeat == suspect) return m;
          }
        }
        if (plain.isEmpty) return skip();
        return _pick<NightActionMove>(plain, (m) => _read(seat, m.targetSeat));
      case Role.citizen || Role.elder:
        if (plain.isEmpty) return skip();
        final target = _pick<NightActionMove>(
          plain,
          (m) => _read(seat, m.targetSeat),
        );
        if (view.lastTraceTarget == target.targetSeat) {
          for (final m in acts) {
            if (m.useBullet && m.targetSeat == target.targetSeat) return m;
          }
        }
        return target;
    }
  }

  int _read(int observer, int target) => _reads[observer]?[target] ?? 0;
  int _said(int observer, int target) => _spoken[observer]?[target] ?? 0;

  int _investigation(int target, int seat, _View view) {
    if ((_knownMafia[seat] ?? const {}).contains(target)) return -10;
    if ((_knownClear[seat] ?? const {}).contains(target)) return -10;
    return (view.publicSuspicion[target] ?? 0) * 1000 + _read(seat, target);
  }

  int _accusation(int target, int seat, _View view) {
    if (_mafia.contains(seat)) {
      if (_mafia.contains(target)) return -10000;
      return (view.publicSuspicion[target] ?? 0) * 1000 - target;
    }
    if ((_knownMafia[seat] ?? const {}).contains(target)) return 1000000;
    if ((_knownClear[seat] ?? const {}).contains(target)) return -500000;
    var score =
        (view.publicSuspicion[target] ?? 0) * 1000 + _said(seat, target);
    if (view.lastTraceTarget == target) score += _traceWeight;
    return score;
  }

  int _ballot(int? target, int seat, _View view) {
    if (target == null) return -1000000;
    if (_mafia.contains(seat)) {
      if (_mafia.contains(target)) return -500000;
      return (view.publicSuspicion[target] ?? 0) * 1000 - target;
    }
    return _accusation(target, seat, view);
  }
}

/// What every bot may read: the public record only.
class _View {
  final Match match;
  const _View(this.match);

  Iterable<Player> get living =>
      match.players.where((p) => p.status == PlayerStatus.alive);

  int? get lastTraceTarget {
    TracePublished? latest;
    for (final e in match.eventLog) {
      if (e is TracePublished && e.type == TraceType.t1) latest = e;
    }
    final seat = latest?.targetSeat;
    if (seat == null) return null;
    return match.players[seat].status == PlayerStatus.alive ? seat : null;
  }

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

  bool heatOn(Set<int> seats) {
    final day = match.dayNumber;
    return match.eventLog.any(
      (e) =>
          e is VoteCast &&
          e.phaseRef.number >= day - 1 &&
          e.targetSeat != null &&
          seats.contains(e.targetSeat),
    );
  }
}
