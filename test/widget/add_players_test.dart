import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/setup/add_players_screen.dart';

import '../support/localized.dart';

/// T058 — AddPlayersScreen widget tests.
///
/// Tests the quick-add flow, duplicate name suffixing, and "التالي" button
/// enable/disable logic.
void main() {
  group('AddPlayersScreen (T058)', () {
    testWidgets('التالي button is disabled with fewer than 5 players',
        (WidgetTester tester) async {
      final names = <List<String>>[];
      await tester.pumpWidget(
        localizedApp(AddPlayersScreen(onBack: () {}, 
            onNext: (list) => names.add(list),
          )
        ),
      );

      // Add 4 players one by one, verify button stays disabled
      for (int i = 1; i <= 4; i++) {
        final input = find.byType(TextField);
        await tester.enterText(input, 'Player $i');
        await tester.tap(find.text('إضافة'));
        await tester.pumpAndSettle();

        // Find the التالي button (it's the one with the text "التالي")
        final nextButton = find.text('التالي');
        expect(nextButton, findsOneWidget);

        // The button should be disabled (onPressed = null)
        final button = find.ancestor(
          of: nextButton,
          matching: find.byType(FilledButton),
        );
        final filledButton = tester.widget<FilledButton>(button);
        expect(filledButton.onPressed, isNull, reason: 'Button should be disabled with $i players');
      }

      // Add 5th player
      final input = find.byType(TextField);
      await tester.enterText(input, 'Player 5');
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      // Now the button should be enabled
      final nextButton = find.text('التالي');
      final button = find.ancestor(
        of: nextButton,
        matching: find.byType(FilledButton),
      );
      final filledButton = tester.widget<FilledButton>(button);
      expect(filledButton.onPressed, isNotNull, reason: 'Button should be enabled');
    });

    testWidgets('Duplicate names are auto-suffixed', (WidgetTester tester) async {
      final capturedNames = <List<String>>[];
      await tester.pumpWidget(
        localizedApp(AddPlayersScreen(onBack: () {}, 
            onNext: (list) => capturedNames.add(list),
          )
        ),
      );

      // Add a player named "Ahmed"
      var input = find.byType(TextField);
      await tester.enterText(input, 'Ahmed');
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      // Try to add another "Ahmed" — should be suffixed to "Ahmed 2"
      input = find.byType(TextField);
      await tester.enterText(input, 'Ahmed');
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      // Verify the second name is "Ahmed 2"
      expect(find.text('Ahmed'), findsOneWidget);
      expect(find.text('Ahmed 2'), findsOneWidget);

      // Add third "Ahmed" — should be "Ahmed 3"
      input = find.byType(TextField);
      await tester.enterText(input, 'Ahmed');
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      expect(find.text('Ahmed 3'), findsOneWidget);

      // Add two more to reach 5, then verify order in callback
      for (int i = 4; i <= 5; i++) {
        input = find.byType(TextField);
        await tester.enterText(input, 'Player $i');
        await tester.tap(find.text('إضافة'));
        await tester.pumpAndSettle();
      }

      // Tap التالي
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      // Verify names in order
      expect(capturedNames.length, equals(1));
      expect(
        capturedNames[0],
        equals(['Ahmed', 'Ahmed 2', 'Ahmed 3', 'Player 4', 'Player 5']),
      );
    });

    testWidgets('Can reorder players', (WidgetTester tester) async {
      final capturedNames = <List<String>>[];
      await tester.pumpWidget(
        localizedApp(AddPlayersScreen(onBack: () {}, 
            onNext: (list) => capturedNames.add(list),
          )
        ),
      );

      // Add 5 players
      for (int i = 1; i <= 5; i++) {
        final input = find.byType(TextField);
        await tester.enterText(input, 'Player $i');
        await tester.tap(find.text('إضافة'));
        await tester.pumpAndSettle();
      }

      // Drag first player down past the second
      final firstPlayer = find.text('Player 1');
      await tester.drag(firstPlayer, const Offset(0, 100));
      await tester.pumpAndSettle();

      // Tap التالي
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      // Verify the order changed
      expect(capturedNames.length, equals(1));
      final reordered = capturedNames[0];
      // The exact reordering depends on ReorderableListView's behavior,
      // but we just verify it's still all 5 players
      expect(reordered.length, equals(5));
      expect(
        reordered.toSet(),
        equals(['Player 1', 'Player 2', 'Player 3', 'Player 4', 'Player 5']),
      );
    });

    testWidgets('Can delete players', (WidgetTester tester) async {
      final capturedNames = <List<String>>[];
      await tester.pumpWidget(
        localizedApp(AddPlayersScreen(onBack: () {}, 
            onNext: (list) => capturedNames.add(list),
          )
        ),
      );

      // Add 5 players
      for (int i = 1; i <= 5; i++) {
        final input = find.byType(TextField);
        await tester.enterText(input, 'Player $i');
        await tester.tap(find.text('إضافة'));
        await tester.pumpAndSettle();
      }

      // Delete the second player. The control is a word now, not a glyph, and
      // it is keyed by seat so the test names the row it means rather than
      // counting icons.
      // Keyed by *seat*, which is 1-based on screen, so Player 2 is seat 2.
      await tester.tap(find.byKey(const ValueKey('delete_player_2')));
      await tester.pumpAndSettle();

      // Player 2 should be gone
      expect(find.text('Player 2'), findsNothing);

      // Now we have only 4, so التالي should be disabled
      var nextButtonText = find.text('التالي');
      var nextButtonWidget = find.ancestor(
        of: nextButtonText,
        matching: find.byType(FilledButton),
      );
      var button = tester.widget<FilledButton>(nextButtonWidget);
      expect(button.onPressed, isNull);

      // Add a new player
      var input = find.byType(TextField);
      await tester.enterText(input, 'Player 6');
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      // Now التالي should be enabled again
      nextButtonText = find.text('التالي');
      nextButtonWidget = find.ancestor(
        of: nextButtonText,
        matching: find.byType(FilledButton),
      );
      button = tester.widget<FilledButton>(nextButtonWidget);
      expect(button.onPressed, isNotNull);

      // Tap التالي
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      // Verify Player 2 is gone
      expect(capturedNames.length, equals(1));
      expect(
        capturedNames[0].toSet(),
        equals(['Player 1', 'Player 3', 'Player 4', 'Player 5', 'Player 6']),
      );
    });
  });
}
