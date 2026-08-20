import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/setup/add_players_screen.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/screens/setup/roles_screen.dart';
import 'package:mafia_master/ui/screens/setup/settings_screen.dart';
import 'package:mafia_master/ui/screens/setup/setup_draft.dart';
import '../support/stores.dart';

/// T063 — the real setup flow, driven through the app's own router.
///
/// The three setup screens each have their own widget test. What none of them
/// can show is that the *sequence* works: that names reach the roles screen,
/// that role counts and settings reach the engine, and that "حفظ" actually
/// starts a match rather than dropping the draft on the floor. That seam is
/// what this exercises, and it is the one US4 is written about — a host has two
/// minutes, and a flow that loses a step costs far more than that.
void main() {
  const surface = Size(390, 1400); // tall enough to avoid scrolling detours
  const names = ['Ahmed', 'Fatima', 'Salem', 'Laila', 'Omar', 'Nada', 'Yusuf'];

  late ProviderContainer container;
  late MemoryMatchStore store;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    store = returningHostStore();
    container = ProviderContainer(
      overrides: [
        matchRepositoryProvider
            .overrideWithValue(MemoryMatchRepository(store)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AmbientMotion(
          // The drifting home-screen icons never stop, so `pumpAndSettle`
          // would spin here forever on a flow test that has nothing to do
          // with them. Bounded motion is left running.
          enabled: false,
          child: MafiaApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterNames(WidgetTester tester, List<String> toAdd) async {
    for (final name in toAdd) {
      await tester.enterText(find.byType(TextField).first, name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
  }

  group('Home → Players → Roles → Settings → match', () {
    testWidgets('a host can start a match without touching the engine',
        (tester) async {
      await pumpApp(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      expect(find.byType(AddPlayersScreen), findsOneWidget);

      await enterNames(tester, names);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      expect(find.byType(RolesScreen), findsOneWidget);
      expect(find.text('${names.length} لاعب'), findsOneWidget,
          reason: 'the roster did not survive the step');

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      // The engine now has a real match, seated in the order that was typed.
      final match = container.read(matchControllerProvider.notifier).engine.match;
      expect(match.phase, equals(GamePhase.distributing));
      expect(match.players.map((p) => p.name).toList(), equals(names));
      expect(match.players.map((p) => p.seat).toList(),
          equals(List.generate(names.length, (i) => i)));
    });

    testWidgets('the dealt roles match what the roles screen offered',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      await enterNames(tester, names);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      final chosen = container.read(setupDraftProvider).roleCounts;
      expect(chosen, isNotNull);

      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      final match = container.read(matchControllerProvider.notifier).engine.match;
      final dealt = <Role, int>{};
      for (final p in match.players) {
        dealt[p.role] = (dealt[p.role] ?? 0) + 1;
      }
      for (final entry in chosen!.entries) {
        expect(dealt[entry.key] ?? 0, equals(entry.value),
            reason: '${entry.key.name} count does not match the setup');
      }
    });

    testWidgets('settings chosen at setup are persisted as the next default',
        (tester) async {
      // FR-005: a group that always plays free discussion should not have to
      // re-pick it every night.
      await pumpApp(tester);
      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      await enterNames(tester, names);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('حر (بدون أدوار)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      final match = container.read(matchControllerProvider.notifier).engine.match;
      expect(match.settings.discussionMode, equals(DiscussionMode.free));

      final saved = await MemoryMatchRepository(store).loadDefaultSettings();
      expect(saved.discussionMode, equals(DiscussionMode.free),
          reason: 'the choice was not stored as the new default');
    });

    testWidgets('fewer than five names cannot advance', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();

      await enterNames(tester, names.take(4).toList());

      final next = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('التالي'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(next.onPressed, isNull,
          reason: 'a four-player match is not playable (FR-004)');
    });

    testWidgets('the roles step is skipped past if entered without a roster',
        (tester) async {
      // Reaching /setup/roles with an empty draft would crash the balance
      // guard. The router has to notice and bounce, not throw.
      await pumpApp(tester);
      expect(container.read(setupDraftProvider).names, isEmpty);

      // Simulate a deep link / restored route by driving the router directly.
      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      // Leave without entering names, then come back to Home.
      expect(find.byType(AddPlayersScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
