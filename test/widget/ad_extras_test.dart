import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/monetization/rewarded_ads.dart';
import 'package:mafia_master/ui/economy/ad_extras.dart';
import 'package:mafia_master/ui/economy/ad_reward_flow.dart';
import 'package:mafia_master/ui/economy/council.dart';
import 'package:mafia_master/ui/economy/daily_rewards.dart';
import 'package:mafia_master/ui/economy/waiting_banner.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

class _Ads implements RewardedAds, RewardedPreload {
  final shown = <(String, RewardedPlacement)>[];
  final preloaded = <RewardedPlacement>[];
  bool configuredValue = true;
  RewardedAdOutcome outcome = RewardedAdOutcome.earned;
  @override
  bool get configured => configuredValue;
  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> checkPrivacyOptions() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  Future<void> preload(RewardedPlacement placement) async =>
      preloaded.add(placement);
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

Map<String, dynamic> caps({
  bool spin = true,
  bool coffer = true,
  bool swap = true,
}) => {
  'version': 2,
  'daily': true,
  'dailyAd': true,
  'adFree': false,
  'interstitial': {'enabled': false},
  'products': const [],
  'ads': {
    'appOpen': {'enabled': false},
    'banner': {'enabled': true},
    'extras': {'spin': spin, 'coffer': coffer, 'swap': swap},
  },
};

const _prizes = [
  {'slot': 0, 'coins': 10, 'weight': 40, 'percent': '40.00'},
  {'slot': 1, 'coins': 20, 'weight': 30, 'percent': '30.00'},
  {'slot': 2, 'coins': 35, 'weight': 20, 'percent': '20.00'},
  {'slot': 3, 'coins': 60, 'weight': 8, 'percent': '8.00'},
  {'slot': 4, 'coins': 100, 'weight': 2, 'percent': '2.00'},
];

Map<String, dynamic> daily({
  bool coffer = false,
  bool spun = false,
  String adState = 'available',
}) => {
  'enabled': true,
  'day': '2026-09-26',
  'coffer': {'claimed': coffer, 'amount': 20},
  'wheel': {
    'spun': spun,
    'slot': spun ? 2 : null,
    'amount': spun ? 35 : null,
    'prizes': _prizes,
  },
  'week': {'progress': 1, 'length': 7, 'bonus': 60},
  'ad': {'enabled': true, 'amount': 25, 'state': adState, 'inMatch': false},
};

Map<String, dynamic> extras({
  bool spinReady = true,
  String spinState = 'available',
  int? spinAmount,
  int? spinSlot,
  bool cofferReady = true,
  String cofferState = 'available',
  String swapState = 'available',
}) => {
  'enabled': true,
  'day': '2026-09-26',
  'inMatch': false,
  'spin': {
    'enabled': true,
    'ready': spinReady,
    'state': spinState,
    'amount': spinAmount,
    'slot': spinSlot,
    'prizes': _prizes,
  },
  'coffer': {
    'enabled': true,
    'ready': cofferReady,
    'state': cofferState,
    'amount': 20,
  },
  'swap': {'enabled': true, 'state': swapState},
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

  Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scope = ProviderScope(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        rewardedAdsProvider.overrideWithValue(ads),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
      ],
      child: localizedApp(Scaffold(body: child)),
    );
    await tester.pumpWidget(scope);
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    return ProviderScope.containerOf(tester.element(find.byWidget(child)));
  }

  /// Lets the wheel settle and the win finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(MafiaTiming.wheelSpin);
    }
    await tester.pump(WinTokens.reveal);
    await tester.pump(WinTokens.reveal);
  }

  int calls(String action) =>
      backend.calls.where((c) => c.body['action'] == action).length;

  group('the second spin lives on the wheel', () {
    testWidgets('before today\'s free spin there is no ad to spin again', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'extras_status' => extras(spinReady: false),
        _ => daily(),
      };
      await pump(tester, const DailyRewardsTab());
      expect(find.byKey(DailyRewardsTab.spinKey), findsOneWidget);
      expect(find.byKey(DailyRewardsTab.extraSpinKey), findsNothing);
      expect(find.text(arStrings.wheelAgainAd), findsNothing);
    });

    testWidgets('after it, the same button asks «spin again?»; the server\'s '
        'prize lands on the wheel and the balance follows', (tester) async {
      var awarded = false;
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'extras_status' =>
          awarded
              ? extras(spinState: 'awarded', spinAmount: 60, spinSlot: 3)
              : extras(spinState: awarded ? 'awarded' : 'available'),
        'extra_claim' => {'claimId': 'e1', 'state': 'pending', 'kind': 'spin'},
        'sync' || 'summary' => {'balance': awarded ? 160 : 100},
        _ => daily(spun: true, coffer: true, adState: 'awarded'),
      };
      final container = await pump(tester, const DailyRewardsTab());
      await container.read(walletProvider.notifier).refresh();
      await tester.pump();
      expect(find.text(arStrings.wheelAgainAd), findsOneWidget);
      // The offer is on screen: its ad loads before any tap.
      await tester.pump(AdTokens.rewardedPreloadAfter);
      expect(ads.preloaded, contains(RewardedPlacement.extra));

      await tester.tap(find.byKey(DailyRewardsTab.extraSpinKey));
      await tester.pump();
      await tester.pump();
      expect(
        backend.calls
            .where((c) => c.body['action'] == 'extra_claim')
            .single
            .body,
        {'action': 'extra_claim', 'day': '2026-09-26', 'kind': 'spin'},
      );
      expect(ads.shown.single, ('x1:e1', RewardedPlacement.extra));
      expect(
        find.text(arStrings.adRewardVerifying),
        findsOneWidget,
        reason: 'watched: confirming, never «watch» again',
      );

      awarded = true; // AdMob's signed callback reaches the server.
      await tester.pump(MafiaTiming.adRewardPoll);
      await tester.pump();
      expect(
        container.read(walletProvider).valueOrNull?.balance,
        160,
        reason: 'the balance moves at once, no reopening',
      );
      await settle(tester);
      expect(find.text(arStrings.adExtraSpinResult(60)), findsOneWidget);
      expect(find.byKey(DailyRewardsTab.extraSpinKey), findsNothing);
      final free = tester.widget<FilledButton>(
        find.byKey(DailyRewardsTab.spinKey),
      );
      expect(free.onPressed, isNull, reason: 'once a day');
      expect(ads.shown, hasLength(1));
    });

    testWidgets('a slow confirmation says «on its way», never offers the ad '
        'again, and lands on a check', (tester) async {
      var awarded = false;
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'extras_status' =>
          awarded
              ? extras(spinState: 'awarded', spinAmount: 20, spinSlot: 1)
              : extras(spinState: 'pending'),
        'extra_claim' => {'claimId': 'e1', 'state': 'pending', 'kind': 'spin'},
        _ => daily(spun: true, coffer: true, adState: 'awarded'),
      };
      await pump(tester, const DailyRewardsTab());
      await tester.tap(find.byKey(DailyRewardsTab.extraSpinKey));
      await tester.pump();
      await tester.pump();
      // Past the whole check window without the server's word.
      await tester.pump(MafiaTiming.adRewardPollWindow);
      await tester.pump(MafiaTiming.adRewardPollCap);
      await tester.pump();
      expect(find.text(arStrings.adRewardLateCheck), findsOneWidget);
      expect(find.text(arStrings.wheelAgainAd), findsNothing);

      awarded = true;
      await tester.tap(find.byKey(DailyRewardsTab.extraSpinKey));
      await tester.pump();
      await tester.pump();
      await settle(tester);
      expect(find.text(arStrings.adExtraSpinResult(20)), findsOneWidget);
      expect(ads.shown, hasLength(1), reason: 'one ad, one claim');
      expect(calls('extra_claim'), 1);
    });

    testWidgets('a double tap starts one ad', (tester) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'extras_status' => extras(),
        'extra_claim' => {'claimId': 'e1', 'state': 'pending', 'kind': 'spin'},
        _ => daily(spun: true, coffer: true, adState: 'awarded'),
      };
      ads.outcome = RewardedAdOutcome.dismissed;
      await pump(tester, const DailyRewardsTab());
      final button = find.byKey(DailyRewardsTab.extraSpinKey);
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      await tester.pump();
      expect(calls('extra_claim'), 1);
      expect(ads.shown, hasLength(1));
      // Closed early: the offer is simply there again.
      await tester.pump();
      expect(find.text(arStrings.wheelAgainAd), findsOneWidget);
    });

    testWidgets('switched off, or no rewarded unit: the wheel offers no ad', (
      tester,
    ) async {
      ads.configuredValue = false;
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'extras_status' => extras(),
        _ => daily(spun: true),
      };
      await pump(tester, const DailyRewardsTab());
      expect(find.byKey(DailyRewardsTab.extraSpinKey), findsNothing);
      expect(backend.calls.any((c) => c.body['action'] == 'extras_status'),
          isFalse);
    });
  });

  group('the coffer\'s own ladder', () {
    testWidgets('open → double it → a little more, one button at a time', (
      tester,
    ) async {
      var doubled = false;
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'extras_status' =>
          doubled ? extras(cofferState: 'awarded') : extras(),
        'extra_claim' => {'claimId': 'c', 'state': 'pending'},
        _ => daily(coffer: true),
      };
      await pump(tester, const DailyRewardsTab());
      expect(find.text(arStrings.cofferDoubleAd(20)), findsOneWidget);
      expect(find.byKey(DailyRewardsTab.adKey), findsNothing);

      await tester.tap(find.byKey(DailyRewardsTab.extraCofferKey));
      await tester.pump();
      await tester.pump();
      expect(ads.shown.single, ('x1:c', RewardedPlacement.extra));
      doubled = true; // the signed callback lands
      await tester.pump(MafiaTiming.adRewardPoll);
      await tester.pump();
      await settle(tester);
      expect(find.text(arStrings.cofferDoubleAd(20)), findsNothing);
      expect(find.text(arStrings.dailyAdMore(25)), findsOneWidget);
    });

    testWidgets('before the coffer is opened, no ad is offered at all', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(),
        'extras_status' => extras(cofferReady: false),
        _ => daily(),
      };
      await pump(tester, const DailyRewardsTab());
      expect(find.byKey(DailyRewardsTab.extraCofferKey), findsNothing);
      expect(find.byKey(DailyRewardsTab.adKey), findsNothing);
      expect(find.text(arStrings.dailyCofferClaim(20)), findsOneWidget);
    });
  });

  testWidgets('a swap sits under the contracts: pick one, then the ad', (
    tester,
  ) async {
    backend.responders['economy'] = (body) => switch (body['action']) {
      'capabilities' => caps(),
      'extra_claim' => {'claimId': 'e2', 'state': 'pending', 'kind': 'swap'},
      _ => extras(),
    };
    final contracts = CouncilContracts.fromJson({
      'enabled': true,
      'day': '2026-09-26',
      'contracts': [
        {
          'slot': 0,
          'code': 'finish_1',
          'metric': 'finish',
          'target': 1,
          'claimed': true,
        },
        {'slot': 1, 'code': 'win_1', 'metric': 'win', 'target': 1},
        {'slot': 2, 'code': 'host_1', 'metric': 'host', 'target': 1},
      ],
    });
    await pump(tester, ContractSwapOffer(contracts: contracts));
    expect(find.text(arStrings.contractSwapAd), findsOneWidget);
    await tester.tap(find.byKey(ContractSwapOffer.actionKey));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ContractSwapOffer.slotKey(0)),
      findsNothing,
      reason: 'a claimed contract is not offered',
    );
    await tester.tap(find.byKey(ContractSwapOffer.slotKey(2)));
    await tester.pump();
    await tester.pump();
    expect(
      backend.calls.where((c) => c.body['action'] == 'extra_claim').single.body,
      {'action': 'extra_claim', 'day': '2026-09-26', 'kind': 'swap', 'slot': 2},
    );
    expect(ads.shown.single, ('x1:e2', RewardedPlacement.extra));
    await tester.pump(const Duration(seconds: 100));
  });

  test('the flow never runs two ads at once', () {
    const state = AdRewardFlowState(
      phases: {AdReward.dailyAd: AdRewardPhase.verifying},
    );
    expect(state.busy, isTrue);
    expect(
      const AdRewardFlowState(
        phases: {AdReward.extraSpin: AdRewardPhase.late},
      ).busy,
      isFalse,
      reason: 'a late reward never blocks another offer',
    );
  });

  testWidgets('a build without a banner unit never asks the server', (
    tester,
  ) async {
    backend.responders['economy'] = (body) => caps();
    await pump(tester, const WaitingBanner());
    expect(find.byKey(WaitingBanner.slotKey), findsNothing);
    expect(backend.called('economy'), isFalse);
  });
}
