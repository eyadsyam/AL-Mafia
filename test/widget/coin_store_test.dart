import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/cosmetic_paint.dart';
import 'package:mafia_master/ui/economy/cosmetic_preview.dart';
import 'package:mafia_master/ui/economy/cosmetics.dart';
import 'package:mafia_master/ui/economy/purchase_reveal.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';
import 'package:mafia_master/ui/screens/setup/help_center.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

Map<String, dynamic> wallet({
  int balance = 1000,
  List<String> owned = const [],
  Map<String, String> equipped = const {},
  List<Map<String, Object?>> history = const [],
}) => {
  'balance': balance,
  'catalog': [
    {
      'code': 'frame_gilded',
      'price': 200,
      'charge': 200,
      'kind': 'frame',
      'slot': 'frame',
    },
    {
      'code': 'plate_noir',
      'price': 150,
      'charge': 150,
      'kind': 'nameplate',
      'slot': 'nameplate',
    },
    {
      'code': 'pack_midnight_manor',
      'price': 600,
      'charge': 600,
      'kind': 'presentation_pack',
      'slot': 'room_pack',
    },
    {
      'code': 'pack_old_town',
      'price': 900,
      'charge': 900,
      'kind': 'presentation_pack',
      'slot': 'room_pack',
    },
    {
      'code': 'narrator_storyteller',
      'price': 1200,
      'charge': 1200,
      'kind': 'narrator_pack',
      'slot': 'narrator',
    },
    {
      'code': 'bundle_council',
      'price': 2300,
      'charge': owned.contains('pack_midnight_manor') ? 1700 : 2300,
      'kind': 'bundle',
      'contents': [
        'pack_midnight_manor',
        'pack_old_town',
        'narrator_storyteller',
      ],
    },
    // A code this build cannot draw is never offered.
    {
      'code': 'future_item',
      'price': 10,
      'charge': 10,
      'kind': 'frame',
      'slot': 'frame',
    },
    // The guide left the store.
    {'code': 'mastermind_guide', 'price': 400, 'charge': 400, 'kind': 'guide'},
  ],
  'owned': owned,
  'equipped': equipped,
  'history': history,
};

