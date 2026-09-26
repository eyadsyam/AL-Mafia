import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/monetization/play_billing.dart';
import 'package:mafia_master/platform/monetization/purchase_store.dart';
import 'package:mafia_master/platform/monetization/rewarded_ads.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/daily_rewards.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/interstitial_coordinator.dart';
import 'package:mafia_master/ui/economy/play_offers.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/rewarded_reward_button.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

class _Ads implements RewardedAds {
  final shown = <String>[];
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
    shown.add(claimId);
    return RewardedAdOutcome.dismissed;
  }

  @override
  void dispose() {}
}

class _Billing implements PlayBilling {
  final stream = StreamController<StorePurchaseEvent>.broadcast();
  final bought = <String>[];
  @override
  bool get supported => true;
  @override
  Stream<StorePurchaseEvent> get events => stream.stream;
  @override
  Future<void> start() async {}
  @override
  Future<bool> available() async => true;
  @override
  Future<Map<String, PlayListing>> listings(Set<String> ids) async => {
    for (final id in ids) id: PlayListing(id: id, title: id, price: 'EGP 29.99'),
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
  int debt = 0,
  List<Map<String, Object?>> products = const [],
}) => {
  'version': 2,
  'adSteps': true,
  'daily': true,
  'dailyAd': true,
  'recoverable': true,
  'accountTag': 'a' * 64,
  'purchaseDebt': debt,
  'interstitial': {'enabled': false},
  'products': products,
};

