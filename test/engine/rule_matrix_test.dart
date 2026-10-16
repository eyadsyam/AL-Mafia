import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
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
