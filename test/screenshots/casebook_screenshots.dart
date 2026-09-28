/// Renders «ملف القضايا» (tonight, season, legacy, the door on Online) for
/// the owner to look at.
///
/// **Not a test** (no `_test` suffix, asserts nothing), like
/// `update101_screenshots.dart`.
///
///     flutter test test/screenshots/casebook_screenshots.dart
///
/// Writes to `build/screens_casebook/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';



import 'package:mafia_master/ui/missions/casebook_data.dart';
import 'package:mafia_master/ui/missions/casebook_sheet.dart';

import '../support/casebook_fixture.dart';
import '../support/localized.dart';

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
  final out = Directory('build/screens_casebook')..createSync(recursive: true);

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

  for (final (page, name) in [(0, 'tonight'), (1, 'season'), (2, 'legacy')]) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      testWidgets('casebook $name ${locale.languageCode}', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await shoot(
          tester,
          'casebook_${name}_${locale.languageCode}',
          Scaffold(body: CasebookSheet(initialPage: page)),
          locale: locale,
          overrides: [
            casebookProvider.overrideWith(FakeCasebookController.new),
          ],
        );
      });
    }
  }

  testWidgets('casebook door', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await shoot(
      tester,
      'casebook_entry_ar',
      Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: const [SizedBox(height: 120), CasebookEntry()]),
          ),
        ),
      ),
      overrides: [casebookProvider.overrideWith(FakeCasebookController.new)],
    );
  });
}
