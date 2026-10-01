import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/monetization/full_screen_away.dart';
import 'package:mafia_master/platform/monetization/rewarded_ads.dart';
import 'package:mafia_master/ui/economy/ad_veil.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/fake_backend.dart';

/// An ad whose close the test decides.
class _HeldAd implements RewardedAds {
  final close = Completer<RewardedAdOutcome>();
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
  }) {
    FullScreenAway.adOpened();
    return close.future.whenComplete(FullScreenAway.adClosed);
  }

  @override
  void dispose() {}
}

void main() {
  tearDown(FullScreenAway.reset);

  group('bug 1 · a back press meant for the ad', () {
    test('is swallowed while the ad is up and just after it closes', () {
      var now = 1000000;
      FullScreenAway.clock = () => now;
      expect(FullScreenAway.swallowsBack(), isFalse);
      FullScreenAway.adOpened();
      expect(FullScreenAway.swallowsBack(), isTrue);
      now += 45000; // a long rewarded ad
      FullScreenAway.adClosed();
      now += AdTokens.backAfterAdGrace.inMilliseconds - 1;
      expect(FullScreenAway.swallowsBack(), isTrue);
      now += 2;
      expect(FullScreenAway.swallowsBack(), isFalse);
    });

    test('the app-open "just returned" rule counts from the return', () {
      var now = 1000000;
      FullScreenAway.clock = () => now;
      FullScreenAway.adOpened();
      now += 60000;
      FullScreenAway.adClosed();
      expect(FullScreenAway.awayMs, now, reason: 'not the departure');
      expect(FullScreenAway.adShowing, isFalse);
    });

    testWidgets('an overlay holding its own PopScope (the vault) answers the '
        'navigator first, so back closes it and never the screen below', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final vault = OverlayPortalController();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: OverlayPortal(
              controller: vault,
              overlayChildBuilder: (_) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) vault.hide();
                },
                child: const SizedBox.expand(),
              ),
              child: const Text('lobby'),
            ),
          ),
        ),
      );
      vault.show();
      await tester.pump();
      // What MafiaApp.didPopRoute asks before any screen-level back.
      expect(await navigator.currentState!.maybePop(), isTrue);
      await tester.pump();
      expect(vault.isShowing, isFalse);
      // Nothing on top: the app's own back target decides.
      expect(await navigator.currentState!.maybePop(), isFalse);
    });
  });

  group('bug 5 · the tap is answered at once', () {
    testWidgets('the veil is up while the ad is prepared and down after', (
      tester,
    ) async {
      final ad = _HeldAd();
      final container = ProviderContainer(
        overrides: [
          rewardedAdsProvider.overrideWithValue(ad),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
        ],
      );
      addTearDown(container.dispose);
      final shown = showRewardedWith(
        container.read,
        customData: 'd1:x',
        userId: 'u',
        placement: RewardedPlacement.daily,
      );
      expect(container.read(rewardedAdLoadingProvider), isTrue);
      await tester.pump();
      ad.close.complete(RewardedAdOutcome.earned);
      expect(await shown, RewardedAdOutcome.earned);
      expect(container.read(rewardedAdLoadingProvider), isFalse);
      expect(FullScreenAway.adShowing, isFalse);
    });
  });

  group('bug 4 · one balance, always current', () {
    late FakeBackend backend;
    late ProviderContainer container;
    var balance = 100;

    setUp(() {
      balance = 100;
      backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'result'),
        players: roster(5),
      );
      backend.responders['economy'] = (_) => {'balance': balance};
      container = ProviderContainer(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        ],
      );
    });
    tearDown(() => container.dispose());

    test('a confirmed grant shows at once, then the server\'s number', () async {
      await container.read(walletProvider.notifier).refresh();
      expect(container.read(walletProvider).valueOrNull?.balance, 100);
      balance = 125;
      final settling = container
          .read(walletProvider.notifier)
          .settle(credited: 25);
      expect(
        container.read(walletProvider).valueOrNull?.balance,
        125,
        reason: 'no reopening the vault, no blank header',
      );
      await settling;
      expect(container.read(walletProvider).valueOrNull?.balance, 125);
      expect(backend.calls.last.body['action'], 'summary');
    });

    test('a wallet nobody has read is left unread', () async {
      await container.read(walletProvider.notifier).settle(credited: 25);
      expect(container.read(walletProvider).valueOrNull, isNull);
      expect(backend.called('economy'), isFalse);
    });
  });
}
