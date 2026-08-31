import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/screens/onboarding/onboarding_chapters.dart';
import 'package:mafia_master/ui/screens/onboarding/onboarding_screen.dart';
import 'package:mafia_master/ui/widgets/onboarding_role_grid.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

/// Writes the onboarding deck to `tool/preview/` so the cards can be looked at.
///
/// Deliberately **not** named `*_test.dart`, for the same reason
/// `card_preview.dart` is not: it asserts nothing and it writes files, and
/// neither belongs in the suite. Run it by naming it:
///
///     flutter test test/preview/onboarding_preview.dart
///
/// ## This one loads the real fonts, and has to
///
/// `card_preview.dart` says the type renders as boxes, because `flutter_test`
/// ships a stub font — fine there, where the point is to judge a painting. Here
/// the type *is* the card: seven faces whose only content is a heading, a
/// paragraph and a numeral. A preview of them in stub boxes would show nothing
/// worth looking at, so the shipped families are registered with a [FontLoader]
/// first. That makes these screenshots a fair likeness of the phone, which the
/// role-card previews explicitly are not.
void main() {
  const boundaryKey = ValueKey('preview_boundary');

  setUpAll(() async {
    // The four families the type scale names, from the same files that ship.
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

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required int chapter,
    Locale locale = const Locale('ar'),
    Role? flip,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: localizedApp(
          OnboardingScreen(onSkip: () {}, onStartMatch: () {}, onRules: () {}),
          locale: locale,
        ),
      ),
    );
    await loadArtwork(tester);
    await tester.pumpAndSettle();

    for (var i = 0; i < chapter; i++) {
      await tester.tap(find.byKey(OnboardingScreen.nextButton));
      await tester.pumpAndSettle();
    }

    if (flip != null) {
      await tester.tap(find.byKey(OnboardingRoleGrid.tileFor(flip)));
      await tester.pumpAndSettle();
    }

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

  testWidgets('chapter 1 — the story', (tester) async {
    await shoot(tester, 'onboarding_1_story',
        chapter: OnboardingChapter.story.index);
  });

  testWidgets('chapter 2 — the roles, one card turned over', (tester) async {
    await shoot(tester, 'onboarding_2_roles',
        chapter: OnboardingChapter.roles.index, flip: Role.mafia);
  });

  testWidgets('chapter 5 — the pass, the longest card', (tester) async {
    await shoot(tester, 'onboarding_5_pass',
        chapter: OnboardingChapter.pass.index);
  });

  testWidgets('chapter 6 — what the app will not give away', (tester) async {
    await shoot(tester, 'onboarding_6_secrecy',
        chapter: OnboardingChapter.secrecy.index);
  });

  testWidgets('chapter 7 — winning, and the way into a match', (tester) async {
    await shoot(tester, 'onboarding_7_win',
        chapter: OnboardingChapter.win.index);
  });

  testWidgets('chapter 1 in English, for the LTR mirror', (tester) async {
    await shoot(tester, 'onboarding_1_story_en',
        chapter: OnboardingChapter.story.index, locale: const Locale('en'));
  });
}
