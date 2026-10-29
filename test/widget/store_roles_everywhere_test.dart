import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/room_settings_panel.dart';
import 'package:mafia_master/ui/screens/setup/bot_match_sheet.dart';
import 'package:mafia_master/ui/screens/setup/optional_roles.dart';
import 'package:mafia_master/ui/screens/setup/role_rows.dart';
import 'package:mafia_master/ui/screens/setup/role_deal_grid.dart';
import 'package:mafia_master/ui/screens/setup/roles_screen.dart';
import 'package:mafia_master/ui/screens/setup/setup_draft.dart';

import '../support/artwork.dart';
import '../support/fake_backend.dart';
import '../support/localized.dart';

/// P9 coverage: a bought role reaches the match's settings in one-phone,
/// bots and online; one that is not owned never does.
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

const _all = {'role_silencer', 'role_elder', 'role_sniper'};

List<Override> _overrides(Set<String> owns) => [
  walletProvider.overrideWith(() => _Owns(owns)),
  onlineBackendFactoryProvider.overrideWithValue(
    () async => FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    ),
  ),
  audioDirectorProvider.overrideWithValue(AudioDirector()),
  paymentCapabilitiesProvider.overrideWithValue(
    const PaymentCapabilities(transfer: false),
  ),
];

void main() {
  void phone(WidgetTester tester, [Size size = const Size(430, 932)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('one phone (roles screen to the setup draft)', () {
    /// Mirrors what the router does with `onOptionalRoles`.
    Future<ProviderContainer> pumpRoles(
      WidgetTester tester,
      Set<String> owns,
    ) async {
      final container = ProviderContainer(overrides: _overrides(owns));
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            RolesScreen(
              playerCount: 8,
              onBack: () {},
              onNext: container.read(setupDraftProvider.notifier).setRoleCounts,
              onOptionalRoles: (on) {
                final draft = container.read(setupDraftProvider);
                container
                    .read(setupDraftProvider.notifier)
                    .setSettings(OptionalRole.flags(draft.settings, on));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('owned roles switched on reach MatchSettings', (tester) async {
      await loadArtwork(tester);
      phone(tester);
      final c = await pumpRoles(tester, _all);
      for (final r in [OptionalRole.silencer, OptionalRole.elder]) {
        final sw = find.byKey(RoleDealGrid.plus(r.role));
        await tester.ensureVisible(sw);
        await tester.tap(sw);
        await tester.pumpAndSettle();
      }
      // The router is told when the host moves on.
      await tester.tap(find.byKey(RolesScreen.nextButton));
      final s = c.read(setupDraftProvider).settings;
      expect(s.silencerEnabled, isTrue);
      expect(s.elderEnabled, isTrue);
      expect(s.sniperEnabled, isFalse);
    });

    testWidgets('roles that are not owned never reach MatchSettings', (
      tester,
    ) async {
      await loadArtwork(tester);
      phone(tester);
      final c = await pumpRoles(tester, const {});
      for (final r in OptionalRole.values) {
        expect(find.byKey(RoleDealGrid.plus(r.role)), findsNothing);
        expect(find.byKey(RoleDealGrid.lock(r.role)), findsOneWidget);
      }
      await tester.ensureVisible(find.byKey(RolesScreen.nextButton));
      await tester.tap(find.byKey(RolesScreen.nextButton));
      final s = c.read(setupDraftProvider).settings;
      expect(s.silencerEnabled, isFalse);
      expect(s.elderEnabled, isFalse);
      expect(s.sniperEnabled, isFalse);
    });

    test('flags only ever follow the owned, switched-on set', () {
      const base = MatchSettings();
      final on = OptionalRole.flags(base, {OptionalRole.sniper});
      expect(on.sniperEnabled, isTrue);
      expect(on.silencerEnabled, isFalse);
      expect(OptionalRole.flags(on, const {}).sniperEnabled, isFalse);
    });
  });

  group('bots', () {
    Future<List<BotMatchPick?>> open(
      WidgetTester tester,
      Set<String> owns,
    ) async {
      final out = <BotMatchPick?>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(owns),
          child: localizedApp(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  key: const ValueKey('open'),
                  onPressed: () async =>
                      out.add(await showBotMatchSheet(context)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      return out;
    }

    testWidgets('not owned: locked rows, the pick carries no new role', (
      tester,
    ) async {
      await loadArtwork(tester);
      phone(tester);
      final out = await open(tester, const {});
      await tester.tap(find.byKey(BotMatchBody.rolesLineKey));
      await tester.pumpAndSettle();
      for (final r in OptionalRole.values) {
        expect(find.byKey(OptionalRoleRows.switchKey(r)), findsNothing);
      }
      await tester.tap(find.byKey(BotMatchBody.startKey));
      await tester.pumpAndSettle();
      final pick = out.single!;
      expect(pick.settings.silencerEnabled, isFalse);
      expect(pick.settings.elderEnabled, isFalse);
      expect(pick.settings.sniperEnabled, isFalse);
      expect(pick.roleCounts.containsKey(Role.sniper), isFalse);
    });
  });

  group('online room settings', () {
    GameSnapshot lobby() => GameSnapshot(
      public: PublicMatchView(
        phase: GamePhase.setup,
        dayNumber: 0,
        players: [
          for (var seat = 0; seat < 8; seat++)
            PublicPlayer(
              seat: seat,
              name: 'P$seat',
              status: PlayerStatus.alive,
            ),
        ],
      ),
    );

    Future<List<Map<String, dynamic>>> pumpPanel(
      WidgetTester tester,
      Set<String> owns,
    ) async {
      final sent = <Map<String, dynamic>>[];
      final container = ProviderContainer(overrides: _overrides(owns));
      addTearDown(container.dispose);
      await container.read(walletProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            Stack(
              children: [
                RoomSettingsPanel(
                  visible: true,
                  snapshot: lobby(),
                  transport: null,
                  onClose: () {},
                  onChanged: ({visibility, title, settings}) {
                    if (settings != null) sent.add(settings);
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return sent;
    }

    testWidgets('an owned role can be asked for; the others stay shut', (
      tester,
    ) async {
      phone(tester, const Size(500, 2400));
      final sent = await pumpPanel(tester, const {'role_elder'});
      final elder = tester.widget<Switch>(
        find.byKey(RoomSettingsPanel.elderKey),
      );
      expect(elder.onChanged, isNotNull);
      await tester.ensureVisible(find.byKey(RoomSettingsPanel.elderKey));
      await tester.tap(find.byKey(RoomSettingsPanel.elderKey));
      await tester.pump();
      expect(sent.single, {'elderEnabled': true});
      for (final key in [
        RoomSettingsPanel.silencerKey,
        RoomSettingsPanel.sniperKey,
      ]) {
        expect(tester.widget<Switch>(find.byKey(key)).onChanged, isNull);
      }
    });

    testWidgets('nothing owned: no role switch can send anything', (
      tester,
    ) async {
      phone(tester, const Size(500, 2400));
      final sent = await pumpPanel(tester, const {});
      for (final key in [
        RoomSettingsPanel.silencerKey,
        RoomSettingsPanel.elderKey,
        RoomSettingsPanel.sniperKey,
      ]) {
        expect(tester.widget<Switch>(find.byKey(key)).onChanged, isNull);
      }
      expect(sent, isEmpty);
    });
  });
}
