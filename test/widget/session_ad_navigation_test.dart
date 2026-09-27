import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/platform/monetization/interstitial_ads.dart';
import 'package:mafia_master/platform/monetization/interstitial_policy.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/interstitial_coordinator.dart';
import 'package:mafia_master/ui/screens/postgame/history_screen.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/stores.dart';

/// Ads v3 session ad (Play's interstitial policy): shown only *before* a
/// forward tap between two menu screens, never after the route changed and
/// never on the system back.
void main() {
  const minute = 60 * 1000;
  final noon = DateTime.utc(2026, 9, 27, 12).millisecondsSinceEpoch;

  testWidgets('back never shows it; the forward tap shows it once when due', (
    tester,
  ) async {
    final store = returningHostStore()..onboardingSeen = true;
    SharedPreferences.setMockInitialValues({
      'community_rules_2026_09': true,
      ProfileStore.profileKey: '{"name":"A","gender":"male"}',
      ...acceptedTermsPrefs,
      'interstitial_ledger_v1':
          '{"completedMatches":3,"highWaterMs":${noon - 60 * minute}}',
    });
    var now = noon;
    final ads = _Ads();
    final container = ProviderContainer(
      overrides: [
        matchRepositoryProvider.overrideWithValue(MemoryMatchRepository(store)),
        interstitialAdsProvider.overrideWithValue(ads),
        interstitialClockProvider.overrideWithValue(() => now),
        economyCapabilitiesProvider.overrideWith(
          (ref) async => const EconomyCapabilities(
            interstitial: InterstitialRules(
              enabled: true,
              session: true,
              maxPerDay: AdTokens.fullScreenMaxPerDay,
              gap: AdTokens.fullScreenMinGap,
              afterReward: Duration(minutes: 3),
              graceMatches: 1,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(economyCapabilitiesProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AmbientMotion(enabled: false, child: MafiaApp()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    container.read(interstitialCoordinatorProvider).foreground(true);

    // Due (ten menu minutes): the tap shows the ad, and only then moves on.
    now += 10 * minute;
    await tester.tap(find.byKey(HomeScreen.historyButton));
    await tester.pumpAndSettle();
    expect(ads.shows, 1);
    expect(ads.shownOver, ['/'], reason: 'shown before the move, over Home');
    expect(find.byType(HistoryScreen), findsOneWidget);

    // Due again, but the system back only goes back.
    now += 10 * minute;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(ads.shows, 1);

    // The next forward tap is where it is shown, once.
    await tester.tap(find.byKey(HomeScreen.historyButton));
    await tester.pumpAndSettle();
    expect(ads.shows, 2);
    expect(find.byType(HistoryScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HomeScreen.historyButton));
    await tester.pumpAndSettle();
    expect(ads.shows, 2, reason: 'the gap and the menu clock hold');
  });
}

class _Ads implements InterstitialAds {
  int shows = 0;
  final shownOver = <String>[];

  @override
  bool get configured => true;

  @override
  bool get ready => true;

  @override
  Future<void> preload() async {}

  @override
  Future<bool> showIfReady() async {
    shows++;
    final home = find.byType(HomeScreen).evaluate().isNotEmpty;
    shownOver.add(home ? '/' : '?');
    return true;
  }

  @override
  Future<bool> canRequestAds() async => true;

  @override
  void dispose() {}
}
