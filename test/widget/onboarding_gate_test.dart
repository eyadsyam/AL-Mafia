import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/ui/screens/setup/setup_draft.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/app/resume_gate.dart';
import 'package:mafia_master/ui/screens/onboarding/onboarding_video_screen.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/screens/setup/how_to_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  setUp(seedReturningProfile);
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
        matchRepositoryProvider.overrideWithValue(MemoryMatchRepository(store)),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
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

  testWidgets('saved audio changes reach the running app without a relaunch', (
    tester,
  ) async {
    store = returningHostStore();
    await launch(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MafiaApp)),
    );
    final draft = container.read(setupDraftProvider.notifier);
    final initial = container.read(setupDraftProvider).settings;
    draft.setSettings(
      initial.copyWith(muteAllAudio: true, scoreEnabled: false),
    );
    await tester.pump();
    final audio = container.read(audioDirectorProvider);
    expect(audio.muted, isTrue);
    expect(audio.scoreEnabled, isFalse);
    draft.setSettings(
      initial.copyWith(muteAllAudio: false, scoreEnabled: true),
    );
    await tester.pump();
    expect(audio.muted, isFalse);
    expect(audio.scoreEnabled, isTrue);
  });

  group('first launch', () {
    testWidgets('a fresh install is asked its questions, not shown the film', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await launch(tester);

      expect(find.byKey(FirstRunScreen.screenKey), findsOneWidget);
      expect(find.byType(OnboardingVideoScreen), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('a first launch mid-match offers resume', (tester) async {
      final engine = scriptedMatch();
      await MemoryMatchRepository(store).persistStep(engine.match);

      await launch(tester);

      expect(find.byKey(ResumeGate.resumeButton), findsOneWidget);
      expect(find.byType(OnboardingVideoScreen), findsNothing);
    });
  });

  group('reaching it on purpose', () {
    testWidgets('the home help control opens the how-to sheet', (tester) async {
      store = returningHostStore();
      await launch(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.byKey(HomeScreen.howToPlayButton));
      await tester.pumpAndSettle();

      expect(find.byKey(HowToKeys.sheet), findsOneWidget);
      expect(find.byType(OnboardingVideoScreen), findsNothing);
    });

    testWidgets('the sheet plays the video; skipping it returns to Home', (
      tester,
    ) async {
      store = returningHostStore();
      await launch(tester);
      await tester.tap(find.byKey(HomeScreen.howToPlayButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(HowToKeys.video));
      await tester.tap(find.byKey(HowToKeys.video));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingVideoScreen), findsOneWidget);

      await tester.tap(find.byKey(OnboardingVideoScreen.skipButton));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(store.onboardingSeen, isTrue);
    });
  });
}
