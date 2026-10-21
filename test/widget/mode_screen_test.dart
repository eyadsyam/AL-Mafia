import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';

import '../support/localized.dart';

/// The question Play now asks.
///
/// Two things are worth a test here rather than a look: that Home no longer
/// carries an online action at all, and that the online card is drawn even by
/// a build with no server — because the old behaviour was to remove it, and
/// removing it is what made "the app can't do that" and "this APK was built
/// wrong" look identical from the outside.
void main() {
  testWidgets('online is offered even when the build has no project', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        ModeScreen(onPlayOffline: () {}, onPlayOnline: null, onBack: () {}),
      ),
    );

    expect(find.byKey(ModeScreen.onlineCard), findsOneWidget);
    expect(find.byKey(ModeScreen.unavailableText), findsOneWidget);
  });

  testWidgets('a configured build says nothing about the build', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        ModeScreen(onPlayOffline: () {}, onPlayOnline: () {}, onBack: () {}),
      ),
    );

    expect(find.byKey(ModeScreen.unavailableText), findsNothing);
  });

  Widget screen({
    VoidCallback? offline,
    VoidCallback? online,
    VoidCallback? bots,
    VoidCallback? stories,
  }) => localizedApp(
    ModeScreen(
      onPlayOffline: offline ?? () {},
      onPlayOnline: online ?? () {},
      onPlayBots: bots ?? () {},
      onPlayStories: stories ?? () {},
      onBack: () {},
    ),
  );

  testWidgets('two cards first: the Mafia and the stories', (tester) async {
    var stories = 0;
    await tester.pumpWidget(screen(stories: () => stories++));
    await tester.pumpAndSettle();
    expect(find.byKey(ModeScreen.mafiaCard).hitTestable(), findsOneWidget);
    expect(find.byKey(ModeScreen.offlineCard).hitTestable(), findsNothing);
    await tester.tap(find.byKey(ModeScreen.storiesCard));
    await tester.pumpAndSettle();
    expect(stories, 1);
  });

  testWidgets('the Mafia card deals each way to play, back puts it away', (
    tester,
  ) async {
    var offline = 0;
    var online = 0;
    var bots = 0;
    await tester.pumpWidget(
      screen(
        offline: () => offline++,
        online: () => online++,
        bots: () => bots++,
      ),
    );
    await tester.pumpAndSettle();
    for (final (key, want) in [
      (ModeScreen.offlineCard, [1, 0, 0]),
      (ModeScreen.onlineCard, [1, 1, 0]),
      (ModeScreen.botsCard, [1, 1, 1]),
    ]) {
      await tester.tap(find.byKey(ModeScreen.mafiaCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect([offline, online, bots], want, reason: '$key');
      await tester.tap(find.byKey(ModeScreen.closeButton));
      await tester.pumpAndSettle();
      expect(find.byKey(ModeScreen.offlineCard).hitTestable(), findsNothing);
      expect(find.byKey(ModeScreen.storiesCard).hitTestable(), findsOneWidget);
    }
  });

  testWidgets('the system back puts the turned card away before leaving', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ModeScreen.mafiaCard));
    await tester.pumpAndSettle();
    expect(find.byKey(ModeScreen.offlineCard).hitTestable(), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(ModeScreen.offlineCard).hitTestable(), findsNothing);
    expect(find.byKey(ModeScreen.storiesCard).hitTestable(), findsOneWidget);
  });

  for (final size in const [Size(360, 640), Size(430, 932)]) {
    testWidgets('everything fits $size, closed and open', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      for (final key in [ModeScreen.mafiaCard, ModeScreen.storiesCard]) {
        expect(
          tester.getRect(find.byKey(key)).bottom,
          lessThanOrEqualTo(size.height),
        );
      }
      await tester.tap(find.byKey(ModeScreen.mafiaCard));
      await tester.pumpAndSettle();
      for (final key in [
        ModeScreen.offlineCard,
        ModeScreen.onlineCard,
        ModeScreen.botsCard,
        ModeScreen.closeButton,
      ]) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$key');
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$key');
        expect(rect.right, lessThanOrEqualTo(size.width), reason: '$key');
      }
      // The small cards do not sit on top of one another or the back button.
      final ways = [
        ModeScreen.offlineCard,
        ModeScreen.onlineCard,
        ModeScreen.botsCard,
      ].map((k) => tester.getRect(find.byKey(k))).toList();
      expect(ways[0].overlaps(ways[1]), isFalse);
      expect(ways[1].overlaps(ways[2]), isFalse);
      expect(
        ways.any(
          (r) => r.overlaps(tester.getRect(find.byKey(ModeScreen.closeButton))),
        ),
        isFalse,
      );
      expect(find.textContaining('بوت'), findsNothing);
    });
  }

  testWidgets('with animations off, every state is simply there', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: screen(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(ModeScreen.mafiaCard));
    await tester.pump();
    expect(find.byKey(ModeScreen.offlineCard).hitTestable(), findsOneWidget);
  });

  test('Home has no online action to hide', () {
    // Scanned rather than rendered, because the thing being asserted is the
    // *absence* of a compile-time flag deciding whether a player ever hears
    // that the app plays online — and a widget test cannot see a branch that
    // was never taken.
    final source = File('lib/ui/screens/setup/home_screen.dart')
        .readAsStringSync()
        .split('\n')
        .map((line) {
          final slash = line.indexOf('//');
          return slash < 0 ? line : line.substring(0, slash);
        })
        .join('\n');

    expect(
      source.contains('onPlayOnline'),
      isFalse,
      reason: 'the online action is back on Home',
    );
    expect(
      source.contains('SupabaseConfig'),
      isFalse,
      reason: 'Home decides what to show from a build flag again',
    );
  });
}
