import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/app/resume_gate.dart';
import 'package:mafia_master/ui/screens/onboarding/onboarding_screen.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';

import '../support/scripted_match.dart';
import '../support/stores.dart';

/// S-19 — the deck is offered once, and only when it is the right moment.
///
/// ## Why "once" is worth a test of its own
///
/// The failure this guards against is not a crash, it is an insult: an app that
/// re-explains itself every time it is opened. That failure is invisible in a
/// single run and obvious to a host on their fourth evening, which is exactly
/// the sort of bug that ships. The store outlives the repository here — the
/// same trick `crash_resume_test` uses — so "the host relaunched" is modelled
/// honestly rather than asserted about a flag.
void main() {
  const surface = Size(390, 844);

  late MemoryMatchStore store;

  Future<void> launch(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Tear the tree down first, so a second `launch` is a real relaunch.
    //
    // Without this, pumping `MafiaApp` again *updates* the existing elements
    // rather than remounting them: `OnboardingGate.initState` never runs a
    // second time and the gate silently never re-checks. The test then passes
    // for the wrong reason — it is looking at the screen the first launch left
    // behind. An empty frame in between is the closest a widget test gets to a
    // process restart.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final container = ProviderContainer(
      overrides: [
        matchRepositoryProvider
            .overrideWithValue(MemoryMatchRepository(store)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AmbientMotion(enabled: false, child: MafiaApp()),
      ),
    );
    // Deliberately no `loadArtwork` here. It runs inside `tester.runAsync`,
    // which lets real plugin traffic through — and Home's card spread asks
    // `sensors_plus` for the accelerometer, which does not exist under
    // `flutter test` and throws a MissingPluginException straight into the
    // test. Nothing here asserts on pixels, so the decode does not matter.
    await tester.pumpAndSettle();
  }

  setUp(() => store = MemoryMatchStore());

  group('first launch', () {
    testWidgets('a fresh install opens the deck instead of Home',
        (tester) async {
      await launch(tester);

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('skipping it records that it was seen', (tester) async {
      await launch(tester);

      await tester.tap(find.byKey(OnboardingScreen.skipButton));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(store.onboardingSeen, isTrue,
          reason: 'a host who dismissed the deck has said they do not want it');
    });

    testWidgets('the next launch goes straight to Home', (tester) async {
      await launch(tester);
      await tester.tap(find.byKey(OnboardingScreen.skipButton));
      await tester.pumpAndSettle();

      // A relaunch: a brand-new repository over the same store, which is what
      // a process restart actually looks like.
      await launch(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });

  group('an unfinished match outranks it', () {
    testWidgets('a first launch mid-match offers resume, not the deck',
        (tester) async {
      final engine = scriptedMatch();
      await MemoryMatchRepository(store).persistStep(engine.match);

      await launch(tester);

      expect(find.byKey(ResumeGate.resumeButton), findsOneWidget,
          reason: 'a table that is mid-game wants its match back, not a '
              'tutorial');
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('and the deck is not lost — it comes up on the next clean '
        'launch', (tester) async {
      final engine = scriptedMatch();
      await MemoryMatchRepository(store).persistStep(engine.match);
      await launch(tester);

      // The host ends the match rather than resuming it.
      await tester.tap(find.byKey(ResumeGate.endButton));
      await tester.pumpAndSettle();

      await launch(tester);
      expect(find.byType(OnboardingScreen), findsOneWidget,
          reason: 'standing down for a resume must defer the deck, not '
              'consume it');
    });
  });

  group('reaching it on purpose', () {
    testWidgets('the home help control opens the deck', (tester) async {
      store = returningHostStore();
      await launch(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.byKey(HomeScreen.howToPlayButton));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });
}
