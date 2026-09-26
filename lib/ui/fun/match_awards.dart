import '../../engine/models/enums.dart';
import '../../engine/models/match.dart';
import '../../engine/models/timeline_event.dart';

/// Phase 109: the awards the result screen hands out.
///
/// ## Zero leakage (Doc 05)
///
/// Every award is about who did what with which role, so every one of them is
/// a leak anywhere before the public end. [localMatchAwards] therefore answers
/// an empty list for any match without an outcome or not on its result, and
/// the online list comes only from the server, which refuses the same way.
///
/// The definitions are the server's (`compute_match_awards` in
/// `20260925000600_awards_reactions.sql`), minus Silver Tongue: on one phone
/// the ballots are cast in seat order, so "who led the table" means nothing.
enum AwardKind {
  mvp('mvp', 'award_mvp'),
  sharpEye('sharp_eye', 'award_sharp_eye'),
  silverTongue('silver_tongue', 'award_silver_tongue'),
  firstBlood('first_blood', 'award_first_blood'),
  lifesaver('lifesaver', 'award_lifesaver'),
  perfectCrime('perfect_crime', 'award_perfect_crime'),
  survivor('survivor', 'award_survivor');

  const AwardKind(this.code, this.art);

  /// The server's name for it.
  final String code;

  /// The file stem under `assets/images/awards/`.
  final String art;

