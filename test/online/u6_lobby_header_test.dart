import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/transport/game_snapshot.dart' show PublicRoom;
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/lobby_header.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/stores.dart';

/// Update 1.5 / WP8 (#u6): the lobby header is a name, three icons and «⋯», and
/// nothing in it overlaps whatever the room or the host is called.
void main() {
  setUp(seedReturningProfile);

  // Twenty Arabic letters: the longest name the room or a player may carry.
  final long = List.filled(20, 'م').join();

  Future<void> pump(
    WidgetTester tester,
    Size size, {
    required bool host,
    String? title,
    int players = 3,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(
        phase: 'lobby',
        phaseNumber: 0,
        status: 'lobby',
        hostId: host ? 'u0' : 'u1',
        title: title,
      ),
      players: [
        for (var seat = 0; seat < players; seat++)
          RoomPlayer(
            userId: 'u$seat',
            seat: seat,
            name: seat == 0 ? long : String.fromCharCode(65 + seat),
            alive: true,
            lastSeen: DateTime.utc(2026, 9, 2, 12),
          ),
      ],
      own: const OwnSeat(seat: 0),
    );
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    container.read(playerProfileProvider);
    await container.read(onlineSessionProvider.notifier).host(long);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(LobbyScreen(onStarted: () {}, onLeave: () {})),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  const sizes = [Size(360, 640), Size(390, 844), Size(640, 360)];

  for (final size in sizes) {
    for (final host in [true, false]) {
      testWidgets('header has no overflow or overlap with long names at $size '
          '(${host ? 'host' : 'guest'})', (tester) async {
        await pump(tester, size, host: host, title: long);
        expect(tester.takeException(), isNull);

        final title = tester.getRect(find.byKey(LobbyHeader.titleKey));
        final controls = <String, Rect>{
          'more': tester.getRect(find.byKey(LobbyHeader.moreButton)),
          'leave': tester.getRect(find.byKey(LobbyScreen.leaveButton)),
          if (host)
            'settings': tester.getRect(find.byKey(LobbyScreen.settingsButton))
          else
            'safety': tester.getRect(find.byKey(LobbyHeader.safetyIcon)),
        };
        // Three icons and «⋯», never more.
        expect(controls, hasLength(3));

        final screen = Offset.zero & size;
        for (final entry in {'title': title, ...controls}.entries) {
          expect(
            screen.contains(entry.value.topLeft) &&
                screen.contains(entry.value.bottomRight),
            isTrue,
            reason: '${entry.key} ${entry.value} leaves the screen',
          );
        }
        final all = {'title': title, ...controls}.entries.toList();
        for (var i = 0; i < all.length; i++) {
          for (var j = i + 1; j < all.length; j++) {
            final overlap = all[i].value.intersect(all[j].value);
            expect(
              overlap.width <= 0.5 || overlap.height <= 0.5,
              isTrue,
              reason: '${all[i].key} overlaps ${all[j].key}',
            );
          }
        }
      });
    }
  }

  testWidgets('a room with no name is titled by its code', (tester) async {
    await pump(tester, const Size(360, 640), host: true);
    final title = tester.widget<Text>(find.byKey(LobbyHeader.titleKey));
    expect(title.data, arStrings.lobbyRoomHeader('ABCDEF'));
  });

  testWidgets('«⋯» holds the store, and the report tools for the host', (
    tester,
  ) async {
    await pump(tester, const Size(360, 640), host: true);
    await tester.tap(find.byKey(LobbyHeader.moreButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(LobbyHeader.moreStore), findsOneWidget);
    expect(find.byKey(LobbyHeader.moreSafety), findsOneWidget);
  });

  testWidgets('under the minimum the one line says what is needed', (
    tester,
  ) async {
    await pump(tester, const Size(360, 640), host: true, players: 3);
    expect(
      find.text(arStrings.lobbyWaitingForPlayers(PublicRoom.defaultMinPlayers)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
