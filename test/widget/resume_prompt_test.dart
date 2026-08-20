import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';
import 'package:mafia_master/app/resume_gate.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';
import 'package:mafia_master/ui/widgets/player_tile.dart';

import '../support/scripted_match.dart';

/// T070 / S-17 — launching with an unfinished match offers Resume or End.
///
/// ## Why a prompt rather than an automatic jump
///
/// Reopening the app is not the same intent as resuming a match. The phone may
/// well be in someone else's hands than it was when the match stopped — that is
/// often *why* it stopped — and dropping straight back into the game is the one
/// moment the pass gate could not protect. Asking also lets a host abandon a
/// match whose table has already gone home.
void main() {
  const surface = Size(390, 844);

  late MemoryMatchStore store;
  late ProviderContainer container;

  Future<void> launch(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    container = ProviderContainer(
      overrides: [
        matchRepositoryProvider
            .overrideWithValue(MemoryMatchRepository(store)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AmbientMotion(
          // The drifting home-screen icons never stop, so `pumpAndSettle`
          // would spin here forever on a flow test that has nothing to do
          // with them. Bounded motion is left running.
          enabled: false,
          child: MafiaApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => store = MemoryMatchStore());

  group('S-17 resume prompt', () {
    testWidgets('no prompt appears when there is nothing to resume',
        (tester) async {
      await launch(tester);
      expect(find.byKey(ResumeGate.resumeButton), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('no prompt appears for a finished match', (tester) async {
      final engine = scriptedMatch(playToEnd: true);
      await MemoryMatchRepository(store).persistStep(engine.match);

      await launch(tester);
      expect(find.byKey(ResumeGate.resumeButton), findsNothing,
          reason: 'a finished match belongs in History, not on the resume path');
    });

    testWidgets('an unfinished match offers both Resume and End',
        (tester) async {
      final engine = scriptedMatch(stopAfterNightActions: 3);
      await MemoryMatchRepository(store).persistStep(engine.match);

      await launch(tester);

      expect(find.byKey(ResumeGate.resumeButton), findsOneWidget);
      expect(find.byKey(ResumeGate.endButton), findsOneWidget);
      // The prompt says how big the match is and where it will pick up, so the
      // host can tell which night they are about to walk back into.
      expect(find.textContaining('${engine.match.players.length} لاعبين'),
          findsOneWidget);
    });

    testWidgets('the prompt names the person the phone goes to, not the phase '
        'content', (tester) async {
      final engine = scriptedMatch(stopAfterNightActions: 3);
      final actorSeat = engine.match.currentActorSeat!;
      await MemoryMatchRepository(store).persistStep(engine.match);

      await launch(tester);

      expect(find.textContaining(engine.match.players[actorSeat].name),
          findsOneWidget);

      // Scoped to the dialog: Home behind it is titled "سيد المافيا", which
      // contains the word for Mafia but says nothing about any player.
      final dialogText = [
        for (final w in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Text),
          ),
        ))
          if (w.data != null) w.data!,
      ].join(' ');
      for (final roleWord in ['مافيا', 'دكتور', 'محقق', 'مواطن']) {
        expect(dialogText.contains(roleWord), isFalse,
            reason: 'the resume prompt leaked "$roleWord"');
      }
    });

    testWidgets('Resume re-enters on the pass gate, never on the night content',
        (tester) async {
      final engine = scriptedMatch(stopAfterNightActions: 3);
      await MemoryMatchRepository(store).persistStep(engine.match);

      await launch(tester);
      await tester.tap(find.byKey(ResumeGate.resumeButton));
      await tester.pumpAndSettle();

      // The interrupted actor has to identify themselves again before anything
      // comes back (L-13).
      expect(find.byType(HoldPad), findsOneWidget);
      expect(find.byType(PlayerTile), findsNothing,
          reason: 'resuming restored the target list without an identity gate');
    });

    testWidgets('Resume restores the exact match that was interrupted',
        (tester) async {
      final engine = scriptedMatch(stopAfterNightActions: 3);
      await MemoryMatchRepository(store).persistStep(engine.match);

      await launch(tester);
      await tester.tap(find.byKey(ResumeGate.resumeButton));
      await tester.pumpAndSettle();

      final restored =
          container.read(matchControllerProvider.notifier).engine.match;
      expect(restored, equals(engine.match));
    });

    testWidgets('End discards the match and stays Home', (tester) async {
      final engine = scriptedMatch(stopAfterNightActions: 3);
      await MemoryMatchRepository(store).persistStep(engine.match);

      await launch(tester);
      await tester.tap(find.byKey(ResumeGate.endButton));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(store.matches, isEmpty,
          reason: 'ending the match should not leave it waiting to be resumed '
              'again on the next launch');
    });

    testWidgets('the prompt is offered once per launch, not on every Home visit',
        (tester) async {
      final engine = scriptedMatch(stopAfterNightActions: 3);
      await MemoryMatchRepository(store).persistStep(engine.match);

      await launch(tester);
      await tester.tap(find.byKey(ResumeGate.resumeButton));
      await tester.pumpAndSettle();
      expect(find.byKey(ResumeGate.resumeButton), findsNothing);

      // Returning Home must not re-ask; the host already answered.
      await tester.pumpAndSettle();
      expect(find.byKey(ResumeGate.resumeButton), findsNothing);
    });
  });
}
