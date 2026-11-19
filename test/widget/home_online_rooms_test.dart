import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/tilt_source.dart';
import 'package:mafia_master/ui/screens/online/match_queue.dart';
import 'package:mafia_master/ui/screens/setup/home_online_rooms.dart';
import 'package:mafia_master/ui/screens/setup/home_play_night.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';

import '../support/localized.dart';

class _NoTilt implements TiltSource {
  @override
  Stream<Tilt> get tilt => const Stream.empty();
}

Future<void> _pump(
  WidgetTester tester,
  Future<int> Function() count, {
  VoidCallback? onOnline,
  PlayNight? night,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        homeOnlineRoomsProvider.overrideWith((ref) => count()),
        homePlayNightProvider.overrideWith((ref) async => night),
      ],
      child: AmbientMotion(
        enabled: false,
        child: localizedApp(
          HomeScreen(
            onNewMatch: () {},
            onHistory: () {},
            onSettings: () {},
            onHowToPlay: () {},
            onOnlineRooms: onOnline,
            tiltSource: _NoTilt(),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('no rooms: nothing is drawn', (tester) async {
    await _pump(tester, () async => 0, onOnline: () {});
    expect(find.byKey(HomeOnlineRoomsLine.lineKey), findsNothing);
    expect(find.byKey(HomeScreen.startButton), findsOneWidget);
  });

  testWidgets('three rooms: the line, in Western digits; a tap goes online', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, () async => 3, onOnline: () => taps++);
    expect(find.byKey(HomeOnlineRoomsLine.lineKey), findsOneWidget);
    expect(find.textContaining('3 أوض أونلاين مستنية ناس'), findsOneWidget);
    await tester.tap(find.byKey(HomeOnlineRoomsLine.lineKey));
    expect(taps, 1);
  });

  testWidgets('a failing fetch: nothing, and no error shown', (tester) async {
    await _pump(
      tester,
      () async => throw StateError('offline'),
      onOnline: () {},
    );
    expect(find.byKey(HomeOnlineRoomsLine.lineKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a build without a server never draws it', (tester) async {
    await _pump(tester, () async => 3);
    expect(find.byKey(HomeOnlineRoomsLine.lineKey), findsNothing);
  });

  testWidgets('O2: during «ليلة اللعب» the card replaces the line', (
    tester,
  ) async {
    final now = DateTime.now();
    var taps = 0;
    await _pump(
      tester,
      () async => 3,
      onOnline: () => taps++,
      night: PlayNight(
        startsAt: now.subtract(const Duration(minutes: 5)),
        endsAt: now.add(const Duration(minutes: 55)),
        active: true,
        reminded: false,
        remindedCount: null,
        queueCount: 9,
      ),
    );
    expect(find.byKey(HomeTonightLine.cardKey), findsOneWidget);
    expect(find.byKey(HomeOnlineRoomsLine.lineKey), findsNothing);
    expect(find.textContaining('9 في الطابور'), findsOneWidget);
    await tester.tap(find.byKey(HomeTonightLine.remindKey));
    expect(taps, 1);
  });

  testWidgets('O2: far from the night, the ordinary line stays', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pump(
      tester,
      () async => 3,
      onOnline: () {},
      night: PlayNight(
        startsAt: now.add(const Duration(hours: 6)),
        endsAt: now.add(const Duration(hours: 7)),
        active: false,
        reminded: false,
        remindedCount: null,
        queueCount: 0,
      ),
    );
    expect(find.byKey(HomeTonightLine.cardKey), findsNothing);
    expect(find.byKey(HomeOnlineRoomsLine.lineKey), findsOneWidget);
  });
}
