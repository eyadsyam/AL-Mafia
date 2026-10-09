import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';

import '../support/localized.dart';
import '../support/stores.dart';

void main() {
  late MemoryMatchStore store;

  Future<void> launch(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('Home greets once after first run, then never again', (
    tester,
  ) async {
    store = returningHostStore();
    await WelcomeGreeting.arm();
    await launch(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(WelcomeLine.lineKey), findsOneWidget);
    expect(find.text(arStrings.homeGreeting('A')), findsOneWidget);
    expect(await WelcomeGreeting.pending(), isFalse);

    // The line leaves on its own.
    await tester.pump(HomeTokens.greetingHold);
    await tester.pump(HomeTokens.greetingFade);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byKey(WelcomeLine.lineKey),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity,
      0,
    );

    // A relaunch: the flag is gone, so there is no line at all.
    await launch(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(WelcomeLine.lineKey), findsNothing);
  });

  testWidgets('a returning player with no flag is not greeted', (tester) async {
    store = returningHostStore();
    await launch(tester);
    expect(find.byKey(WelcomeLine.lineKey), findsNothing);
  });
}
