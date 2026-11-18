import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/platform/metrics.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/before_start_sheet.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';
import 'package:mafia_master/ui/screens/setup/roles_screen.dart';
import 'package:mafia_master/ui/screens/setup/settings_screen.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/stores.dart';

/// Usage counts: each event is one body with an event name and at most one
/// enum value, recorded once, on the action itself.
void main() {
  late List<Map<String, Object?>> bodies;
  late MetricsClient client;

  setUp(() {
    bodies = [];
    client = MetricsClient(
      enabled: () async => true,
      send: (body) async => bodies.add(body),
    );
  });

  List<List<String>> sent() => [
    for (final b in bodies) [b['event']! as String, b['prop']! as String],
  ];

  Future<void> settle() async {
    await client.settled;
  }

  group('app and setup flow', () {
    late ProviderContainer container;

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      container = ProviderContainer(
        overrides: [
          matchRepositoryProvider.overrideWithValue(
            MemoryMatchRepository(returningHostStore()),
          ),
          metricsClientProvider.overrideWithValue(client),
          economyCapabilitiesProvider.overrideWith(
            (ref) async => const EconomyCapabilities(metrics: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Capabilities already loaded, as after any earlier backend contact.
      await container.read(economyCapabilitiesProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AmbientMotion(enabled: false, child: MafiaApp()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('app_open once; mode_pick local; match_local_started size', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.runAsync(settle);
      expect(sent().where((e) => e[0] == 'app_open'), [
        ['app_open', ''],
      ]);

      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ModeScreen.mafiaCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ModeScreen.offlineCard));
      await tester.pumpAndSettle();
      await tester.runAsync(settle);
      expect(sent().where((e) => e[0] == 'mode_pick'), [
        ['mode_pick', 'local'],
      ]);
      expect(sent().where((e) => e[0] == 'match_local_started'), isEmpty);

      for (final name in ['A1', 'B2', 'C3', 'D4', 'E5', 'F6', 'G7']) {
        await tester.enterText(find.byType(TextField).first, name);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('كمل'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RolesScreen.nextButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SettingsScreen.saveButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BeforeStartKeys.go));
      await tester.pumpAndSettle();
      await tester.runAsync(settle);

      expect(sent().where((e) => e[0] == 'match_local_started'), [
        ['match_local_started', 'p7_9'],
      ]);
      expect(sent().where((e) => e[0] == 'app_open'), hasLength(1));
      expect(sent().where((e) => e[0] == 'online_action'), isEmpty);
    }, skip: SupabaseConfig.isConfigured);

    testWidgets('mode_pick online on a build with a server', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ModeScreen.mafiaCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ModeScreen.onlineCard));
      await tester.pump();
      await tester.runAsync(settle);
      expect(sent().where((e) => e[0] == 'mode_pick'), [
        ['mode_pick', 'online'],
      ]);
    }, skip: !SupabaseConfig.isConfigured);
  });

  group('online entry', () {
    late FakeBackend backend;

    Future<void> pumpEntry(WidgetTester tester) async {
      seedReturningProfile();
      backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
        players: roster(3),
        own: const OwnSeat(seat: 0),
      );
      backend
        ..responses['browse_rooms'] = {
          'rooms': [
            {'code': 'NEARAA', 'players': 4, 'capacity': 8, 'voice': false},
          ],
        }
        ..responses['create_room'] = {'roomId': 'room-1', 'code': 'ABCDEF'}
        ..responses['join_room'] = {'roomId': 'room-1', 'seat': 0}
        ..responses['quick_match'] = {
          'roomId': 'room-1',
          'code': 'ABCDEF',
          'seat': 0,
          'created': true,
        };
      final container = ProviderContainer(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          onlineHeartbeatProvider.overrideWithValue(Duration.zero),
          metricsClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await container.read(playerProfileProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            OnlineEntryScreen(onJoined: () {}, onBack: () {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('quick', (tester) async {
      await pumpEntry(tester);
      await tester.tap(find.byKey(OnlineEntryScreen.quickMatchButton));
      await tester.pump();
      await tester.pump();
      await tester.runAsync(settle);
      expect(sent(), [
        ['online_action', 'quick'],
      ]);
    });

    testWidgets('create', (tester) async {
      await pumpEntry(tester);
      await tester.tap(find.byKey(OnlineEntryScreen.hostButton));
      await tester.pump();
      await tester.runAsync(settle);
      expect(sent(), [
        ['online_action', 'create'],
      ]);
    });

    testWidgets('join_code', (tester) async {
      await pumpEntry(tester);
      await tester.tap(find.byKey(OnlineEntryScreen.haveCodeButton));
      await tester.pump();
      expect(sent(), isEmpty, reason: 'opening the sheet is not a join');
      await tester.enterText(find.byKey(OnlineEntryScreen.codeField), 'ABCDEF');
      await tester.pump();
      await tester.tap(find.byKey(OnlineEntryScreen.joinButton));
      await tester.pump();
      await tester.pump();
      await tester.runAsync(settle);
      expect(sent(), [
        ['online_action', 'join_code'],
      ]);
    });

    testWidgets('join_public', (tester) async {
      await pumpEntry(tester);
      await tester.tap(find.byKey(const ValueKey('public_room_NEARAA')));
      await tester.pump();
      await tester.pump();
      await tester.runAsync(settle);
      expect(sent(), [
        ['online_action', 'join_public'],
      ]);
    });
  });

  group('store', () {
    testWidgets('store_open once per open, not per rebuild', (tester) async {
      final backend = FakeBackend(
        roomId: 'room',
        state: roomState(phase: 'lobby'),
        players: roster(5),
      );
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineBackendFactoryProvider.overrideWithValue(() async => backend),
            metricsClientProvider.overrideWithValue(client),
          ],
          child: localizedApp(const CoinStore()),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(settle);
      expect(sent(), [
        ['store_open', ''],
      ]);
    });
  });
}
