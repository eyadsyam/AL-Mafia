import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/setup/setup_draft.dart';

void main() {
  test('saved defaults seed the first draft and survive a new match', () async {
    final store = MemoryMatchStore();
    final writer = MemoryMatchRepository(store);
    const saved = MatchSettings(
      muteAllAudio: true,
      scoreEnabled: false,
      speechSeconds: 45,
      traceEnabled: false,
    );
    await writer.saveDefaultSettings(saved);
    final reader = MemoryMatchRepository(store);
    final container = ProviderContainer(
      overrides: [
        initialMatchSettingsProvider.overrideWithValue(
          await reader.loadDefaultSettings(),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(setupDraftProvider).settings, saved);
    container.read(setupDraftProvider.notifier)
      ..setNames(['A', 'B', 'C', 'D', 'E'])
      ..resetForNewMatch();
    expect(container.read(setupDraftProvider).settings, saved);
    expect(container.read(setupDraftProvider).names, isEmpty);
  });
}
