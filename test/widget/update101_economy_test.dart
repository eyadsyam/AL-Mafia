import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/monetization/play_billing.dart';
import 'package:mafia_master/platform/monetization/purchase_store.dart';
import 'package:mafia_master/platform/monetization/rewarded_ads.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/daily_rewards.dart';
import 'package:mafia_master/ui/economy/play_offers.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/rewarded_reward_button.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

class _Ads implements RewardedAds {
  final shown = <(String, RewardedPlacement)>[];
  RewardedAdOutcome outcome = RewardedAdOutcome.earned;
  @override
  bool get configured => true;
  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> initialize() async {}
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
    shown.add((claimId, placement));
    return outcome;
  }

  @override
  void dispose() {}
}

class _Billing implements PlayBilling {
  final bought = <String>[];
  @override
  bool get supported => true;
  @override
  Stream<StorePurchaseEvent> get events => const Stream.empty();
  @override
  Future<void> start() async {}
  @override
  Future<bool> available() async => true;
  @override
  Future<Map<String, PlayListing>> listings(Set<String> ids) async => {
    for (final id in ids)
      if (id != 'mm_coins_2500')
        id: PlayListing(id: id, title: id, price: 'EGP 29.99'),
  };
  @override
  Future<bool> buy(
    String productId, {
    required bool consumable,
    required String accountTag,
  }) async {
    bought.add(productId);
    return true;
  }

  @override
  Future<void> restore() async {}
  @override
  Future<void> finishEntitlement(String token) async {}
  @override
  void dispose() {}
}

Map<String, dynamic> caps({
  bool adSteps = true,
  bool daily = true,
  bool recoverable = true,
  List<Map<String, Object?>> products = const [],
}) => {
  'version': 2,
  'adSteps': adSteps,
  'daily': daily,
  'dailyAd': daily,
  'recoverable': recoverable,
  'accountTag': 'a' * 64,
  'adFree': false,
  'interstitial': {'enabled': false},
  'products': products,
};

// Ads v3 (phase 110): each step is the whole base — x2, then x3.
Map<String, dynamic> steps(String one, String two) => {
  'scheme': 'steps',
  'mode': 'multiply',
  'base': 100,
  'total': 100,
  'double': 200,
  'triple': 300,
  'steps': [
    {'step': 1, 'amount': 100, 'totalAfter': 200, 'state': one, 'claimId': 'c1'},
    {
      'step': 2,
      'amount': 100,
      'totalAfter': 300,
      'state': two,
      'claimId': two == 'available' ? null : 'c2',
    },
  ],
};

Map<String, dynamic> daily({bool coffer = false, bool spun = false, int? slot}) => {
  'enabled': true,
  'day': '2026-09-25',
  'coffer': {'claimed': coffer, 'amount': 20},
  'wheel': {
    'spun': spun,
    'slot': slot,
    'amount': slot == null ? null : 35,
    'prizes': [
      {'slot': 0, 'coins': 10, 'weight': 40, 'percent': '40.00'},
      {'slot': 1, 'coins': 20, 'weight': 30, 'percent': '30.00'},
      {'slot': 2, 'coins': 35, 'weight': 20, 'percent': '20.00'},
      {'slot': 3, 'coins': 60, 'weight': 8, 'percent': '8.00'},
      {'slot': 4, 'coins': 100, 'weight': 2, 'percent': '2.00'},
    ],
  },
  'week': {'claimedDays': 3, 'progress': 3, 'length': 7, 'bonus': 60},
  'ad': {'enabled': true, 'amount': 25, 'state': 'available', 'inMatch': false},
};

