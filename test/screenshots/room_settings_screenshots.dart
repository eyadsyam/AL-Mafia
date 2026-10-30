/// Renders the host's room settings, the deal and «شكلي وأدواتي», for a look.
/// **Not a test** (no `_test` suffix, asserts nothing).
///
///     flutter test test/screenshots/room_settings_screenshots.dart
///
/// Writes to `build/screens_room_settings/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/ui/economy/table_tools.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/my_match_panel.dart';
import 'package:mafia_master/ui/screens/online/online_deal_panel.dart';
import 'package:mafia_master/ui/screens/online/room_settings_panel.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

const _everything = {
  'role_silencer',
  'role_elder',
  'role_sniper',
  'frame_gilded',
  'frame_crimson',
  'frame_moonlit',
  'plate_noir',
  'pack_midnight_manor',
  'pack_old_town',
  'narrator_storyteller',
  'narrator_keeper',
  'narrator_noir',
};

class _Wallet extends WalletController {
  @override
  Future<WalletState?> build() async => const WalletState(
    balance: 0,
    catalog: [],
    owned: _everything,
    equipped: {'frame': 'frame_gilded'},
    history: [],
  );
}

class _Tools extends TableToolsController {
  @override
  Future<TableToolsState> build() async => TableToolsState.fromJson({
    'balance': 0,
    'tools': [
      for (final (code, phase) in const [
        ('lock_door', 'night'),
        ('sense', 'night'),
        ('double_vote', 'vote'),
        ('vote_shield', 'vote'),
        ('extra_minute', 'discuss'),
        ('impersonate', 'discuss'),
      ])
        {
          'code': code,
          'phase': phase,
          'charges': 2,
          'tier': 'light',
          'packs': {'1': 50},
        },
    ],
  });
}

Future<void> _fonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'Aref Ruqaa': 'assets/fonts/ArefRuqaa-Bold.ttf',
    'IBM Plex Mono': 'assets/fonts/IBMPlexMono-Regular.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

GameSnapshot _lobby(int seats) => GameSnapshot(
  public: PublicMatchView(
    phase: GamePhase.setup,
    dayNumber: 0,
    players: [
      for (var seat = 0; seat < seats; seat++)
        PublicPlayer(seat: seat, name: 'P$seat', status: PlayerStatus.alive),
    ],
  ),
  settings: const MatchSettings(sniperEnabled: true, elderEnabled: true),
);

void main() {
  final out = Directory('build/screens_room_settings')
    ..createSync(recursive: true);

  Future<void> capture(WidgetTester tester, String name) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage(
            (element.widget as Image).image,
            element,
          ).timeout(const Duration(seconds: 2), onTimeout: () {});
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 1);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${out.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.runAsync(_fonts);
    await loadArtwork(tester);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: [
            walletProvider.overrideWith(_Wallet.new),
            tableToolsProvider.overrideWith(_Tools.new),
            audioDirectorProvider.overrideWithValue(AudioDirector()),
          ],
          child: localizedApp(Stack(children: [child])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('settings', (tester) async {
    await pump(
      tester,
      RoomSettingsPanel(
        visible: true,
        snapshot: _lobby(3),
        transport: null,
        onClose: () {},
        onChanged: ({visibility, title, settings}) {},
      ),
    );
    await capture(tester, '1_room');
    for (final (id, name) in const [
      ('roles', '2_roles'),
      ('look', '3_look'),
      ('play', '7_play'),
      ('info', '8_info'),
    ]) {
      await tester.tap(find.byKey(RoomSettingsPanel.section(id)));
      await tester.pumpAndSettle();
      await capture(tester, name);
    }
    await tester.tap(find.byKey(RoomSettingsPanel.section('info')));
    await tester.pumpAndSettle();
    await capture(tester, '0_all_closed');
  });

  testWidgets('deal', (tester) async {
    await pump(
      tester,
      OnlineDealPanel(
        visible: true,
        players: 3,
        settings: const MatchSettings(sniperEnabled: true, elderEnabled: true),
        base: null,
        onBase: (_) {},
        onRole: (_, _) {},
        onClose: () {},
      ),
    );
    await capture(tester, '4_deal');
  });

  testWidgets('mine', (tester) async {
    await pump(tester, MyMatchPanel(visible: true, onClose: () {}));
    await capture(tester, '5_my_look');
    await tester.tap(find.text('أدواتك'));
    await tester.pumpAndSettle();
    await capture(tester, '6_my_tools');
  });
}
