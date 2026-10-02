import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/monetization/rewarded_ads.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/rewarded_reward_button.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

class _FakeAds implements RewardedAds {
  _FakeAds(this.outcome);
  RewardedAdOutcome outcome;
  int shows = 0;
  bool? audioMutedDuringShow;
  AudioDirector? audio;

  @override
  bool get configured => true;
  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> initialize() async => initializations++;
  int initializations = 0;
  bool privacyRequired = false;
  @override
  Future<bool> checkPrivacyOptions() async => privacyRequired;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
    RewardedPlacement placement = RewardedPlacement.matchLegacy,
  }) async {
    shows++;
    audioMutedDuringShow = audio?.muted;
    return outcome;
  }

  @override
  void dispose() {}
}

void main() {
  late FakeBackend backend;
  late _FakeAds ads;
  late AudioDirector audio;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          rewardedAdsProvider.overrideWithValue(ads),
          audioDirectorProvider.overrideWithValue(audio),
        ],
        child: localizedApp(
          const Scaffold(body: RewardedRewardButton(roomId: 'room-1')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> pollOut(WidgetTester tester) async {
    for (var i = 0; i < 7; i++) {
      await tester.pump(MafiaTiming.adRewardPoll);
    }
  }

  OutlinedButton button(WidgetTester tester) =>
      tester.widget<OutlinedButton>(find.byKey(RewardedRewardButton.actionKey));

  setUp(() {
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'result'),
      players: roster(5),
    );
    audio = AudioDirector();
    ads = _FakeAds(RewardedAdOutcome.dismissed)..audio = audio;
  });

  testWidgets('a claim left pending by a closed ad can be tried again', (
    tester,
  ) async {
    backend.responses['economy'] = {'state': 'pending', 'amount': 100};
    await pump(tester);
    expect(button(tester).onPressed, isNull, reason: 'checking first');

    await pollOut(tester);

    expect(
      button(tester).onPressed,
      isNotNull,
      reason: 'a pending claim is not a reward on its way forever',
    );
  });

  testWidgets('a reward verified while away shows on reopening', (
    tester,
  ) async {
    backend.responses['economy'] = {'state': 'pending', 'amount': 100};
    await pump(tester);
    backend.responses['economy'] = {'state': 'awarded', 'amount': 100};
    await pollOut(tester);

    expect(button(tester).onPressed, isNull);
    expect(find.text(arStrings.adRewardUsed), findsOneWidget);
  });

  testWidgets('the game is silent during the ad and restored after', (
    tester,
  ) async {
    backend.responses['economy'] = {
      'state': 'available',
      'amount': 100,
      'claimId': 'c1',
    };
    await pump(tester);
    expect(audio.muted, isFalse);

    await tester.tap(find.byKey(RewardedRewardButton.actionKey));
    await tester.pump();
    await tester.pump();

    expect(ads.shows, 1);
    expect(ads.audioMutedDuringShow, isTrue);
    expect(audio.muted, isFalse, reason: 'put back as it was');
    expect(button(tester).onPressed, isNotNull, reason: 'closed early: retry');
  });

  testWidgets('settings checks privacy status without starting the ad SDK', (
    tester,
  ) async {
    ads.privacyRequired = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rewardedAdsProvider.overrideWithValue(ads)],
        child: localizedApp(const Scaffold(body: AdPrivacyButton())),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(arStrings.privacyChoices), findsOneWidget);
    expect(ads.initializations, 0, reason: 'no consent form from Settings');
  });
}