void main() {
  late FakeBackend backend;
  late AudioDirector audio;

  setUp(() {
    backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    );
    audio = AudioDirector();
  });

  Future<void> pumpStore(
    WidgetTester tester, {
    bool webTransfer = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          audioDirectorProvider.overrideWithValue(audio),
          paymentCapabilitiesProvider.overrideWithValue(
            PaymentCapabilities(transfer: webTransfer),
          ),
        ],
        child: localizedApp(const CoinStore()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Iterable<FakeCall> economy(String action) => backend.calls.where(
    (call) => call.function == 'economy' && call.body['action'] == action,
  );

  testWidgets('the shop offers only real, drawable content', (tester) async {
    backend.responses['economy'] = wallet();
    await pumpStore(tester);
    expect(find.text('1000'), findsOneWidget);
    expect(find.text(arStrings.coinsName), findsWidgets);
    for (final code in [
      'frame_gilded',
      'plate_noir',
      'pack_midnight_manor',
      'narrator_storyteller',
      'bundle_council',
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(CoinStore.item(code)),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(CoinStore.shopList),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byKey(CoinStore.item(code)), findsOneWidget);
    }
    expect(find.byKey(CoinStore.item('future_item')), findsNothing);
    expect(find.byKey(CoinStore.item('mastermind_guide')), findsNothing);
    // The Play-safe default has no coin purchase tab at all.
    expect(find.text(arStrings.storeTabCoins), findsNothing);
  });

  testWidgets('buying sends only the code, once, and shows the server result', (
    tester,
  ) async {
    backend.responses['economy'] = wallet();
    await pumpStore(tester);
    await tester.tap(find.byKey(CoinStore.item('frame_gilded')));
    await tester.pumpAndSettle();
    // The real preview: a seat with the frame drawn around it.
    expect(find.byType(SeatPreview), findsOneWidget);

    backend.responses['economy'] = wallet(
      balance: 800,
      owned: ['frame_gilded'],
    );
    await tester.tap(find.byKey(CoinStore.buy('frame_gilded')));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.storeBuyConfirmBody(200)), findsOneWidget);
    await tester.tap(find.byKey(CoinStore.confirmBuy));
    await tester.pumpAndSettle();

    final buys = economy('buy').toList();
    expect(buys, hasLength(1));
    expect(buys.single.body.keys.toSet(), {'action', 'item'});
    expect(buys.single.body['item'], 'frame_gilded');
    // Store truth: the purchase ends on the item doing its job on the buyer,
    // with one tap to wear it.
    expect(find.byKey(PurchaseReveal.revealKey), findsOneWidget);
    expect(find.byKey(CosmeticFrameRing.ringKey), findsOneWidget);
    backend.responses['economy'] = wallet(
      balance: 800,
      owned: ['frame_gilded'],
      equipped: {'frame': 'frame_gilded'},
    );
    await tester.tap(find.byKey(PurchaseReveal.equipNowKey));
    await tester.pumpAndSettle();
    final equips = economy('equip').toList();
    expect(equips, hasLength(1));
    expect(equips.single.body['slot'], 'frame');
    expect(equips.single.body['item'], 'frame_gilded');
    expect(find.byKey(PurchaseReveal.revealKey), findsNothing);
    expect(find.text('800'), findsOneWidget);
  });

  testWidgets('not enough coins: no buy, and how long it takes to earn', (
    tester,
  ) async {
    backend.responses['economy'] = wallet(balance: 250);
    await pumpStore(tester);
    await tester.scrollUntilVisible(
      find.byKey(CoinStore.item('narrator_storyteller')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(CoinStore.shopList),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // The rails are shorter than the old list rows: a card found in the
    // cache extent may still be below the fold.
    await tester.ensureVisible(
      find.byKey(CoinStore.item('narrator_storyteller')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CoinStore.item('narrator_storyteller')));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(CoinStore.buy('narrator_storyteller')),
    );
    expect(button.onPressed, isNull);
    expect(find.text(arStrings.storeNotEnough(950)), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(arStrings.storeEarnTime(950, 10)),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(CoinStore.sheetList),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text(arStrings.storeEarnTime(950, 10)), findsOneWidget);
  });

  testWidgets('a bundle charges only for what is not owned yet', (
    tester,
  ) async {
    backend.responses['economy'] = wallet(
      balance: 3000,
      owned: ['pack_midnight_manor'],
    );
    await pumpStore(tester);
    await tester.scrollUntilVisible(
      find.byKey(CoinStore.item('bundle_council')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(CoinStore.shopList),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byKey(CoinStore.item('bundle_council')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CoinStore.item('bundle_council')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(arStrings.storeBuyFor(1700)),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(CoinStore.sheetList),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text(arStrings.storeBuyFor(1700)), findsOneWidget);
    // It says what the bundle saves against buying the rest one by one.
    expect(find.text(arStrings.storeBundleSaves(2100 - 1700)), findsOneWidget);
  });

  testWidgets('owned identity items are equipped through the server', (
    tester,
  ) async {
    backend.responses['economy'] = wallet(owned: ['frame_gilded']);
    await pumpStore(tester);
    await tester.tap(find.text(arStrings.storeTabCollection));
    await tester.pumpAndSettle();
    backend.responses['economy'] = wallet(
      owned: ['frame_gilded'],
      equipped: {'frame': 'frame_gilded'},
    );
    await tester.tap(find.byKey(CoinStore.equip('frame_gilded')));
    await tester.pumpAndSettle();
    final equip = economy('equip').single;
    expect(equip.body['slot'], 'frame');
    expect(equip.body['item'], 'frame_gilded');
    expect(find.text(arStrings.storeUnequip), findsOneWidget);
  });

  testWidgets(
    'a pack preview is the pack: backdrop, transition, lines, sound',
    (tester) async {
      backend.responses['economy'] = wallet();
      await pumpStore(tester);
      await tester.scrollUntilVisible(
        find.byKey(CoinStore.item('pack_midnight_manor')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(CoinStore.shopList),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // The rails are shorter than the old list rows: a card found in the
      // cache extent may still be below the fold.
      await tester.ensureVisible(
        find.byKey(CoinStore.item('pack_midnight_manor')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CoinStore.item('pack_midnight_manor')));
      await tester.pumpAndSettle();
      expect(find.byType(PackBackdrop), findsOneWidget);
      expect(find.text(arStrings.packManorIntro), findsOneWidget);
      await tester.tap(find.byKey(PackPreview.transitionButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(PackTransitionOverlay.overlayKey), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PackPreview.introSoundButton));
      expect(audio.emittedAccents, [
        Cosmetics.packs['pack_midnight_manor']!.introSound,
      ]);
      // Muted means silent, preview or not.
      audio.muted = true;
      await tester.tap(find.byKey(PackPreview.introSoundButton));
      expect(audio.emittedAccents, hasLength(1));
    },
  );

  testWidgets('history names each movement', (tester) async {
    backend.responses['economy'] = wallet(
      history: [
        {
          'kind': 'match_completion',
          'amount': 100,
          'at': '2026-09-20T10:00:00Z',
        },
        {
          'kind': 'catalog_spend',
          'amount': -200,
          'item': 'frame_gilded',
          'at': '2026-09-21T10:00:00Z',
        },
        {
          'kind': 'catalog_refund',
          'amount': 400,
          'item': 'mastermind_guide',
          'at': '2026-09-22T10:00:00Z',
        },
      ],
    );
    await pumpStore(tester);
    await tester.tap(find.text(arStrings.storeTabHistory));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.historyMatchCompletion), findsOneWidget);
    expect(
      find.text(arStrings.historyCatalogSpend(arStrings.cosmeticFrameGilded)),
      findsOneWidget,
    );
    expect(
      find.text(arStrings.historyCatalogRefund(arStrings.coinsGuideTitle)),
      findsOneWidget,
    );
    expect(find.text('+100'), findsOneWidget);
    expect(find.text('-200'), findsOneWidget);
  });

  testWidgets('a failed load says nothing was deducted and retries', (
    tester,
  ) async {
    // The network is down for every economy call (capabilities included).
    backend.refusals['economy'] = const BackendException('NETWORK', 'down');
    backend.stickyRefusals.add('economy');
    await pumpStore(tester);
    expect(find.text(arStrings.coinsLoadFailed), findsOneWidget);
  });

  testWidgets('the strategy guide is free in Help', (tester) async {
    await tester.pumpWidget(localizedApp(const HelpCenter()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(arStrings.coinsGuideTitle),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(arStrings.coinsGuideTitle), findsOneWidget);
  });
}
