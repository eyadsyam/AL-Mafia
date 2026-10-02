import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/ui/economy/cosmetic_art_cache.dart';
import 'package:mafia_master/ui/economy/cosmetics.dart';
import 'package:mafia_master/ui/economy/cosmetic_paint.dart';
import 'package:mafia_master/ui/economy/store_art.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// The full store v2 catalog as the server would list it once
/// 20260924000700_store_v2_catalog is applied.
const _catalog = <(String, int, String, String?)>[
  ('frame_gilded', 200, 'frame', 'frame'),
  ('frame_crimson', 250, 'frame', 'frame'),
  ('frame_moonlit', 300, 'frame', 'frame'),
  ('plate_noir', 150, 'nameplate', 'nameplate'),
  ('plate_gilded', 250, 'nameplate', 'nameplate'),
  ('plate_ember', 300, 'nameplate', 'nameplate'),
  ('pack_midnight_manor', 600, 'presentation_pack', 'room_pack'),
  ('pack_old_town', 900, 'presentation_pack', 'room_pack'),
  ('pack_moonlit_archive', 750, 'presentation_pack', 'room_pack'),
  ('narrator_storyteller', 1200, 'narrator_pack', 'narrator'),
  ('narrator_keeper', 1000, 'narrator_pack', 'narrator'),
  ('narrator_noir', 1000, 'narrator_pack', 'narrator'),
  ('bundle_council', 2300, 'bundle', null),
  ('bundle_identity', 1200, 'bundle', null),
  ('bundle_nocturne', 1800, 'bundle', null),
];

