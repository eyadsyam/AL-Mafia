import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/stores.dart';

/// Update 1.5 / WP8 (#u6): the code field and its button stay above the
/// keyboard, at every size, including a phone on its side.
void main() {
  setUp(seedReturningProfile);

  Future<void> open(
    WidgetTester tester,
    Size size, {
    required double keyboard,
  }) async {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: roster(3),
      own: const OwnSeat(seat: 0),
    )..responses['browse_rooms'] = {'rooms': const []};
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await container.read(playerProfileProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(OnlineEntryScreen(onJoined: () {}, onBack: () {})),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(OnlineEntryScreen.haveCodeButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The keyboard rises after the sheet is already up, as it does on a phone.
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // Keyboards cover roughly 40% of a portrait phone and most of a landscape
  // one; the landscape inset leaves the sheet barely 160dp.
  const cases = <(String, Size, double)>[
    ('360x640', Size(360, 640), 280),
    ('390x844', Size(390, 844), 336),
    ('640x360', Size(640, 360), 200),
  ];

  for (final (label, size, keyboard) in cases) {
    testWidgets('code field and button sit above the keyboard at $label', (
      tester,
    ) async {
      await open(tester, size, keyboard: keyboard);
      expect(tester.takeException(), isNull);
      final limit = size.height - keyboard;
      for (final key in [
        OnlineEntryScreen.codeField,
        OnlineEntryScreen.joinButton,
      ]) {
        final rect = tester.getRect(find.byKey(key));
        expect(
          rect.bottom,
          lessThanOrEqualTo(limit + 0.5),
          reason: '$key bottom ${rect.bottom} is under the keyboard ($limit)',
        );
        expect(rect.top, greaterThanOrEqualTo(0));
      }
    });
  }
}
