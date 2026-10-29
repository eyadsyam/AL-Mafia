import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/engine/balance_guard.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_deal_panel.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/setup/role_deal_grid.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/stores.dart';

/// The online host's deal, from the lobby to the server (owner, 2026-10-29:
/// «لازم في توزيع الادوار يكون عندي صلاحية لكل حاجه كا هوست»; the seats are
/// still dealt at random by the server). The host opens the cards, changes the
/// split, switches on a role they bought, and starts — and the server is sent
/// exactly that split, citizens filling the rest.
void main() {
  setUp(seedReturningProfile);
  late FakeBackend backend;

  Future<ProviderContainer> lobby(
    WidgetTester tester, {
    int players = 8,
    Set<String> owned = const {},
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(430, 1100);
    addTearDown(tester.view.reset);
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: roster(players),
      own: const OwnSeat(seat: 0),
    );
    backend.responses['economy'] = {
      'balance': 0,
      'catalog': <Object>[],
      'owned': owned.toList(),
      'equipped': <String, Object>{},
    };
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    container.read(playerProfileProvider);
    await container.read(walletProvider.notifier).refresh();
    await container.read(onlineSessionProvider.notifier).host('A');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(LobbyScreen(onStarted: () {}, onLeave: () {})),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  // The lobby keeps living animations, so it never settles; time is pumped.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Map<String, int> sentRoles() {
    final call = backend.lastCall('start_match');
    expect(call, isNotNull, reason: 'the match was started');
    return Map<String, int>.from(call!.body['roles'] as Map);
  }

  Future<void> openDeal(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.ensureVisible(find.byKey(LobbyDeckStrip.editKey));
    await tester.tap(find.byKey(LobbyDeckStrip.editKey));
    await settle(tester);
  }

  Future<void> closeDeal(WidgetTester tester) async {
    await tester.tap(find.byKey(OnlineDealPanel.doneKey));
    await settle(tester);
  }

  Future<void> start(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(LobbyScreen.startButton));
    await tester.tap(find.byKey(LobbyScreen.startButton));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('untouched, the server gets the recommended split', (
    tester,
  ) async {
    await lobby(tester);
    await start(tester);
    final rec = BalanceGuard.recommended(8);
    final roles = sentRoles();
    expect(roles['mafia'], rec[Role.mafia]);
    expect(roles.values.fold<int>(0, (a, b) => a + b), 8);
  });

  testWidgets('one more Mafioso: sent as chosen, citizens fill the rest', (
    tester,
  ) async {
    await lobby(tester, players: 10);
    final rec = BalanceGuard.recommended(10);
    await openDeal(tester);
    await tester.tap(find.byKey(RoleDealGrid.plus(Role.mafia)));
    await settle(tester);
    await closeDeal(tester);
    await start(tester);
    final roles = sentRoles();
    expect(roles['mafia'], rec[Role.mafia]! + 1);
    expect(roles['doctor'] ?? 0, rec[Role.doctor] ?? 0);
    expect(roles['detective'] ?? 0, rec[Role.detective] ?? 0);
    expect(roles.values.fold<int>(0, (a, b) => a + b), 10);
  });

  testWidgets('a bought role switched on goes to the room for everyone', (
    tester,
  ) async {
    await lobby(tester, owned: {'role_elder'});
    await openDeal(tester);
    await tester.tap(find.byKey(RoleDealGrid.plus(Role.elder)));
    await settle(tester);
    final call = backend.calls.lastWhere(
      (c) => c.body['settings'] is Map && c.function != 'start_match',
    );
    expect((call.body['settings'] as Map)['elderEnabled'], isTrue);
  });

  testWidgets('a role not bought cannot be switched on from the deal', (
    tester,
  ) async {
    await lobby(tester);
    await openDeal(tester);
    expect(find.byKey(RoleDealGrid.plus(Role.elder)), findsNothing);
    expect(find.byKey(RoleDealGrid.lock(Role.elder)), findsOneWidget);
    expect(backend.calls.where((c) => c.body['settings'] is Map), isEmpty);
  });

  testWidgets('a split the room outgrew falls back, and the strip says so', (
    tester,
  ) async {
    await lobby(tester, players: 10);
    await openDeal(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(RoleDealGrid.plus(Role.mafia)));
      await settle(tester);
    }
    await closeDeal(tester);
    // Five leave: the custom split no longer fits five seats.
    backend.setPlayers(roster(5));
    backend.pushResync();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await start(tester);
    final roles = sentRoles();
    expect(roles['mafia'], BalanceGuard.recommended(5)[Role.mafia]);
    expect(roles.values.fold<int>(0, (a, b) => a + b), 5);
  });
}
