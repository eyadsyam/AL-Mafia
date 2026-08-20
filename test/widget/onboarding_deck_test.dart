import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/screens/onboarding/onboarding_chapters.dart';
import 'package:mafia_master/ui/screens/onboarding/onboarding_screen.dart';
import 'package:mafia_master/ui/widgets/back_action.dart';
import 'package:mafia_master/ui/widgets/onboarding_role_grid.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

/// S-19 — the onboarding deck.
///
/// ## What is worth asserting here and what is not
///
/// The deal animation is not tested and should not be: it is bounded, it
/// respects Reduce Motion, and a golden of a card mid-flight would fail on
/// every curve tweak while catching nothing anybody cares about. What matters
/// is that the deck *arrives* — every chapter reachable, the last card offering
/// a way into a real match, and no exit that leaves the host stranded.
void main() {
  const surface = Size(390, 844);

  late int skips;
  late int starts;
  late int rules;

  Future<void> open(WidgetTester tester, {Locale? locale}) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      localizedApp(
        OnboardingScreen(
          onSkip: () => skips++,
          onStartMatch: () => starts++,
          onRules: () => rules++,
        ),
        locale: locale ?? const Locale('ar'),
      ),
    );
    // The roles chapter decodes four paintings; a fixed pump count passes in
    // isolation and fails under a loaded parallel run. See test/support.
    await loadArtwork(tester);
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(OnboardingScreen.nextButton));
    await tester.pumpAndSettle();
  }

  setUp(() {
    skips = 0;
    starts = 0;
    rules = 0;
  });

  group('dealing through', () {
    testWidgets('opens on the first chapter', (tester) async {
      await open(tester);
      expect(
        find.text(OnboardingChapter.story.title(arStrings)),
        findsOneWidget,
      );
    });

    testWidgets('every chapter is reachable by tapping next', (tester) async {
      await open(tester);

      for (final chapter in OnboardingChapter.values) {
        expect(find.text(chapter.title(arStrings)), findsOneWidget,
            reason: 'chapter ${chapter.name} did not come up');
        if (!chapter.finish) await next(tester);
      }
    });

    testWidgets('the last chapter swaps the actions rather than adding a row',
        (tester) async {
      await open(tester);
      expect(find.byKey(OnboardingScreen.startButton), findsNothing);

      for (var i = 0; i < OnboardingChapter.values.length - 1; i++) {
        await next(tester);
      }

      // Next and Skip are gone; Start and Rules stand in the same two places.
      expect(find.byKey(OnboardingScreen.nextButton), findsNothing);
      expect(find.byKey(OnboardingScreen.skipButton), findsNothing);
      expect(find.byKey(OnboardingScreen.startButton), findsOneWidget);
      expect(find.byKey(OnboardingScreen.rulesButton), findsOneWidget);
    });

    testWidgets('the header steps back a chapter before it leaves',
        (tester) async {
      await open(tester);
      await next(tester);
      expect(find.text(OnboardingChapter.roles.title(arStrings)),
          findsOneWidget);

      await tester.tap(find.byKey(BackAction.button));
      await tester.pumpAndSettle();

      expect(find.text(OnboardingChapter.story.title(arStrings)),
          findsOneWidget);
      expect(skips, 0, reason: 'back on card 2 must not leave the deck');

      // Only from the first card does back mean out.
      await tester.tap(find.byKey(BackAction.button));
      await tester.pumpAndSettle();
      expect(skips, 1);
    });
  });

  group('the way out', () {
    testWidgets('skip reports once, from any chapter', (tester) async {
      await open(tester);
      await next(tester);
      await tester.tap(find.byKey(OnboardingScreen.skipButton));
      await tester.pumpAndSettle();

      expect(skips, 1);
      expect(starts, 0);
    });

    testWidgets('the last card offers a match and the full rules',
        (tester) async {
      await open(tester);
      for (var i = 0; i < OnboardingChapter.values.length - 1; i++) {
        await next(tester);
      }

      await tester.tap(find.byKey(OnboardingScreen.rulesButton));
      await tester.pumpAndSettle();
      expect(rules, 1);

      await tester.tap(find.byKey(OnboardingScreen.startButton));
      await tester.pumpAndSettle();
      expect(starts, 1);
    });
  });

  group('the roles chapter', () {
    testWidgets('is the only one that carries cards', (tester) async {
      await open(tester);
      expect(find.byType(OnboardingRoleGrid), findsNothing);

      await next(tester);
      expect(find.byType(OnboardingRoleGrid), findsOneWidget);

      await next(tester);
      expect(find.byType(OnboardingRoleGrid), findsNothing);
    });

    testWidgets('a card turns over to its description and back again',
        (tester) async {
      await open(tester);
      await next(tester);

      final description = EngineCopy.roleDescription(arStrings, Role.mafia);
      expect(find.text(description), findsNothing);

      // Keyed by role, not by position, so the test does not encode the grid
      // order.
      final card = find.byKey(OnboardingRoleGrid.tileFor(Role.mafia));
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text(description), findsOneWidget);

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text(description), findsNothing);
    });
  });

  group('copy', () {
    testWidgets('renders in English too', (tester) async {
      await open(tester, locale: const Locale('en'));
      expect(
        find.text(OnboardingChapter.story.title(enStrings)),
        findsOneWidget,
      );
    });

    test('every chapter has a title and a body in both locales', () {
      for (final chapter in OnboardingChapter.values) {
        for (final strings in [arStrings, enStrings]) {
          expect(chapter.title(strings), isNotEmpty);
          expect(chapter.body(strings), isNotEmpty);
        }
      }
    });

    test('exactly one chapter finishes the deck, and it is the last', () {
      final finishing =
          OnboardingChapter.values.where((c) => c.finish).toList();
      expect(finishing, hasLength(1));
      expect(finishing.single, OnboardingChapter.values.last,
          reason: 'a finishing card in the middle would strand every chapter '
              'after it — Next is the only control that advances');
    });
  });
}
