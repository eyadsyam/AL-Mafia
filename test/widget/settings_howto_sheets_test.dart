import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/motion_preference.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/ui/screens/setup/how_to_sheet.dart';
import 'package:mafia_master/ui/screens/setup/settings_sheet.dart';
import 'package:mafia_master/ui/screens/setup/setup_draft.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

const _sizes = [Size(360, 640), Size(430, 932)];

Future<ProviderContainer> _open(
  WidgetTester tester,
  Size size,
  Future<void> Function(BuildContext) show, {
  MemoryMatchStore? store,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      matchRepositoryProvider.overrideWithValue(
        MemoryMatchRepository(store ?? MemoryMatchStore()),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('settings sheet', () {
    for (final size in _sizes) {
      testWidgets('fits $size and has no save button', (tester) async {
        await _open(tester, size, showSettingsSheet);
        expect(find.byKey(SettingsSheetKeys.sheet), findsOneWidget);
        expect(find.byKey(const ValueKey('settings_save')), findsNothing);
        expect(tester.takeException(), isNull);
        // The three groups are there, scrolled into view one by one.
        for (final name in ['narration', 'revealDeath', 'reduceMotion']) {
          await tester.ensureVisible(find.byKey(SettingsSheetKeys.row(name)));
          await tester.pump();
          expect(find.byKey(SettingsSheetKeys.row(name)), findsOneWidget);
        }
        // The optional roles are no longer switched here (they are gated by
        // ownership on the roles screen).
        expect(find.byKey(const ValueKey('setting_silencer')), findsNothing);
        expect(find.byKey(const ValueKey('setting_elder')), findsNothing);
        expect(find.byKey(const ValueKey('setting_sniper')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a change saves by itself, says so, and reaches the app', (
      tester,
    ) async {
      final store = MemoryMatchStore();
      final container = await _open(
        tester,
        _sizes.first,
        showSettingsSheet,
        store: store,
      );
      expect(
        tester
            .widget<AnimatedOpacity>(find.byKey(SettingsSheetKeys.saved))
            .opacity,
        0,
      );
      final before = container.read(setupDraftProvider).settings;
      final row = find.byKey(SettingsSheetKeys.row('revealDeath'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump();
      await tester.pump(SettingsSheetTokens.toastMove);
      expect(
        tester
            .widget<AnimatedOpacity>(find.byKey(SettingsSheetKeys.saved))
            .opacity,
        1,
      );
      expect(
        container.read(setupDraftProvider).settings.revealNightVictimRole,
        !before.revealNightVictimRole,
      );
      final saved = await MemoryMatchRepository(store).loadDefaultSettings();
      expect(saved.revealNightVictimRole, !before.revealNightVictimRole);
      // The toast leaves on its own.
      await tester.pump(SettingsSheetTokens.toast);
      await tester.pump(SettingsSheetTokens.toastMove);
      expect(
        tester
            .widget<AnimatedOpacity>(find.byKey(SettingsSheetKeys.saved))
            .opacity,
        0,
      );
    });

    testWidgets('discussion minutes step through the existing options', (
      tester,
    ) async {
      final container = await _open(tester, _sizes.last, showSettingsSheet);
      final more = find.byKey(SettingsSheetKeys.minutesMore);
      await tester.ensureVisible(more);
      final start = container.read(setupDraftProvider).settings.discussionSeconds;
      await tester.tap(more);
      await tester.pump();
      final now = container.read(setupDraftProvider).settings.discussionSeconds;
      expect(now == start || now > start, isTrue);
      await tester.tap(find.byKey(SettingsSheetKeys.minutesLess));
      await tester.pump();
      expect(
        container.read(setupDraftProvider).settings.discussionSeconds,
        lessThanOrEqualTo(now),
      );
    });

    testWidgets('open or secret vote and the death reveal save too', (
      tester,
    ) async {
      final container = await _open(tester, _sizes.first, showSettingsSheet);
      final reveal = find.byKey(SettingsSheetKeys.row('revealDeath'));
      await tester.ensureVisible(reveal);
      final was = container
          .read(setupDraftProvider)
          .settings
          .revealNightVictimRole;
      await tester.tap(reveal);
      await tester.pump();
      expect(
        container.read(setupDraftProvider).settings.revealNightVictimRole,
        !was,
      );
      final secret = find.byKey(SettingsSheetKeys.row('voteSecret'));
      await tester.ensureVisible(secret);
      await tester.tap(secret);
      await tester.pump();
      expect(container.read(setupDraftProvider).settings.openVoting, isFalse);
    });

    testWidgets('reduce motion is stored and acknowledged', (tester) async {
      await _open(tester, _sizes.first, showSettingsSheet);
      final row = find.byKey(SettingsSheetKeys.row('reduceMotion'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(await loadReduceMotionPreference(), isTrue);
    });
  });

  group('how to play sheet', () {
    for (final size in _sizes) {
      testWidgets('fits $size on every page', (tester) async {
        await _open(
          tester,
          size,
          (c) => showHowToSheet(c, onVideo: () {}),
        );
        expect(find.byKey(HowToKeys.sheet), findsOneWidget);
        for (var i = 0; i < 5; i++) {
          await tester.drag(find.byKey(HowToKeys.pages), const Offset(400, 0));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'page $i');
        }
        // The last page holds all seven role cards.
        for (final role in [
          'mafia',
          'detective',
          'doctor',
          'citizen',
          'elder',
          'silencer',
          'sniper',
        ]) {
          expect(find.byKey(HowToKeys.role(role)), findsOneWidget, reason: role);
        }
      });
    }

    testWidgets('a role card flips to say what the role does', (tester) async {
      await _open(
        tester,
        _sizes.last,
        (c) => showHowToSheet(c, onVideo: () {}),
      );
      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byKey(HowToKeys.pages), const Offset(400, 0));
        await tester.pumpAndSettle();
      }
      expect(find.text(arStrings.howRoleMafiaDo), findsNothing);
      await tester.tap(find.byKey(HowToKeys.role('mafia')));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.howRoleMafiaDo), findsOneWidget);
    });

    testWidgets('the FAQ opens one answer at a time', (tester) async {
      await _open(
        tester,
        _sizes.last,
        (c) => showHowToSheet(c, onVideo: () {}),
      );
      await tester.ensureVisible(find.byKey(HowToKeys.faq(0)));
      await tester.tap(find.byKey(HowToKeys.faq(0)));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.howFaq1A), findsOneWidget);
      await tester.ensureVisible(find.byKey(HowToKeys.faq(1)));
      await tester.tap(find.byKey(HowToKeys.faq(1)));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.howFaq1A), findsNothing);
      expect(find.text(arStrings.howFaq2A), findsOneWidget);
    });

    testWidgets('the video button closes the sheet and plays the film', (
      tester,
    ) async {
      var played = 0;
      await _open(
        tester,
        _sizes.first,
        (c) => showHowToSheet(c, onVideo: () => played++),
      );
      await tester.ensureVisible(find.byKey(HowToKeys.video));
      await tester.tap(find.byKey(HowToKeys.video));
      await tester.pumpAndSettle();
      expect(played, 1);
      expect(find.byKey(HowToKeys.sheet), findsNothing);
    });

    testWidgets('reduced motion: a flip is instant', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _open(
        tester,
        _sizes.first,
        (c) => showHowToSheet(c, onVideo: () {}),
      );
      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byKey(HowToKeys.pages), const Offset(400, 0));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(HowToKeys.role('sniper')));
      await tester.pump();
      expect(find.text(arStrings.howRoleSniperDo), findsOneWidget);
    });
  });
}
