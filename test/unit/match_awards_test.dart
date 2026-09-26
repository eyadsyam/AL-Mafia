import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:mafia_master/ui/fun/match_awards.dart';

/// Phase 109: the pass-and-play awards helper. The six-player town win is the
/// same match the server's contract (`supabase/tests/awards_reactions.sql`,
/// A3) asserts, so the two definitions are held to one answer.
void main() {
  final t0 = DateTime.utc(2026, 9, 20, 12);
  var tick = 0;
  DateTime at() => t0.add(Duration(seconds: tick++));
  PhaseRef night(int n) => PhaseRef(phase: GamePhase.night, number: n);
  PhaseRef day(int n) => PhaseRef(phase: GamePhase.voting, number: n);

  Player player(int seat, Role role, {bool dead = false}) => Player(
    seat: seat,
    name: 'P$seat',
    role: role,
    status: dead ? PlayerStatus.dead : PlayerStatus.alive,
  );

  VoteCast vote(int d, int voter, int target, {int round = 1}) => VoteCast(
    at: at(),
    phaseRef: day(d),
    voterSeat: voter,
    targetSeat: target,
    round: round,
  );

  Match match({
    required List<Player> players,
    required List<TimelineEvent> log,
    Alignment? winner,
    GamePhase phase = GamePhase.result,
  }) => Match(
    id: 1,
    createdAt: t0,
    seed: 1,
    players: players,
    settings: const MatchSettings(),
    phase: phase,
    dayNumber: 2,
    eventLog: log,
    outcome: winner == null
        ? null
        : MatchOutcome(winner: winner, completedAt: t0),
  );

  // Seats: 0,1 Mafia · 2 Doctor · 3 Detective · 4,5 Citizens.
  List<TimelineEvent> townWinLog() => [
    ProtectCast(at: at(), phaseRef: night(1), actorSeat: 2, targetSeat: 4),
    MafiaVoteCast(at: at(), phaseRef: night(1), actorSeat: 0, targetSeat: 4),
    NightResolved(at: at(), phaseRef: night(1), savedSeat: 4),
    vote(1, 3, 0),
    vote(1, 4, 0),
    vote(1, 2, 0),
    vote(1, 5, 3),
    vote(1, 0, 5),
    vote(1, 1, 5),
    DayResolved(
      at: at(),
      phaseRef: day(1),
      eliminatedSeat: 0,
      tally: const {0: 3, 5: 2, 3: 1},
    ),
    vote(2, 3, 4),
    vote(2, 5, 1, round: 2),
    vote(2, 4, 1, round: 2),
    vote(2, 3, 1, round: 2),
    vote(2, 1, 3, round: 2),
    DayResolved(
      at: at(),
      phaseRef: day(2),
      eliminatedSeat: 1,
      tally: const {1: 3, 3: 1},
    ),
  ];

  List<Player> townWinPlayers() => [
    player(0, Role.mafia, dead: true),
    player(1, Role.mafia, dead: true),
    player(2, Role.doctor),
    player(3, Role.detective),
    player(4, Role.citizen),
    player(5, Role.citizen),
  ];

  List<int> seatsOf(List<MatchAward> awards, AwardKind kind) =>
      awards.where((a) => a.kind == kind).firstOrNull?.seats ?? const [];

  test('a town win gets the same awards the server computes', () {
    final awards = localMatchAwards(
      match(
        players: townWinPlayers(),
        log: townWinLog(),
        winner: Alignment.town,
      ),
    );
    expect(seatsOf(awards, AwardKind.sharpEye), [3]);
    expect(seatsOf(awards, AwardKind.firstBlood), [3]);
    expect(seatsOf(awards, AwardKind.lifesaver), [2]);
    expect(seatsOf(awards, AwardKind.survivor), [2, 3, 4, 5]);
    // Doctor, detective and c1 tie on 8; the lowest seat wins.
    expect(seatsOf(awards, AwardKind.mvp), [2]);
    expect(seatsOf(awards, AwardKind.perfectCrime), isEmpty);
    expect(
      seatsOf(awards, AwardKind.silverTongue),
      isEmpty,
      reason: 'one phone casts ballots in seat order: nobody led anybody',
    );
    // Ribbon order is the enum's.
    expect(awards.map((a) => a.kind).toList(), [
      AwardKind.mvp,
      AwardKind.sharpEye,
      AwardKind.firstBlood,
      AwardKind.lifesaver,
      AwardKind.survivor,
    ]);
    expect(awards.first.names, ['P2']);
  });

  group('role leak: nothing before the public end', () {
    test('a match without an outcome answers nothing', () {
      expect(
        localMatchAwards(match(players: townWinPlayers(), log: townWinLog())),
        isEmpty,
      );
    });

    for (final phase in GamePhase.values) {
      if (phase == GamePhase.result || phase == GamePhase.analytics) continue;
      test('nothing in $phase, even with an outcome recorded', () {
        expect(
          localMatchAwards(
            match(
              players: townWinPlayers(),
              log: townWinLog(),
              winner: Alignment.town,
              phase: phase,
            ),
          ),
          isEmpty,
        );
      });
    }
  });

  test('a Mafia win with no Mafia caught is a perfect crime', () {
    final awards = localMatchAwards(
      match(
        players: [
          player(0, Role.mafia),
          player(1, Role.mafia),
          player(2, Role.doctor),
          player(3, Role.detective, dead: true),
          player(4, Role.citizen, dead: true),
        ],
        log: [
          vote(1, 0, 4),
          vote(1, 1, 4),
          vote(1, 2, 4),
          DayResolved(
            at: at(),
            phaseRef: day(1),
            eliminatedSeat: 4,
            tally: const {4: 3},
          ),
        ],
        winner: Alignment.mafia,
      ),
    );
    expect(seatsOf(awards, AwardKind.perfectCrime), [0, 1]);
    expect(seatsOf(awards, AwardKind.survivor), [0, 1]);
    expect(seatsOf(awards, AwardKind.mvp), [0]);
    expect(seatsOf(awards, AwardKind.sharpEye), isEmpty);
    expect(seatsOf(awards, AwardKind.firstBlood), isEmpty);
  });

  test('a removed player is never awarded, and a removed Mafia is caught', () {
    final awards = localMatchAwards(
      match(
        players: [
          player(0, Role.mafia, dead: true),
          player(1, Role.mafia),
          player(2, Role.doctor),
          player(3, Role.citizen),
          player(4, Role.citizen),
        ],
        log: [PlayerRemoved(at: at(), phaseRef: day(1), seat: 0)],
        winner: Alignment.mafia,
      ),
    );
    expect(seatsOf(awards, AwardKind.perfectCrime), isEmpty);
    expect(seatsOf(awards, AwardKind.survivor), [1]);
    expect(awards.every((a) => !a.seats.contains(0)), isTrue);
  });

  test('the server answer parses, and a not-ready room carries nothing', () {
    expect(OnlineAwards.fromJson({'enabled': false}).enabled, isFalse);
    final live = OnlineAwards.fromJson({
      'enabled': true,
      'ready': false,
      'awards': [
        {
          'code': 'mvp',
          'seats': [0],
        },
      ],
    });
    expect(live.ready, isFalse);
    expect(live.awards, isEmpty);
    final done = OnlineAwards.fromJson({
      'enabled': true,
      'ready': true,
      'awards': [
        {
          'code': 'mvp',
          'seats': [2],
          'names': ['Mona'],
          'coins': 15,
        },
        {
          'code': 'unknown_award',
          'seats': [1],
        },
      ],
      'mine': ['mvp'],
      'granted': 15,
    });
    expect(done.awards, [
      const MatchAward(
        kind: AwardKind.mvp,
        seats: [2],
        names: ['Mona'],
        coins: 15,
      ),
    ]);
    expect(done.mine, {AwardKind.mvp});
    expect(done.granted, 15);
  });
}
