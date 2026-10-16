import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:test/test.dart';

void main() {
  const roles = {
    Role.mafia: 1,
    Role.doctor: 1,
    Role.sniper: 1,
    Role.citizen: 4,
  };
  const settings = MatchSettings(
    quietNightEnabled: true,
    sniperEnabled: true,
    traceEnabled: false,
    confrontationEnabled: false,
  );

  MatchEngine start() {
    final n = roles.values.fold<int>(0, (a, b) => a + b);
    final engine = MatchEngine(clock: Clocks.monotonic());
    engine.start(
      names: [for (var i = 0; i < n; i++) 'P$i'],
      roleCounts: roles,
      settings: settings,
      seed: 3,
    );
    for (var i = 0; i < n; i++) {
      engine.revealFor(i);
      engine.confirmRevealed();
    }
    return engine;
  }

  int seatOf(MatchEngine e, Role role) =>
      e.match.players.firstWhere((p) => p.role == role).seat;

  void advanceTo(MatchEngine e, Role role) {
    e.beginNight();
    final seat = seatOf(e, role);
    while (e.match.currentActorSeat != seat) {
      e.skipNightAction(seat: e.match.currentActorSeat!);
    }
  }

  void markDead(MatchEngine e, int seat) {
    final m = e.match;
    e.match = m.copyWith(
      players: [
        for (final p in m.players)
          if (p.seat == seat)
            p.copyWith(
              status: PlayerStatus.dead,
              eliminatedOn: const PhaseRef(phase: GamePhase.night, number: 1),
            )
          else
            p,
      ],
    );
  }

  test('submitNightAction refuses outside night without changing state', () {
    final e = start();
    final before = e.match;
    expect(
      () => e.submitNightAction(
        seat: seatOf(e, Role.mafia),
        kind: NightActionKind.mafiaVote,
        targetSeat: seatOf(e, Role.citizen),
      ),
      throwsStateError,
    );
    expect(identical(e.match, before), isTrue);
    expect(e.match.eventLog.length, before.eventLog.length);
  });

  test('skipNightAction refuses outside night before doctor fallback', () {
    final e = start();
    final before = e.match;
    expect(() => e.skipNightAction(seat: seatOf(e, Role.doctor)), throwsStateError);
    expect(identical(e.match, before), isTrue);
    expect(e.match.eventLog.length, before.eventLog.length);
  });

  test('suspicion refuses outside night without changing state', () {
    final e = start();
    final before = e.match;
    expect(
      () => e.submitNightAction(
        seat: seatOf(e, Role.citizen),
        kind: NightActionKind.suspect,
        targetSeat: seatOf(e, Role.mafia),
      ),
      throwsStateError,
    );
    expect(identical(e.match, before), isTrue);
    expect(e.match.eventLog.length, before.eventLog.length);
  });

  test('mafia refused armed vote keeps quiet-night bullet', () {
    final e = start();
    advanceTo(e, Role.mafia);
    final seat = seatOf(e, Role.mafia);
    final dead = seatOf(e, Role.citizen);
    markDead(e, dead);
    final before = e.match.eventLog.length;
    expect(
      () => e.submitNightAction(
        seat: seat,
        kind: NightActionKind.mafiaVote,
        targetSeat: dead,
        useBullet: true,
      ),
      throwsStateError,
    );
    expect(e.match.eventLog.length, before);
    expect(e.canArmBullet(seat), isTrue);
    final valid = e.match.players.firstWhere(
      (p) => p.role == Role.citizen && p.status == PlayerStatus.alive,
    ).seat;
    e.submitNightAction(
      seat: seat,
      kind: NightActionKind.mafiaVote,
      targetSeat: valid,
      useBullet: true,
    );
    expect(e.match.eventLog.whereType<BulletSpent>().length, 1);
    expect(e.canArmBullet(seat), isFalse);
  });

  test('doctor refused armed wrong move keeps self-protection bullet', () {
    final e = start();
    advanceTo(e, Role.doctor);
    final seat = seatOf(e, Role.doctor);
    final target = seatOf(e, Role.citizen);
    final before = e.match.eventLog.length;
    expect(
      () => e.submitNightAction(
        seat: seat,
        kind: NightActionKind.suspect,
        targetSeat: target,
        useBullet: true,
      ),
      throwsStateError,
    );
    expect(e.match.eventLog.length, before);
    expect(e.canArmBullet(seat), isTrue);
    e.submitNightAction(
      seat: seat,
      kind: NightActionKind.protect,
      targetSeat: target,
      useBullet: true,
    );
    expect(e.match.eventLog.whereType<BulletSpent>().length, 1);
    expect(e.canArmBullet(seat), isFalse);
  });

  test('sniper refused armed suspicion keeps shot', () {
    final e = start();
    advanceTo(e, Role.sniper);
    final seat = seatOf(e, Role.sniper);
    final dead = seatOf(e, Role.citizen);
    markDead(e, dead);
    final before = e.match.eventLog.length;
    expect(
      () => e.submitNightAction(
        seat: seat,
        kind: NightActionKind.suspect,
        targetSeat: dead,
        useBullet: true,
      ),
      throwsStateError,
    );
    expect(e.match.eventLog.length, before);
    expect(e.canArmBullet(seat), isTrue);
    e.submitNightAction(
      seat: seat,
      kind: NightActionKind.suspect,
      targetSeat: seatOf(e, Role.mafia),
      useBullet: true,
    );
    expect(e.match.eventLog.whereType<BulletSpent>().length, 1);
    expect(e.canArmBullet(seat), isFalse);
  });
}
