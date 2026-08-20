import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart' as models;
import 'package:mafia_master/ui/screens/postgame/analytics_screen.dart';
import 'package:mafia_master/ui/screens/postgame/history_screen.dart';

import '../support/localized.dart';

import '../support/scripted_match.dart';

/// T069 / FR-033 — finished matches are listed, reopenable, and deletable.
void main() {
  const surface = Size(390, 844);

  late MemoryMatchStore store;

  Future<MatchEngine> storeFinishedMatch({
    required int seed,
    required DateTime createdAt,
  }) async {
    final engine =
        scriptedMatch(playToEnd: true, seed: seed, createdAt: createdAt);
    await MemoryMatchRepository(store).persistStep(engine.match);
    return engine;
  }

  Future<void> pumpHistory(
    WidgetTester tester, {
    void Function(int)? onOpen,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider
              .overrideWithValue(MemoryMatchRepository(store)),
        ],
        child: localizedApp(HistoryScreen(onOpen: onOpen ?? (_) {}, onBack: () {})
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => store = MemoryMatchStore());

  group('history listing', () {
    testWidgets('shows an empty state when nothing has been played',
        (tester) async {
      await pumpHistory(tester);
      expect(find.text('لا توجد مباريات سابقة'), findsOneWidget);
      expect(find.byKey(HistoryScreen.list), findsNothing);
    });

    testWidgets('lists finished matches with players, winner and night count',
        (tester) async {
      final engine =
          await storeFinishedMatch(seed: 7, createdAt: DateTime(2026, 3, 1));
      await pumpHistory(tester);

      expect(find.byKey(HistoryScreen.tileFor(engine.match.id)), findsOneWidget);

      final winner = engine.match.outcome!.winner;
      expect(
        find.text(winner == models.Alignment.mafia ? 'المافيا كسبت' : 'الشعب كسب'),
        findsOneWidget,
      );
      expect(find.textContaining('${engine.match.players.length} لاعبين'),
          findsOneWidget);
      expect(find.textContaining(engine.match.players.first.name),
          findsOneWidget);
    });

    testWidgets('does not reveal any role', (tester) async {
      // History is a glance-able list. Roles belong one tap deeper.
      await storeFinishedMatch(seed: 7, createdAt: DateTime(2026, 3, 1));
      await pumpHistory(tester);

      final text = [
        for (final w in tester.widgetList<Text>(find.byType(Text)))
          if (w.data != null) w.data!,
      ].join(' ');

      for (final roleWord in ['مافيا', 'دكتور', 'محقق', 'مواطن']) {
        // "المافيا كسبت" names the winning side, not any player's role, so the
        // check is for a role attached to a name.
        for (final player in ['Ahmed', 'A', 'B', 'C']) {
          expect(text.contains('$player $roleWord'), isFalse,
              reason: 'history attributed a role to a player');
        }
      }
    });

    testWidgets('is ordered newest first', (tester) async {
      final older =
          await storeFinishedMatch(seed: 1, createdAt: DateTime(2026, 1, 1));
      final newer =
          await storeFinishedMatch(seed: 2, createdAt: DateTime(2026, 6, 1));
      await pumpHistory(tester);

      final newerTile =
          tester.getTopLeft(find.byKey(HistoryScreen.tileFor(newer.match.id)));
      final olderTile =
          tester.getTopLeft(find.byKey(HistoryScreen.tileFor(older.match.id)));
      expect(newerTile.dy, lessThan(olderTile.dy));
    });

    testWidgets('an in-progress match is not listed', (tester) async {
      final unfinished = scriptedMatch(stopAfterNightActions: 3);
      await MemoryMatchRepository(store).persistStep(unfinished.match);
      await pumpHistory(tester);

      expect(find.text('لا توجد مباريات سابقة'), findsOneWidget);
    });
  });

  group('reopening and deleting', () {
    testWidgets('tapping a match opens its analytics', (tester) async {
      final engine =
          await storeFinishedMatch(seed: 7, createdAt: DateTime(2026, 3, 1));
      int? opened;
      await pumpHistory(tester, onOpen: (id) => opened = id);

      await tester.tap(find.byKey(HistoryScreen.tileFor(engine.match.id)));
      await tester.pumpAndSettle();
      expect(opened, equals(engine.match.id));
    });

    testWidgets('swipe-to-delete asks first, and cancelling keeps the match',
        (tester) async {
      final engine =
          await storeFinishedMatch(seed: 7, createdAt: DateTime(2026, 3, 1));
      await pumpHistory(tester);

      // The app is RTL (FR-034), so `DismissDirection.endToStart` is a drag
      // towards the *right*. A negative offset would be startToEnd and would
      // not dismiss anything.
      await tester.drag(find.byKey(HistoryScreen.tileFor(engine.match.id)),
          const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(HistoryScreen.deleteConfirm), findsOneWidget);
      await tester.tap(find.byKey(HistoryScreen.deleteCancel));
      await tester.pumpAndSettle();

      expect(store.matches, hasLength(1),
          reason: 'cancelling the confirm still deleted the match');
      expect(find.byKey(HistoryScreen.tileFor(engine.match.id)), findsOneWidget);
    });

    testWidgets('confirming the swipe deletes the match', (tester) async {
      final engine =
          await storeFinishedMatch(seed: 7, createdAt: DateTime(2026, 3, 1));
      await pumpHistory(tester);

      // The app is RTL (FR-034), so `DismissDirection.endToStart` is a drag
      // towards the *right*. A negative offset would be startToEnd and would
      // not dismiss anything.
      await tester.drag(find.byKey(HistoryScreen.tileFor(engine.match.id)),
          const Offset(500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistoryScreen.deleteConfirm));
      await tester.pumpAndSettle();

      expect(store.matches, isEmpty);
      expect(find.text('لا توجد مباريات سابقة'), findsOneWidget);
    });
  });

  group('stored analytics', () {
    testWidgets('a reopened match shows all four tabs and every role',
        (tester) async {
      final engine =
          await storeFinishedMatch(seed: 7, createdAt: DateTime(2026, 3, 1));

      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchRepositoryProvider
                .overrideWithValue(MemoryMatchRepository(store)),
          ],
          child: localizedApp(StoredAnalyticsScreen(
              matchId: engine.match.id,
              onClose: () {},
            )
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(AnalyticsView.timelineTab), findsOneWidget);
      expect(find.byKey(AnalyticsView.playersTab), findsOneWidget);
      expect(find.byKey(AnalyticsView.suspicionTab), findsOneWidget);
      expect(find.byKey(AnalyticsView.achievementsTab), findsOneWidget);

      // The players tab is the post-game reveal: every seat, with its role.
      await tester.tap(find.byKey(AnalyticsView.playersTab));
      await tester.pumpAndSettle();
      expect(find.textContaining('مافيا'), findsWidgets,
          reason: 'post-game analytics must reveal roles (FR-032)');
    });
  });
}
