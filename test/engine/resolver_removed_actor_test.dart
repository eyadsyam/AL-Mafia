import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:test/test.dart';

/// A player the host removes after choosing at night takes the choice with
/// them (as online resolution does): the left player's kill vote, protection
/// or silence decides nothing.
void main() {
  MatchEngine start(int seed, Map<Role, int> counts, MatchSettings settings) {
    final engine = MatchEngine(clock: Clocks.monotonic());
    engine.start(
      names: const ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
      roleCounts: counts,
      settings: settings,
      seed: seed,
    );
    for (var i = 0; i < 7; i++) {
      engine.revealFor(i);
      engine.confirmRevealed();
    }
    engine.beginNight();
    return engine;
  }

  List<int> seatsOf(MatchEngine e, Role role) => [
    for (final p in e.match.players)
      if (p.role == role) p.seat,
  ];

  NightActionKind kindFor(Role role) => switch (role) {
    Role.mafia => NightActionKind.mafiaVote,
    Role.silencer => NightActionKind.silence,
    Role.doctor => NightActionKind.protect,
    Role.detective => NightActionKind.investigate,
    _ => NightActionKind.suspect,
  };

  /// Plays the night; [choose] picks each actor's target, [afterAct] runs
  /// once right after a given seat has acted.
  void playNight(
    MatchEngine e,
    int Function(int seat, Role role) choose, {
    int? removeAfter,
  }) {
    while (e.match.currentActorSeat != null) {
      final seat = e.match.currentActorSeat!;
      final role = e.match.players[seat].role;
      e.submitNightAction(
        seat: seat,
        kind: kindFor(role),
        targetSeat: choose(seat, role),
      );
      if (seat == removeAfter) e.removePlayer(seat);
    }
    e.resolveNight();
  }

  test('a removed Mafioso\'s kill vote decides nothing', () {
    for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
      final e = start(seed, const {
        Role.mafia: 2,
        Role.doctor: 1,
        Role.citizen: 4,
      }, const MatchSettings());
      final mafia = seatsOf(e, Role.mafia);
      final town = [
        for (final p in e.match.players)
          if (p.role != Role.mafia && p.role != Role.doctor) p.seat,
      ];
      final doctor = seatsOf(e, Role.doctor).single;
      playNight(e, (seat, role) {
        if (seat == mafia[0]) return town[0];
        if (seat == mafia[1]) return town[1];
        if (role == Role.doctor) return town[2];
        return seat == town[3] ? town[2] : town[3];
      }, removeAfter: mafia[0]);
      if (e.match.phase == GamePhase.result) continue;
      expect(
        e.match.players[town[0]].status,
        PlayerStatus.alive,
        reason: 'seed $seed: the removed Mafioso chose this seat',
      );
      expect(e.match.players[town[1]].status, PlayerStatus.dead);
      expect(e.match.players[doctor].status, PlayerStatus.alive);
    }
  });

  test('a removed Doctor\'s protection saves nobody', () {
    final e = start(3, const {
      Role.mafia: 2,
      Role.doctor: 1,
      Role.citizen: 4,
    }, const MatchSettings());
    final mafia = seatsOf(e, Role.mafia);
    final doctor = seatsOf(e, Role.doctor).single;
    final victim = e.match.players
        .firstWhere((p) => p.role == Role.citizen)
        .seat;
    playNight(e, (seat, role) {
      if (role == Role.mafia || role == Role.doctor) return victim;
      return mafia.first;
    }, removeAfter: doctor);
    expect(e.match.players[victim].status, PlayerStatus.dead);
  });
}
