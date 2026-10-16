import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:test/test.dart';

/// The Mafia core audit's case matrix, offline (docs/specs/17-roles-and-tools.md,
/// docs/plans/MAFIA-CORE-AUDIT-PLAN.md A2). One test per case; each names its
/// case id so a failure points back at the rule book.
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

  List<int> seatsOf(MatchEngine e, Role r) => [
    for (final p in e.match.players)
      if (p.role == r) p.seat,
  ];
  int seatOf(MatchEngine e, Role r) => seatsOf(e, r).first;

  /// Plays one night: [choice] returns (kind, target, useBullet) per seat;
  /// unlisted seats skip.
  void night(
    MatchEngine e,
    (NightActionKind, int, bool)? Function(int seat, Role role) choice,
  ) {
    e.beginNight();
    while (e.match.currentActorSeat != null) {
      final seat = e.match.currentActorSeat!;
      final role = e.match.players[seat].role;
      final c = choice(seat, role);
      if (c == null && role != Role.doctor) {
        e.skipNightAction(seat: seat);
        continue;
      }
      final pick =
          c ??
          (
            NightActionKind.protect,
            e.match.players
                .firstWhere(
                  (p) => p.seat != seat && p.status == PlayerStatus.alive,
                )
                .seat,
            false,
          );
      e.submitNightAction(
        seat: seat,
        kind: pick.$1,
        targetSeat: pick.$2,
        useBullet: pick.$3,
      );
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

  group('silence', () {
    test('F1: a seat killed the same night is not announced as silenced', () {
      final e = start(sevenWithSilencer, silencerOn);
      final citizens = seatsOf(e, Role.citizen);
      final target = citizens.first;
      night(e, (seat, role) {
        if (role == Role.silencer) {
          return (NightActionKind.silence, target, false);
        }
        if (role == Role.mafia) {
          return (NightActionKind.mafiaVote, target, false);
        }
        if (role == Role.doctor) {
          return (NightActionKind.protect, citizens.last, false);
        }
        return null;
      });
      final report = e.resolveNight();
      expect(report.victimSeats, [target]);
      expect(report.silencedSeat, isNull);
    });

    test('F1: a saved seat that was silenced stays silenced', () {
      final e = start(sevenWithSilencer, silencerOn);
      final citizens = seatsOf(e, Role.citizen);
      final target = citizens.first;
      night(e, (seat, role) {
        if (role == Role.silencer) {
          return (NightActionKind.silence, target, false);
        }
        if (role == Role.mafia) {
          return (NightActionKind.mafiaVote, target, false);
        }
        if (role == Role.doctor) {
          return (NightActionKind.protect, target, false);
        }
        return null;
      });
      final report = e.resolveNight();
      expect(report.victimSeats, isEmpty);
      expect(report.silencedSeat, target);
      expect(e.silencedSeatToday, target);
    });
  });

  group('saves', () {
    final roles = {
      Role.mafia: 2,
      Role.sniper: 1,
      Role.doctor: 1,
      Role.detective: 1,
      Role.citizen: 2,
    };

    test('RL17: a covered seat the Sniper takes is no save', () {
      const settings = MatchSettings(
        sniperEnabled: true,
        quietNightEnabled: false,
      );
      final e = start(roles, settings);
      final citizen = seatsOf(e, Role.citizen).first;
      night(e, (seat, role) {
        if (role == Role.mafia) {
          return (NightActionKind.mafiaVote, citizen, false);
        }
        if (role == Role.doctor) {
          return (NightActionKind.protect, citizen, false);
        }
        if (role == Role.sniper) {
          return (NightActionKind.suspect, citizen, true);
        }
        return null;
      });
      final report = e.resolveNight();
      expect(report.victimSeats, contains(citizen));
      expect(report.someoneSavedUnnamed, isFalse);
    });

    test('RL2: with no bullets (the fast preset) a save is told', () {
      const fast = MatchSettings(bulletsEnabled: false);
      final e = start({
        Role.mafia: 1,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 3,
      }, fast);
      final citizen = seatsOf(e, Role.citizen).first;
      night(e, (seat, role) {
        if (role == Role.mafia) {
          return (NightActionKind.mafiaVote, citizen, false);
        }
        if (role == Role.doctor) {
          return (NightActionKind.protect, citizen, false);
        }
        return null;
      });
      final report = e.resolveNight();
      expect(report.victimSeats, isEmpty);
      expect(report.someoneSavedUnnamed, isTrue);
    });

    test('RL2: with the quiet night on, a save reads as «nobody died»', () {
      const quiet = MatchSettings();
      final e = start({
        Role.mafia: 1,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 3,
      }, quiet);
      final citizen = seatsOf(e, Role.citizen).first;
      night(e, (seat, role) {
        if (role == Role.mafia) {
          return (NightActionKind.mafiaVote, citizen, false);
        }
        if (role == Role.doctor) {
          return (NightActionKind.protect, citizen, false);
        }
        return null;
      });
      final report = e.resolveNight();
      expect(report.victimSeats, isEmpty);
      expect(report.someoneSavedUnnamed, isFalse);
    });
  });

  group('deal', () {
    test('RL6: the Mafia and the Silencer know each other at the deal', () {
      final n = sevenWithSilencer.values.fold(0, (a, b) => a + b);
      final engine = MatchEngine(clock: Clocks.monotonic());
      engine.start(
        names: [for (var i = 0; i < n; i++) 'P$i'],
        roleCounts: sevenWithSilencer,
        settings: silencerOn,
        seed: 3,
      );
      final names = {for (final p in engine.match.players) p.seat: p.name};
      final mafiaSide = [
        for (final p in engine.match.players)
          if (p.role.alignment == Alignment.mafia) p.seat,
      ];
      for (var i = 0; i < n; i++) {
        final seen = engine.revealFor(i);
        if (mafiaSide.contains(i)) {
          expect(seen.teammateNames, [
            for (final other in mafiaSide)
              if (other != i) names[other],
          ]);
        } else {
          expect(seen.teammateNames, isEmpty);
        }
        engine.confirmRevealed();
      }
    });
  });

  group('engine guards', () {
    test('RL18: a night move on a dead seat is refused by the engine', () {
      final e = start(sevenWithSilencer, silencerOn);
      final gone = seatsOf(e, Role.citizen).first;
      e.beginNight();
      final m = e.match;
      e.match = m.copyWith(
        players: [
          for (final p in m.players)
            if (p.seat == gone)
              p.copyWith(
                status: PlayerStatus.dead,
                eliminatedOn: const PhaseRef(phase: GamePhase.night, number: 1),
              )
            else
              p,
        ],
      );
      final actor = e.match.currentActorSeat!;
      final kind = e.match.players[actor].role.nightAction!;
      expect(
        () => e.submitNightAction(seat: actor, kind: kind, targetSeat: gone),
        throwsStateError,
      );
    });

    test('RL18: removing a player mid-day keeps the match going', () {
      final e = start(sevenWithSilencer, silencerOn);
      final citizens = seatsOf(e, Role.citizen);
      e.removePlayer(citizens.first);
      expect(e.match.outcome, isNull);
      expect(e.match.players[citizens.first].status, PlayerStatus.dead);
    });

    test('RL18: a removal that reaches parity ends the match', () {
      final e = start({
        Role.mafia: 1,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 2,
      }, const MatchSettings(quietNightEnabled: false));
      final town = [
        for (final p in e.match.players)
          if (p.role.alignment == Alignment.town) p.seat,
      ];
      e.removePlayer(town[0]);
      e.removePlayer(town[1]);
      e.removePlayer(town[2]);
      expect(e.match.outcome?.winner, Alignment.mafia);
      expect(e.match.phase, GamePhase.result);
    });
  });

  group('ties', () {
    test('F4: a split Mafia vote is drawn from the seats in seat order', () {
      // Two killers each pick a different citizen; whichever order they act
      // in, the same seed must take the same victim.
      final roles = {
        Role.mafia: 2,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 4,
      };
      const settings = MatchSettings(quietNightEnabled: false);
      int? victimWith(bool lowFirst) {
        final e = start(roles, settings, seed: 11);
        final killers = seatsOf(e, Role.mafia);
        final citizens = seatsOf(e, Role.citizen);
        final a = citizens.first, b = citizens.last;
        final first = killers.first;
        night(e, (seat, role) {
          if (role != Role.mafia) {
            return role == Role.doctor
                ? (NightActionKind.protect, citizens[1], false)
                : null;
          }
          final low = seat == first ? lowFirst : !lowFirst;
          return (NightActionKind.mafiaVote, low ? a : b, false);
        });
        return e.resolveNight().victimSeat;
      }

      expect(victimWith(true), victimWith(false));
    });
  });
}