  static AwardKind? fromCode(Object? code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

/// One award and everybody who earned it, in seat order.
class MatchAward {
  final AwardKind kind;
  final List<int> seats;
  final List<String> names;

  /// The coins it pays online (0 offline, where there is no wallet).
  final int coins;

  const MatchAward({
    required this.kind,
    required this.seats,
    this.names = const [],
    this.coins = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is MatchAward &&
      other.kind == kind &&
      _same(other.seats, seats) &&
      _same(other.names, names) &&
      other.coins == coins;

  @override
  int get hashCode =>
      Object.hash(kind, Object.hashAll(seats), Object.hashAll(names), coins);

  @override
  String toString() => 'MatchAward(${kind.code}, $seats)';

  static bool _same<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The server's answer for one room.
class OnlineAwards {
  final bool enabled;

  /// False until the room is at its public end; then [awards] is empty.
  final bool ready;
  final List<MatchAward> awards;

  /// The caller's own awards.
  final Set<AwardKind> mine;

  /// Coins credited by this read (0 on a replay).
  final int granted;

  const OnlineAwards({
    this.enabled = false,
    this.ready = false,
    this.awards = const [],
    this.mine = const {},
    this.granted = 0,
  });

  static const off = OnlineAwards();

  factory OnlineAwards.fromJson(Map<String, dynamic> json) {
    if (json['enabled'] != true) return off;
    final ready = json['ready'] == true;
    if (!ready) return const OnlineAwards(enabled: true);
    return OnlineAwards(
      enabled: true,
      ready: true,
      awards: [
        for (final row in (json['awards'] as List?) ?? const [])
          if (row is Map && AwardKind.fromCode(row['code']) != null)
            MatchAward(
              kind: AwardKind.fromCode(row['code'])!,
              seats: [
                for (final s in (row['seats'] as List?) ?? const [])
                  if (s is num) s.toInt(),
              ],
              names: [
                for (final n in (row['names'] as List?) ?? const [])
                  if (n is String) n,
              ],
              coins: (row['coins'] as num?)?.toInt() ?? 0,
            ),
      ],
      mine: {
        for (final code in (json['mine'] as List?) ?? const [])
          ?AwardKind.fromCode(code),
      },
      granted: (json['granted'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The awards of a finished pass-and-play match, from its own log.
///
/// Pure and UI-side: reads the engine's finished [Match], writes nothing, and
/// answers `[]` for a match that is not over.
List<MatchAward> localMatchAwards(Match match) {
  final outcome = match.outcome;
  if (outcome == null) return const [];
  if (match.phase != GamePhase.result && match.phase != GamePhase.analytics) {
    return const [];
  }

  final removed = <int>{
    for (final e in match.eventLog)
      if (e is PlayerRemoved) e.seat,
  };
  final roleOf = {for (final p in match.players) p.seat: p.role};
  final nameOf = {for (final p in match.players) p.seat: p.name};
  bool mafia(int seat) => roleOf[seat] == Role.mafia;
  final players = [
    for (final p in match.players)
      if (!removed.contains(p.seat)) p,
  ]..sort((a, b) => a.seat.compareTo(b.seat));
  final inPlay = {for (final p in players) p.seat};
  final winners = [
    for (final p in players)
      if (p.role.alignment == outcome.winner) p,
  ];

  // A day's ballot is its final round; the last word per voter counts. The
  // log index is the order the ballots were cast in.
  final finalRound = <int, int>{};
  for (final e in match.eventLog) {
    if (e is VoteCast) {
      final day = e.phaseRef.number;
      if ((finalRound[day] ?? 0) < e.round) finalRound[day] = e.round;
    }
  }
  final ballots = <(int, int), _Ballot>{};
  for (final (i, e) in match.eventLog.indexed) {
    if (e is! VoteCast || e.targetSeat == null) continue;
    final day = e.phaseRef.number;
    if (e.round != finalRound[day] || !inPlay.contains(e.voterSeat)) continue;
    ballots[(day, e.voterSeat)] = _Ballot(day, e.voterSeat, e.targetSeat!, i);
  }
  final cast = ballots.values.toList()..sort((a, b) => a.at.compareTo(b.at));
  final dayOut = <int, int>{
    for (final e in match.eventLog)
      if (e is DayResolved) e.phaseRef.number: e.eliminatedSeat,
  };

  final result = <MatchAward>[];
  MatchAward award(AwardKind kind, List<int> seats) => MatchAward(
    kind: kind,
    seats: seats,
    names: [for (final s in seats) nameOf[s] ?? ''],
  );

  // Sharp eye.
  final onMafia = <int, int>{};
  final firstOnMafia = <int, int>{};
  for (final b in cast) {
    if (mafia(b.voter) || !mafia(b.target) || !inPlay.contains(b.target)) {
      continue;
    }
    onMafia[b.voter] = (onMafia[b.voter] ?? 0) + 1;
    firstOnMafia.putIfAbsent(b.voter, () => b.at);
  }
  if (onMafia.isNotEmpty) {
    final best = onMafia.keys.toList()
      ..sort((a, b) {
        final byCount = onMafia[b]!.compareTo(onMafia[a]!);
        if (byCount != 0) return byCount;
        final byTime = firstOnMafia[a]!.compareTo(firstOnMafia[b]!);
        return byTime != 0 ? byTime : a.compareTo(b);
      });
    result.add(award(AwardKind.sharpEye, [best.first]));
  }

  // First blood.
  final caughtDays =
      dayOut.entries
          .where((e) => mafia(e.value) && inPlay.contains(e.value))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  if (caughtDays.isNotEmpty) {
    final day = caughtDays.first;
    final first = cast
        .where(
          (b) => b.day == day.key && b.target == day.value && !mafia(b.voter),
        )
        .firstOrNull;
    if (first != null) result.add(award(AwardKind.firstBlood, [first.voter]));
  }

  // Lifesaver.
  final savedOn = <int, int>{
    for (final e in match.eventLog)
      if (e is NightResolved && e.savedSeat != null)
        e.phaseRef.number: e.savedSeat!,
  };
  final savers = <int>{
    for (final e in match.eventLog)
      if (e is ProtectCast &&
          savedOn[e.phaseRef.number] == e.targetSeat &&
          roleOf[e.actorSeat] == Role.doctor &&
          inPlay.contains(e.actorSeat))
        e.actorSeat,
  };
  final saves = <int, int>{};
  for (final e in match.eventLog) {
    if (e is ProtectCast &&
        savedOn[e.phaseRef.number] == e.targetSeat &&
        savers.contains(e.actorSeat)) {
      saves[e.actorSeat] = 1; // One award, counted once, like the server.
    }
  }
  if (savers.isNotEmpty) {
    result.add(award(AwardKind.lifesaver, savers.toList()..sort()));
  }

  // Perfect crime.
  final mafiaSeats = [
    for (final p in match.players)
      if (p.role == Role.mafia) p,
  ];
  if (outcome.winner == Alignment.mafia &&
      mafiaSeats.every(
        (p) => p.status == PlayerStatus.alive && !removed.contains(p.seat),
      )) {
    result.add(
      award(AwardKind.perfectCrime, [
        for (final p in players)
          if (p.role == Role.mafia) p.seat,
      ]),
    );
  }

  // Survivor.
  final survivors = [
    for (final p in winners)
      if (p.status == PlayerStatus.alive) p.seat,
  ];
  if (survivors.isNotEmpty) result.add(award(AwardKind.survivor, survivors));

  // MVP.
  if (winners.isNotEmpty) {
    int score(int seat, bool alive) {
      final town = !mafia(seat);
      final misled = cast
          .where(
            (b) =>
                b.voter == seat &&
                dayOut[b.day] == b.target &&
                inPlay.contains(b.target) &&
                !mafia(b.target),
          )
          .length;
      return 3 * (town ? onMafia[seat] ?? 0 : 0) +
          3 * (saves[seat] ?? 0) +
          2 * (town ? 0 : misled) +
          (alive ? 2 : 0);
    }

    final ranked =
        [
          for (final p in winners)
            (p.seat, score(p.seat, p.status == PlayerStatus.alive)),
        ]..sort((a, b) {
          final byScore = b.$2.compareTo(a.$2);
          return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
        });
    result.insert(0, award(AwardKind.mvp, [ranked.first.$1]));
  }

  result.sort((a, b) => a.kind.index.compareTo(b.kind.index));
  return List.unmodifiable(result);
}

class _Ballot {
  final int day;
  final int voter;
  final int target;
  final int at;
  const _Ballot(this.day, this.voter, this.target, this.at);
}
