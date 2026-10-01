/// The owner's night rules of 2026-10-01, offline half. The online half lives
/// in `supabase/functions/submit_night_action` and `resolve_night`.
library;

import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/legal_moves.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:test/test.dart';

MatchEngine _night(Map<Role, int> counts, {int seed = 7}) {
  final n = counts.values.fold(0, (a, b) => a + b);
  final engine = MatchEngine(clock: Clocks.monotonic());
  engine.start(
    names: [for (var i = 0; i < n; i++) 'P$i'],
    roleCounts: counts,
    settings: const MatchSettings(quietNightEnabled: false),
    seed: seed,
  );
  for (var i = 0; i < n; i++) {
    engine.revealFor(i);
    engine.confirmRevealed();
  }
  engine.beginNight();
  return engine;
}

List<int> _seats(MatchEngine e, Role role) => [
  for (final p in e.match.players)
    if (p.role == role) p.seat,
];

void main() {
  group('a Mafioso never chooses a fellow Mafioso', () {
    const counts = {
      Role.mafia: 3,
      Role.doctor: 1,
      Role.detective: 1,
      Role.citizen: 4,
    };

    test('the teammates are drawn but blocked, and not legal moves', () {
      final e = _night(counts);
      final mafia = _seats(e, Role.mafia).toSet();
      while (e.match.currentActorSeat != null) {
        final seat = e.match.currentActorSeat!;
        if (e.match.players[seat].role == Role.mafia) {
          final view = e.actorView(seat);
          expect(view.blockedTargets.toSet(), mafia.difference({seat}));
          expect(view.targets.toSet().containsAll(view.blockedTargets), isTrue);
          final legalTargets = legalMoves(e.match)
              .whereType<NightActionMove>()
              .map((m) => m.targetSeat)
              .toSet();
          expect(legalTargets.intersection(mafia), isEmpty);
          final teammate = mafia.firstWhere((s) => s != seat);
          expect(
            () => e.submitNightAction(
              seat: seat,
              kind: NightActionKind.mafiaVote,
              targetSeat: teammate,
            ),
            throwsStateError,
          );
          e.skipNightAction(seat: seat);
        } else {
          expect(e.actorView(seat).blockedTargets, isEmpty);
          e.skipNightAction(seat: seat);
        }
      }
    });
  });

  group('two Doctors protect one seat between them', () {
    const counts = {
      Role.mafia: 2,
      Role.doctor: 2,
      Role.detective: 1,
      Role.citizen: 4,
    };

    /// Plays a night where the Mafia kill [victimOf] and the two Doctors
    /// cover [aOf] and [bOf]; returns whether the victim survived.
    bool survived(int seed, {required bool doctorsAgree}) {
      final e = _night(counts, seed: seed);
      final citizens = _seats(e, Role.citizen);
      final victim = citizens[0];
      final other = citizens[1];
      final doctors = _seats(e, Role.doctor);
      while (e.match.currentActorSeat != null) {
        final seat = e.match.currentActorSeat!;
        switch (e.match.players[seat].role) {
          case Role.mafia:
            e.submitNightAction(
              seat: seat,
              kind: NightActionKind.mafiaVote,
              targetSeat: victim,
            );
          case Role.doctor:
            final first = seat == doctors.first;
            e.submitNightAction(
              seat: seat,
              kind: NightActionKind.protect,
              targetSeat: first || doctorsAgree ? victim : other,
            );
          default:
            e.skipNightAction(seat: seat);
        }
      }
      return e.resolveNight().victimSeat == null;
    }

    test('when they agree, their seat is protected', () {
      for (var seed = 0; seed < 20; seed++) {
        expect(survived(seed, doctorsAgree: true), isTrue);
      }
    });

    test('when they split, one of the two is drawn: sometimes each', () {
      final outcomes = {
        for (var seed = 0; seed < 40; seed++)
          survived(seed, doctorsAgree: false),
      };
      // Under the old union both seats were covered and the victim always
      // lived. Now only one is, so across seeds the victim sometimes dies.
      expect(outcomes, {true, false});
    });

    test('the draw is seeded: the same match resolves the same way', () {
      for (var seed = 0; seed < 10; seed++) {
        expect(
          survived(seed, doctorsAgree: false),
          survived(seed, doctorsAgree: false),
        );
      }
    });
  });
}
