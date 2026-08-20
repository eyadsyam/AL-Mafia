import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart'
    show DiscussionMode, Role, PlayerStatus;
import 'package:mafia_master/engine/models/enums.dart' as engine;
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/ui/screens/day/discussion_screen.dart';
import 'package:mafia_master/ui/screens/postgame/result_screen.dart';
import 'package:mafia_master/ui/widgets/phase_timer.dart';

import '../support/localized.dart';

/// T034, T036 — Discussion and Result screen widget tests.
void main() {
  group('PhaseTimer', () {
    testWidgets('Renders mm:ss text correctly for a given duration',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        localizedApp(Scaffold(
            body: PhaseTimer(
              remaining: const Duration(minutes: 2, seconds: 45),
              total: const Duration(minutes: 5),
            ),
          )
        ),
      );

      // Verify the timer displays "02:45"
      expect(find.text('02:45'), findsOneWidget);
    });

    testWidgets('Renders zero time correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        localizedApp(Scaffold(
            body: PhaseTimer(
              remaining: Duration.zero,
              total: const Duration(minutes: 5),
            ),
          )
        ),
      );

      // Verify the timer displays "00:00"
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('Renders single-digit minutes and seconds with leading zeros',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        localizedApp(Scaffold(
            body: PhaseTimer(
              remaining: const Duration(seconds: 7),
              total: const Duration(minutes: 1),
            ),
          )
        ),
      );

      // Verify the timer displays "00:07"
      expect(find.text('00:07'), findsOneWidget);
    });
  });

  group('DiscussionScreen', () {
    testWidgets('Structured mode shows current speaker and speaker count',
        (WidgetTester tester) async {
      final players = [
        const PublicPlayer(seat: 0, name: 'Ahmed', status: PlayerStatus.alive),
        const PublicPlayer(seat: 1, name: 'Fatima', status: PlayerStatus.alive),
        const PublicPlayer(seat: 2, name: 'Salem', status: PlayerStatus.alive),
      ];

      await tester.pumpWidget(
        localizedApp(DiscussionScreen(
            mode: DiscussionMode.structured,
            alivePlayers: players,
            perSpeakerTime: const Duration(minutes: 1),
            onFinished: () {},
          )
        ),
      );

      // Verify the first speaker is displayed
      expect(find.text('Ahmed'), findsWidgets);
      // Verify the speaker count is displayed
      expect(find.text('متبقي: 3'), findsOneWidget);
    });

    testWidgets('Structured mode advances to next speaker when skip is tapped',
        (WidgetTester tester) async {
      final players = [
        const PublicPlayer(seat: 0, name: 'Ahmed', status: PlayerStatus.alive),
        const PublicPlayer(seat: 1, name: 'Fatima', status: PlayerStatus.alive),
        const PublicPlayer(seat: 2, name: 'Salem', status: PlayerStatus.alive),
      ];

      await tester.pumpWidget(
        localizedApp(DiscussionScreen(
            mode: DiscussionMode.structured,
            alivePlayers: players,
            perSpeakerTime: const Duration(seconds: 10),
            onFinished: () {},
          )
        ),
      );

      // Verify Ahmed is the current speaker
      expect(find.text('Ahmed'), findsWidgets);
      expect(find.text('متبقي: 3'), findsOneWidget);

      // Tap the skip button
      await tester.tap(find.text('تخطي'));
      await tester.pumpAndSettle();

      // Verify Fatima is now the current speaker
      expect(find.text('Fatima'), findsWidgets);
      expect(find.text('متبقي: 2'), findsOneWidget);
    });

    testWidgets(
        'Structured mode calls onFinished when last speaker finishes',
        (WidgetTester tester) async {
      var finishedCalled = false;
      final players = [
        const PublicPlayer(seat: 0, name: 'Ahmed', status: PlayerStatus.alive),
      ];

      await tester.pumpWidget(
        localizedApp(DiscussionScreen(
            mode: DiscussionMode.structured,
            alivePlayers: players,
            perSpeakerTime: const Duration(seconds: 1),
            onFinished: () => finishedCalled = true,
          )
        ),
      );

      // Skip should end the discussion since there's only 1 speaker
      await tester.tap(find.text('تخطي'));
      await tester.pumpAndSettle();

      expect(finishedCalled, isTrue);
    });

    testWidgets('Free mode shows open discussion label',
        (WidgetTester tester) async {
      final players = [
        const PublicPlayer(seat: 0, name: 'Ahmed', status: PlayerStatus.alive),
        const PublicPlayer(seat: 1, name: 'Fatima', status: PlayerStatus.alive),
      ];

      await tester.pumpWidget(
        localizedApp(DiscussionScreen(
            mode: DiscussionMode.free,
            alivePlayers: players,
            perSpeakerTime: const Duration(seconds: 30),
            onFinished: () {},
          )
        ),
      );

      // Verify free discussion title is shown
      expect(find.text('النقاش الحر'), findsOneWidget);
      // Verify current speaker info is NOT shown (only shown in structured mode)
      expect(find.text('المتحدث الآن'), findsNothing);
    });

    testWidgets('Pause button toggles between pause and resume states',
        (WidgetTester tester) async {
      final players = [
        const PublicPlayer(seat: 0, name: 'Ahmed', status: PlayerStatus.alive),
      ];

      await tester.pumpWidget(
        localizedApp(DiscussionScreen(
            mode: DiscussionMode.free,
            alivePlayers: players,
            perSpeakerTime: const Duration(minutes: 2),
            onFinished: () {},
          )
        ),
      );

      // Initial button should say "إيقاف"
      expect(find.text('إيقاف'), findsOneWidget);

      // Tap pause
      await tester.tap(find.text('إيقاف'));
      await tester.pumpAndSettle();

      // Button should now say "متابعة"
      expect(find.text('متابعة'), findsOneWidget);

      // Tap resume
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();

      // Button should say "إيقاف" again
      expect(find.text('إيقاف'), findsOneWidget);
    });
  });

  group('ResultScreen', () {
    testWidgets('Shows winning side prominently', (WidgetTester tester) async {
      final rows = [
        ResultRow(
          seat: 0,
          name: 'Ahmed',
          role: Role.mafia,
          eliminatedLabel: 'Day 1',
        ),
      ];

      await tester.pumpWidget(
        localizedApp(ResultScreen(
            winner: engine.Alignment.mafia,
            rows: rows,
            onAnalytics: () {},
            onHome: () {},
          )
        ),
      );

      // Verify winner text is shown
      expect(find.text('المافيا كسبت'), findsOneWidget);
    });

    testWidgets('Shows town victory when town wins', (WidgetTester tester) async {
      final rows = [
        ResultRow(
          seat: 0,
          name: 'Ahmed',
          role: Role.mafia,
          eliminatedLabel: 'Night 1',
        ),
      ];

      await tester.pumpWidget(
        localizedApp(ResultScreen(
            winner: engine.Alignment.town,
            rows: rows,
            onAnalytics: () {},
            onHome: () {},
          )
        ),
      );

      // Verify town victory text is shown
      expect(find.text('الشعب كسب'), findsOneWidget);
    });

    testWidgets('Shows every player with their role', (WidgetTester tester) async {
      // The roster is a lazily-built ListView, so the assertion below is only
      // meaningful on a surface tall enough to hold every row at once. The
      // default 800x600 test window clips the last one.
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final rows = [
        ResultRow(
          seat: 0,
          name: 'Ahmed',
          role: Role.mafia,
          eliminatedLabel: 'Day 1',
        ),
        ResultRow(
          seat: 1,
          name: 'Fatima',
          role: Role.doctor,
          eliminatedLabel: 'Night 2',
        ),
        ResultRow(
          seat: 2,
          name: 'Salem',
          role: Role.detective,
          eliminatedLabel: null, // Survived
        ),
        ResultRow(
          seat: 3,
          name: 'Laila',
          role: Role.citizen,
          eliminatedLabel: 'Day 2',
        ),
      ];

      await tester.pumpWidget(
        localizedApp(ResultScreen(
            winner: engine.Alignment.town,
            rows: rows,
            onAnalytics: () {},
            onHome: () {},
          )
        ),
      );

      // Verify all players are shown with correct names
      expect(find.text('Ahmed'), findsWidgets);
      expect(find.text('Fatima'), findsWidgets);
      expect(find.text('Salem'), findsWidgets);
      expect(find.text('Laila'), findsWidgets);

      // Verify all roles are shown
      expect(find.text('مافيا'), findsOneWidget);
      expect(find.text('دكتور'), findsOneWidget);
      expect(find.text('محقق'), findsOneWidget);
      expect(find.text('مواطن'), findsOneWidget);

      // Verify elimination labels where present
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Night 2'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);
    });

    testWidgets('Action buttons are present and tappable',
        (WidgetTester tester) async {
      var analyticsTapped = false;
      var homeTapped = false;

      final rows = [
        ResultRow(
          seat: 0,
          name: 'Ahmed',
          role: Role.mafia,
          eliminatedLabel: 'Night 1',
        ),
      ];

      await tester.pumpWidget(
        localizedApp(ResultScreen(
            winner: engine.Alignment.mafia,
            rows: rows,
            onAnalytics: () => analyticsTapped = true,
            onHome: () => homeTapped = true,
          )
        ),
      );

      // Verify buttons exist
      expect(find.text('التحليلات'), findsOneWidget);
      expect(find.text('الرئيسية'), findsOneWidget);

      // Tap analytics button
      await tester.tap(find.text('التحليلات'));
      await tester.pumpAndSettle();
      expect(analyticsTapped, isTrue);

      // Tap home button
      await tester.tap(find.text('الرئيسية'));
      await tester.pumpAndSettle();
      expect(homeTapped, isTrue);
    });

    testWidgets('Displays survival label when player survived',
        (WidgetTester tester) async {
      final rows = [
        ResultRow(
          seat: 0,
          name: 'Ahmed',
          role: Role.mafia,
          eliminatedLabel: null, // Survived
        ),
      ];

      await tester.pumpWidget(
        localizedApp(ResultScreen(
            winner: engine.Alignment.town,
            rows: rows,
            onAnalytics: () {},
            onHome: () {},
          )
        ),
      );

      // Verify player is shown
      expect(find.text('Ahmed'), findsWidgets);
      // Verify no elimination label is shown
      expect(find.text('Day'), findsNothing);
      expect(find.text('Night'), findsNothing);
    });
  });
}
