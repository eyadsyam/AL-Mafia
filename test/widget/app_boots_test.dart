import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/platform/monetization/rewarded_ads.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';

import '../support/stores.dart';

void main() {
  group('App Boot', () {
    testWidgets('MafiaApp boots and displays title', (
      WidgetTester tester,
    ) async {
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
  
    testWidgets('launch starts no ad consent or ad SDK (phase 100)', (
      WidgetTester tester,
    ) async {
      final ads = _CountingAds();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchRepositoryProvider.overrideWithValue(
              MemoryMatchRepository(returningHostStore()),
            ),
            rewardedAdsProvider.overrideWithValue(ads),
          ],
          child: const AmbientMotion(enabled: false, child: MafiaApp()),
        ),
      );
      await tester.pumpAndSettle();
      expect(ads.initializations, 0);
      expect(ads.shows, 0);
    });
  });
}

/// Configured, so a launch that started ads would be counted here.
class _CountingAds implements RewardedAds {
  int initializations = 0;
  int shows = 0;
  @override
  bool get configured => true;
  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> initialize() async => initializations++;
  @override
  Future<bool> checkPrivacyOptions() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
    RewardedPlacement placement = RewardedPlacement.matchLegacy,
  }) async {
    shows++;
    return RewardedAdOutcome.unavailable;
  }

  @override
  void dispose() {}
}
