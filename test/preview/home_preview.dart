import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/tilt_source.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

/// Writes the home screen to `tool/preview/` so the spread can be looked at.
///
/// Deliberately **not** named `*_test.dart`, for the same reason
/// `card_preview.dart` and `onboarding_preview.dart` are not: it asserts
/// nothing and it writes files, and neither belongs in the suite. Run it by
/// naming it:
///
///     flutter test test/preview/home_preview.dart
///
/// ## What this is for
///
/// Home is the screen where every visual decision in the app collides: the
/// backdrop loop, the four paintings, the falling icons, the haze, the ground
/// and the one accent. It is also the screen nobody can judge from a diff — the
/// spread's shape, whether the cards dominate the picture, whether the backdrop
/// stays behind them. Those are questions about a rendered frame, and until
/// somebody runs the app on a phone this is the closest thing to one.
///
/// [HomeScreen] is pumped directly rather than through `MafiaApp`, so the two
/// platform channels it opens can be stubbed: neither the accelerometer behind
/// the parallax nor the audio plugin behind the deal sound is registered in a
/// widget test, and both throw the moment anything listens.
///
/// The fonts are registered for the same reason `onboarding_preview.dart`
/// registers them: `flutter_test` ships a stub font that draws every glyph as a
/// box, and a preview of a screen whose title is a wordmark would be showing
/// the wrong thing.
///
/// ## What it is not a likeness of
///
/// The loop is a still here — the animated backdrop, the deal, the float and
/// the parallax are all either disabled or frozen at whatever frame the pump
/// left them on. It shows composition and colour, and says nothing about
/// motion.
void main() {
  const boundaryKey = ValueKey('preview_boundary');

  setUpAll(() async {
    const families = <String, List<String>>{
      'Bebas Neue': ['assets/fonts/BebasNeue-Regular.ttf'],
      'Cairo': ['assets/fonts/Cairo-Variable.ttf'],
      'IBM Plex Sans Arabic': [
        'assets/fonts/IBMPlexSansArabic-Regular.ttf',
        'assets/fonts/IBMPlexSansArabic-Medium.ttf',
        'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
      ],
      'IBM Plex Mono': [
        'assets/fonts/IBMPlexMono-Regular.ttf',
        'assets/fonts/IBMPlexMono-Medium.ttf',
      ],
    };

    for (final entry in families.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(
          File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
      await loader.load();
    }
  });

  Future<void> shoot(WidgetTester tester, String name, {Size? surface}) async {
    await tester.binding.setSurfaceSize(surface ?? const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ProviderScope(
          overrides: [
            // The deal fires a sound, and the audio plugin is not registered
            // behind a widget test either. Silent backend, same director.
            audioDirectorProvider.overrideWithValue(AudioDirector()),
          ],
          // The falling icons and the card float never end, so `pumpAndSettle`
          // would spin here forever. Both are ambient; neither is what this
          // screenshot is about.
          child: AmbientMotion(
            enabled: false,
            child: localizedApp(
              HomeScreen(
                onNewMatch: () {},
                onHistory: () {},
                onSettings: () {},
                onHowToPlay: () {},
                // The real screen reads the accelerometer for the parallax,
                // and there is no accelerometer behind a widget test — the
                // plugin channel throws the moment anything listens.
                tiltSource: const LevelTiltSource(),
              ),
            ),
          ),
        ),
      ),
    );
    await loadArtwork(tester);
    await tester.pumpAndSettle();

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('tool/preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });
  }

  testWidgets('home — the four-card spread', (tester) async {
    await shoot(tester, 'home');
  });

  testWidgets('home on a short screen, where the fan has least room',
      (tester) async {
    await shoot(tester, 'home_short', surface: const Size(360, 640));
  });
}
