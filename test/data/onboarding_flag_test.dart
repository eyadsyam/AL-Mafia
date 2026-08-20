import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/engine/models/match_settings.dart';

/// The onboarding flag, and the one way it can be lost.
///
/// ## The bug this exists to catch
///
/// The flag shares its row with the default settings — one app-level singleton,
/// two independent things on it. `IsarMatchRepository` therefore has to
/// read-modify-write, because a `put` of a freshly constructed `SettingsRecord`
/// resets whichever field it does not set. Get that wrong and saving settings
/// silently un-sees the onboarding: the host finishes their first match, the app
/// stores their settings on the way in, and the tutorial is waiting for them the
/// next time they open it.
///
/// That is a coupling introduced by the storage layout, so it is asserted at the
/// repository level in both directions. The Isar implementation cannot be
/// exercised here — its native library is not loaded under `flutter test` — so
/// what this pins is the *contract*, and `repository_roundtrip_test` is where
/// the two implementations are held to the same one.
void main() {
  late MemoryMatchStore store;
  late MemoryMatchRepository repository;

  setUp(() {
    store = MemoryMatchStore();
    repository = MemoryMatchRepository(store);
  });

  test('a fresh install has not seen onboarding', () async {
    expect(await repository.hasSeenOnboarding(), isFalse);
  });

  test('marking it is idempotent', () async {
    await repository.markOnboardingSeen();
    await repository.markOnboardingSeen();
    expect(await repository.hasSeenOnboarding(), isTrue);
  });

  test('it survives the repository being rebuilt over the same store',
      () async {
    await repository.markOnboardingSeen();

    // A relaunch. The repository is gone; the storage is not.
    expect(await MemoryMatchRepository(store).hasSeenOnboarding(), isTrue);
  });

  test('saving settings does not un-see it', () async {
    await repository.markOnboardingSeen();
    await repository.saveDefaultSettings(
      const MatchSettings.defaults().copyWith(muteAllAudio: true),
    );

    expect(await repository.hasSeenOnboarding(), isTrue);
  });

  test('marking it does not disturb stored settings', () async {
    const settings = MatchSettings.defaults();
    await repository.saveDefaultSettings(settings);
    await repository.markOnboardingSeen();

    expect(await repository.loadDefaultSettings(), settings);
  });

  test('settings are still their defaults when only the flag was written',
      () async {
    await repository.markOnboardingSeen();

    expect(
      await repository.loadDefaultSettings(),
      const MatchSettings.defaults(),
      reason: 'a row written by markOnboardingSeen carries no settings '
          'payload, and must read back as though there were no row at all',
    );
  });
}
