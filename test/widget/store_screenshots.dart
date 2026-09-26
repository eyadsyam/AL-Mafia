/// Renders the Council Vault and the identity it sells, for looking at.
///
/// **Not a test** (no `_test` suffix, asserts nothing), like
/// `test/online/council_screenshots.dart`. Real fonts and the real asset
/// bundle are loaded so the pictures show the shipped artwork.
///
///     flutter test test/widget/store_screenshots.dart
///
/// Writes to `build/phase98/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/ui/economy/cosmetic_art_cache.dart';
import 'package:mafia_master/ui/economy/store_art.dart';
import 'package:mafia_master/ui/screens/online/council/council_band.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

const _codes = <(String, int, String, String?)>[
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

Map<String, dynamic> _wallet() => {
  'balance': 1450,
  'catalog': [
    for (final (code, price, kind, slot) in _codes)
      {
        'code': code,
        'price': price,
        'charge': price,
        'kind': kind,
        'slot': slot,
      },
  ],
  'owned': ['frame_moonlit', 'plate_noir', 'pack_old_town'],
  'equipped': {'frame': 'frame_moonlit', 'nameplate': 'plate_noir'},
  'history': const [],
};

Future<void> _fonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

void main() {
  final out = Directory('build/phase98')..createSync(recursive: true);

  Future<void> save(WidgetTester tester, String name) async {
    // Image.asset decodes off the fake clock; give it real time.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final widget = element.widget as Image;
        await precacheImage(widget.image, element);
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 2);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${out.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  Future<void> store(
    WidgetTester tester,
    Size size,
    Locale locale, {
    bool webTransfer = false,
  }) async {
    await tester.runAsync(() async {
      await _fonts();
      await CosmeticArtCache.load(rootBundle.load);
    });
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    )..responses['economy'] = _wallet();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: [
            onlineBackendFactoryProvider.overrideWithValue(() async => backend),
            audioDirectorProvider.overrideWithValue(AudioDirector()),
            paymentCapabilitiesProvider.overrideWithValue(
              PaymentCapabilities(transfer: webTransfer),
            ),
          ],
          child: localizedApp(CoinStore(onClose: () {}), locale: locale),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Finder shop() => find
      .descendant(
        of: find.byKey(CoinStore.shopList),
        matching: find.byType(Scrollable),
      )
      .first;

  const narrow = Size(360, 780);

  testWidgets('01 store ar narrow', (tester) async {
    await store(tester, narrow, const Locale('ar'));
    await save(tester, '01-store-ar-360');
    await tester.drag(shop(), const Offset(0, -560));
    await tester.pumpAndSettle();
    await save(tester, '02-store-ar-360-scrolled');
    await tester.drag(shop(), const Offset(0, -900));
    await tester.pumpAndSettle();
    await save(tester, '03-store-ar-360-bottom');
  });

  testWidgets('04 store en narrow', (tester) async {
    await store(tester, narrow, const Locale('en'));
    await save(tester, '04-store-en-360');
  });

  testWidgets('05 store desktop', (tester) async {
    await store(tester, const Size(1280, 800), const Locale('ar'));
    await save(tester, '05-store-ar-desktop');
  });

  for (final code in [
    'frame_gilded',
    'plate_ember',
    'pack_moonlit_archive',
    'narrator_noir',
    'bundle_nocturne',
  ]) {
    testWidgets('detail $code', (tester) async {
      await store(tester, narrow, const Locale('ar'));
      if (StoreArt.forCode(code) == null) return;
      final rail = switch (code.split('_').first) {
        'frame' => 'frames',
        'plate' => 'plates',
        'pack' => 'rooms',
        'narrator' => 'narration',
        _ => 'bundles',
      };
      await tester.scrollUntilVisible(
        find.byKey(CoinStore.rail(rail)),
        200,
        scrollable: shop(),
      );
      await tester.ensureVisible(find.byKey(CoinStore.rail(rail)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(CoinStore.item(code)),
        150,
        scrollable: find
            .descendant(
              of: find.byKey(CoinStore.rail(rail)),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.byKey(CoinStore.item(code)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CoinStore.item(code)));
      await tester.pumpAndSettle();
      await save(tester, '06-detail-$code');
    });
  }

  testWidgets('07 council with identity', (tester) async {
    await tester.runAsync(() async {
      await _fonts();
      await CosmeticArtCache.load(rootBundle.load);
    });
    const phone = Size(412, 915);
    tester.view.physicalSize = phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const names = [
      'أمينة',
      'كريم عبد الرحمن',
      'سارة',
      'يوسف',
      'ليلى',
      'Hassan',
    ];
    final snapshot = GameSnapshot(
      public: PublicMatchView(
        phase: GamePhase.discussion,
        dayNumber: 2,
        players: [
          for (var seat = 0; seat < names.length; seat++)
            PublicPlayer(
              seat: seat,
              name: names[seat],
              status: PlayerStatus.alive,
            ),
        ],
      ),
      viewerSeat: 0,
      connection: ConnectionQuality.connected,
      room: const RoomOptions(presentationPack: 'pack_moonlit_archive'),
      seatCosmetics: const {
        0: SeatCosmetics(frame: 'frame_moonlit', plate: 'plate_noir'),
        1: SeatCosmetics(frame: 'frame_crimson', plate: 'plate_ember'),
        2: SeatCosmetics(frame: 'frame_gilded', plate: 'plate_gilded'),
        4: SeatCosmetics(plate: 'plate_gilded'),
      },
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: [audioDirectorProvider.overrideWithValue(AudioDirector())],
          child: localizedApp(
            TableScene(snapshot: snapshot, centre: const SizedBox.shrink()),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await tester.pump(const Duration(seconds: 2));
    var loaded = false;
    for (var attempt = 0; attempt < 30 && !loaded; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      loaded = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<CouncilPainter>()
          .any((p) => p.idle != null);
    }
    expect(
      loaded,
      isTrue,
      reason: 'Never accept an empty council capture while art is pending',
    );
    await save(tester, '07-council-identity');
  });
}
