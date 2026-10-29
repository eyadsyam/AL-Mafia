import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/match_codec.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/all_access.dart'
    show allAccessAccountProvider;
import 'package:mafia_master/ui/economy/my_cosmetics.dart';
import 'package:mafia_master/ui/economy/table_tools.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/optional_roles.dart';
import 'package:mafia_master/ui/screens/setup/role_rows.dart';
import 'package:mafia_master/ui/screens/setup/settings_sheet.dart';
import 'package:mafia_master/ui/screens/setup/setup_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

class _Owns extends WalletController {
  final Set<String> codes;
  _Owns(this.codes);

  @override
  Future<WalletState?> build() async => WalletState(
    balance: 0,
    catalog: const [],
    owned: codes,
    equipped: const {},
    history: const [],
  );
}

/// The device copy is the signed-in account's; these tests stay on one.
final _sameAccount = allAccessAccountProvider.overrideWith(
  (ref) => Stream.value('account-a'),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('owned roles are remembered on the device', () {
    test(
      'a wallet read is saved; with no wallet the copy is restored',
      () async {
        final first = ProviderContainer(
          overrides: [
            walletProvider.overrideWith(() => _Owns({'role_elder', 'frame_x'})),
            _sameAccount,
          ],
        );
        addTearDown(first.dispose);
        first.read(ownedRolesProvider);
        await first.read(walletProvider.future);
        await Future<void>.delayed(Duration.zero);
        expect(first.read(ownedRolesProvider), {'role_elder'});

        // A later launch with no wallet answer yet.
        final second = ProviderContainer(overrides: [_sameAccount]);
        addTearDown(second.dispose);
        expect(second.read(ownedRolesProvider), isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(second.read(ownedRolesProvider), {'role_elder'});
      },
    );

    test('the wallet replaces the copy when it answers', () async {
      SharedPreferences.setMockInitialValues({
        OwnedRolesController.storageKey: jsonEncode(['role_sniper']),
      });
      final c = ProviderContainer(
        overrides: [
          walletProvider.overrideWith(() => _Owns({'role_elder'})),
          _sameAccount,
        ],
      );
      addTearDown(c.dispose);
      c.read(ownedRolesProvider);
      await c.read(walletProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(ownedRolesProvider), {'role_elder'});
    });

    testWidgets('a role stays switchable while the wallet is unread', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        OwnedRolesController.storageKey: jsonEncode(['role_elder']),
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_sameAccount],
          child: localizedApp(
            Scaffold(
              body: SingleChildScrollView(
                child: OptionalRoleRows(
                  players: 8,
                  mafia: 2,
                  citizens: 4,
                  selected: const {},
                  onChanged: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(OptionalRoleRows.switchKey(OptionalRole.elder)),
        findsOneWidget,
      );
      expect(
        find.byKey(OptionalRoleRows.lockKey(OptionalRole.sniper)),
        findsOneWidget,
      );
    });
  });

  group('settings sheet discussion stepper', () {
    Future<ProviderContainer> open(WidgetTester tester, int seconds) async {
      final store = MemoryMatchStore()
        ..defaultSettings = jsonEncode(
          MatchCodec.encodeSettings(MatchSettings(discussionSeconds: seconds)),
        );
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          matchRepositoryProvider.overrideWithValue(
            MemoryMatchRepository(store),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            const Scaffold(
              body: SingleChildScrollView(child: SettingsSheetBody()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    int now(ProviderContainer c) =>
        c.read(setupDraftProvider).settings.discussionSeconds;

    testWidgets('the Hard preset length (2 min) steps both ways', (
      tester,
    ) async {
      final c = await open(tester, 120);
      final more = find.byKey(SettingsSheetKeys.minutesMore);
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pump();
      expect(now(c), 180);
      await tester.tap(find.byKey(SettingsSheetKeys.minutesLess));
      await tester.pump();
      expect(now(c), 120);
    });

    testWidgets('a value that is not a stop snaps to the nearest one', (
      tester,
    ) async {
      final c = await open(tester, 240);
      final more = find.byKey(SettingsSheetKeys.minutesMore);
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pump();
      // 240 is nearest to 180 (tie broken downward), so "more" lands on 300.
      expect(now(c), 300);
    });
  });

  group('tools sheet', () {
    testWidgets('floor tools require turn based talk', (tester) async {
      final backend = FakeBackend(
        roomId: 'room',
        state: roomState(phase: 'discuss'),
        players: roster(5),
      );
      backend.responders['economy'] = (_) => {
        'balance': 0,
        'tools': [
          for (final code in ['extra_minute', 'objection'])
            {
              'code': code,
              'tier': 'light',
              'packs': {'1': 40},
              'charges': 1,
              'perMatch': 1,
              'phase': 'discuss',
              'targets': 0,
            },
        ],
      };
      Future<void> open(bool freeTalk) async {
        // A fresh tree each time: the previous sheet would cover the button.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onlineBackendFactoryProvider.overrideWithValue(
                () async => backend,
              ),
            ],
            child: localizedApp(
              Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showTableToolsSheet(
                      context,
                      roomId: 'room',
                      phase: 'discuss',
                      alive: true,
                      freeTalk: freeTalk,
                      seats: const {},
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      await open(true);
      expect(
        find.byWidgetPredicate((w) => w is ToolBagTile && w.now),
        findsNothing,
      );
      await open(false);
      expect(
        find.byWidgetPredicate((w) => w is ToolBagTile && w.now),
        findsNWidgets(2),
      );
    });

    testWidgets('a failed use frees the button and says so', (tester) async {
      final backend = FakeBackend(
        roomId: 'room',
        state: roomState(phase: 'lobby'),
        players: roster(5),
      );
      backend.responders['economy'] = (body) {
        if (body['action'] == 'toolUse') throw StateError('reset');
        return {
          'balance': 0,
          'tools': [
            {
              'code': 'anon_note',
              'tier': 'light',
              'packs': {'1': 40},
              'charges': 2,
              'perMatch': 1,
              'phase': 'discuss',
              'targets': 0,
            },
          ],
        };
      };
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          ],
          child: localizedApp(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTableToolsSheet(
                    context,
                    roomId: 'room',
                    phase: 'discuss',
                    alive: true,
                    freeTalk: false,
                    seats: const {1: 'A'},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate((w) => w is ToolBagTile && w.now),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pumpAndSettle();
      final use = find.byType(FilledButton);
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(arStrings.toolRefused), findsOneWidget);
      // The button is live again, not stuck busy.
      expect(tester.widget<FilledButton>(use).onPressed, isNotNull);
    });

    testWidgets('each tool refusal explains its server code', (tester) async {
      final cases = <String, String>{
        'LIMIT_MATCH': arStrings.toolLimitMatch,
        'LIMIT_HEAVY': arStrings.toolLimitHeavy,
        'LIMIT_TOOL': arStrings.toolLimitTool,
        'LIMIT_PHASE': arStrings.toolLimitPhase,
        'NO_CHARGES': arStrings.toolNoCharges,
        'WRONG_PHASE': arStrings.toolWrongPhase,
        'BAD_TARGETS': arStrings.toolBadTargets,
        'ALIVE': arStrings.toolDeadOnly,
        'NOT_PLAYING': arStrings.toolMatchOver,
        'BAD_NOTE': arStrings.toolBadNote,
      };
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final entry in cases.entries) {
        final backend = FakeBackend(
          roomId: 'room',
          state: roomState(phase: 'lobby'),
          players: roster(5),
        );
        backend.responders['economy'] = (body) {
          if (body['action'] == 'toolUse') {
            throw BackendException(entry.key, 'refused');
          }
          return {
            'balance': 0,
            'tools': [
              {
                'code': 'extra_minute',
                'tier': 'light',
                'packs': {'1': 40},
                'charges': 2,
                'perMatch': 1,
                'phase': 'discuss',
                'targets': 0,
              },
            ],
          };
        };
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onlineBackendFactoryProvider.overrideWithValue(
                () async => backend,
              ),
            ],
            child: localizedApp(
              Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showTableToolsSheet(
                      context,
                      roomId: 'room',
                      phase: 'discuss',
                      alive: true,
                      freeTalk: false,
                      seats: const {},
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate((w) => w is ToolBagTile && w.now),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump();
        expect(find.text(entry.value), findsOneWidget, reason: entry.key);
      }
    });
  });
}
