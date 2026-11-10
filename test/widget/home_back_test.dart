import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';

import '../support/localized.dart';
import '../support/stores.dart';

/// Players who only ever use the phone's back: on Home the first press says
/// how to leave, and the app stays open.
void main() {
  testWidgets('back on Home warns once instead of closing the game', (
    tester,
  ) async {
    final store = returningHostStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(MemoryMatchRepository(store)),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
        ],
        child: const AmbientMotion(enabled: false, child: MafiaApp()),
      ),
    );
    await tester.pumpAndSettle();
    final handled = await tester.binding.handlePopRoute();
    await tester.pump();
    expect(handled, isTrue, reason: 'the first back is answered in the app');
    expect(find.text(arStrings.backAgainToExit), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
