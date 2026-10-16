import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/balance_guard.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:mafia_master/engine/presets.dart';
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

  /// Who the Doctor covered last, per engine, so the default cover never
  /// repeats a seat two nights running (RL3).
  final lastCover = Expando<int>();

  /// Plays one night: [choice] returns (kind, target, useBullet) per seat;
  /// unlisted seats skip; an unlisted Doctor covers the first other living
  /// seat that was not last night's.
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
                  (p) =>
                      p.seat != seat &&
                      p.status == PlayerStatus.alive &&
                      p.seat != lastCover[e],
                )
                .seat,
            false,
          );
      if (pick.$1 == NightActionKind.protect) lastCover[e] = pick.$2;
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
      final kind = e.match.players[actor].role.nightAction;
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

  // The candidate cases below use the same public transitions as the table.
  const plain = MatchSettings(
    quietNightEnabled: false,
    traceEnabled: false,
    confrontationEnabled: false,
  );
  const sniperOn = MatchSettings(
    sniperEnabled: true,
    quietNightEnabled: false,
    traceEnabled: false,
    confrontationEnabled: false,
  );
  const elderOn = MatchSettings(
    elderEnabled: true,
    quietNightEnabled: false,
    traceEnabled: false,
    confrontationEnabled: false,
  );
  final standard = {
    Role.mafia: 2,
    Role.doctor: 1,
    Role.detective: 1,
    Role.citizen: 3,
  };
  final withSniper = {
    Role.mafia: 2,
    Role.doctor: 1,
    Role.sniper: 1,
    Role.citizen: 3,
  };

  void toVoting(MatchEngine e) {
    e.beginDay();
    while (e.match.phase == GamePhase.openingRound) {
      final actor = e.match.currentActorSeat!;
      final target = e.match.players.firstWhere(
        (p) => p.status == PlayerStatus.alive && p.seat != actor,
      ).seat;
      e.submitOpeningAccusation(seat: actor, targetSeat: target);
    }
    if (e.match.phase == GamePhase.confrontation) e.endConfrontation();
    e.beginVoting();
  }

  void abstainOrSkip(MatchEngine e) {
    while (e.match.phase == GamePhase.voting) {
      final actor = e.match.currentActorSeat!;
      if (e.silencedSeatToday == actor) {
        e.skipSilencedVote(actor);
      } else {
        e.submitVote(seat: actor, voterSeat: actor, targetSeat: null);
      }
    }
  }

  void nextNight(MatchEngine e) {
    toVoting(e);
    abstainOrSkip(e);
    e.resolveDayVote();
    expect(e.winCheck(), isNull);
  }

  int? saved(MatchEngine e) => e.match.eventLog
      .whereType<NightResolved>()
      .last
      .savedSeat;

  group('doctor', () {
    test('C1: covered Mafia target survives and is recorded', () {
      final e = start(standard, plain);
      final x = seatOf(e, Role.citizen);
      night(e, (_, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, x, false),
        Role.doctor => (NightActionKind.protect, x, false),
        _ => null,
      });
      final report = e.resolveNight();
      expect(report.victimSeats, isEmpty);
      expect(saved(e), x);
      expect(report.someoneSavedUnnamed, isTrue);
    });

    test('C2: split Mafia vote saves X only when the draw selects X', () {
      for (var seed = 1; seed <= 20; seed++) {
        final e = start(standard, plain, seed: seed);
        final m = seatsOf(e, Role.mafia);
        final c = seatsOf(e, Role.citizen);
        night(e, (seat, role) => switch (role) {
          Role.mafia => (NightActionKind.mafiaVote, seat == m.first ? c[0] : c[1], false),
          Role.doctor => (NightActionKind.protect, c[0], false),
          _ => null,
        });
        final r = e.resolveNight();
        expect(r.victimSeats.isEmpty, saved(e) == c[0], reason: 'seed $seed');
        if (r.victimSeats.isNotEmpty) expect(r.victimSeats, [c[1]]);
      }
    });

    test('C3: doctor self bullet blocks a kill and is spent', () {
      final e = start(standard, plain);
      final d = seatOf(e, Role.doctor);
      final c = seatOf(e, Role.citizen);
      night(e, (_, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, d, false),
        Role.doctor => (NightActionKind.protect, c, true),
        _ => null,
      });
      expect(e.resolveNight().victimSeats, isEmpty);
      expect(saved(e), d);
      expect(e.canArmBullet(d), isFalse);
    });

    test('C4: doctor cannot spend self bullet twice', () {
      final e = start(standard, plain);
      final d = seatOf(e, Role.doctor), c = seatOf(e, Role.citizen);
      night(e, (_, role) => role == Role.doctor
          ? (NightActionKind.protect, c, true) : null);
      e.resolveNight();
      nextNight(e);
      night(e, (_, _) => null);
      e.resolveNight();
      nextNight(e);
      e.beginNight();
      while (e.match.currentActorSeat != d) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      expect(() => e.submitNightAction(seat: d, kind: NightActionKind.protect,
          targetSeat: c, useBullet: true), throwsStateError);
    });

    test('C5: doctor cannot cover the same player on consecutive nights', () {
      final e = start(standard, plain);
      final d = seatOf(e, Role.doctor), c = seatOf(e, Role.citizen);
      night(e, (_, role) => role == Role.doctor
          ? (NightActionKind.protect, c, false) : null);
      e.resolveNight();
      nextNight(e);
      e.beginNight();
      while (e.match.currentActorSeat != d) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      expect(() => e.submitNightAction(seat: d, kind: NightActionKind.protect,
          targetSeat: c), throwsStateError);
    });

    test('C6: an intervening self-protection permits the previous target', () {
      final e = start(standard, plain);
      final d = seatOf(e, Role.doctor), c = seatOf(e, Role.citizen);
      night(e, (_, role) => role == Role.doctor
          ? (NightActionKind.protect, c, false) : null);
      e.resolveNight(); nextNight(e);
      night(e, (_, role) => role == Role.doctor
          ? (NightActionKind.protect, c, true) : null);
      e.resolveNight(); nextNight(e);
      night(e, (_, role) => role == Role.doctor
          ? (NightActionKind.protect, c, false) : null);
      e.resolveNight();
      expect(e.match.eventLog.whereType<ProtectCast>()
          .where((p) => p.actorSeat == d).map((p) => p.targetSeat), [c, d, c]);
    });

    test('C7: doctor plain skip protects the first legal target', () {
      final e = start(standard, plain);
      final d = seatOf(e, Role.doctor);
      e.beginNight();
      while (e.match.currentActorSeat != d) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      final first = e.match.players.firstWhere((p) => p.seat != d).seat;
      e.skipNightAction(seat: d);
      expect(e.match.eventLog.whereType<ProtectCast>().last.targetSeat, first);
    });

    test('C8: tied doctor votes protect exactly one seat', () {
      final roles = {Role.mafia: 2, Role.doctor: 2, Role.citizen: 4};
      for (var seed = 1; seed <= 20; seed++) {
        final e = start(roles, plain, seed: seed);
        final doctors = seatsOf(e, Role.doctor), c = seatsOf(e, Role.citizen);
        night(e, (seat, role) => switch (role) {
          Role.mafia => (NightActionKind.mafiaVote, c[0], false),
          Role.doctor => (NightActionKind.protect,
              seat == doctors.first ? c[0] : c[1], false),
          _ => null,
        });
        final r = e.resolveNight();
        expect(r.victimSeats, anyOf(isEmpty, [c[0]]));
        expect(saved(e) == c[0], r.victimSeats.isEmpty);
      }
    });

    test('C9: doctor cannot stop a town sniper shot', () {
      final e = start(withSniper, sniperOn);
      final x = seatOf(e, Role.citizen), s = seatOf(e, Role.sniper);
      night(e, (_, role) => switch (role) {
        Role.doctor => (NightActionKind.protect, x, false),
        Role.sniper => (NightActionKind.suspect, x, true),
        _ => null,
      });
      expect(e.resolveNight().victimSeats, containsAll([x, s]));
    });

    test('C10: protected Mafia target shot by sniper is not a save', () {
      final e = start(withSniper, sniperOn);
      final x = seatOf(e, Role.citizen), s = seatOf(e, Role.sniper);
      night(e, (_, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, x, false),
        Role.doctor => (NightActionKind.protect, x, false),
        Role.sniper => (NightActionKind.suspect, x, true),
        _ => null,
      });
      final r = e.resolveNight();
      expect(r.victimSeats, containsAll([x, s]));
      expect(saved(e), isNull);
      expect(r.someoneSavedUnnamed, isFalse);
    });

    test('C11: doctor protection still resolves when doctor dies', () {
      final e = start(standard, plain);
      final d = seatOf(e, Role.doctor), x = seatOf(e, Role.citizen);
      night(e, (_, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, d, false),
        Role.doctor => (NightActionKind.protect, x, false),
        _ => null,
      });
      expect(e.resolveNight().victimSeats, [d]);
      expect(e.match.eventLog.whereType<ProtectCast>().last.targetSeat, x);
    });

    test('C12: doctor cannot save a mafioso from sniper', () {
      final e = start(withSniper, sniperOn);
      final m = seatOf(e, Role.mafia);
      night(e, (_, role) => switch (role) {
        Role.doctor => (NightActionKind.protect, m, false),
        Role.sniper => (NightActionKind.suspect, m, true),
        _ => null,
      });
      expect(e.resolveNight().victimSeats, [m]);
    });

    test('C13: death of the last doctor leaves no later protection', () {
      final e = start(standard, plain);
      final d = seatOf(e, Role.doctor), x = seatOf(e, Role.citizen);
      night(e, (_, role) => role == Role.mafia
          ? (NightActionKind.mafiaVote, d, false) : null);
      expect(e.resolveNight().victimSeats, [d]);
      nextNight(e);
      night(e, (_, role) => role == Role.mafia
          ? (NightActionKind.mafiaVote, x, false) : null);
      expect(e.resolveNight().victimSeats, [x]);
    });

    test('C14: fast preset announces a doctor save', () {
      final e = start(standard, const MatchSettings(bulletsEnabled: false));
      final x = seatOf(e, Role.citizen);
      night(e, (_, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, x, false),
        Role.doctor => (NightActionKind.protect, x, false),
        _ => null,
      });
      expect(e.resolveNight().someoneSavedUnnamed, isTrue);
    });
  });

  group('sniper', () {
    test('C15: a mafia shot kills the mafioso and spares the sniper', () {
      final e = start(withSniper, sniperOn);
      final m = seatOf(e, Role.mafia), s = seatOf(e, Role.sniper);
      night(e, (_, role) => role == Role.sniper
          ? (NightActionKind.suspect, m, true) : null);
      expect(e.resolveNight().victimSeats, [m]);
      expect(e.match.players[s].status, PlayerStatus.alive);
    });

    test('C16: a citizen shot names both citizen and sniper deaths', () {
      final e = start(withSniper, sniperOn);
      final x = seatOf(e, Role.citizen), s = seatOf(e, Role.sniper);
      night(e, (_, role) => role == Role.sniper
          ? (NightActionKind.suspect, x, true) : null);
      expect(e.resolveNight().victimSeats, containsAll([x, s]));
    });

    test('C17: silencer is mafia-aligned for a sniper shot', () {
      final e = start({Role.mafia: 1, Role.silencer: 1, Role.sniper: 1,
        Role.doctor: 1, Role.citizen: 3},
        sniperOn.copyWith(silencerEnabled: true));
      final s = seatOf(e, Role.silencer), sniper = seatOf(e, Role.sniper);
      night(e, (_, role) => role == Role.sniper
          ? (NightActionKind.suspect, s, true) : null);
      expect(e.resolveNight().victimSeats, [s]);
      expect(e.match.players[sniper].status, PlayerStatus.alive);
    });

    test('C18: shooting elder or detective kills shooter too', () {
      for (final targetRole in [Role.elder, Role.detective]) {
        final roles = {Role.mafia: 2, Role.sniper: 1,
          targetRole: 1, Role.citizen: 3};
        final e = start(roles,
            sniperOn.copyWith(elderEnabled: targetRole == Role.elder));
        final x = seatOf(e, targetRole), s = seatOf(e, Role.sniper);
        night(e, (_, role) => role == Role.sniper
            ? (NightActionKind.suspect, x, true) : null);
        expect(e.resolveNight().victimSeats, containsAll([x, s]));
      }
    });

    test('C19: a killed sniper still lands its mafia shot', () {
      final e = start(withSniper, sniperOn);
      final m = seatOf(e, Role.mafia), s = seatOf(e, Role.sniper);
      night(e, (_, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, s, false),
        Role.sniper => (NightActionKind.suspect, m, true),
        _ => null,
      });
      expect(e.resolveNight().victimSeats, containsAll([m, s]));
    });

    test('C20: second sniper bullet is refused', () {
      final e = start(withSniper, sniperOn);
      final m = seatOf(e, Role.mafia), s = seatOf(e, Role.sniper);
      night(e, (_, role) => role == Role.sniper
          ? (NightActionKind.suspect, m, true) : null);
      e.resolveNight(); nextNight(e);
      e.beginNight();
      while (e.match.currentActorSeat != s) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      expect(() => e.submitNightAction(seat: s, kind: NightActionKind.suspect,
          targetSeat: seatOf(e, Role.citizen), useBullet: true), throwsStateError);
    });

    test('C21: unarmed sniper suspicion does not kill', () {
      final e = start(withSniper, sniperOn);
      final x = seatOf(e, Role.citizen);
      night(e, (_, role) => role == Role.sniper
          ? (NightActionKind.suspect, x, false) : null);
      expect(e.resolveNight().victimSeats, isEmpty);
      expect(e.match.eventLog.whereType<SuspectCast>().last.targetSeat, x);
    });

    test('C22: overlapping kill and town shot deduplicate the target', () {
      final e = start(withSniper, sniperOn);
      final x = seatOf(e, Role.citizen), s = seatOf(e, Role.sniper);
      night(e, (_, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, x, false),
        Role.sniper => (NightActionKind.suspect, x, true),
        _ => null,
      });
      expect(e.resolveNight().victimSeats.toSet(), {x, s});
      expect(e.match.eventLog.whereType<NightResolved>().last.victimSeats.length, 2);
    });

    test('C23: last mafioso shot ends in town win after morning', () {
      final e = start({Role.mafia: 1, Role.sniper: 1,
        Role.doctor: 1, Role.citizen: 4}, sniperOn);
      final m = seatOf(e, Role.mafia);
      night(e, (_, role) => role == Role.sniper
          ? (NightActionKind.suspect, m, true) : null);
      expect(e.resolveNight().victimSeats, [m]);
      expect(e.match.phase, GamePhase.morning);
      expect(e.concludeAfterNight(), Alignment.town);
    });

    test('C24: town shot that reaches parity awards mafia after morning', () {
      final e = start({Role.mafia: 2, Role.sniper: 1,
        Role.doctor: 1, Role.citizen: 3}, sniperOn);
      final c = seatsOf(e, Role.citizen);
      night(e, (_, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, c.last, false),
        Role.sniper => (NightActionKind.suspect, c.first, true),
        Role.doctor => (NightActionKind.protect, seatOf(e, Role.mafia), false),
        _ => null,
      });
      expect(e.resolveNight().victimSeats.length, 3);
      expect(e.concludeAfterNight(), Alignment.mafia);
    });

    test('C26: Mafia quiet night does not cancel a sniper shot', () {
      final e = start(withSniper, sniperOn.copyWith(quietNightEnabled: true));
      final x = seatOf(e, Role.citizen), m = seatOf(e, Role.mafia);
      e.beginNight();
      while (e.match.currentActorSeat != null) {
        final seat = e.match.currentActorSeat!, role = e.match.players[seat].role;
        if (role == Role.mafia && seat == m) {
          e.skipNightAction(seat: seat, useBullet: true);
        } else if (role == Role.mafia) {
          e.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote,
            targetSeat: x);
        } else if (role == Role.sniper) {
          e.submitNightAction(seat: seat, kind: NightActionKind.suspect,
            targetSeat: x, useBullet: true);
        } else {
          e.skipNightAction(seat: seat);
        }
      }
      expect(e.resolveNight().victimSeats, contains(x));
    });

    test('C27: disabling general bullets still permits sniper shot', () {
      final e = start(withSniper, sniperOn.copyWith(bulletsEnabled: false));
      final m = seatOf(e, Role.mafia), s = seatOf(e, Role.sniper);
      expect(e.canArmBullet(s), isTrue);
      night(e, (_, role) => role == Role.sniper
          ? (NightActionKind.suspect, m, true) : null);
      expect(e.resolveNight().victimSeats, [m]);
    });
  });

  group('silencer', () {
    test('C28: silenced seat cannot cast a ballot', () {
      final e = start(sevenWithSilencer, silencerOn);
      final x = seatOf(e, Role.citizen);
      night(e, (_, role) => role == Role.silencer
          ? (NightActionKind.silence, x, false) : null);
      e.resolveNight(); toVoting(e);
      while (e.match.currentActorSeat != x) {
        final a = e.match.currentActorSeat!;
        e.submitVote(seat: a, voterSeat: a, targetSeat: null);
      }
      expect(() => e.submitVote(seat: x, voterSeat: x,
          targetSeat: seatOf(e, Role.mafia)), throwsStateError);
      e.skipSilencedVote(x);
    });

    test('C29: silenced seat may be voted out', () {
      final e = start(sevenWithSilencer, silencerOn);
      final x = seatOf(e, Role.citizen);
      night(e, (_, role) => role == Role.silencer
          ? (NightActionKind.silence, x, false) : null);
      e.resolveNight(); toVoting(e);
      while (e.match.phase == GamePhase.voting) {
        final a = e.match.currentActorSeat!;
        if (a == x) { e.skipSilencedVote(a); continue; }
        e.submitVote(seat: a, voterSeat: a, targetSeat: x);
      }
      expect(e.resolveDayVote().eliminatedSeat, x);
    });

    test('C30: a dead silence target has no silence mark', () {
      final e = start(sevenWithSilencer, silencerOn);
      final x = seatOf(e, Role.citizen);
      night(e, (_, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, x, false),
        Role.silencer => (NightActionKind.silence, x, false),
        _ => null,
      });
      final r = e.resolveNight();
      expect(r.victimSeats, [x]);
      expect(r.silencedSeat, isNull);
    });

    test('C31: silencer inherits kill after last killer leaves', () {
      final e = start(sevenWithSilencer, silencerOn);
      final m = seatOf(e, Role.mafia), s = seatOf(e, Role.silencer);
      night(e, (_, _) => null); e.resolveNight(); nextNight(e);
      night(e, (_, _) => null); e.resolveNight(); toVoting(e);
      while (e.match.phase == GamePhase.voting) {
        final a = e.match.currentActorSeat!;
        e.submitVote(seat: a, voterSeat: a,
          targetSeat: a == m ? null : m);
      }
      expect(e.resolveDayVote().eliminatedSeat, m);
      expect(e.winCheck(), isNull);
      final x = seatOf(e, Role.citizen);
      night(e, (_, role) => role == Role.silencer
          ? (NightActionKind.silence, x, false) : null);
      expect(e.resolveNight().victimSeats, [x]);
      expect(e.match.eventLog.whereType<MafiaVoteCast>().last.actorSeat, s);
    });

    test('C32: silence persists when last killer is shot that night', () {
      final e = start({Role.mafia: 1, Role.silencer: 1,
        Role.sniper: 1, Role.doctor: 1, Role.citizen: 3},
        sniperOn.copyWith(silencerEnabled: true));
      final m = seatOf(e, Role.mafia), y = seatOf(e, Role.citizen);
      night(e, (_, _) => null); e.resolveNight(); nextNight(e);
      night(e, (_, role) => switch (role) {
        Role.silencer => (NightActionKind.silence, y, false),
        Role.sniper => (NightActionKind.suspect, m, true),
        _ => null,
      });
      final r = e.resolveNight();
      expect(r.victimSeats, [m]);
      expect(r.silencedSeat, y);
      nextNight(e);
      final x = seatsOf(e, Role.citizen).last;
      night(e, (_, role) => role == Role.silencer
          ? (NightActionKind.silence, x, false) : null);
      expect(e.resolveNight().victimSeats, [x]);
    });

    test('C33: silencer may silence itself and loses its vote', () {
      final e = start(sevenWithSilencer, silencerOn);
      final s = seatOf(e, Role.silencer);
      night(e, (_, role) => role == Role.silencer
          ? (NightActionKind.silence, s, false) : null);
      expect(e.resolveNight().silencedSeat, s);
      toVoting(e);
      while (e.match.currentActorSeat != s) {
        final a = e.match.currentActorSeat!;
        e.submitVote(seat: a, voterSeat: a, targetSeat: null);
      }
      expect(() => e.submitVote(seat: s, voterSeat: s, targetSeat: null),
          throwsStateError);
    });

    test('C34: silencer may silence a teammate', () {
      final e = start(sevenWithSilencer, silencerOn);
      final m = seatOf(e, Role.mafia);
      night(e, (_, role) => role == Role.silencer
          ? (NightActionKind.silence, m, false) : null);
      expect(e.resolveNight().silencedSeat, m);
    });

    test('C35: silenced elder may reveal but cannot vote', () {
      final e = start({Role.mafia: 1, Role.silencer: 1,
        Role.elder: 1, Role.citizen: 4},
        silencerOn.copyWith(elderEnabled: true));
      final elder = seatOf(e, Role.elder);
      night(e, (_, role) => role == Role.silencer
          ? (NightActionKind.silence, elder, false) : null);
      e.resolveNight();
      e.beginDay(); e.revealElder(elder);
      expect(e.voteWeightFor(elder), 3);
      e.beginVoting();
      while (e.match.currentActorSeat != elder) {
        final a = e.match.currentActorSeat!;
        e.submitVote(seat: a, voterSeat: a, targetSeat: null);
      }
      expect(() => e.submitVote(seat: elder, voterSeat: elder,
          targetSeat: seatOf(e, Role.mafia)), throwsStateError);
    });

    test('C38: offline silence is a public mark with no talk turn', () {
      final e = start(sevenWithSilencer, silencerOn);
      final x = seatOf(e, Role.citizen);
      night(e, (_, role) => role == Role.silencer
          ? (NightActionKind.silence, x, false) : null);
      expect(e.resolveNight().silencedSeat, x);
      e.beginDay();
      expect(e.match.phase, GamePhase.discussion);
      expect(e.silencedSeatToday, x);
    });

    test('C43: Mafia and Silencer know each other at deal', () {
      final roles = sevenWithSilencer;
      final e = MatchEngine(clock: Clocks.monotonic());
      e.start(names: [for (var i = 0; i < 7; i++) 'P$i'],
          roleCounts: roles, settings: silencerOn, seed: 3);
      for (var i = 0; i < 7; i++) {
        final view = e.revealFor(i);
        if (e.match.players[i].role.alignment == Alignment.mafia) {
          expect(view.teammateNames, hasLength(1));
        }
        e.confirmRevealed();
      }
    });
  });

  group('detective', () {
    test('C44: detective sees the Silencer exact role', () {
      final e = start(sevenWithSilencer, silencerOn);
      final s = seatOf(e, Role.silencer), d = seatOf(e, Role.detective);
      e.beginNight();
      while (e.match.currentActorSeat != d) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      expect(e.submitNightAction(seat: d, kind: NightActionKind.investigate,
          targetSeat: s)?.revealedRole, Role.silencer);
    });

    test('C45: detective sees the Elder exact role', () {
      final e = start({Role.mafia: 1, Role.elder: 1,
        Role.detective: 1, Role.citizen: 4}, elderOn);
      final elder = seatOf(e, Role.elder), d = seatOf(e, Role.detective);
      e.beginNight();
      while (e.match.currentActorSeat != d) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      expect(e.submitNightAction(seat: d, kind: NightActionKind.investigate,
          targetSeat: elder)?.revealedRole, Role.elder);
    });

    test('C50: detective cannot investigate twice in one night', () {
      final e = start(standard, plain);
      final d = seatOf(e, Role.detective), c = seatsOf(e, Role.citizen);
      e.beginNight();
      while (e.match.currentActorSeat != d) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      e.submitNightAction(seat: d, kind: NightActionKind.investigate,
          targetSeat: c[0]);
      expect(() => e.submitNightAction(seat: d,
          kind: NightActionKind.investigate, targetSeat: c[1]), throwsStateError);
      expect(e.match.eventLog.whereType<InvestigateCast>()
          .where((v) => v.actorSeat == d), hasLength(1));
    });

    test('C51: detective receives answer before dying that night', () {
      final e = start(standard, plain);
      final d = seatOf(e, Role.detective), m = seatOf(e, Role.mafia);
      e.beginNight();
      Role? answer;
      while (e.match.currentActorSeat != null) {
        final a = e.match.currentActorSeat!, role = e.match.players[a].role;
        if (role == Role.mafia) {
          e.submitNightAction(seat: a, kind: NightActionKind.mafiaVote,
              targetSeat: d);
        } else if (role == Role.detective) {
          answer = e.submitNightAction(seat: a,
              kind: NightActionKind.investigate, targetSeat: m)?.revealedRole;
        } else if (role == Role.doctor) {
          e.submitNightAction(seat: a, kind: NightActionKind.protect,
              targetSeat: seatOf(e, Role.citizen));
        } else { e.skipNightAction(seat: a); }
      }
      expect(answer, Role.mafia);
      expect(e.resolveNight().victimSeats, [d]);
    });

    test('C52: a second detective is refused by the setup guard', () {
      final report = BalanceGuard.evaluate(playerCount: 7,
        roleCounts: {Role.mafia: 2, Role.detective: 2, Role.citizen: 3});
      expect(report.issues.any((i) =>
          i.code == 'one_detective_only' && i.blocking), isTrue);
    });
  });

  group('elder', () {
    test('C53: revealed Elder who dies keeps reveal but casts no ballot', () {
      final e = start({Role.mafia: 1, Role.elder: 1,
        Role.citizen: 5}, elderOn);
      final elder = seatOf(e, Role.elder);
      night(e, (_, _) => null); e.resolveNight();
      e.beginDay(); e.revealElder(elder);
      e.beginVoting(); abstainOrSkip(e); e.resolveDayVote(); e.winCheck();
      night(e, (_, role) => role == Role.mafia
          ? (NightActionKind.mafiaVote, elder, false) : null);
      expect(e.resolveNight().victimSeats, [elder]);
      expect(e.isElderRevealed(elder), isTrue);
      toVoting(e);
      expect(e.match.players[elder].status, PlayerStatus.dead);
    });

    test('C54: revealed Elder three votes beat two other votes', () {
      final e = start({Role.mafia: 1, Role.elder: 1,
        Role.citizen: 4}, elderOn);
      final elder = seatOf(e, Role.elder), c = seatsOf(e, Role.citizen);
      night(e, (_, _) => null); e.resolveNight();
      e.beginDay(); e.revealElder(elder); e.beginVoting();
      while (e.match.phase == GamePhase.voting) {
        final a = e.match.currentActorSeat!;
        final target = a == elder ? c[0] :
            (a == c[1] || a == c[2]) ? c[3] : null;
        e.submitVote(seat: a, voterSeat: a, targetSeat: target);
      }
      final r = e.resolveDayVote();
      expect(r.tally?[c[0]], 3);
      expect(r.tally?[c[3]], 2);
      expect(r.eliminatedSeat, c[0]);
    });

    test('C55: reveal after casting weights that ballot retroactively', () {
      final e = start({Role.mafia: 1, Role.elder: 1,
        Role.citizen: 4}, elderOn);
      final elder = seatOf(e, Role.elder), c = seatsOf(e, Role.citizen);
      night(e, (_, _) => null); e.resolveNight(); toVoting(e);
      while (e.match.phase == GamePhase.voting) {
        final a = e.match.currentActorSeat!;
        e.submitVote(seat: a, voterSeat: a,
          targetSeat: a == elder ? c[0] : null);
      }
      e.revealElder(elder);
      expect(e.resolveDayVote().tally?[c[0]], 3);
    });

    test('C56: Elder may reveal while vote resolves', () {
      final e = start({Role.mafia: 1, Role.elder: 1,
        Role.citizen: 4}, elderOn);
      final elder = seatOf(e, Role.elder);
      night(e, (_, _) => null); e.resolveNight(); toVoting(e);
      abstainOrSkip(e);
      expect(e.match.phase, GamePhase.voteResolving);
      e.revealElder(elder);
      expect(e.isElderRevealed(elder), isTrue);
    });

    test('C57: Elder cannot reveal at night', () {
      final e = start({Role.mafia: 1, Role.elder: 1,
        Role.citizen: 4}, elderOn);
      e.beginNight();
      expect(() => e.revealElder(seatOf(e, Role.elder)), throwsStateError);
    });

    test('C59: revealed Elder keeps triple weight in a revote', () {
      final e = start({Role.mafia: 1, Role.elder: 1,
        Role.citizen: 4}, elderOn.copyWith(dayTieRule: DayTieRule.revote));
      final elder = seatOf(e, Role.elder), c = seatsOf(e, Role.citizen);
      final forB = [for (final p in e.match.players)
        if (p.seat != elder && p.seat != c[1]) p.seat].take(3).toSet();
      night(e, (_, _) => null); e.resolveNight();
      e.beginDay(); e.revealElder(elder); e.beginVoting();
      while (e.match.phase == GamePhase.voting) {
        final a = e.match.currentActorSeat!;
        e.submitVote(seat: a, voterSeat: a,
          targetSeat: a == elder ? c[0] : forB.contains(a) ? c[1] : null);
      }
      expect(e.resolveDayVote().tie, isTrue);
      expect(e.currentVoteRound, 2);
      while (e.match.phase == GamePhase.voting) {
        final a = e.match.currentActorSeat!;
        e.submitVote(seat: a, voterSeat: a,
          targetSeat: a == elder ? c[0] : null);
      }
      final r = e.resolveDayVote();
      expect(r.tally?[c[0]], 3);
      expect(r.eliminatedSeat, c[0]);
    });

    test('C61: offline Elder may record a night suspicion', () {
      final e = start({Role.mafia: 1, Role.elder: 1,
        Role.citizen: 4}, elderOn);
      final x = seatOf(e, Role.mafia), elder = seatOf(e, Role.elder);
      night(e, (_, role) => role == Role.elder
          ? (NightActionKind.suspect, x, false) : null);
      expect(e.match.eventLog.whereType<SuspectCast>()
          .any((v) => v.actorSeat == elder && v.targetSeat == x), isTrue);
    });

    test('C62: sniper treats Elder as town', () {
      final e = start({Role.mafia: 2, Role.elder: 1,
        Role.sniper: 1, Role.citizen: 3},
        sniperOn.copyWith(elderEnabled: true));
      final elder = seatOf(e, Role.elder), s = seatOf(e, Role.sniper);
      night(e, (_, role) => role == Role.sniper
          ? (NightActionKind.suspect, elder, true) : null);
      expect(e.resolveNight().victimSeats, containsAll([elder, s]));
    });
  });

  group('mafia', () {
    test('C63: Mafia cannot vote for a Mafia teammate', () {
      final e = start(standard, plain);
      final m = seatsOf(e, Role.mafia);
      e.beginNight();
      while (e.match.currentActorSeat != m.first) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      expect(() => e.submitNightAction(seat: m.first,
        kind: NightActionKind.mafiaVote, targetSeat: m.last), throwsStateError);
    });

    test('C64: a team quiet night cancels another Mafia vote', () {
      final e = start(standard, const MatchSettings());
      final m = seatsOf(e, Role.mafia), x = seatOf(e, Role.citizen);
      e.beginNight();
      while (e.match.currentActorSeat != null) {
        final a = e.match.currentActorSeat!;
        if (a == m.first) {
          e.skipNightAction(seat: a, useBullet: true);
        } else if (a == m.last) {
          e.submitNightAction(seat: a,
            kind: NightActionKind.mafiaVote, targetSeat: x);
        } else { e.skipNightAction(seat: a); }
      }
      expect(e.resolveNight().victimSeats, isEmpty);
    });

    test('C65: second Mafioso cannot spend the team bullet', () {
      final e = start(standard, const MatchSettings());
      final m = seatsOf(e, Role.mafia);
      e.beginNight();
      while (e.match.currentActorSeat != m.first) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      e.skipNightAction(seat: m.first, useBullet: true);
      expect(e.canArmBullet(m.last), isFalse);
      while (e.match.currentActorSeat != m.last) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      expect(() => e.skipNightAction(seat: m.last, useBullet: true),
          throwsStateError);
    });

    test('C66: Mafia choose nobody arms quiet night once', () {
      final e = start(standard, const MatchSettings());
      final m = seatOf(e, Role.mafia);
      e.beginNight();
      while (e.match.currentActorSeat != m) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      e.skipNightAction(seat: m, useBullet: true);
      expect(e.canArmBullet(m), isFalse);
      expect(e.match.eventLog.whereType<BulletSpent>().last.kind,
          BulletKind.quietNight);
    });
  });

  group('day/vote/win/setup', () {
    test('C100: default tie stands; ordinary revote ties only once', () {
      for (final rule in [DayTieRule.noElimination, DayTieRule.revote]) {
        final e = start(standard, plain.copyWith(dayTieRule: rule));
        final c = seatsOf(e, Role.citizen);
        night(e, (_, _) => null); e.resolveNight(); toVoting(e);
        void tieBallot() {
          final available = [for (final p in e.match.players)
            if (p.seat != c[0] && p.seat != c[1]) p.seat];
          final forA = available.take(2).toSet();
          final forB = available.skip(2).take(2).toSet();
          while (e.match.phase == GamePhase.voting) {
            final a = e.match.currentActorSeat!;
            e.submitVote(seat: a, voterSeat: a,
              targetSeat: forA.contains(a) ? c[0] :
                  forB.contains(a) ? c[1] : null);
          }
        }
        tieBallot();
        final first = e.resolveDayVote();
        expect(first.tie, isTrue);
        if (rule == DayTieRule.revote) {
          expect(e.match.phase, GamePhase.voting);
          tieBallot();
          expect(e.resolveDayVote().eliminatedSeat, isNull);
        } else {
          expect(e.match.phase, GamePhase.reveal);
          expect(first.eliminatedSeat, isNull);
        }
      }
    });

    test('C101: one ballot beats all abstentions', () {
      final e = start(standard, plain);
      final x = seatOf(e, Role.citizen);
      night(e, (_, _) => null); e.resolveNight(); toVoting(e);
      var cast = false;
      while (e.match.phase == GamePhase.voting) {
        final a = e.match.currentActorSeat!;
        final target = !cast && a != x ? x : null;
        if (target != null) cast = true;
        e.submitVote(seat: a, voterSeat: a, targetSeat: target);
      }
      expect(e.resolveDayVote().eliminatedSeat, x);
    });

    test('C102: unanimous abstention advances without elimination', () {
      final e = start(standard, plain);
      night(e, (_, _) => null); e.resolveNight(); toVoting(e);
      abstainOrSkip(e);
      expect(e.resolveDayVote().eliminatedSeat, isNull);
      expect(e.match.phase, GamePhase.reveal);
    });

    test('C103: a silence target remains eligible for elimination', () {
      final e = start(sevenWithSilencer, silencerOn);
      final x = seatOf(e, Role.citizen);
      night(e, (_, role) => role == Role.silencer
          ? (NightActionKind.silence, x, false) : null);
      e.resolveNight(); toVoting(e);
      while (e.match.phase == GamePhase.voting) {
        final a = e.match.currentActorSeat!;
        if (a == x) { e.skipSilencedVote(a); continue; }
        e.submitVote(seat: a, voterSeat: a, targetSeat: x);
      }
      expect(e.resolveDayVote().eliminatedSeat, x);
    });

    test('C105: last Mafioso voted out reveals role and town wins', () {
      final e = start({Role.mafia: 1, Role.doctor: 1,
        Role.detective: 1, Role.citizen: 3}, plain);
      final m = seatOf(e, Role.mafia);
      night(e, (_, _) => null); e.resolveNight(); toVoting(e);
      while (e.match.phase == GamePhase.voting) {
        final a = e.match.currentActorSeat!;
        e.submitVote(seat: a, voterSeat: a,
          targetSeat: a == m ? null : m);
      }
      final r = e.resolveDayVote();
      expect(r.eliminatedRole, Role.mafia);
      expect(e.winCheck(), Alignment.town);
    });

    test('C106: day elimination reaching parity awards Mafia', () {
      final e = start({Role.mafia: 2, Role.citizen: 3}, plain);
      final x = seatOf(e, Role.citizen);
      night(e, (_, _) => null); e.resolveNight(); toVoting(e);
      while (e.match.phase == GamePhase.voting) {
        final a = e.match.currentActorSeat!;
        e.submitVote(seat: a, voterSeat: a,
          targetSeat: a == x ? null : x);
      }
      expect(e.resolveDayVote().eliminatedSeat, x);
      expect(e.winCheck(), Alignment.mafia);
    });

    test('C107: night parity is decided after the morning', () {
      final e = start({Role.mafia: 1, Role.citizen: 2,
        Role.doctor: 1, Role.detective: 1}, plain);
      final c = seatsOf(e, Role.citizen);
      e.removePlayer(c.first);
      e.removePlayer(seatOf(e, Role.detective));
      final x = c.last;
      night(e, (_, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, x, false),
        Role.doctor => (NightActionKind.protect, seatOf(e, Role.mafia), false),
        _ => null,
      });
      expect(e.resolveNight().victimSeats, [x]);
      expect(e.match.phase, GamePhase.morning);
      expect(e.concludeAfterNight(), Alignment.mafia);
    });

    test('C111: ten-player classic deals recommended Mafia split', () {
      final counts = MatchPreset.classic.roleCounts(10);
      expect(counts[Role.mafia], 2);
      expect(BalanceGuard.recommendedMafia(10), 2);
      final e = start(counts, MatchPreset.classic.settings);
      expect(seatsOf(e, Role.mafia), hasLength(2));
    });

    test('C112: eight-player fast uses classic split and no bullets', () {
      final counts = MatchPreset.fast.roleCounts(8);
      expect(counts[Role.mafia], MatchPreset.classic.roleCounts(8)[Role.mafia]);
      final e = start(counts, MatchPreset.fast.settings);
      expect(e.match.settings.bulletsEnabled, isFalse);
      expect(e.match.settings.revealNightVictimRole, isTrue);
      expect(e.canArmBullet(seatOf(e, Role.mafia)), isFalse);
    });
  });
}
