/// Renders Council Life (phase 107) for looking at.
///
/// **Not a test** (no `_test` suffix, asserts nothing), like
/// `store_screenshots.dart`. Real fonts and the real asset bundle.
///
///     flutter test test/widget/council_screenshots.dart
///
/// Writes to `build/phase107/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/ui/economy/cosmetic_art_cache.dart';
import 'package:mafia_master/ui/economy/cosmetic_paint.dart';
import 'package:mafia_master/ui/economy/council_art.dart';
import 'package:mafia_master/ui/economy/council_hub.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import 'council_life_test.dart' as fixtures;

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
  final out = Directory('build/phase107')..createSync(recursive: true);

  Future<void> save(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final widget = element.widget as Image;
        await precacheImage(widget.image, element);
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 2);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  Future<void> show(
    WidgetTester tester,
    Widget child,
    Size size,
    Locale locale, {
    bool reduceMotion = false,
    bool levelUp = false,
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
    );
    backend.responders['economy'] = (body) => switch (body['action']) {
      'capabilities' => fixtures.caps(),
      'contracts_get' => fixtures.contracts(weeklyClaimable: true),
      'rank_get' => fixtures.rank(
        xp: 1250,
        level: 8,
        levelUps: levelUp
            ? [
                {'level': 8, 'coins': 25},
              ]
            : const [],
      ),
      'invite_get' => fixtures.invite(canRedeem: true),
      'leaderboard_get' => {
        'enabled': true,
        'week': '2026-W39',
        'entries': [
          for (var i = 1; i <= 8; i++)
            {
              'position': i,
              'xp': 1200 - i * 90,
              'name': ['ليلى', 'Omar', 'سلمى', 'Karim', 'نور', 'Yara', 'حسن', 'Mona'][i - 1],
              'gender': i.isEven ? 'male' : 'female',
              'level': 50 - i * 6,
              'me': i == 5,
            },
        ],
        'me': {'position': 5, 'xp': 750},
        'visible': true,
      },
      _ => {'ok': true},
    };
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: [
            onlineBackendFactoryProvider.overrideWithValue(() async => backend),
            audioDirectorProvider.overrideWithValue(AudioDirector()),
          ],
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              disableAnimations: reduceMotion,
            ),
            child: localizedApp(Scaffold(body: child), locale: locale),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  for (final (width, locale) in [
    (360.0, const Locale('ar')),
    (390.0, const Locale('en')),
    (320.0, const Locale('ar')),
  ]) {
    testWidgets('hub ${locale.languageCode} $width', (tester) async {
      await show(tester, const CouncilHubTab(), Size(width, 1600), locale);
      await save(tester, 'hub-${locale.languageCode}-${width.toInt()}');
    });
  }

  testWidgets('hub landscape reduced motion', (tester) async {
    await show(
      tester,
      const CouncilHubTab(),
      const Size(780, 360),
      const Locale('ar'),
      reduceMotion: true,
    );
    await save(tester, 'hub-ar-landscape-reduced');
  });

  testWidgets('level up', (tester) async {
    await show(
      tester,
      const CouncilHubTab(),
      const Size(360, 780),
      const Locale('ar'),
      levelUp: true,
    );
    await save(tester, 'level-up-ar');
  });

  testWidgets('leaderboard', (tester) async {
    await show(tester, const CouncilHubTab(), const Size(360, 780), const Locale('ar'));
    await tester.tap(find.byKey(CouncilHubTab.leaderboardKey));
    await tester.pumpAndSettle();
    await save(tester, 'leaderboard-ar');
  });

  testWidgets('emblems and seal', (tester) async {
    await show(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var tier = 1; tier <= 10; tier++)
                  RankEmblem(level: tier * 5, size: CouncilLifeTokens.emblemCard),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                for (var tier = 1; tier <= 10; tier++)
                  RankEmblem(level: tier * 5, size: CouncilLifeTokens.emblemSeat),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                for (final m in ['finish', 'town', 'mafia', 'win', 'host', 'reunion'])
                  ContractIcon(metric: m),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StarterBundleArt(),
                SizedBox(width: 16),
                SeatPreview(name: 'ليلى', frame: 'frame_council_seal'),
              ],
            ),
          ],
        ),
      ),
      const Size(420, 640),
      const Locale('ar'),
    );
    await save(tester, 'emblems-seal');
  });
}
