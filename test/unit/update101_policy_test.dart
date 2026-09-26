import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/monetization/interstitial_policy.dart';
import 'package:mafia_master/ui/economy/daily_rewards.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'dart:math' as math;

void main() {
  const rules = InterstitialRules(
    enabled: true,
    maxPerDay: 3,
    gap: Duration(minutes: 10),
    afterReward: Duration(minutes: 3),
    graceMatches: 1,
  );
  final noon = DateTime.utc(2026, 9, 25, 12).millisecondsSinceEpoch;
  const minute = 60 * 1000;

  InterstitialVerdict decide(
    InterstitialLedger ledger, {
    int? now,
    ResultExit exit = ResultExit.homeAfterCompleted,
    bool adFree = false,
    bool loaded = true,
    InterstitialRules r = rules,
  }) => decideInterstitial(
    rules: r,
    ledger: ledger,
    nowMs: now ?? noon,
    exit: exit,
    adFree: adFree,
    loaded: loaded,
  );

  InterstitialLedger played(int matches, [int? at]) {
    var ledger = InterstitialLedger.empty;
    for (var i = 0; i < matches; i++) {
      ledger = ledger.matchCompleted('room-$i', at ?? noon);
    }
    return ledger;
  }

  group('interstitial policy', () {
    test('never in the first completed match per install', () {
      expect(decide(played(1)), InterstitialVerdict.grace);
      expect(decide(played(2)), InterstitialVerdict.show);
    });

    test('a room is counted once however often the result rebuilds', () {
      final ledger = InterstitialLedger.empty
          .matchCompleted('same', noon)
          .matchCompleted('same', noon);
      expect(ledger.completedMatches, 1);
    });

    test('only the explicit home exit of a completed match', () {
      for (final exit in [
        ResultExit.rematch,
        ResultExit.back,
        ResultExit.kicked,
        ResultExit.disconnected,
      ]) {
        expect(decide(played(3), exit: exit), InterstitialVerdict.notThisExit);
      }
    });

    test('owners of the Quiet Pass and a server switch-off get none', () {
      expect(decide(played(3), adFree: true), InterstitialVerdict.adFree);
      expect(
        decide(played(3), r: InterstitialRules.off),
        InterstitialVerdict.off,
      );
    });

    test('preloaded-or-skip: nothing loaded, nothing waited for', () {
      expect(decide(played(3), loaded: false), InterstitialVerdict.notLoaded);
    });

    test('ten minutes apart, three a day, three minutes after a reward', () {
      var ledger = played(3).shown(noon);
      expect(decide(ledger, now: noon + 9 * minute), InterstitialVerdict.tooSoon);
      expect(decide(ledger, now: noon + 10 * minute), InterstitialVerdict.show);
      ledger = ledger.shown(noon + 10 * minute).shown(noon + 20 * minute);
      expect(decide(ledger, now: noon + 60 * minute), InterstitialVerdict.dailyCap);
      // A new UTC day resets the daily count, not the grace.
      final tomorrow = DateTime.utc(2026, 9, 26, 1).millisecondsSinceEpoch;
      expect(decide(ledger, now: tomorrow), InterstitialVerdict.show);
      final rewarded = played(3).rewarded(noon);
      expect(decide(rewarded, now: noon + 2 * minute), InterstitialVerdict.afterReward);
      expect(decide(rewarded, now: noon + 3 * minute), InterstitialVerdict.show);
    });

    test('a clock moved backwards never unlocks an ad', () {
      final ledger = played(3).shown(noon);
      // Back an hour, or back a whole day: both read as "no time passed".
      expect(decide(ledger, now: noon - 60 * minute), InterstitialVerdict.tooSoon);
      final yesterday = DateTime.utc(2026, 9, 24, 23).millisecondsSinceEpoch;
      final capped = ledger.shown(noon + 11 * minute).shown(noon + 22 * minute);
      // Yesterday's date does not reset today's count.
      expect(decide(capped, now: yesterday), InterstitialVerdict.dailyCap);
      expect(capped.effectiveNow(yesterday), capped.highWaterMs);
    });

    test('survives a round trip through storage', () {
      final ledger = played(2).shown(noon).rewarded(noon + minute);
      final back = InterstitialLedger.fromJson(ledger.toJson());
      expect(back.toJson(), ledger.toJson());
    });

    test('server numbers are clamped to the product rules', () {
      final wild = InterstitialRules.fromJson({
        'enabled': true,
        'maxPerDay': 20,
        'gapSeconds': 5,
        'afterRewardSeconds': 1,
        'graceMatches': 0,
      });
      // Ads v3 (phase 110): the global safety cap is 40 and the gap floor
      // 90 s; the server can only tighten them.
      expect(wild.maxPerDay, 20);
      expect(wild.gap, const Duration(seconds: 90));
      expect(
        InterstitialRules.fromJson({'maxPerDay': 99}).maxPerDay,
        40,
      );
      expect(wild.afterReward, const Duration(minutes: 3));
      expect(wild.graceMatches, 1);
    });
  });

  group('capabilities', () {
    test('anything but a version-2 answer is all off', () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'balance': 100},
        {'version': 1, 'adSteps': true, 'daily': true},
      ]) {
        final caps = EconomyCapabilities.fromJson(json);
        expect(caps.adSteps || caps.daily || caps.dailyAd, isFalse);
        expect(caps.interstitial.enabled, isFalse);
        expect(caps.products, isEmpty);
      }
    });

    test('a version-2 answer is read field by field', () {
      final caps = EconomyCapabilities.fromJson({
        'version': 2,
        'adSteps': true,
        'daily': true,
        'dailyAd': false,
        'adFree': true,
        'recoverable': true,
        'accountTag': 'a' * 64,
        'interstitial': {'enabled': true, 'maxPerDay': 3},
        'products': [
          {'id': 'mm_coins_500', 'kind': 'coins', 'coins': 500},
          {'id': 'mm_remove_interruptions', 'kind': 'entitlement'},
        ],
      });
      expect(caps.adSteps && caps.daily && caps.adFree, isTrue);
      expect(caps.dailyAd, isFalse);
      expect(caps.products.map((p) => p.consumable), [true, false]);
    });
  });

  group('wheel geometry', () {
    const prizes = [
      WheelPrize(0, 10, 40, '40.00'),
      WheelPrize(1, 20, 30, '30.00'),
      WheelPrize(2, 35, 20, '20.00'),
      WheelPrize(3, 60, 8, '8.00'),
      WheelPrize(4, 100, 2, '2.00'),
    ];

    test('slices are proportional to the published odds', () {
      final g = WheelGeometry.of(prizes);
      final total = g.sweeps.fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(2 * math.pi, 1e-9));
      expect(g.sweeps[4] / total, closeTo(0.02, 1e-9));
      expect(g.sweeps[0] / total, closeTo(0.40, 1e-9));
    });

    test('the wheel rests with the server outcome under the pointer', () {
      final g = WheelGeometry.of(prizes);
      for (var slot = 0; slot < prizes.length; slot++) {
        final r = g.restingRotation(slot);
        final middle = g.starts[slot] + g.sweeps[slot] / 2 + r;
        // The pointer is at the top (-pi/2).
        final off = ((middle + math.pi / 2) % (2 * math.pi) + 2 * math.pi) %
            (2 * math.pi);
        expect(math.min(off, 2 * math.pi - off), lessThan(1e-9));
      }
    });
  });
}
