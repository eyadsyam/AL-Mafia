/// Renders what 1.2.0 (15) adds, for the owner to look at: the stories in
/// their Ruqaa headings, «العب ضد البوتات» from the mode screen through the
/// sheet to the table talk and the rematch.
/// **Not a test** (no `_test` suffix, asserts nothing).
///
///     flutter test test/screenshots/v15_screenshots.dart
///
/// Writes to `build/screens_v15/`.
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
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/screens/stories/story_flow_screen.dart';
import 'package:mafia_master/ui/screens/stories/widgets/story_palette.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

const _phone = Size(390, 844);

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
  final out = Directory('build/screens_v15')..createSync(recursive: true);

  Future<void> prepare(WidgetTester tester) async {
    await tester.runAsync(_fonts);
    await loadArtwork(tester);
    tester.view.physicalSize = _phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

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

  Future<void> shoot(WidgetTester tester, String name, Widget child) async {
    await prepare(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(child: localizedApp(child)),
      ),
    );
    await capture(tester, name);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('stories hub', (tester) async {
    await shoot(
      tester,
      '01_stories_hub',
      StoryPalette(child: StoriesScreen(onBack: () {})),
    );
  });

  for (final (n, id) in const [
    (2, 'qahwet_el_moallem'),
    (3, 'fondo2_shepheard'),
  ]) {
    testWidgets('story $id', (tester) async {
      final story = StoryDefinition.decode(
        File('assets/stories/$id.json').readAsStringSync(),
      );
      await shoot(
        tester,
        '0${n}_story_$id',
        StoryPalette(
          child: StoryFlowScreen(
            story: story,
            playerCount: 1,
            onExit: () {},
            onComplete: (_) async {},
            playNarration: (_) async {},
          ),
        ),
      );
    });
  }

  testWidgets('mode screen', (tester) async {
    await shoot(
      tester,
      '04_mode_card',
      ModeScreen(
        onPlayOffline: () {},
        onPlayOnline: () {},
        onPlayStories: () {},
        onBack: () {},
      ),
    );
  });
}
