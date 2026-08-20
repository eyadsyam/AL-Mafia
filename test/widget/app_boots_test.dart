import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';

import '../support/stores.dart';

void main() {
  group('App Boot', () {
    testWidgets('MafiaApp boots and displays title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          // A returning host. Booting onto Home is only what a launch does once
          // onboarding has been seen — on a genuine first install the app opens
          // the deck instead, which `onboarding_gate_test.dart` covers.
          overrides: [
            matchRepositoryProvider.overrideWithValue(
              MemoryMatchRepository(returningHostStore()),
            ),
          ],
          child: const AmbientMotion(enabled: false, child: MafiaApp()),
        ),
      );
      await tester.pumpAndSettle();

      // The Arabic wordmark and the primary action. The Latin subtitle that
      // used to sit under the title is gone — the home screen is the card
      // spread now, and a second wordmark competed with the deck.
      expect(find.text('سيد المافيا'), findsOneWidget);
      expect(find.text('ابدأ اللعبة'), findsOneWidget);
    });
  });
}
