import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/data/online_session_store.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/home_room_return.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

/// Home's «ارجع لأوضتك» shows only for a seat that is this player's and that
/// the server still holds, and hands the room code on when tapped.
void main() {
  Future<String?> pump(
    WidgetTester tester, {
    required FakeBackend backend,
    Map<String, Object> stored = const {},
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    String? returned;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        ],
        child: MaterialApp(
          theme: MafiaTheme.dark,
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HomeRoomReturn(onReturn: (code) => returned = code),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (find.byKey(HomeRoomReturn.actionKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(HomeRoomReturn.actionKey));
      await tester.pump();
    }
    return returned;
  }

  FakeBackend backend({String status = 'playing', bool seated = true}) =>
      FakeBackend(
        roomId: 'room-1',
        state: roomState(status: status),
        players: roster(4),
        own: seated ? const OwnSeat(seat: 0, role: 'citizen') : null,
      );

  String pointer({String userId = 'u0'}) =>
      '{"roomId":"room-1","code":"ABCDEF","userId":"$userId"}';

  testWidgets('a live seat of this player is offered, and the tap hands on '
      'its code', (tester) async {
    final code = await pump(
      tester,
      backend: backend(),
      stored: {OnlineSessionStore.key: pointer()},
    );
    expect(code, 'ABCDEF');
  });

  testWidgets('nothing stored: nothing shown', (tester) async {
    await pump(tester, backend: backend());
    expect(find.byKey(HomeRoomReturn.cardKey), findsNothing);
  });

  testWidgets('another account\'s seat on this phone is not offered', (
    tester,
  ) async {
    await pump(
      tester,
      backend: backend(),
      stored: {OnlineSessionStore.key: pointer(userId: 'someone-else')},
    );
    expect(find.byKey(HomeRoomReturn.cardKey), findsNothing);
  });

  testWidgets('a finished room is not offered', (tester) async {
    await pump(
      tester,
      backend: backend(status: 'finished'),
      stored: {OnlineSessionStore.key: pointer()},
    );
    expect(find.byKey(HomeRoomReturn.cardKey), findsNothing);
  });

  testWidgets('a room that no longer seats this player is not offered', (
    tester,
  ) async {
    await pump(
      tester,
      backend: backend(seated: false),
      stored: {OnlineSessionStore.key: pointer()},
    );
    expect(find.byKey(HomeRoomReturn.cardKey), findsNothing);
  });

  testWidgets('no network: nothing shown', (tester) async {
    final offline = backend()..unreachable = true;
    await pump(
      tester,
      backend: offline,
      stored: {OnlineSessionStore.key: pointer()},
    );
    expect(find.byKey(HomeRoomReturn.cardKey), findsNothing);
  });
}
