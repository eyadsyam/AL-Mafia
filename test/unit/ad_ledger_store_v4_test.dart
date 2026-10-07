import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/platform/monetization/ad_ledger_store.dart';
import '../../lib/platform/monetization/ad_policy.dart';
import '../../lib/platform/monetization/ad_placement_registry.dart';
import '../../lib/ui/economy/economy_capabilities.dart';

void main() {
  test(
    'parallel callbacks increment the latest budget without lost updates',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = AdLedgerStoreV4();
      await Future.wait([
        for (var i = 0; i < 6; i++)
          store.update((ledger) => ledger.shown(adInventoryV4[8], 2000)),
      ]);
      expect((await store.load()).automaticShows.length, 6);
      await expectLater(
        store.save(const AdLedgerV4(highWaterMs: 1)),
        throwsStateError,
      );
      expect((await store.load()).automaticShows.length, 6);
    },
  );
  test('malformed timestamps cannot erase caps or lower clock watermark', () {
    expect(
      () => AdLedgerV4.fromJson({
        'automaticShows': ['bad'],
      }),
      throwsFormatException,
    );
    final ledger = AdLedgerV4.fromJson({
      'highWaterMs': 1,
      'automaticShows': [2000],
    });
    expect(ledger.now(1000), 2000);
  });
  test('migrates global legacy cap without resetting restart pacing', () async {
    SharedPreferences.setMockInitialValues({
      'interstitial_ledger_v1': jsonEncode({
        'lastShownMs': 1000,
        'shownToday': 6,
        'lastRewardMs': 900,
        'highWaterMs': 1200,
      }),
    });
    final store = AdLedgerStoreV4();
    final ledger = await store.load();
    expect(ledger.automaticShows.length, 6);
    expect(ledger.lastRewardMs, 900);
    expect(ledger.now(100), 1200);
    await store.save(const AdLedgerV4(highWaterMs: 1500));
    expect((await AdLedgerStoreV4().load()).highWaterMs, 1500);
  });
  test('corrupt persistent cap does not become an empty budget', () async {
    SharedPreferences.setMockInitialValues({AdLedgerStoreV4.key: 'invalid'});
    await expectLater(AdLedgerStoreV4().load(), throwsFormatException);
  });
  test('missing v4 keeps legacy ownership; malformed present v4 is off', () {
    expect(EconomyCapabilities.fromJson({'version': 3}).adsV4Present, false);
    final invalid = EconomyCapabilities.fromJson({
      'version': 3,
      'adsV4': {},
    }, receivedAtMs: 1000);
    expect(invalid.adsV4Present, true);
    expect(invalid.adsV4.units, isEmpty);
  });
}
