import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_types.dart';
import 'package:mafia_master/data/resume_resolver.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';

import '../support/scripted_match.dart';

/// T050 / L-13 / T7 — force-quit mid-night, relaunch, land on the pass screen.
///
/// ## How the crash is simulated
///
/// [MemoryMatchStore] holds the encoded bytes; [MemoryMatchRepository] is just a
/// view over it. Throwing the repository away and building a new one over the
/// same store reproduces exactly what a process kill does — every in-memory
/// object is gone, and all that survives is what was actually written. Anything
/// the app could only recover by remembering something is therefore
/// unrecoverable here too, which is the property under test.
void main() {
  group('L-13 resume lands on a neutral surface', () {
    late MemoryMatchStore store;

    setUp(() => store = MemoryMatchStore());

    /// Persists [match], then loads it back through a brand-new repository.
    Future<(Match, ResumeTarget)> killAndRelaunch(Match match) async {
      await MemoryMatchRepository(store).persistStep(match);

      // --- process dies here; only `store` survives ---

      final afterRelaunch = MemoryMatchRepository(store);
      final loaded = await afterRelaunch.loadActiveMatch();
      expect(loaded, isNotNull, reason: 'the match was not recovered at all');
      return (loaded!, await afterRelaunch.resolveResume(loaded));
    }

    test('interrupted mid-night, resume targets the current actor\'s pass screen',
        () async {
      final engine = scriptedMatch(stopAfterNightActions: 3);
      final interruptedActor = engine.match.currentActorSeat;
      expect(engine.match.phase, GamePhase.night);
      expect(interruptedActor, isNotNull);

      final (loaded, target) = await killAndRelaunch(engine.match);

      expect(loaded, equals(engine.match), reason: 'the match changed on reload');
      expect(target.screen, equals(ResumeScreen.pass));
      expect(target.seat, equals(interruptedActor));
      expect(target.playerName,
          equals(engine.match.players[interruptedActor!].name));
    });

    test('the resume target carries no game content', () async {
      final engine = scriptedMatch(stopAfterNightActions: 3);
      final (_, target) = await killAndRelaunch(engine.match);

      // ResumeTarget is deliberately a four-field record. If a role, a target
      // list or an investigation result ever needed to travel with it, the
      // resume path would be reopening secrets straight onto the screen.
      expect(target.toString(), isNot(contains('Role.')));
      expect(target.toString(), isNot(contains('mafia')));
      expect(target.toString(), isNot(contains('doctor')));
    });

    test('every in-hand phase resumes on the pass screen', () async {
      // The specific phase does not matter — what matters is that no in-hand
      // phase has its own, more permissive resume path.
      const inHand = [
        GamePhase.distributing,
        GamePhase.night,
        GamePhase.nightResolving,
        GamePhase.voting,
        GamePhase.voteResolving,
      ];

      final base = scriptedMatch(stopAfterNightActions: 2).match;
      for (final phase in inHand) {
        final match = base.copyWith(phase: phase, currentActorSeat: 4);
        final target = ResumeResolver.resolve(match);
        expect(target.screen, equals(ResumeScreen.pass),
            reason: '$phase resumed onto ${target.screen} instead of the pass '
                'screen');
        expect(target.seat, equals(4));
      }
    });

    test('on-table phases resume directly, since the table already saw them',
        () async {
      final base = scriptedMatch(stopAfterNightActions: 2).match;
      const expected = {
        GamePhase.preNightLobby: ResumeScreen.preNightLobby,
        GamePhase.morning: ResumeScreen.morning,
        GamePhase.discussion: ResumeScreen.discussion,
        GamePhase.reveal: ResumeScreen.voteReveal,
        GamePhase.winCheck: ResumeScreen.voteReveal,
      };

      for (final entry in expected.entries) {
        final target = ResumeResolver.resolve(base.copyWith(phase: entry.key));
        expect(target.screen, equals(entry.value), reason: '${entry.key}');
      }
    });

    test('a match with no living actor falls back to the lobby, not a crash',
        () async {
      final base = scriptedMatch(stopAfterNightActions: 2).match;
      final allDead = base.copyWith(
        phase: GamePhase.night,
        players: [
          for (final p in base.players) p.copyWith(status: PlayerStatus.dead),
        ],
        currentActorSeat: null,
        clearCurrentActorSeat: true,
      );

      final target = ResumeResolver.resolve(allDead);
      expect(target.screen, equals(ResumeScreen.preNightLobby));
      expect(target.seat, isNull);
    });

    test('no stored match resumes to home', () async {
      expect(await MemoryMatchRepository(store).loadActiveMatch(), isNull);
      expect(ResumeResolver.resolve(null).screen, equals(ResumeScreen.home));
    });

    test('a finished match is never offered for resume', () async {
      final engine = scriptedMatch(playToEnd: true);
      expect(engine.match.phase, GamePhase.result);

      await MemoryMatchRepository(store).persistStep(engine.match);
      expect(await MemoryMatchRepository(store).loadActiveMatch(), isNull);
      expect(ResumeResolver.isActive(engine.match), isFalse);
    });

    test('resuming preserves the rules the engine derives from the log',
        () async {
      // The detective's one-shot rule and the doctor's no-repeat rule are both
      // re-derived from the event log. If the log were lossy, a resumed match
      // would silently hand someone a second investigation.
      final engine = scriptedMatch(stopAfterNightActions: 5);
      final (loaded, _) = await killAndRelaunch(engine.match);

      expect(
        loaded.eventLog.whereType<InvestigateCast>().toList(),
        equals(engine.match.eventLog.whereType<InvestigateCast>().toList()),
      );
      expect(
        loaded.eventLog.whereType<ProtectCast>().toList(),
        equals(engine.match.eventLog.whereType<ProtectCast>().toList()),
      );
    });
  });
}
