import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/legal_moves.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:test/test.dart';

/// Owner rules for the three new roles (docs/plans/STORE-ROLES-STORIES-PLAN.md
/// part 2): silencer, elder, sniper.
void main() {
  MatchEngine start(
    Map<Role, int> roles,
    MatchSettings settings, {
    int seed = 3,
  }) {
    final n = roles.values.fold(0, (a, b) => a + b);
    final engine = MatchEngine(clock: Clocks.monotonic());
    engine.start(
      names: [for (var i = 0; i < n; i++) 'P$i'],
      roleCounts: roles,
      settings: settings,
      seed: seed,
    );
    for (var i = 0; i < n; i++) {
      engine.revealFor(i);
      engine.confirmRevealed();
    }
    return engine;
  }

  int seatOf(MatchEngine e, Role r) =>
      e.match.players.firstWhere((p) => p.role == r).seat;

  List<int> seatsOf(MatchEngine e, Role r) => [
    for (final p in e.match.players)
      if (p.role == r) p.seat,
  ];

  /// Plays one night: [choice] returns (kind, target, useBullet) per seat;
  /// unlisted seats act on the first other living player they may target.
  void night(
    MatchEngine e,
    (NightActionKind, int, bool)? Function(int seat, Role role) choice,
  ) {
    e.beginNight();
    while (e.match.currentActorSeat != null) {
      final seat = e.match.currentActorSeat!;
      final role = e.match.players[seat].role;
      final c = choice(seat, role);
      if (c != null) {
        e.submitNightAction(
          seat: seat,
          kind: c.$1,
          targetSeat: c.$2,
          useBullet: c.$3,
        );
        continue;
      }
      final other = e.match.players
          .firstWhere(
            (p) =>
                p.seat != seat &&
                p.status == PlayerStatus.alive &&
                !(role.alignment == Alignment.mafia &&
                    p.role.alignment == Alignment.mafia),
          )
          .seat;
      final kind = switch (role) {
        Role.mafia => NightActionKind.mafiaVote,
        Role.doctor => NightActionKind.protect,
        Role.detective => NightActionKind.investigate,
        Role.silencer => NightActionKind.silence,
        _ => NightActionKind.suspect,
      };
      e.submitNightAction(seat: seat, kind: kind, targetSeat: other);
    }
  }

  const silencerOn = MatchSettings(
    silencerEnabled: true,
    quietNightEnabled: false,
  );
  final sevenWithSilencer = {
    Role.mafia: 1,
    Role.silencer: 1,
    Role.doctor: 1,
    Role.detective: 1,
    Role.citizen: 3,
  };

  group('silencer', () {
    test('silences one player for the next day; the kill still lands', () {
      final e = start(sevenWithSilencer, silencerOn);
      final citizens = seatsOf(e, Role.citizen);
      final silenced = citizens.first;
      final victim = citizens.last;
      night(e, (seat, role) {
        if (role == Role.silencer) {
          return (NightActionKind.silence, silenced, false);
        }
        if (role == Role.mafia) {
          return (NightActionKind.mafiaVote, victim, false);
        }
        if (role == Role.doctor) {
          return (NightActionKind.protect, citizens[1], false);
        }
        return null;
      });
      final report = e.resolveNight();
      expect(report.silencedSeat, silenced);
      expect(report.victimSeats, [victim]);
      expect(e.silencedSeatToday, silenced);
    });

    test('a silencer may silence himself', () {
      final e = start(sevenWithSilencer, silencerOn);
      final me = seatOf(e, Role.silencer);
      night(e, (seat, role) {
        if (role == Role.silencer) return (NightActionKind.silence, me, false);
        return null;
      });
      expect(e.resolveNight().silencedSeat, me);
    });

    test('a lone silencer is offered only moves the engine accepts', () {
      const gone = PhaseRef(phase: GamePhase.night, number: 1);
      for (var seed = 1; seed <= 12; seed++) {
        final e = start(sevenWithSilencer, silencerOn, seed: seed);
        e.beginNight();
        final silencer = seatOf(e, Role.silencer);
        final mafia = seatOf(e, Role.mafia);
        final m = e.match;
        e.match = m.copyWith(
          players: [
            for (final p in m.players)
              if (p.seat == mafia) p.copyWith(status: PlayerStatus.dead, eliminatedOn: gone) else p,
          ],
          currentActorSeat: silencer,
        );
        final moves = legalMoves(e.match);
        final targets = [
          for (final move in moves.whereType<NightActionMove>()) move.targetSeat,
        ];
        expect(targets, isNotEmpty);
        expect(targets, isNot(contains(silencer)), reason: 'seed $seed');
        expect(targets, isNot(contains(mafia)), reason: 'seed $seed');
        // The timer default must apply for every phase index.
        for (var index = 0; index < 20; index++) {
          final copy = start(sevenWithSilencer, silencerOn, seed: seed)
            ..beginNight();
          final cm = copy.match;
          copy.match = cm.copyWith(
            players: [
              for (final p in cm.players)
                if (p.seat == mafia)
                  p.copyWith(status: PlayerStatus.dead, eliminatedOn: gone)
                else
                  p,
            ],
            currentActorSeat: silencer,
          );
          final move = defaultMoveOnExpiry(copy.match, phaseIndex: index);
          expect(move, isNotNull);
          expect(() => move!.apply(copy), returnsNormally,
              reason: 'seed $seed index $index');
        }
      }
    });

    test('silencer requires two mafia', () {
      expect(
        () => start({
          Role.silencer: 1,
          Role.doctor: 1,
          Role.detective: 1,
          Role.citizen: 4,
        }, silencerOn),
        throwsArgumentError,
      );
    });
  });

  group('elder', () {
    const elderOn = MatchSettings(elderEnabled: true);
    final six = {
      Role.mafia: 1,
      Role.elder: 1,
      Role.doctor: 1,
      Role.detective: 1,
      Role.citizen: 2,
    };

    test('weighs 1 before the reveal and 3 after it', () {
      final e = start(six, elderOn);
      final elder = seatOf(e, Role.elder);
      expect(e.voteWeightFor(elder), 1);
      night(e, (_, _) => null);
      e.resolveNight();
      if (e.match.players[elder].status != PlayerStatus.alive) return;
      e.beginDay();
      e.revealElder(elder);
      expect(e.isElderRevealed(elder), isTrue);
      expect(e.voteWeightFor(elder), 3);
    });

    test('only the elder may reveal', () {
      final e = start(six, elderOn);
      night(e, (_, _) => null);
      e.resolveNight();
      e.beginDay();
      final citizen = e.match.players
          .firstWhere(
            (p) => p.role == Role.citizen && p.status == PlayerStatus.alive,
          )
          .seat;
      expect(() => e.revealElder(citizen), throwsStateError);
    });

    test('needs six players', () {
      expect(
        () => start({
          Role.mafia: 1,
          Role.elder: 1,
          Role.doctor: 1,
          Role.detective: 1,
          Role.citizen: 1,
        }, elderOn),
        throwsArgumentError,
      );
    });
  });

  group('sniper', () {
    const sniperOn = MatchSettings(
      sniperEnabled: true,
      quietNightEnabled: false,
    );
    final seven = {
      Role.mafia: 2,
      Role.sniper: 1,
      Role.doctor: 1,
      Role.detective: 1,
      Role.citizen: 2,
    };

    test('a hit on mafia kills only the mafioso, even when protected', () {
      final e = start(seven, sniperOn);
      final mafia = seatsOf(e, Role.mafia).first;
      final sniper = seatOf(e, Role.sniper);
      night(e, (seat, role) {
        if (role == Role.sniper) return (NightActionKind.suspect, mafia, true);
        if (role == Role.doctor) {
          return (NightActionKind.protect, mafia, false);
        }
        return null;
      });
      final report = e.resolveNight();
      expect(report.victimSeats.contains(mafia), isTrue);
      expect(report.victimSeats.contains(sniper), isFalse);
    });

    test('a miss takes the target and the sniper', () {
      final e = start(seven, sniperOn);
      final sniper = seatOf(e, Role.sniper);
      final citizen = seatsOf(e, Role.citizen).first;
      night(e, (seat, role) {
        if (role == Role.sniper) {
          return (NightActionKind.suspect, citizen, true);
        }
        return null;
      });
      final report = e.resolveNight();
      expect(report.victimSeats, containsAll([citizen, sniper]));
    });

    test('needs seven players', () {
      expect(
        () => start({
          Role.mafia: 1,
          Role.sniper: 1,
          Role.doctor: 1,
          Role.detective: 1,
          Role.citizen: 2,
        }, sniperOn),
        throwsArgumentError,
      );
    });
  });
}
