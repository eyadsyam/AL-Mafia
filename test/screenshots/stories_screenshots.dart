/// Renders the stories mode on a small phone, for the owner to look at.
/// **Not a test** (no `_test` suffix, asserts nothing).
///
///     flutter test test/screenshots/stories_screenshots.dart
///
/// Writes to `build/screens_stories/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mafia_master/stories/story_model.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/screens/stories/story_flow_screen.dart';

import '../support/localized.dart';

const _phone = Size(360, 640);

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
  final out = Directory('build/screens_stories')..createSync(recursive: true);

  Future<void> shoot(WidgetTester tester, String name, Widget child) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = _phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(child: localizedApp(child)),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(seconds: 1));
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('stories hub', (tester) async {
    await shoot(tester, 'hub', StoriesScreen(onBack: () {}));
  });

  for (final id in const ['qahwet_el_moallem', 'el_oda_el_mafoola']) {
    testWidgets('solo board $id', (tester) async {
      final source = await tester.runAsync(
        () => rootBundle.loadString('assets/stories/$id.json'),
      );
      final story = StoryDefinition.decode(source!);
      await shoot(
        tester,
        'solo_$id',
        StoryFlowScreen(
          story: story,
          playerCount: 1,
          onExit: () {},
          onComplete: (_) async {},
        ),
      );
    });
  }
}
