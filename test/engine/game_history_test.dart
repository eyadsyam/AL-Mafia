import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/information/game_history.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';

import '../support/information_match.dart';

/// `GameHistory` is a projection of the event log, not a second store — so the
/// thing worth testing is that it reproduces what actually happened, on a match
/// that was really played rather than on a hand-built log.
///
/// A hand-built log would round-trip happily while missing the event a real
/// match produces, which is the failure `scripted_match.dart` was written to
/// avoid and the same reasoning applies here.
void main() {
  group('buildHistory projects a played match', () {
    test('an unplayed match has no nights and no days', () {
      final engine = MatchEngine(clock: Clocks.monotonic());
      engine.start(
        names: kNames,
        roleCounts: kRoles,
        settings: const MatchSettings(openingRoundEnabled: true),
        seed: 3,
      );
      final history = buildHistory(engine.match);
      expect(history.nights, isEmpty);
      expect(history.days, isEmpty);
      expect(history.alive, hasLength(kNames.length));
    });

    test('night 1 records every suspicion, protect and investigation', () {
      final engine = informationMatch(seed: 11);
      openNight(engine);

      final protects = <int, int>{};
      final suspicions = <int, int>{};
      int? investigated;

      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        final role = engine.match.players[seat].role;
        final target = firstLegalTarget(engine, seat);
        engine.submitNightAction(
          seat: seat,
          kind: role.nightAction,
          targetSeat: target,
        );
        switch (role) {
          case Role.doctor:
            protects[seat] = target;
          case Role.citizen:
            suspicions[seat] = target;
          case Role.detective:
            investigated = target;
          case Role.mafia:
            break;
        }
      }
      engine.resolveNight();

      final night = buildHistory(engine.match).nightAt(1)!;
      expect(night.resolved, isTrue);
      expect(night.recordedSuspicions, equals(suspicions));
      expect(night.doctorProtect, equals(protects.values.single));
      expect(night.detectiveCheck, equals(investigated));
    });

    test('a skipped turn is a key with a null value, not a missing key', () {
      final engine = informationMatch(seed: 5);
      openNight(engine);

      final citizen = engine.match.players
          .firstWhere((p) => p.role == Role.citizen && p.status == PlayerStatus.alive)
          .seat;

      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        if (seat == citizen) {
          engine.skipNightAction(seat: seat);
          continue;
        }
        engine.submitNightAction(
          seat: seat,
          kind: engine.match.players[seat].role.nightAction,
          targetSeat: firstLegalTarget(engine, seat),
        );
      }
      engine.resolveNight();

      final night = buildHistory(engine.match).nightAt(1)!;
      expect(night.suspicions.containsKey(citizen), isTrue,
          reason: 'the seat took its turn; that is a fact worth keeping');
      expect(night.suspicions[citizen], isNull);
      expect(night.skipped, contains(citizen));
      expect(night.recordedSuspicions.containsKey(citizen), isFalse);
    });

    test('a doctor save is recorded with the seat, not just the flag', () {
      final engine = informationMatch(seed: 21);
      openNight(engine);

      final doctor =
          engine.match.players.firstWhere((p) => p.role == Role.doctor).seat;
      final victim = engine.match.players
          .firstWhere((p) => p.role == Role.citizen && p.seat != doctor)
          .seat;

      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        final role = engine.match.players[seat].role;
        // Everybody who can aim at the victim does, so the kill and the cover
        // land on the same seat.
        final target = (role == Role.mafia || role == Role.doctor)
            ? victim
            : firstLegalTarget(engine, seat);
        engine.submitNightAction(
          seat: seat,
          kind: role.nightAction,
          targetSeat: target,
        );
      }
      engine.resolveNight();

      final night = buildHistory(engine.match).nightAt(1)!;
      expect(night.victim, isNull);
      expect(night.saveOccurred, isTrue);
      expect(night.savedSeat, equals(victim),
          reason: 'the record must be able to tell a save from a quiet night');
      expect(night.mafiaTargetSeat, equals(victim));
    });

    test('the Day-1 opener lands in the day record', () {
      final engine = informationMatch(seed: 31);
      playQuietNight(engine);
      engine.beginDay();
      expect(engine.match.phase, GamePhase.openingRound);

      final named = <int, int>{};
      while (engine.match.phase == GamePhase.openingRound) {
        final seat = engine.match.currentActorSeat!;
        final target = (seat + 1) % kNames.length;
        engine.submitOpeningAccusation(seat: seat, targetSeat: target);
        named[seat] = target;
      }

      final day = buildHistory(engine.match).dayAt(1)!;
      expect(day.openingAccusations, equals(named));
    });

    test('the published trace is on the record it belongs to', () {
      final engine = informationMatch(seed: 41);
      playQuietNight(engine);
      final night = buildHistory(engine.match).nightAt(1)!;
      expect(night.revealedTrace, isNotNull,
          reason: 'a resolved night always publishes something, even T0');
      expect(night.revealedTrace, equals(engine.currentTrace!.type));
    });

    test('votes are grouped by round and the last round wins', () {
      final engine = informationMatch(seed: 51);
      playQuietNight(engine);
      engine.beginDay();
      while (engine.match.phase == GamePhase.openingRound) {
        final seat = engine.match.currentActorSeat!;
        engine.submitOpeningAccusation(
          seat: seat,
          targetSeat: (seat + 1) % kNames.length,
        );
      }
      if (engine.match.phase == GamePhase.confrontation) {
        engine.endConfrontation();
      }
      engine.beginVoting();

      final cast = <int, int>{};
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        final target = seat == 0 ? 1 : 0;
        engine.submitVote(seat: seat, voterSeat: seat, targetSeat: target);
        cast[seat] = target;
      }
      engine.resolveDayVote();

      final day = buildHistory(engine.match).dayAt(1)!;
      expect(day.votesByRound.keys, equals({1}));
      expect(day.votes, equals(cast));
    });
  });
}
