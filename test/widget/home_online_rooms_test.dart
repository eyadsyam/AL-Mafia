import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/tilt_source.dart';
import 'package:mafia_master/ui/screens/setup/home_online_rooms.dart';
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
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        homeOnlineRoomsProvider.overrideWith((ref) => count()),
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
}
