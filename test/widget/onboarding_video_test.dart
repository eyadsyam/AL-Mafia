import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/onboarding/onboarding_video_screen.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';

import '../support/fake_video_platform.dart';
import '../support/localized.dart';

/// P0.4 — the introduction, when the browser says no.
///
/// A refused `play()` is the ordinary case on the web, not the exotic one: the
/// film loads, the first frame is there, and the element refuses to start
/// because nothing has been tapped yet. The screen used to raise its failure
/// flag for that and then never show it — the failure branch lived in the
/// `else` of "is the video ready", and by then it was. What the player got was
/// a play button that did nothing, for ever, with no way out but the skip
/// control in the corner.
void main() {
  const defaultSurface = Size(390, 844);

  /// The panel around the film breathes, so this screen never settles. Fixed
  /// pumps rather than [WidgetTester.pumpAndSettle].
  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onFinished,
    Size? surface,
  }) async {
    await tester.binding.setSurfaceSize(surface ?? defaultSurface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: AmbientMotion(
          enabled: false,
          child: localizedApp(
            OnboardingVideoScreen(onFinished: onFinished ?? () {}),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('a refused play says so and offers another go', (tester) async {
    final platform = FakeVideoPlatform.install(refusePlay: true);
    await pumpScreen(tester);

    // The film is loaded: this is the ready screen, not the fallback. Native
    // playback starts itself, so the refusal has already happened.
    expect(find.byKey(OnboardingVideoScreen.player), findsOneWidget);
    expect(platform.playCalls, 1);
    expect(find.text(arStrings.videoFailed), findsOneWidget);
    expect(find.byKey(OnboardingVideoScreen.retryButton), findsOneWidget);
    expect(
      find.byKey(OnboardingVideoScreen.skipButton),
      findsOneWidget,
      reason: 'the way out must never be the thing that disappears',
    );
  });

  testWidgets('the retry is a real retry, and clears the message', (
    tester,
  ) async {
    final platform = FakeVideoPlatform.install(refusePlay: true);
    await pumpScreen(tester);
    expect(find.byKey(OnboardingVideoScreen.retryButton), findsOneWidget);

    platform.refusePlay = false;
    await tester.tap(find.byKey(OnboardingVideoScreen.retryButton));
    await settle(tester);

    expect(platform.playCalls, 2);
    expect(find.text(arStrings.videoFailed), findsNothing);
    expect(find.byKey(OnboardingVideoScreen.retryButton), findsNothing);
  });

  testWidgets('leaving the screen takes the sound with it', (tester) async {
    final platform = FakeVideoPlatform.install();
    var finished = false;
    await pumpScreen(tester, onFinished: () => finished = true);

    expect(platform.playCalls, 1, reason: 'native playback starts itself');
    await tester.tap(find.byKey(OnboardingVideoScreen.skipButton));
    await settle(tester);

    expect(finished, isTrue);
    expect(
      platform.pauseCalls,
      greaterThan(0),
      reason:
          'a film that is still running while the next screen builds is '
          'audio with nothing on screen to explain it',
    );
  });

  testWidgets('skip is offered before the film has loaded at all', (
    tester,
  ) async {
    // No platform installed: `initialize()` throws, which is the "could not
    // load" case the fallback copy exists for.
    await pumpScreen(tester);

    expect(find.byKey(OnboardingVideoScreen.skipButton), findsOneWidget);
    expect(find.byKey(OnboardingVideoScreen.continueButton), findsOneWidget);
  });

  group('the film stays inside its frame', () {
    // Phone portrait, tall phone, the same phone turned over, and a laptop.
    const sizes = [
      Size(360, 640),
      Size(390, 844),
      Size(844, 390),
      Size(1366, 768),
    ];

    for (final size in sizes) {
      testWidgets('at ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        FakeVideoPlatform.install();
        await pumpScreen(tester, surface: size);

        final player = tester.getRect(find.byKey(OnboardingVideoScreen.player));
        expect(player.width, greaterThan(0));
        expect(player.height, greaterThan(0));
        expect(
          player.width / player.height,
          closeTo(1280 / 720, 0.01),
          reason: 'a frame of another shape is a stretched film',
        );
        expect(player.left, greaterThanOrEqualTo(-0.01));
        expect(player.top, greaterThanOrEqualTo(-0.01));
        expect(player.right, lessThanOrEqualTo(size.width + 0.01));
        expect(player.bottom, lessThanOrEqualTo(size.height + 0.01));
        expect(
          find.byKey(OnboardingVideoScreen.skipButton),
          findsOneWidget,
          reason: 'the way out is on every size',
        );
      });
    }

    testWidgets('and survives being turned over mid-play', (tester) async {
      final platform = FakeVideoPlatform.install();
      await pumpScreen(tester, surface: const Size(390, 844));

      await tester.binding.setSurfaceSize(const Size(844, 390));
      await settle(tester);

      final player = tester.getRect(find.byKey(OnboardingVideoScreen.player));
      expect(player.right, lessThanOrEqualTo(844.01));
      expect(player.bottom, lessThanOrEqualTo(390.01));
      expect(
        platform.playCalls,
        1,
        reason: 'a rotation is not a reason to start the film again',
      );
    });
  });
}