Map<String, dynamic> daily() => {
  'enabled': true,
  'day': '2026-09-25',
  'coffer': {'claimed': false, 'amount': 20},
  'wheel': {
    'spun': false,
    'prizes': [
      {'slot': 0, 'coins': 10, 'weight': 40, 'percent': '40.00'},
    ],
  },
  'week': {'progress': 0, 'length': 7, 'bonus': 60},
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
    await tester.binding.setSurfaceSize(const Size(390, 1200));
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
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  group('1 · automatic ad only after the room is left', () {
    test('left in time: exit, then the ad is considered', () async {
      final order = <String>[];
      final left = await leaveThenMaybeAd(
        leave: () async => order.add('leave'),
        exit: () => order.add('exit'),
        ad: () async => order.add('ad'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(left, isTrue);
      expect(order, ['leave', 'exit', 'ad']);
    });

    test('a failing leave still exits, and no ad follows', () async {
      final order = <String>[];
      final left = await leaveThenMaybeAd(
        leave: () async => throw StateError('network'),
        exit: () => order.add('exit'),
        ad: () async => order.add('ad'),
      );
      expect(left, isFalse);
      expect(order, ['exit']);
    });

    testWidgets('a slow leave exits at the timeout, and no ad follows', (
      tester,
    ) async {
      final order = <String>[];
      final never = Completer<void>();
      unawaited(
        leaveThenMaybeAd(
          leave: () => never.future,
          exit: () => order.add('exit'),
          ad: () async => order.add('ad'),
          timeout: const Duration(seconds: 3),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(order, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(order, ['exit']);
    });
  });

  group('3 · refund and debt disclosed before buying', () {
    testWidgets('the rule sits beside packs and pass; open debt is shown', (
      tester,
    ) async {
      backend.responders['economy'] = (_) => caps(
        debt: 500,
        products: [
          {'id': 'mm_remove_interruptions', 'kind': 'entitlement'},
          {'id': 'mm_coins_500', 'kind': 'coins', 'coins': 500},
        ],
      );
      await pump(tester, const PlayOffersTab(), billing: _Billing());
      expect(find.byKey(PlayOffersTab.debtKey), findsOneWidget);
      expect(find.text(arStrings.playDebtNotice(500)), findsOneWidget);
      expect(
        find.textContaining(arStrings.playRefundRule),
        findsOneWidget,
      );
      expect(
        find.textContaining(arStrings.quietPassRefundRule),
        findsOneWidget,
      );
    });

    testWidgets('no debt, no debt notice', (tester) async {
      backend.responders['economy'] = (_) => caps(
        products: [
          {'id': 'mm_coins_500', 'kind': 'coins', 'coins': 500},
        ],
      );
      await pump(tester, const PlayOffersTab(), billing: _Billing());
      expect(find.byKey(PlayOffersTab.debtKey), findsNothing);
    });
  });

  group('6 · daily ad', () {
    testWidgets('an already-awarded claim shows no ad', (tester) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'daily_ad_claim' => {'claimId': 'd', 'state': 'awarded', 'amount': 25},
        _ => daily(),
      };
      await pump(tester, const DailyRewardsTab());
      await tester.scrollUntilVisible(
        find.byKey(DailyRewardsTab.adKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.byKey(DailyRewardsTab.adKey));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(
        backend.calls.any((c) => c.body['action'] == 'daily_ad_claim'),
        isTrue,
        reason: 'the tap reached the button',
      );
      expect(ads.shown, isEmpty);
    });
  });

  group('7 · wheel slots by value', () {
    test('gapped slots resolve to their own slice', () {
      const prizes = [
        WheelPrize(3, 10, 50, '50.00'),
        WheelPrize(7, 100, 50, '50.00'),
      ];
      final g = WheelGeometry.of(prizes);
      // Slot 7 is the second slice, not list index 7 (clamped) or slot 3.
      expect(g.restingRotation(7), isNot(g.restingRotation(3)));
      expect(g.restingRotation(7), g.restingRotation(7));
      final byIndex = WheelGeometry.of(const [
        WheelPrize(0, 10, 50, '50.00'),
        WheelPrize(1, 100, 50, '50.00'),
      ]);
      expect(g.restingRotation(7), closeTo(byIndex.restingRotation(1), 1e-9));
    });
  });

  group('8 · capabilities and Play state', () {
    test('a network failure is marked failed; an old server is not', () async {
      final container = ProviderContainer(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        ],
      );
      addTearDown(container.dispose);
      backend.unreachable = true;
      expect(
        (await container.read(economyCapabilitiesProvider.future)).failed,
        isTrue,
      );
      backend.unreachable = false;
      backend.responders['economy'] = (_) =>
          throw const BackendException('BAD_REQUEST', 'invalid economy request');
      container.invalidate(economyCapabilitiesProvider);
      final old = await container.read(economyCapabilitiesProvider.future);
      expect(old.failed, isFalse);
      expect(old.adSteps, isFalse);
    });

    testWidgets('a pending payment does not disable the other buttons', (
      tester,
    ) async {
      final billing = _Billing();
      backend.responders['economy'] = (_) => caps(
        products: [
          {'id': 'mm_coins_500', 'kind': 'coins', 'coins': 500},
          {'id': 'mm_coins_1200', 'kind': 'coins', 'coins': 1200},
        ],
      );
      await pump(tester, const PlayOffersTab(), billing: billing);
      await tester.tap(find.byKey(PlayOffersTab.buyKey('mm_coins_500')));
      await tester.pump();
      await tester.pump();
      billing.stream.add(
        const StorePurchaseEvent(
          state: StorePurchaseState.pending,
          productId: 'mm_coins_500',
        ),
      );
      await tester.pump();
      final other = tester.widget<FilledButton>(
        find.byKey(PlayOffersTab.buyKey('mm_coins_1200')),
      );
      expect(other.onPressed, isNotNull);
      expect(find.text(arStrings.playPending), findsOneWidget);
    });
  });

  group('steps answer this build cannot draw', () {
    testWidgets('falls back to the single ad instead of loading forever', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'ad_steps_status_v2' => {'scheme': 'steps', 'steps': []},
        _ => {'state': 'available', 'amount': 100},
      };
      await pump(tester, const RewardedRewardButton(roomId: 'room-1'));
      final button = tester.widget<OutlinedButton>(
        find.byKey(RewardedRewardButton.actionKey),
      );
      expect(button.onPressed, isNotNull);
      expect(find.text(arStrings.adRewardAction(100)), findsOneWidget);
    });
  });
}
