/// Renders «قبل ما تبدأوا» and the closed Stories card, for a look.
/// **Not a test** (no `_test` suffix, asserts nothing).
///
///     flutter test test/screenshots/wp6_wp9_screenshots.dart
///
/// Writes to `build/screens_wp6_wp9/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/setup/before_start_sheet.dart';
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

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

void main() {
  final out = Directory('build/screens_wp6_wp9')..createSync(recursive: true);

  Future<void> capture(WidgetTester tester, String name, Size size) async {
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
      File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  Future<void> prepare(WidgetTester tester, Size size) async {
    await tester.runAsync(_fonts);
    await loadArtwork(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget shot(Widget child) =>
      RepaintBoundary(key: const ValueKey('shot'), child: localizedApp(child));

  for (final size in const [Size(360, 640), Size(640, 360)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('picker $tag', (tester) async {
      await prepare(tester, size);
      await tester.pumpWidget(
        shot(
          ModeScreen(
            onPlayOffline: () {},
            onPlayOnline: () {},
            storiesSoon: true,
            onBack: () {},
          ),
        ),
      );
      await capture(tester, 'picker_closed_$tag', size);
      await tester.tap(find.byKey(ModeScreen.mafiaCard));
      await tester.pumpAndSettle();
      await capture(tester, 'picker_open_$tag', size);
    });

    testWidgets('sheet $tag', (tester) async {
      await prepare(tester, size);
      await tester.pumpWidget(
        shot(
          Builder(
            builder: (c) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showBeforeStartSheet(c),
                  child: const Text('setup'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('setup'));
      await tester.pumpAndSettle();
      await capture(tester, 'sheet_$tag', size);
    });
  }
}
