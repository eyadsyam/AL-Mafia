import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/online/host_sheet.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// The host's sheet on another player's seat: mute and kick, only for the
/// host, never on their own seat, and each tap sent to the server once.
void main() {
  late FakeBackend backend;
  late OnlineTransport transport;

  Future<void> connect({String hostId = 'u0'}) async {
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'discuss', hostId: hostId),
      players: roster(5),
    );
    transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    addTearDown(transport.dispose);
  }

  Future<List<int>> pump(
    WidgetTester tester, {
    required int? seat,
    GameSnapshot? snapshot,
    bool withTransport = true,
  }) async {
    final dismissed = <int>[];
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: HostSheet(
            snapshot: snapshot ?? transport.snapshot,
            transport: withTransport ? transport : null,
            seat: seat,
            onDismiss: () => dismissed.add(1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return dismissed;
  }

  testWidgets('the host opens another seat: its name, mute and kick', (
    tester,
  ) async {
    await connect();
    await pump(tester, seat: 2);
    expect(find.text('C'), findsOneWidget);
    expect(find.byKey(HostSheet.muteAction), findsOneWidget);
    expect(find.byKey(HostSheet.kickAction), findsOneWidget);
    expect(find.text(arStrings.onlineMute), findsOneWidget);
  });

  testWidgets('mute is sent once and the sheet closes', (tester) async {
    await connect();
    final dismissed = await pump(tester, seat: 2);
    await tester.tap(find.byKey(HostSheet.muteAction));
    await tester.pumpAndSettle();
    expect(dismissed, [1]);
    final mutes = backend.calls.where((c) => c.function == 'mute_player');
    expect(
      mutes.single.body,
      allOf([
        for (final e in {'roomId': 'room-1', 'seat': 2, 'muted': true}.entries)
          containsPair(e.key, e.value),
      ]),
    );
  });

  testWidgets('kick is sent once and the sheet closes', (tester) async {
    await connect();
    final dismissed = await pump(tester, seat: 3);
    await tester.tap(find.byKey(HostSheet.kickAction));
    await tester.pumpAndSettle();
    expect(dismissed, [1]);
    final kicks = backend.calls.where((c) => c.function == 'kick_player');
    expect(
      kicks.single.body,
      allOf([
        for (final e in {'roomId': 'room-1', 'seat': 3}.entries)
          containsPair(e.key, e.value),
      ]),
    );
  });

  testWidgets('a muted seat offers unmute', (tester) async {
    await connect();
    await pump(
      tester,
      seat: 1,
      snapshot: transport.snapshot.copyWith(mutedSeats: {1}),
    );
    expect(find.text(arStrings.onlineUnmute), findsOneWidget);
    await tester.tap(find.byKey(HostSheet.muteAction));
    await tester.pumpAndSettle();
    final mutes = backend.calls.where((c) => c.function == 'mute_player');
    expect(
      mutes.single.body,
      allOf([
        for (final e in {'roomId': 'room-1', 'seat': 1, 'muted': false}.entries)
          containsPair(e.key, e.value),
      ]),
    );
  });

  {
    testWidgets('closed for a player who is not the host', (tester) async {
      await connect(hostId: 'u4');
      await pump(tester, seat: 2);
      expect(find.byKey(HostSheet.kickAction), findsNothing);
      expect(find.byKey(HostSheet.muteAction), findsNothing);
    });
  }

  testWidgets('closed on the host\'s own seat, no seat, or no transport', (
    tester,
  ) async {
    await connect();
    await pump(tester, seat: transport.snapshot.viewerSeat);
    expect(find.byKey(HostSheet.kickAction), findsNothing);
    await pump(tester, seat: null);
    expect(find.byKey(HostSheet.kickAction), findsNothing);
    await pump(tester, seat: 2, withTransport: false);
    expect(find.byKey(HostSheet.kickAction), findsNothing);
    await pump(tester, seat: 9);
    expect(find.byKey(HostSheet.kickAction), findsNothing);
    expect(
      backend.calls.where(
        (c) => c.function == 'kick_player' || c.function == 'mute_player',
      ),
      isEmpty,
    );
  });
}
