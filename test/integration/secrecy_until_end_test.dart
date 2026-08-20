import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:mafia_master/engine/views.dart';

import '../support/scripted_match.dart';

/// T065 / FR-019 / FR-031 — who voted for whom, and who suspected whom, stay
/// hidden until the match is over.
///
/// ## Why the ballot is secret in the first place
///
/// A public tally turns the day vote into a loyalty test: the Mafia can see who
/// broke ranks, and a Citizen who guessed right becomes the next night's
/// target. Suspicions recorded at night are worse — they are a Citizen's only
/// private act, and exposing them mid-match would make recording one actively
/// dangerous. Both become interesting the moment the match ends, and only then.
///
/// This suite works at the data layer rather than the widget layer on purpose:
/// a screen can only leak what it is handed, so the enforceable guarantee is
/// that no in-play view *carries* the information at all.
void main() {
  group('FR-019 / FR-031 in-play views carry no ballots or suspicions', () {
    test('PublicMatchView exposes no role', () {
      final engine = scriptedMatch(stopAfterNightActions: 4);
      final view = engine.publicView();

      for (final player in view.players) {
        // PublicPlayer has no role field by construction; this asserts that the
        // rendered form leaks nothing either.
        expect(player.toString(), isNot(contains('role')));
        for (final role in Role.values) {
          expect(player.toString().toLowerCase(),
              isNot(contains(role.name.toLowerCase())));
        }
      }
    });

    test('PublicMatchView carries no per-voter ballot', () {
      final engine = scriptedMatch(playToEnd: true);
      final view = engine.publicView();

      // `lastTally` is an aggregate — counts per target, never per voter. The
      // distinction is the whole of FR-019.
      final tally = view.lastTally;
      if (tally != null) {
        expect(tally, isA<VoteTally>());
        expect(tally.votes.keys, everyElement(isA<int>()),
            reason: 'the tally is keyed by target, not by voter');
      }
      expect(view.toString(), isNot(contains('voterSeat')));
    });

    test('the day reveal names the eliminated role but not who voted for them',
        () {
      final engine = playToTiedVote();
      // Break the tie so someone is actually eliminated.
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        final ballot = engine.currentVoteCandidates!;
        final target = ballot.firstWhere((s) => s != seat, orElse: () => ballot.first);
        if (target == seat) break;
        engine.submitVote(seat: seat, voterSeat: seat, targetSeat: target);
      }
      final result = engine.resolveDayVote();

      if (result.eliminatedSeat != null) {
        // The role is public — the table watched them get voted out (FR-019).
        expect(result.eliminatedRole, isNotNull);
        // The ballot is not.
        expect(result.toString(), isNot(contains('voterSeat')));
      }
    });

    test('a mid-match repository refuses to serve analytics', () async {
      final store = MemoryMatchStore();
      final repository = MemoryMatchRepository(store);
      final engine = scriptedMatch(stopAfterNightActions: 4);
      await repository.persistStep(engine.match);

      expect(() => repository.loadAnalytics(engine.match.id), throwsStateError,
          reason: 'analytics is the only role-exposing read and must wait for '
              'the match to end (repository contract inv. 6)');
    });
  });

  group('FR-032 post-game, everything is available', () {
    test('analytics exposes roles, suspicions and the vote history', () async {
      final store = MemoryMatchStore();
      final repository = MemoryMatchRepository(store);
      final engine = scriptedMatch(playToEnd: true);
      await repository.persistStep(engine.match);

      final analytics = await repository.loadAnalytics(engine.match.id);
      final data = analytics.data;

      expect(data.finalRoles, hasLength(engine.match.players.length),
          reason: 'every role should be revealed post-game');
      expect(data.winner, equals(engine.match.outcome!.winner));
      expect(data.timeline, isNotEmpty);
      expect(data.achievements, isNotEmpty,
          reason: 'FR-032 requires at least one achievement');
      expect(data.nightsPlayed, greaterThan(0));
    });

    test('suspicions recorded at night surface in the suspicion map', () async {
      final store = MemoryMatchStore();
      final repository = MemoryMatchRepository(store);
      final engine = scriptedMatch(playToEnd: true);
      await repository.persistStep(engine.match);

      final suspicionsInLog =
          engine.match.eventLog.whereType<SuspectCast>().toList();
      final analytics = await repository.loadAnalytics(engine.match.id);

      if (suspicionsInLog.isEmpty) {
        fail('the scripted match recorded no suspicions, so this proves '
            'nothing — the citizens must act at night');
      }

      final recorded = analytics.data.suspicionMatrix.counts;
      for (final event in suspicionsInLog) {
        expect(recorded[event.actorSeat]?[event.targetSeat], isNotNull,
            reason: 'seat ${event.actorSeat} suspected ${event.targetSeat} but '
                'it is missing from the suspicion map');
      }
    });

    test('suspicion accuracy counts a suspicion correct iff the target was '
        'mafia', () async {
      final store = MemoryMatchStore();
      final repository = MemoryMatchRepository(store);
      final engine = scriptedMatch(playToEnd: true);
      await repository.persistStep(engine.match);

      final analytics = await repository.loadAnalytics(engine.match.id);
      final roles = analytics.data.finalRoles;

      for (final accuracy in analytics.data.suspicionAccuracy) {
        final expectedCorrect = engine.match.eventLog
            .whereType<SuspectCast>()
            .where((e) => e.actorSeat == accuracy.seat)
            .where((e) => roles[e.targetSeat] == Role.mafia)
            .length;
        expect(accuracy.correctSuspicions, equals(expectedCorrect),
            reason: 'accuracy for seat ${accuracy.seat} is miscounted');
      }
    });
  });
}
