import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/app/router.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/screens/onboarding/onboarding_video_screen.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/screens/setup/how_to_play_screen.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';
import 'package:mafia_master/ui/widgets/gender_picker.dart';
import 'package:mafia_master/ui/widgets/language_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

/// P1 — setup, asked once, before anything else.
///
/// The owner's order (docs/CLAUDE-UX-ECONOMY-NEXT.md §87): language, name and
/// avatar, preferences, 18+ and terms, then the film and rules (skippable),
/// then Home. Skipping the film must not skip setup, a relaunch asks nothing
/// again, and an invite code survives the whole of it.
void main() {
  const surface = Size(390, 844);

  /// A first launch on a device that has never run this app: no profile, no
  /// intro seen, no saved match.
  MemoryMatchStore freshInstall() {
    SharedPreferences.setMockInitialValues({});
    return MemoryMatchStore();
  }

  late FakeBackend backend;

  Future<ProviderContainer> launch(
    WidgetTester tester,
    MemoryMatchStore store, {
    String? at,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // An empty frame between launches, so a second one remounts the gate
    // rather than updating it — see `onboarding_gate_test.dart`.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: roster(3),
      own: const OwnSeat(seat: 0),
    );
    backend.responses['browse_rooms'] = const {'rooms': []};
    final container = ProviderContainer(
      overrides: [
        matchRepositoryProvider.overrideWithValue(MemoryMatchRepository(store)),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AmbientMotion(
          enabled: false,
          child: MafiaApp(initialLocation: at),
        ),
      ),
    );
    return container;
  }

  Future<void> completeSetup(WidgetTester tester) async {
    await tester.pumpAndSettle();
    expect(find.byKey(FirstRunScreen.screenKey), findsOneWidget);
    expect(find.byType(LanguagePicker), findsOneWidget);
    await tester.tap(find.byKey(FirstRunScreen.nextKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(FirstRunScreen.nameKey), 'سامي');
    await tester.pump();
    // The address choice is a labelled row under the name (phase 99), below
    // the fold of this 800x600 surface.
    await tester.ensureVisible(find.byKey(GenderPicker.maleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GenderPicker.maleKey));
    await tester.pump();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(FirstRunScreen.nextKey));
      await tester.pumpAndSettle();
    }
    for (final key in [FirstRunScreen.adultKey, FirstRunScreen.termsKey]) {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pump();
    }
    await tester.ensureVisible(find.byKey(FirstRunScreen.continueKey));
    await tester.tap(find.byKey(FirstRunScreen.continueKey));
    await tester.pumpAndSettle();
  }

  /// Skip the film, read the rules, come out the other side.
  Future<void> throughTheIntro(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OnboardingVideoScreen.skipButton));
    await tester.pumpAndSettle();
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    await tester.tap(find.byKey(HowToPlayScreen.startButton));
    await tester.pumpAndSettle();
  }

  group('the first run', () {
    testWidgets('setup comes first; the film waits behind it', (tester) async {
      await launch(tester, freshInstall());
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingVideoScreen), findsNothing);
      await completeSetup(tester);
      expect(find.byType(OnboardingVideoScreen), findsOneWidget);
    });

    testWidgets('skipping the film lands on Home with setup kept', (
      tester,
    ) async {
      await launch(tester, freshInstall());
      await completeSetup(tester);
      await throughTheIntro(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(FirstRunScreen.screenKey), findsNothing);
    });

    testWidgets('a relaunch asks for none of it again', (tester) async {
      final store = freshInstall();
      await launch(tester, store);
      await completeSetup(tester);
      await throughTheIntro(tester);

      await launch(tester, store);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingVideoScreen), findsNothing);
      expect(find.byKey(FirstRunScreen.screenKey), findsNothing);
    });
  });

  group('an invite is the first thing this device ever sees', () {
    testWidgets('the code survives setup, the film and the rules', (
      tester,
    ) async {
      await launch(tester, freshInstall(), at: Routes.joinLink('K7M2QP'));
      await completeSetup(tester);
      expect(
        find.byType(OnboardingVideoScreen),
        findsOneWidget,
        reason: 'a link is not a reason to skip the explanation',
      );
      await throughTheIntro(tester);

      expect(find.byType(OnlineEntryScreen), findsOneWidget);
      final code = tester.widget<TextField>(
        find.byKey(OnlineEntryScreen.codeField),
      );
      expect(code.controller?.text, 'K7M2QP');
      expect(
        backend.calls.where((call) => call.function == 'joinRoom'),
        isEmpty,
        reason: 'a link that seated somebody is a link anybody could send them',
      );
    });
  });
}
