import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/monetization/ad_formats.dart';
import 'package:mafia_master/platform/monetization/app_open_policy.dart';
import 'package:mafia_master/platform/monetization/interstitial_policy.dart';
import 'package:mafia_master/ui/economy/app_open_gate.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Ads implements AppOpenAds {
  final loaded = Completer<int?>();
  final loading = Completer<void>();
  int shows = 0;
  int discards = 0;

  @override
  bool get configured => true;
  @override
  Future<bool> canRequestAds() async => true;
  @override
  Future<int?> load(Duration timeout, {bool resume = false}) {
    loading.complete();
    return loaded.future;
  }

  @override
  Future<bool> show() async {
    shows++;
    return true;
  }

  @override
  void discard() => discards++;
}

void main() {
  test('room becoming active during load suppresses app-open ad', () async {
    final now = DateTime.utc(2026, 9, 26, 12).millisecondsSinceEpoch;
    final ledger = AppOpenLedger.empty
        .launched(now - const Duration(days: 2).inMilliseconds)
        .known(enabled: true, adFree: false);
    SharedPreferences.setMockInitialValues({
      'app_open_ledger_v1': jsonEncode(ledger.toJson()),
    });
    final ads = _Ads();
    final container = ProviderContainer(
      overrides: [
        appOpenAdsProvider.overrideWithValue(ads),
        appOpenClockProvider.overrideWithValue(() => now),
        economyCapabilitiesProvider.overrideWith(
          (ref) async => const EconomyCapabilities(
            ads: AdsCapabilities(appOpen: AppOpenRules.on),
            interstitial: InterstitialRules.pacingDefaults,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    var roomActive = false;
    final attempt = container
        .read(appOpenCoordinatorProvider)
        .attempt(
          trigger: AppOpenTrigger.coldStart,
          busy: () async => roomActive,
          onboarded: () async => true,
        );
    await ads.loading.future;
    roomActive = true;
    ads.loaded.complete(now);
    expect(await attempt, AppOpenVerdict.busy);
    expect(ads.shows, 0);
    expect(ads.discards, greaterThan(0));
  });
}