Map<String, dynamic> _wallet({
  int balance = 3000,
  List<String> owned = const [],
  Map<String, String> equipped = const {},
  Set<String> listed = const {},
}) => {
  'balance': balance,
  'catalog': [
    for (final (code, price, kind, slot) in _catalog)
      if (listed.isEmpty || listed.contains(code))
        {
          'code': code,
          'price': price,
          'charge': price,
          'kind': kind,
          'slot': slot,
        },
  ],
  'owned': owned,
  'equipped': equipped,
  'history': const [],
};

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    );
  });

  Widget scope(Widget child, {Locale locale = const Locale('ar')}) =>
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
          paymentCapabilitiesProvider.overrideWithValue(
            const PaymentCapabilities(webTransfer: false),
          ),
        ],
        child: localizedApp(child, locale: locale),
      );

  Future<void> pumpStore(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    Locale locale = const Locale('ar'),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(scope(const CoinStore(), locale: locale));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Finder rail(String id) => find
      .descendant(
        of: find.byKey(CoinStore.rail(id)),
        matching: find.byType(Scrollable),
      )
      .first;

  Iterable<FakeCall> economy(String action) => backend.calls.where(
    (call) => call.function == 'economy' && call.body['action'] == action,
  );

  testWidgets('frame and plate art decodes at the bounded sizes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await CosmeticArtCache.load(rootBundle.load);
      // Drawn art only: the Council Seal is vector by design (phase 107).
      for (final style in Cosmetics.frames.values.where(
        (s) => StoreArt.codes.contains(s.artCode),
      )) {
        final image = CosmeticArtCache.images[style.artCode];
        expect(image, isNotNull, reason: style.artCode);
        expect(image!.width, StoreTokens.frameDecodeWidth);
      }
      for (final style in Cosmetics.plates.values) {
        final image = CosmeticArtCache.images[style.artCode];
        expect(image, isNotNull, reason: style.artCode);
        expect(image!.width, StoreTokens.plateDecodeWidth);
      }
      // Every product image in the bundle decodes.
      for (final code in [...StoreArt.codes, 'store_hero']) {
        final path = code == 'store_hero'
            ? StoreArt.hero
            : StoreArt.forCode(code)!;
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 64,
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 64, reason: path);
        frame.image.dispose();
        codec.dispose();
      }
    });
  });

  testWidgets('table frames stay inside the seat artwork bounds', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await CosmeticArtCache.load(rootBundle.load);
      for (final style in Cosmetics.frames.values) {
        final recorder = ui.PictureRecorder();
        paintCosmeticFrame(
          Canvas(recorder),
          const Offset(100, 100),
          88,
          style,
          maxSide: 100,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(200, 200);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var ink = 0;
        for (var y = 0; y < 200; y++) {
          for (var x = 0; x < 200; x++) {
            final alpha = bytes.getUint8((y * 200 + x) * 4 + 3);
            if (x < 50 || x >= 150 || y < 50 || y >= 150) {
              expect(alpha, 0, reason: style.artCode);
            } else {
              ink += alpha;
            }
          }
        }
        expect(
          ink,
          greaterThan(0),
          reason: 'A missing frame must not make the bounds test pass',
        );
        image.dispose();
        picture.dispose();
      }
    });
  });

  group('catalog', () {
    test('every sellable code has a look, art, and a known bundle content', () {
      for (final (code, _, _, _) in _catalog) {
        expect(Cosmetics.knows(code), isTrue, reason: code);
        expect(StoreArt.forCode(code), isNotNull, reason: code);
      }
      for (final code in ['coins_500', 'coins_1200', 'coins_2500']) {
        expect(StoreArt.forCode(code), isNotNull, reason: code);
      }
      expect(StoreArt.forCode('future_item'), isNull);
      for (final kind in CosmeticKind.values) {
        expect(
          Cosmetics.items.values.where((i) => i.kind == kind).length,
          greaterThanOrEqualTo(3),
          reason: '$kind',
        );
      }
      expect(Cosmetics.bundles['bundle_nocturne'], [
        'pack_moonlit_archive',
        'frame_moonlit',
        'plate_noir',
        'narrator_keeper',
      ]);
      // The original collections keep their real contents.
      expect(Cosmetics.bundles['bundle_council'], [
        'pack_midnight_manor',
        'pack_old_town',
        'narrator_storyteller',
      ]);
      expect(Cosmetics.bundles['bundle_identity'], hasLength(6));
      for (final contents in Cosmetics.bundles.values) {
        for (final code in contents) {
          expect(Cosmetics.items[code]?.slot, isNotNull, reason: code);
        }
      }
    });

    test('narration never names a role or a player, in either language', () {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        final l = lookupAppLocalizations(locale);
        final roles = [
          l.roleMafia,
          l.roleDoctor,
          l.roleDetective,
          l.roleCitizen,
          l.previewSampleName,
        ];
        final lines = <String>{
          for (final narrator in Cosmetics.narrators.values)
            for (final beat in NarrationBeat.values) narrator.line(l, beat),
          for (final pack in Cosmetics.packs.values) ...[
            pack.intro(l),
            pack.outro(l),
          ],
        };
        // 3 narrators x 5 beats + 3 packs x 2, all distinct.
        expect(lines, hasLength(21), reason: '$locale');
        for (final line in lines) {
          expect(line.trim(), isNotEmpty);
          for (final role in roles) {
            expect(line.contains(role), isFalse, reason: '$locale: $line');
          }
        }
      }
    });

    test('the server decides what is for sale: unlisted codes are absent', () {
      // Until the owner applies the migration, the hosted catalog lists 11.
      final hosted = _wallet(
        listed: {
          for (final (code, _, _, _) in _catalog)
            if (!const {
              'pack_moonlit_archive',
              'narrator_keeper',
              'narrator_noir',
              'bundle_nocturne',
            }.contains(code))
              code,
        },
      );
      final decoded = WalletState.fromJson(hosted);
      expect(decoded.catalog, hasLength(11));
      expect(
        decoded.catalog.any((item) => item.code == 'pack_moonlit_archive'),
        isFalse,
      );
    });
  });

  group('layout', () {
    testWidgets('360 dp Arabic: the first product is on the first screen', (
      tester,
    ) async {
      backend.responses['economy'] = _wallet();
      await pumpStore(tester);
      final card = tester.getRect(find.byKey(CoinStore.item('frame_gilded')));
      expect(card.bottom, lessThanOrEqualTo(780));
      // Arabic rails start on the right, and the next card's edge shows.
      expect(card.right, closeTo(360 - 16, 1));
      final second = tester.getRect(
        find.byKey(CoinStore.item('frame_crimson')),
      );
      expect(second.right, lessThan(card.left));
      expect(second.left, lessThan(16)); // clipped by the rail at x=16
      expect(tester.takeException(), isNull);
    });

    testWidgets('English rails start on the left', (tester) async {
      backend.responses['economy'] = _wallet();
      await pumpStore(tester, locale: const Locale('en'));
      final card = tester.getRect(find.byKey(CoinStore.item('frame_gilded')));
      expect(card.left, closeTo(16, 1));
      expect(find.text(enStrings.storeFrames), findsOneWidget);
    });

    testWidgets('five rails of three, each scrolling on its own', (
      tester,
    ) async {
      backend.responses['economy'] = _wallet();
      await pumpStore(tester);
      for (final id in ['frames', 'plates', 'rooms', 'narration', 'bundles']) {
        await tester.scrollUntilVisible(
          find.byKey(CoinStore.railNext(id)),
          200,
          scrollable: find
              .descendant(
                of: find.byKey(CoinStore.shopList),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.byKey(CoinStore.railNext(id)));
        await tester.pumpAndSettle();
        final before = tester.state<ScrollableState>(rail(id)).position.pixels;
        expect(
          before,
          0,
          reason: "an untouched rail must not inherit another rail position",
        );
        await tester.tap(find.byKey(CoinStore.railNext(id)));
        await tester.pumpAndSettle();
        final after = tester.state<ScrollableState>(rail(id)).position.pixels;
        expect(after, greaterThan(before), reason: id);
        // At the end «next» is disabled rather than hidden.
        final next = tester.widget<IconButton>(
          find.byKey(CoinStore.railNext(id)),
        );
        expect(next.onPressed, isNull, reason: id);
      }
    });

    testWidgets('desktop keeps a column and hides arrows that have no use', (
      tester,
    ) async {
      backend.responses['economy'] = _wallet();
      await pumpStore(tester, size: const Size(1280, 800));
      final card = tester.getRect(find.byKey(CoinStore.item('frame_gilded')));
      expect(card.right, lessThanOrEqualTo(1280 - (1280 - 960) / 2 + 1));
      expect(find.byKey(CoinStore.railNext('frames')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('arrows and cards meet the 48 dp touch target', (tester) async {
      backend.responses['economy'] = _wallet();
      await pumpStore(tester);
      final arrow = tester.getSize(find.byKey(CoinStore.railNext('frames')));
      expect(arrow.width, greaterThanOrEqualTo(StoreTokens.touchTarget));
      expect(arrow.height, greaterThanOrEqualTo(StoreTokens.touchTarget));
      final info = tester.getSize(find.byKey(CoinStore.earnInfo));
      expect(info.height, greaterThanOrEqualTo(StoreTokens.touchTarget));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('a keyboard can reach and open a product', (tester) async {
      backend.responses['economy'] = _wallet();
      await pumpStore(tester, size: const Size(1280, 800));
      var reached = false;
      for (var i = 0; i < 20 && !reached; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus?.context;
        reached =
            focus != null &&
            focus.widget is Focus &&
            find
                .ancestor(
                  of: find.byWidgetPredicate((w) => identical(w, focus.widget)),
                  matching: find.byKey(CoinStore.item('frame_gilded')),
                )
                .evaluate()
                .isNotEmpty;
      }
      expect(reached, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(CoinStore.sheetList), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('the buy button is on screen without scrolling the sheet', (
      tester,
    ) async {
      backend.responses['economy'] = _wallet();
      await pumpStore(tester);
      await tester.tap(find.byKey(CoinStore.item('frame_gilded')));
      await tester.pumpAndSettle();
      final button = tester.getRect(find.byKey(CoinStore.buy('frame_gilded')));
      expect(button.bottom, lessThanOrEqualTo(780));
      expect(button.height, greaterThanOrEqualTo(StoreTokens.touchTarget - 8));
    });

    testWidgets('after buying, the same sheet offers «use»', (tester) async {
      backend.responses['economy'] = _wallet();
      await pumpStore(tester);
      await tester.tap(find.byKey(CoinStore.item('frame_gilded')));
      await tester.pumpAndSettle();
      backend.responses['economy'] = _wallet(
        balance: 2800,
        owned: ['frame_gilded'],
      );
      await tester.tap(find.byKey(CoinStore.buy('frame_gilded')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CoinStore.confirmBuy));
      await tester.pumpAndSettle();
      expect(economy('buy'), hasLength(1));
      expect(find.byKey(CoinStore.sheetList), findsOneWidget);
      expect(find.byKey(CoinStore.equip('frame_gilded')), findsOneWidget);
      expect(find.text('2800'), findsOneWidget);
    });

    testWidgets('a second tap while equipping sends nothing', (tester) async {
      backend.responses['economy'] = _wallet(owned: ['frame_gilded']);
      await pumpStore(tester);
      await tester.tap(find.byKey(CoinStore.item('frame_gilded')));
      await tester.pumpAndSettle();
      final reply = Completer<Map<String, dynamic>>();
      backend.delayedResponses['economy'] = reply.future;
      await tester.tap(find.byKey(CoinStore.equip('frame_gilded')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(CoinStore.equip('frame_gilded')))
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(CoinStore.equip('frame_gilded')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(economy('equip'), hasLength(1));
      backend.delayedResponses.remove('economy');
      reply.complete(
        _wallet(owned: ['frame_gilded'], equipped: {'frame': 'frame_gilded'}),
      );
      await tester.pumpAndSettle();
      expect(find.text(arStrings.storeUnequip), findsOneWidget);
    });

    testWidgets('system back closes the store, not the screen under it', (
      tester,
    ) async {
      backend.responses['economy'] = _wallet();
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        scope(
          Navigator(
            key: navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('first')),
            ),
          ),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Column(children: [Text('second'), CoinStoreButton()]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CoinStoreButton.buttonKey));
      await tester.pumpAndSettle();
      expect(find.byType(CoinStore), findsOneWidget);

      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(CoinStore), findsNothing);
      expect(find.text('second'), findsOneWidget);

      // With the store closed, back leaves the screen as before.
      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('first'), findsOneWidget);
    });
  });
}
