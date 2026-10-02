import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/app/router.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/onboarding/onboarding_video_screen.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/screens/setup/how_to_play_screen.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';
import 'package:mafia_master/ui/widgets/gender_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

/// P1 — the one thing a first-time player is asked, asked once.
///
/// There is no sign-in in this app and there is not going to be one, so the
/// whole of identity is a name and a character kept on this device. That makes
/// the order it is asked in the entire feature: before the film it is an
/// interruption to a person who has not been told what the app is yet, after
/// the rules it is the last step before playing, and on the second launch it is
/// an insult. The invite case is the one that has to survive all of it — a code
/// that arrives with a stranger has three screens to live through before the
/// room it names.
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
    final container = ProviderContainer(overrides: [
      matchRepositoryProvider.overrideWithValue(MemoryMatchRepository(store)),
      audioDirectorProvider.overrideWithValue(AudioDirector()),
      onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      onlineHeartbeatProvider.overrideWithValue(Duration.zero),
      voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
    ]);
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

  Future<void> fillProfile(WidgetTester tester) async {
    expect(find.byKey(const ValueKey('profile_name')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('profile_name')), 'سامي');
    await tester.pump();
    await tester.tap(find.byKey(GenderPicker.maleKey));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('profile_save')));
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
    testWidgets('the film is not asked to wait behind a name field', (
      tester,
    ) async {
      await launch(tester, freshInstall());

      // Frame by frame rather than settled: the defect this guards against is
      // one frame long. The profile's storage read finishes before the gate's
      // three, so without the gate holding the door the form appears, is typed
      // over by nobody, and is replaced by the film.
      for (var frame = 0; frame < 20; frame++) {
        expect(
          find.byKey(const ValueKey('profile_name')),
          findsNothing,
          reason: 'the app has not told this player what it is yet',
        );
        if (find.byType(OnboardingVideoScreen).evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingVideoScreen), findsOneWidget);
    });

    testWidgets('the name is asked after the rules, and Home follows', (
      tester,
    ) async {
      await launch(tester, freshInstall());
      await throughTheIntro(tester);

      expect(find.byType(HomeScreen), findsNothing);
      await fillProfile(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a relaunch asks for none of it again', (tester) async {
      final store = freshInstall();
      await launch(tester, store);
      await throughTheIntro(tester);
      await fillProfile(tester);

      await launch(tester, store);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingVideoScreen), findsNothing);
      expect(find.byKey(const ValueKey('profile_name')), findsNothing);
    });
  });

  group('an invite is the first thing this device ever sees', () {
    testWidgets('the code survives the film, the rules and the profile', (
      tester,
    ) async {
      await launch(tester, freshInstall(), at: Routes.joinLink('K7M2QP'));
      await tester.pumpAndSettle();

      expect(
        find.byType(OnboardingVideoScreen),
        findsOneWidget,
        reason: 'a link is not a reason to skip the explanation',
      );
      await throughTheIntro(tester);
      await fillProfile(tester);

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
