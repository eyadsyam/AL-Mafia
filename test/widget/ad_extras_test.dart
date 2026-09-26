import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/monetization/rewarded_ads.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/economy/ad_extras.dart';
import 'package:mafia_master/ui/economy/waiting_banner.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

class _Ads implements RewardedAds {
  final shown = <(String, RewardedPlacement)>[];
  bool configuredValue = true;
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
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
    RewardedPlacement placement = RewardedPlacement.matchLegacy,
  }) async {
    shown.add((claimId, placement));
    return RewardedAdOutcome.earned;
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
  'adFree': false,
  'interstitial': {'enabled': false},
  'products': const [],
  'ads': {
    'appOpen': {'enabled': false},
    'banner': {'enabled': true},
    'extras': {'spin': spin, 'coffer': coffer, 'swap': swap},
  },
};

Map<String, dynamic> extras({
  bool spinReady = true,
  String spinState = 'available',
  int? spinAmount,
  bool cofferReady = true,
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
    'prizes': [
      {'slot': 0, 'coins': 10, 'weight': 40, 'percent': '40.00'},
      {'slot': 1, 'coins': 20, 'weight': 30, 'percent': '30.00'},
      {'slot': 2, 'coins': 35, 'weight': 20, 'percent': '20.00'},
      {'slot': 3, 'coins': 60, 'weight': 8, 'percent': '8.00'},
      {'slot': 4, 'coins': 100, 'weight': 2, 'percent': '2.00'},
    ],
  },
  'coffer': {
    'enabled': true,
    'ready': cofferReady,
    'state': 'available',
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

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          rewardedAdsProvider.overrideWithValue(ads),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
        ],
        child: localizedApp(
          Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('every extra shows its exact terms; odds are published', (
    tester,
  ) async {
    backend.responders['economy'] = (body) => switch (body['action']) {
      'capabilities' => caps(),
      _ => extras(),
    };
    await pump(tester, const AdExtrasPanel());
    expect(find.text(arStrings.adExtrasTitle), findsOneWidget);
    expect(find.byKey(AdExtrasPanel.spinKey), findsOneWidget);
    expect(find.text(arStrings.adExtraCofferAction(20)), findsWidgets);
    expect(find.byKey(AdExtrasPanel.swapKey), findsOneWidget);
    expect(
      find.textContaining(arStrings.dailyWheelPercent('2')),
      findsOneWidget,
      reason: 'the 2% prize is named beside the action',
    );
  });

  testWidgets('the second spin waits for the free one', (tester) async {
    backend.responders['economy'] = (body) => switch (body['action']) {
      'capabilities' => caps(),
      _ => extras(spinReady: false),
    };
    await pump(tester, const AdExtrasPanel());
    final spin = tester.widget<OutlinedButton>(
      find.byKey(AdExtrasPanel.spinKey),
    );
    expect(spin.onPressed, isNull);
    expect(find.text(arStrings.adExtraSpinNotReady), findsOneWidget);
  });

  testWidgets('a spin names the day, uses the x1 claim and the extra unit; '
      'the amount comes from the server', (tester) async {
    var awarded = false;
    backend.responders['economy'] = (body) => switch (body['action']) {
      'capabilities' => caps(),
      'extra_claim' => {'claimId': 'e1', 'state': 'pending', 'kind': 'spin'},
      _ => awarded ? extras(spinState: 'awarded', spinAmount: 35) : extras(),
    };
    await pump(tester, const AdExtrasPanel());
    awarded = true; // AdMob's signed callback lands while the ad plays.
    await tester.tap(find.byKey(AdExtrasPanel.spinKey));
    await tester.pump();
    await tester.pump();
    expect(
      backend.calls.where((c) => c.body['action'] == 'extra_claim').single.body,
      {'action': 'extra_claim', 'day': '2026-09-26', 'kind': 'spin'},
    );
    expect(ads.shown.single, ('x1:e1', RewardedPlacement.extra));
    await tester.pump(MafiaTiming.adRewardPoll);
    await tester.pump();
    expect(find.text(arStrings.adExtraSpinResult(35)), findsWidgets);
    final spin = tester.widget<OutlinedButton>(
      find.byKey(AdExtrasPanel.spinKey),
    );
    expect(spin.onPressed, isNull, reason: 'once a day');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a swap asks which unclaimed contract, then claims that slot', (
    tester,
  ) async {
    backend.responders['economy'] = (body) => switch (body['action']) {
      'capabilities' => caps(),
      'contracts_get' => {
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
        'bonus': {'coins': 30},
      },
      'extra_claim' => {'claimId': 'e2', 'state': 'pending', 'kind': 'swap'},
      _ => extras(),
    };
    await pump(tester, const AdExtrasPanel());
    await tester.tap(find.byKey(AdExtrasPanel.swapKey));
    await tester.pumpAndSettle();
    expect(
      find.byKey(AdExtrasPanel.swapSlotKey(0)),
      findsNothing,
      reason: 'a claimed contract is not offered',
    );
    await tester.tap(find.byKey(AdExtrasPanel.swapSlotKey(2)));
    await tester.pumpAndSettle();
    expect(
      backend.calls.where((c) => c.body['action'] == 'extra_claim').single.body,
      {'action': 'extra_claim', 'day': '2026-09-26', 'kind': 'swap', 'slot': 2},
    );
    expect(ads.shown.single, ('x1:e2', RewardedPlacement.extra));
    await tester.pump(const Duration(seconds: 100));
  });

  testWidgets('switched off (or an old server): nothing at all', (
    tester,
  ) async {
    backend.responders['economy'] = (body) => switch (body['action']) {
      'capabilities' => {'version': 2},
      _ => extras(),
    };
    await pump(tester, const AdExtrasPanel());
    expect(find.text(arStrings.adExtrasTitle), findsNothing);
  });

  testWidgets('no rewarded unit in the build: nothing at all', (tester) async {
    ads.configuredValue = false;
    backend.responders['economy'] = (body) => switch (body['action']) {
      'capabilities' => caps(),
      _ => extras(),
    };
    await pump(tester, const AdExtrasPanel());
    expect(find.text(arStrings.adExtrasTitle), findsNothing);
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
