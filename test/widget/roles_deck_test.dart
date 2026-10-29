import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';
import 'package:mafia_master/ui/screens/setup/optional_roles.dart';
import 'package:mafia_master/ui/screens/setup/role_deal_grid.dart';
import 'package:mafia_master/ui/screens/setup/roles_screen.dart';
import 'package:mafia_master/ui/widgets/deck/deck_public.dart' show DeckChip;

import '../support/artwork.dart';
import '../support/fake_backend.dart';
import '../support/localized.dart';

/// «الأدوار» (P6): presets, the fan, rows, and the bought roles.
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

typedef _Out = ({List<Map<Role, int>> dealt, List<Set<OptionalRole>> optional});

void main() {
  const phones = <Size>[Size(360, 640), Size(430, 932)];

  void phone(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<_Out> pump(
    WidgetTester tester, {
    int players = 8,
    Set<String> owns = const {},
    bool still = false,
  }) async {
    final dealt = <Map<Role, int>>[];
    final optional = <Set<OptionalRole>>[];
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
            child: RolesScreen(
              playerCount: players,
              onBack: () {},
              onNext: dealt.add,
              onOptionalRoles: optional.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (dealt: dealt, optional: optional);
  }

  /// Every card the deal grid shows, summed: the whole table.
  int fan(WidgetTester tester) => [
    for (final r in Role.values)
      int.parse(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(RoleDealGrid.count(r)),
                matching: find.byType(Text),
              ),
            )
            .data!,
      ),
  ].fold(0, (a, b) => a + b);

  Finder inc(String label) =>
      find.byTooltip('${arStrings.increaseRole} $label');

  for (final size in phones) {
    for (final n in [5, 8, 20]) {
      testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} at $n', (
        tester,
      ) async {
        await loadArtwork(tester);
        phone(tester, size);
        await pump(tester, players: n);
        expect(tester.takeException(), isNull);
        expect(fan(tester), n);
      });
    }
  }

  testWidgets('the fan follows the steppers and an edit means custom', (
    tester,
  ) async {
    phone(tester, phones[1]);
    await pump(tester);
    expect(find.text(arStrings.rolesBalanceLine(2, 6)), findsOneWidget);
    await tester.tap(inc(arStrings.roleGroupMafia));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.rolesBalanceLine(3, 5)), findsOneWidget);
    expect(fan(tester), 8);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(RoleDealGrid.count(Role.citizen)),
              matching: find.byType(Text),
            ),
          )
          .data,
      '3',
    );
    DeckChip chip(String code) =>
        tester.widget<DeckChip>(find.byKey(RolesScreen.preset(code)));
    expect(chip('custom').selected, isTrue);
    expect(chip('normal').selected, isFalse);
  });

  testWidgets('hard takes a third of the table and no Doctor', (tester) async {
    phone(tester, phones[1]);
    final out = await pump(tester);
    await tester.tap(find.byKey(RolesScreen.preset('hard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RolesScreen.nextButton));
    expect(out.dealt.single[Role.mafia], 2);
    expect(out.dealt.single[Role.doctor], isNull);
    expect(out.dealt.single.values.fold<int>(0, (a, b) => a + b), 8);
  });

  testWidgets('hard is not offered under eight', (tester) async {
    phone(tester, phones[1]);
    await pump(tester, players: 6);
    await tester.tap(
      find.byKey(RolesScreen.preset('hard')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text(arStrings.rolesBalanceLine(1, 5)), findsOneWidget);
  });

  testWidgets('citizens are computed and cannot be edited', (tester) async {
    phone(tester, phones[1]);
    await pump(tester);
    for (final key in [
      RoleDealGrid.plus(Role.citizen),
      RoleDealGrid.minus(Role.citizen),
    ]) {
      expect(tester.widget<IconButton>(find.byKey(key)).onPressed, isNull);
    }
    expect(find.byKey(RoleDealGrid.count(Role.citizen)), findsOneWidget);
  });

  testWidgets('not owned: the row is locked and the pill opens the store', (
    tester,
  ) async {
    phone(tester, phones[1]);
    await pump(tester);
    for (final r in OptionalRole.values) {
      expect(find.byKey(RoleDealGrid.plus(r.role)), findsNothing);
      expect(find.byKey(RoleDealGrid.lock(r.role)), findsOneWidget);
    }
    expect(find.text(arStrings.roleLockedPill), findsNWidgets(3));
    final lock = find.byKey(RoleDealGrid.lock(Role.sniper));
    await tester.ensureVisible(lock);
    await tester.tap(lock);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CoinStore), findsOneWidget);
  });

  testWidgets('owned: a switch that takes a seat and tells the router', (
    tester,
  ) async {
    phone(tester, phones[1]);
    final out = await pump(
      tester,
      players: 8,
      owns: {'role_silencer', 'role_elder', 'role_sniper'},
    );
    for (final r in OptionalRole.values) {
      await tester.ensureVisible(find.byKey(RoleDealGrid.plus(r.role)));
      await tester.tap(find.byKey(RoleDealGrid.plus(r.role)));
      await tester.pumpAndSettle();
    }
    expect(fan(tester), 8);
    await tester.tap(find.byKey(RolesScreen.nextButton));
    final counts = out.dealt.single;
    expect(counts[Role.silencer], 1);
    expect(counts[Role.mafia], 1);
    expect(counts[Role.elder], 1);
    expect(counts[Role.sniper], 1);
    expect(counts[Role.citizen], 2);
    expect(counts.values.fold<int>(0, (a, b) => a + b), 8);
    expect(out.optional.single, OptionalRole.values.toSet());
  });

  testWidgets('a small table says why it cannot take a role', (tester) async {
    phone(tester, phones[1]);
    await pump(tester, players: 5, owns: {'role_elder', 'role_sniper'});
    final plus = tester.widget<IconButton>(
      find.byKey(RoleDealGrid.plus(Role.sniper)),
    );
    expect(plus.onPressed, isNull);
    expect(find.text(arStrings.balanceSniperMinPlayers), findsOneWidget);
  });

  testWidgets('always tells the router, with none on', (tester) async {
    phone(tester, phones[1]);
    final out = await pump(tester);
    await tester.tap(find.byKey(RolesScreen.nextButton));
    expect(out.optional.single, isEmpty);
    expect(out.dealt, hasLength(1));
  });

  testWidgets('reduced motion: the deal is simply there', (tester) async {
    await loadArtwork(tester);
    phone(tester, phones[0]);
    await pump(tester, still: true);
    await tester.ensureVisible(inc(arStrings.roleGroupDoctor));
    await tester.tap(inc(arStrings.roleGroupDoctor));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(fan(tester), 8);
    expect(
      find
          .descendant(
            of: find.byKey(RoleDealGrid.card(Role.doctor)),
            matching: find.byType(Opacity),
          )
          .evaluate()
          .map((e) => (e.widget as Opacity).opacity)
          .every((o) => o == 1),
      isTrue,
    );
  });
}
