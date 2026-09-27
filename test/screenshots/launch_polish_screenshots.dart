/// Renders the 1.0.1+10 launch-polish screens (History as case files, the
/// mode choice with painted marks) for the owner to look at.
///
/// **Not a test** (no `_test` suffix, asserts nothing), like
/// `update101_screenshots.dart`.
///
///     flutter test test/screenshots/launch_polish_screenshots.dart
///
/// Writes to `build/screens_launch/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/online_match_history.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/ui/screens/postgame/history_screen.dart';
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';

import '../support/localized.dart';
import '../support/scripted_match.dart';

const _phone = Size(390, 844);

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
  final out = Directory('build/screens_launch')..createSync(recursive: true);

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget child, {
    List<Override> overrides = const [],
    Locale locale = const Locale('ar'),
  }) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = _phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: overrides,
          child: localizedApp(child, locale: locale),
        ),
      ),
    );
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
      await tester.pump(const Duration(milliseconds: 300));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 1);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  testWidgets('history — case files', (tester) async {
    SharedPreferences.setMockInitialValues({
      OnlineMatchHistory.storageKey:
          '[{"roomId":"r1","names":["ليلى","كريم","سارة","عمر","نور"],"winner":"mafia","days":3}]',
    });
    final store = MemoryMatchStore();
    for (final seed in [3, 7]) {
      final engine = scriptedMatch(
        playToEnd: true,
        seed: seed,
        createdAt: DateTime(2026, 9, 20 + seed),
      );
      await tester.runAsync(
        () => MemoryMatchRepository(store).persistStep(engine.match),
      );
    }
    await shoot(
      tester,
      'history_ar',
      HistoryScreen(onOpen: (_) {}, onBack: () {}),
      overrides: [
        matchRepositoryProvider.overrideWithValue(MemoryMatchRepository(store)),
      ],
    );
  });

  testWidgets('history — empty', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await shoot(
      tester,
      'history_empty_ar',
      HistoryScreen(onOpen: (_) {}, onBack: () {}),
      overrides: [
        matchRepositoryProvider.overrideWithValue(
          MemoryMatchRepository(MemoryMatchStore()),
        ),
      ],
    );
  });

  testWidgets('mode choice', (tester) async {
    await shoot(
      tester,
      'mode_ar',
      ModeScreen(onBack: () {}, onPlayOnline: () {}, onPlayOffline: () {}),
    );
  });
}
