import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/bots/bot_brain.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/presets.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/bot_match_sheet.dart';
import 'package:mafia_master/ui/screens/setup/optional_roles.dart';
import 'package:mafia_master/ui/screens/setup/role_rows.dart';
import 'package:mafia_master/ui/widgets/deck/card_fan.dart';

import '../support/artwork.dart';
import '../support/fake_backend.dart';
import '../support/localized.dart';

/// «ضد الكمبيوتر» (P7): the table, the three levels, the roles line.
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

void main() {
  const phones = <Size>[Size(360, 640), Size(430, 932)];

  void phone(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Opens the sheet from a button; returns what «ابدأ الماتش» hands back.
  Future<List<BotMatchPick?>> open(
    WidgetTester tester, {
    Set<String> owns = const {},
    bool still = false,
  }) async {
    final out = <BotMatchPick?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
        ],
        child: localizedApp(
          MediaQuery(
            data: MediaQueryData(
              size: tester.view.physicalSize / tester.view.devicePixelRatio,
              disableAnimations: still,
            ),
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const ValueKey('open'),
                    onPressed: () async =>
                        out.add(await showBotMatchSheet(context)),
                    child: const Text('open'),
                  ),
                ),
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

  int seats(WidgetTester tester) => tester
      .widget<CardFan>(
        find.descendant(
          of: find.byKey(BotMatchBody.tableKey),
          matching: find.byType(CardFan),
        ),
      )
      .cards
      .length;

  for (final size in phones) {
    testWidgets('fits ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      await loadArtwork(tester);
      phone(tester, size);
      await open(tester);
      expect(tester.takeException(), isNull);
      expect(seats(tester), 8);
      // The roles line opens too, and still fits.
      await tester.ensureVisible(find.byKey(BotMatchBody.rolesLineKey));
      await tester.tap(find.byKey(BotMatchBody.rolesLineKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byType(OptionalRoleRows, skipOffstage: false),
        findsOneWidget,
      );
    });
  }

  testWidgets('the stepper fans seats in and stops at its bounds', (
    tester,
  ) async {
    phone(tester, phones[1]);
    await open(tester);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(BotMatchBody.minusKey));
      await tester.pumpAndSettle();
    }
    expect(seats(tester), 5);
    expect(
      tester.widget<IconButton>(find.byKey(BotMatchBody.minusKey)).onPressed,
      isNull,
    );
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byKey(BotMatchBody.plusKey));
      await tester.pumpAndSettle();
    }
    expect(seats(tester), 12);
    expect(
      tester.widget<IconButton>(find.byKey(BotMatchBody.plusKey)).onPressed,
      isNull,
    );
  });

  testWidgets('the start button hands back size, level and preset', (
    tester,
  ) async {
    phone(tester, phones[1]);
    final out = await open(tester);
    await tester.tap(find.byKey(BotMatchBody.plusKey));
    await tester.tap(find.byKey(BotMatchBody.levelKey(BotLevel.hard)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BotMatchBody.startKey));
    await tester.pumpAndSettle();
    final pick = out.single!;
    expect(pick.players, 9);
    expect(pick.level, BotLevel.hard);
    expect(pick.preset, MatchPreset.classic);
    expect(pick.roles, isEmpty);
    expect(pick.roleCounts.values.fold<int>(0, (a, b) => a + b), 9);
    expect(pick.settings.silencerEnabled, isFalse);
  });

  testWidgets('owned roles get a switch, the rest a lock', (tester) async {
    phone(tester, phones[1]);
    await open(tester, owns: {'role_silencer', 'role_elder'});
    await tester.tap(find.byKey(BotMatchBody.rolesLineKey));
    await tester.pumpAndSettle();
    expect(
      find.byKey(OptionalRoleRows.switchKey(OptionalRole.silencer)),
      findsOneWidget,
    );
    expect(
      find.byKey(OptionalRoleRows.lockKey(OptionalRole.sniper)),
      findsOneWidget,
    );
  });

  testWidgets('owned roles reach the pick and become a legal split', (
    tester,
  ) async {
    phone(tester, phones[1]);
    final out = await open(tester, owns: {'role_silencer', 'role_elder'});
    await tester.tap(find.byKey(BotMatchBody.rolesLineKey));
    await tester.pumpAndSettle();
    for (final r in [OptionalRole.silencer, OptionalRole.elder]) {
      final sw = find.byKey(OptionalRoleRows.switchKey(r));
      await tester.ensureVisible(sw);
      await tester.tap(sw);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(BotMatchBody.startKey));
    await tester.pumpAndSettle();
    final pick = out.single!;
    expect(pick.settings.silencerEnabled, isTrue);
    expect(pick.settings.elderEnabled, isTrue);
    expect(pick.settings.sniperEnabled, isFalse);
    expect(pick.roleCounts[Role.silencer], 1);
    expect(pick.roleCounts[Role.elder], 1);
    expect(pick.roleCounts.values.fold<int>(0, (a, b) => a + b), 8);
  });

  testWidgets('a role left on at a table that cannot take it is dropped', (
    tester,
  ) async {
    final pick = (
      players: 5,
      preset: MatchPreset.classic,
      level: BotLevel.normal,
      roles: OptionalRole.values.toSet(),
    );
    expect(pick.effectiveRoles, isEmpty);
    expect(pick.settings.sniperEnabled, isFalse);
    expect(pick.roleCounts.values.fold<int>(0, (a, b) => a + b), 5);
  });

  testWidgets('reduced motion: nothing animates', (tester) async {
    await loadArtwork(tester);
    phone(tester, phones[0]);
    await open(tester, still: true);
    await tester.tap(find.byKey(BotMatchBody.plusKey));
    await tester.tap(find.byKey(BotMatchBody.levelKey(BotLevel.easy)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(seats(tester), 9);
  });
}