void main() {
  late FakeBackend backend;
  late _Ads ads;

  setUp(() {
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'result'),
      players: roster(5),
    );
    ads = _Ads();
  });

  Future<void> pump(WidgetTester tester, Widget child, {PlayBilling? billing}) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          rewardedAdsProvider.overrideWithValue(ads),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
          if (billing != null) playBillingProvider.overrideWithValue(billing),
        ],
        child: localizedApp(Scaffold(body: child)),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  group('x2 / x3 post-match reward', () {
    testWidgets('both totals are shown before any tap; the triple waits', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        _ => steps('available', 'available'),
      };
      await pump(tester, const RewardedRewardButton(roomId: 'room-1'));
      expect(find.text(arStrings.adDoubleTitle), findsOneWidget);
      expect(find.text(arStrings.adDoubleAction(200)), findsOneWidget);
      expect(find.text(arStrings.adTripleAction(300)), findsOneWidget);
      expect(
        find.text(arStrings.adDoubleDisclosure(100, 200, 300)),
        findsOneWidget,
      );
      final two = tester.widget<OutlinedButton>(
        find.byKey(RewardedRewardButton.stepKey(2)),
      );
      expect(two.onPressed, isNull, reason: 'step 2 only after step 1 is verified');
    });

    testWidgets('a verified step 1 is kept; step 2 opens with its own claim', (
      tester,
    ) async {
      var awarded = false;
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'ad_step_claim_v2' => {
          ...steps('pending', 'available'),
          'claimId': 'c1',
          'claimState': 'pending',
        },
        'ad_steps_status_v2' => awarded
            ? steps('awarded', 'available')
            : steps('available', 'available'),
        _ => {'ok': true},
      };
      await pump(tester, const RewardedRewardButton(roomId: 'room-1'));
      awarded = true; // AdMob's signed callback lands while the ad plays.
      await tester.tap(find.byKey(RewardedRewardButton.stepKey(1)));
      await tester.pump();
      await tester.pump(MafiaTiming.adRewardPoll);
      await tester.pump();
      expect(ads.shown.single, ('s2:c1', RewardedPlacement.matchStep));
      expect(find.text(arStrings.adDoubleDone(200)), findsOneWidget);
      final two = tester.widget<OutlinedButton>(
        find.byKey(RewardedRewardButton.stepKey(2)),
      );
      expect(two.onPressed, isNotNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('both verified: the match now pays x3', (tester) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        _ => steps('awarded', 'awarded'),
      };
      await pump(tester, const RewardedRewardButton(roomId: 'room-1'));
      expect(find.text(arStrings.adTripleComplete(300)), findsOneWidget);
      expect(find.text(arStrings.adDoubleDone(200)), findsOneWidget);
      expect(find.text(arStrings.adTripleDone(300)), findsOneWidget);
      for (final step in [1, 2]) {
        final button = tester.widget<OutlinedButton>(
          find.byKey(RewardedRewardButton.stepKey(step)),
        );
        expect(button.onPressed, isNull, reason: 'no third payment');
      }
    });

    testWidgets('totals are derived when the server omits them', (tester) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        _ => {
          'scheme': 'steps',
          'base': 80,
          'total': 80,
          'steps': [
            {'step': 1, 'amount': 80, 'state': 'available'},
            {'step': 2, 'amount': 80, 'state': 'available'},
          ],
        },
      };
      await pump(tester, const RewardedRewardButton(roomId: 'room-1'));
      expect(find.text(arStrings.adDoubleAction(160)), findsOneWidget);
      expect(find.text(arStrings.adTripleAction(240)), findsOneWidget);
    });

    testWidgets('an old server keeps the 1.0.0 single ad', (tester) async {
      backend.responders['economy'] = (body) {
        if (body['action'] == 'capabilities') {
          throw const BackendException('BAD_REQUEST', 'invalid economy request');
        }
        return {'state': 'available', 'amount': 100};
      };
      await pump(tester, const RewardedRewardButton(roomId: 'room-1'));
      expect(find.byKey(RewardedRewardButton.actionKey), findsOneWidget);
      expect(find.byKey(RewardedRewardButton.stepKey(1)), findsNothing);
      expect(find.text(arStrings.adRewardAction(100)), findsOneWidget);
    });

    testWidgets('a match with a 1.0.0 claim stays a single ad', (tester) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        _ => {'scheme': 'v1', 'claimId': 'old', 'state': 'awarded', 'amount': 100},
      };
      await pump(tester, const RewardedRewardButton(roomId: 'room-1'));
      expect(find.byKey(RewardedRewardButton.stepKey(1)), findsNothing);
      expect(find.text(arStrings.adRewardUsed), findsOneWidget);
    });
  });

  group('daily rewards', () {
    testWidgets('the coffer claim names the server day; odds are published', (
      tester,
    ) async {
      var claimed = false;
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'daily_coffer' => () {
          claimed = true;
          return {'granted': 20, 'bonus': 0, 'daily': daily(coffer: true)};
        }(),
        _ => daily(coffer: claimed),
      };
      await pump(tester, const DailyRewardsTab());
      expect(find.text(arStrings.dailyWheelPercent('2')), findsOneWidget);
      expect(find.text(arStrings.dailyWheelPercent('40')), findsOneWidget);
      await tester.tap(find.byKey(DailyRewardsTab.cofferKey));
      await tester.pump();
      await tester.pump();
      expect(backend.lastCall('economy')!.body, {
        'action': 'daily_coffer',
        'day': '2026-09-25',
      });
      final button = tester.widget<FilledButton>(
        find.byKey(DailyRewardsTab.cofferKey),
      );
      expect(button.onPressed, isNull, reason: 'once a day');
    });

    testWidgets('the wheel lands on the stored outcome; no respin', (tester) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'daily_spin' => {'slot': 2, 'amount': 35, 'granted': 35, 'daily': daily(spun: true, slot: 2)},
        _ => daily(),
      };
      await pump(tester, const DailyRewardsTab());
      await tester.tap(find.byKey(DailyRewardsTab.spinKey));
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(MafiaTiming.wheelSpin);
      }
      expect(find.text(arStrings.dailyWheelResult(35)), findsOneWidget);
      final spin = tester.widget<FilledButton>(find.byKey(DailyRewardsTab.spinKey));
      expect(spin.onPressed, isNull);
    });

    testWidgets('a reopened tab shows today\'s spin without spinning', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        _ => daily(spun: true, slot: 2),
      };
      await pump(tester, const DailyRewardsTab());
      expect(find.text(arStrings.dailyWheelDone(35)), findsOneWidget);
      expect(backend.calls.where((c) => c.body['action'] == 'daily_spin'), isEmpty);
    });
  });

  group('Play offers', () {
    testWidgets('only products the server sells and Play lists; localized price', (
      tester,
    ) async {
      final billing = _Billing();
      backend.responders['economy'] = (_) => caps(
        products: [
          {'id': 'mm_remove_interruptions', 'kind': 'entitlement'},
          {'id': 'mm_coins_500', 'kind': 'coins', 'coins': 500},
          {'id': 'mm_coins_2500', 'kind': 'coins', 'coins': 2500},
        ],
      );
      await pump(tester, const PlayOffersTab(), billing: billing);
      await tester.pump();
      expect(find.byKey(PlayOffersTab.buyKey('mm_remove_interruptions')), findsOneWidget);
      expect(find.byKey(PlayOffersTab.buyKey('mm_coins_500')), findsOneWidget);
      expect(find.byKey(PlayOffersTab.buyKey('mm_coins_2500')), findsNothing,
          reason: 'not listed by Play on this device');
      expect(find.text(arStrings.payWithGoogle('EGP 29.99')), findsNWidgets(2));
    });

    testWidgets('an unprotected account is asked to link an email first', (
      tester,
    ) async {
      final billing = _Billing();
      backend.responders['economy'] = (_) => caps(
        recoverable: false,
        products: [
          {'id': 'mm_coins_500', 'kind': 'coins', 'coins': 500},
        ],
      );
      await pump(tester, const PlayOffersTab(), billing: billing);
      await tester.pump();
      await tester.tap(find.byKey(PlayOffersTab.buyKey('mm_coins_500')));
      await tester.pump();
      await tester.pump();
      expect(billing.bought, isEmpty);
      expect(find.text(arStrings.playNeedsProtection), findsOneWidget);
    });

    testWidgets('no active products: nothing to buy, said honestly', (tester) async {
      backend.responders['economy'] = (_) => caps();
      await pump(tester, const PlayOffersTab(), billing: _Billing());
      await tester.pump();
      expect(find.text(arStrings.playUnavailable), findsOneWidget);
      expect(find.byKey(PlayOffersTab.restoreKey), findsNothing);
    });
  });
}
