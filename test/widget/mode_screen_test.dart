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

  testWidgets('each card leads to its own mode', (tester) async {
    var offline = 0;
    var online = 0;
    var bots = 0;
    await tester.pumpWidget(
      localizedApp(
        ModeScreen(
          onPlayOffline: () => offline++,
          onPlayOnline: () => online++,
          onPlayBots: () => bots++,
          onBack: () {},
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(ModeScreen.offlineCard));
    await tester.tap(find.byKey(ModeScreen.offlineCard));
    await tester.pump();
    expect([offline, online, bots], [1, 0, 0]);

    await tester.ensureVisible(find.byKey(ModeScreen.onlineCard));
    await tester.tap(find.byKey(ModeScreen.onlineCard));
    await tester.pump();
    expect([offline, online, bots], [1, 1, 0]);

    await tester.ensureVisible(find.byKey(ModeScreen.botsCard));
    await tester.tap(find.byKey(ModeScreen.botsCard));
    await tester.pump();
    expect([offline, online, bots], [1, 1, 1]);
  });

  testWidgets('three ways to play fit a small phone, stories live on Home', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      localizedApp(
        ModeScreen(
          onPlayOffline: () {},
          onPlayOnline: () {},
          onPlayBots: () {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final key in [
      ModeScreen.offlineCard,
      ModeScreen.onlineCard,
      ModeScreen.botsCard,
    ]) {
      final rect = tester.getRect(find.byKey(key));
      expect(rect.bottom, lessThanOrEqualTo(640), reason: '$key below the fold');
    }
    expect(find.textContaining('بوت'), findsNothing);
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
