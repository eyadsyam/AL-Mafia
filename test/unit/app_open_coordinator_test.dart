import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/monetization/ad_formats.dart';
import 'package:mafia_master/platform/monetization/app_open_policy.dart';
import 'package:mafia_master/platform/monetization/interstitial_policy.dart';
import 'package:mafia_master/ui/economy/app_open_gate.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app-open ad's coordinator: it decides first, loads only inside its
/// budget, mutes the game while the ad plays, never stacks two attempts, and
/// never shows to an ad-free account, in a room, or before onboarding.
class _Ads implements AppOpenAds {
  _Ads({this.configured = true, this.never = false});

  @override
  final bool configured;
  final bool never;
  bool consent = true;
  int loads = 0;
  int shows = 0;
  int discards = 0;
  bool? mutedDuringShow;
  AudioDirector? audio;

  @override
  Future<bool> canRequestAds() async => consent;

  @override
  Future<int?> load(Duration timeout, {bool resume = false}) {
    loads++;
    if (never) return Completer<int?>().future;
    return Future.value(_now);
  }

  @override
  Future<bool> show() async {
    shows++;
    mutedDuringShow = audio?.muted;
    return true;
  }

  @override
  void discard() => discards++;
}

final _now = DateTime.utc(2026, 10, 29, 20).millisecondsSinceEpoch;

void main() {
  late _Ads ads;
  late AudioDirector audio;

  ProviderContainer container({
    EconomyCapabilities caps = const EconomyCapabilities(
      ads: AdsCapabilities(appOpen: AppOpenRules.on),
      interstitial: InterstitialRules.pacingDefaults,
    ),
    bool known = true,
    _Ads? with_,
    int Function()? clock,
  }) {
    final ledger = AppOpenLedger.empty
        .launched(_now - const Duration(days: 2).inMilliseconds)
        .known(enabled: known, adFree: false);
    SharedPreferences.setMockInitialValues({
      'app_open_ledger_v1': jsonEncode(ledger.toJson()),
    });
    ads = with_ ?? _Ads();
    audio = AudioDirector();
    ads.audio = audio;
    final c = ProviderContainer(
      overrides: [
        appOpenAdsProvider.overrideWithValue(ads),
        appOpenClockProvider.overrideWithValue(clock ?? () => _now),
        audioDirectorProvider.overrideWithValue(audio),
        economyCapabilitiesProvider.overrideWith((ref) async => caps),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<AppOpenVerdict> attempt(
    ProviderContainer c, {
    bool busy = false,
    bool onboarded = true,
  }) => c
      .read(appOpenCoordinatorProvider)
      .attempt(
        trigger: AppOpenTrigger.coldStart,
        busy: () async => busy,
        onboarded: () async => onboarded,
      );

  test('all clear: one ad, the game muted while it plays, then back', () async {
    final c = container();
    expect(await attempt(c), AppOpenVerdict.show);
    expect(ads.shows, 1);
    expect(ads.mutedDuringShow, isTrue);
    expect(audio.muted, isFalse, reason: 'the sound is given back');
  });

  test('a player already muted stays muted after the ad', () async {
    final c = container();
    audio.muted = true;
    await attempt(c);
    expect(audio.muted, isTrue);
  });

  test('no ad unit built in: off, nothing loaded', () async {
    final c = container(with_: _Ads(configured: false));
    expect(await attempt(c), AppOpenVerdict.off);
    expect(ads.loads, 0);
  });

  test('an ad-free account never loads one', () async {
    final c = container(
      caps: const EconomyCapabilities(
        ads: AdsCapabilities(appOpen: AppOpenRules.on),
        adFree: true,
      ),
    );
    expect(await attempt(c), isNot(AppOpenVerdict.show));
    expect(ads.loads, 0);
    expect(ads.shows, 0);
  });

  test('busy from the start (a room, a match) loads nothing', () async {
    final c = container();
    expect(await attempt(c, busy: true), AppOpenVerdict.busy);
    expect(ads.loads, 0);
  });

  test('before onboarding there is no ad', () async {
    final c = container();
    expect(await attempt(c, onboarded: false), isNot(AppOpenVerdict.show));
    expect(ads.shows, 0);
  });

  test('without ad consent nothing is requested', () async {
    final c = container();
    ads.consent = false;
    expect(await attempt(c), isNot(AppOpenVerdict.show));
    expect(ads.loads, 0);
  });

  test('a load that never answers gives up inside the budget', () async {
    final c = container(with_: _Ads(never: true));
    final verdict = await attempt(
      c,
    ).timeout(AdTokens.appOpenLoadTimeout + const Duration(seconds: 2));
    expect(verdict, AppOpenVerdict.notLoaded);
    expect(ads.shows, 0);
    expect(ads.discards, greaterThan(0));
  });

  test('a second attempt while one runs is refused', () async {
    final c = container(with_: _Ads(never: true));
    final first = attempt(c);
    expect(await attempt(c), AppOpenVerdict.notLoaded);
    await first.timeout(
      AdTokens.appOpenLoadTimeout + const Duration(seconds: 2),
    );
  });

  test('a feature the server switched off costs no load', () async {
    final c = container(known: false);
    expect(await attempt(c), isNot(AppOpenVerdict.show));
    expect(ads.loads, 0);
  });

  test('a return can show only after long enough away', () async {
    var clock = _now;
    final c = container(clock: () => clock);
    final coordinator = c.read(appOpenCoordinatorProvider);
    await coordinator.backgrounded();
    expect(await coordinator.mightShowOnResume(), isFalse);
    clock += AdTokens.appOpenResumeAfter.inMilliseconds;
    expect(await coordinator.mightShowOnResume(), isTrue);
  });

  test('an ad-free answer is remembered: no launch screen for it', () async {
    final c = container();
    final coordinator = c.read(appOpenCoordinatorProvider);
    await coordinator.remember(
      const EconomyCapabilities(
        ads: AdsCapabilities(appOpen: AppOpenRules.on),
        creator: true,
      ),
    );
    await coordinator.backgrounded();
    expect(await coordinator.mightShowOnResume(), isFalse);
  });

  test('a failed read changes nothing remembered', () async {
    final c = container();
    final coordinator = c.read(appOpenCoordinatorProvider);
    await coordinator.remember(EconomyCapabilities.unreachable);
    final raw = (await SharedPreferences.getInstance()).getString(
      'app_open_ledger_v1',
    );
    expect(
      AppOpenLedger.fromJson(
        jsonDecode(raw!) as Map<String, dynamic>,
      ).knownEnabled,
      isTrue,
    );
  });

  test('no app-open ad over a match, a room or setup', () {
    for (final path in [
      '/match',
      '/match/night',
      '/online/lobby/X',
      '/setup',
    ]) {
      expect(appOpenBlockedPath(path), isTrue, reason: path);
    }
    for (final path in ['/', '/store', '/online', '/settings']) {
      expect(appOpenBlockedPath(path), isFalse, reason: path);
    }
  });
}
