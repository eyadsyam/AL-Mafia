// Ads v3 (phase 110): every automatic-ad rule, pure policy plus the
// coordinator with a fake ad unit. No SDK, no network.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/monetization/interstitial_ads.dart';
import 'package:mafia_master/platform/monetization/interstitial_policy.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/interstitial_coordinator.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _second = 1000;
const _minute = 60 * _second;

const _all = InterstitialRules(
  enabled: true,
  preMatch: true,
  passAndPlay: true,
  session: true,
  maxPerDay: AdTokens.fullScreenMaxPerDay,
  gap: AdTokens.fullScreenMinGap,
  afterReward: Duration(minutes: 3),
  graceMatches: 1,
);

void main() {
  final noon = DateTime.utc(2026, 9, 27, 12).millisecondsSinceEpoch;

  InterstitialLedger played(int matches) {
    var ledger = InterstitialLedger.empty;
    for (var i = 0; i < matches; i++) {
      ledger = ledger.matchCompleted('m$i', noon - 3 * 60 * _minute);
    }
    return ledger;
  }

  InterstitialVerdict decide(
    AdPlacement placement, {
    InterstitialLedger? ledger,
    InterstitialRules rules = _all,
    int? now,
    bool adFree = false,
    bool loaded = true,
    bool consent = true,
    bool firstOfLaunch = false,
    bool gameplay = false,
    int menuMs = 0,
    ResultExit exit = ResultExit.homeAfterCompleted,
  }) => decideInterstitial(
    rules: rules,
    ledger: ledger ?? played(3),
    nowMs: now ?? noon,
    placement: placement,
    exit: exit,
    adFree: adFree,
    loaded: loaded,
    canRequestAds: consent,
    firstMatchOfLaunch: firstOfLaunch,
    gameplay: gameplay,
    menuMs: menuMs,
  );

  const fiveMinutes = 5 * _minute;

  group('placements', () {
    test('each is shown when every rule allows it', () {
      for (final p in AdPlacement.values) {
        if (p == AdPlacement.passAndPlayDeal) continue;
        expect(
          decide(p, menuMs: fiveMinutes),
          InterstitialVerdict.show,
          reason: '$p',
        );
      }
    });

    test('P6: never before the deal in «القعدة», whatever the rules say', () {
      expect(decide(AdPlacement.passAndPlayDeal, menuMs: fiveMinutes), InterstitialVerdict.off);
      expect(
        decide(AdPlacement.passAndPlayDeal, ledger: played(50)),
        InterstitialVerdict.off,
      );
    });

    test('missing config is off, and each switch is independent', () {
      final none = InterstitialRules.fromJson(const {});
      for (final p in AdPlacement.values) {
        expect(decide(p, rules: none, menuMs: fiveMinutes), InterstitialVerdict.off);
      }
      final onlyPre = InterstitialRules.fromJson(const {'preMatch': true});
      expect(decide(AdPlacement.preMatch, rules: onlyPre), InterstitialVerdict.show);
      expect(decide(AdPlacement.postMatch, rules: onlyPre), InterstitialVerdict.off);
      expect(
        decide(AdPlacement.passAndPlayDeal, rules: onlyPre),
        InterstitialVerdict.off,
      );
      expect(
        decide(AdPlacement.session, rules: onlyPre, menuMs: fiveMinutes),
        InterstitialVerdict.off,
      );
    });
  });

  group('first match', () {
    test('a brand-new player sees none before or after their first match', () {
      final brandNew = played(0);
      expect(
        decide(AdPlacement.preMatch, ledger: brandNew),
        InterstitialVerdict.grace,
      );
      expect(
        decide(AdPlacement.session, ledger: brandNew, menuMs: fiveMinutes),
        InterstitialVerdict.grace,
      );
      final afterFirst = played(1);
      expect(
        decide(AdPlacement.postMatch, ledger: afterFirst),
        InterstitialVerdict.grace,
      );
      expect(
        decide(AdPlacement.passAndPlayResult, ledger: afterFirst),
        InterstitialVerdict.grace,
      );
      // From the second match on, before and after.
      expect(decide(AdPlacement.preMatch, ledger: afterFirst), InterstitialVerdict.show);
      expect(decide(AdPlacement.postMatch, ledger: played(2)), InterstitialVerdict.show);
    });

    test('the first match after a launch skips the pre-match ads', () {
      expect(
        decide(AdPlacement.preMatch, firstOfLaunch: true),
        InterstitialVerdict.firstAfterLaunch,
      );
      // After-match placements are unaffected.
      expect(
        decide(AdPlacement.postMatch, firstOfLaunch: true),
        InterstitialVerdict.show,
      );
    });
  });

  group('global pacing', () {
    test('at least 90 s between any two full-screen ads', () {
      final ledger = played(3).shown(noon);
      for (final p in [AdPlacement.preMatch, AdPlacement.postMatch]) {
        expect(
          decide(p, ledger: ledger, now: noon + 89 * _second),
          InterstitialVerdict.tooSoon,
        );
        expect(
          decide(p, ledger: ledger, now: noon + 90 * _second),
          InterstitialVerdict.show,
        );
      }
    });

    test('no practical daily cap: the safety cap is 40', () {
      var ledger = played(3);
      for (var i = 0; i < 39; i++) {
        ledger = ledger.shown(noon - 10 * 60 * _minute + i * 2 * _minute);
      }
      expect(decide(AdPlacement.postMatch, ledger: ledger), InterstitialVerdict.show);
      ledger = ledger.shown(noon - _minute * 5);
      expect(
        decide(AdPlacement.postMatch, ledger: ledger),
        InterstitialVerdict.dailyCap,
      );
      final tomorrow = DateTime.utc(2026, 9, 28, 1).millisecondsSinceEpoch;
      expect(
        decide(AdPlacement.postMatch, ledger: ledger, now: tomorrow),
        InterstitialVerdict.show,
      );
    });

    test('server numbers: cap never above 40, gap never below 90 s', () {
      final wild = InterstitialRules.fromJson(const {
        'maxPerDay': 500,
        'gapSeconds': 10,
        'sessionAfterSeconds': 30,
        'afterRewardSeconds': 1,
      });
      expect(wild.maxPerDay, AdTokens.fullScreenMaxPerDay);
      expect(wild.gap, AdTokens.fullScreenMinGap);
      expect(wild.sessionAfter, AdTokens.sessionInterstitialAfter);
      expect(wild.afterReward, MafiaTiming.interstitialAfterReward);
      final tight = InterstitialRules.fromJson(const {
        'maxPerDay': 5,
        'gapSeconds': 600,
      });
      expect(tight.maxPerDay, 5);
      expect(tight.gap, const Duration(minutes: 10));
    });

    test('never stacked right after a rewarded ad', () {
      final ledger = played(3).rewarded(noon);
      expect(
        decide(AdPlacement.postMatch, ledger: ledger, now: noon + 2 * _minute),
        InterstitialVerdict.afterReward,
      );
      expect(
        decide(AdPlacement.preMatch, ledger: ledger, now: noon + 3 * _minute),
        InterstitialVerdict.show,
      );
    });

    test('Quiet Pass removes every interstitial', () {
      for (final p in AdPlacement.values) {
        if (p == AdPlacement.passAndPlayDeal) continue; // P6: never shown at all
        expect(
          decide(p, adFree: true, menuMs: fiveMinutes),
          InterstitialVerdict.adFree,
        );
      }
    });

    test('consent is required; no fill never waits', () {
      expect(decide(AdPlacement.preMatch, consent: false), InterstitialVerdict.noConsent);
      expect(decide(AdPlacement.preMatch, loaded: false), InterstitialVerdict.notLoaded);
    });
  });

  group('pass-and-play', () {
    test('never while a match (and so the phone) is in play', () {
      expect(
        decide(AdPlacement.passAndPlayResult, gameplay: true),
        InterstitialVerdict.busy,
      );
      expect(
        decide(AdPlacement.passAndPlayDeal, gameplay: true),
        InterstitialVerdict.off,
        reason: 'P6: the pre-deal placement does not exist',
      );
      expect(adSurfaceOf('/match'), AdSurface.gameplay);
      expect(adSurfaceOf('/online/lobby'), AdSurface.waiting);
    });

    test('the result ad only on the home exit', () {
      expect(
        decide(AdPlacement.passAndPlayResult, exit: ResultExit.back),
        InterstitialVerdict.notThisExit,
      );
    });
  });

  group('session', () {
    test('only after five minutes of menu time', () {
      expect(
        decide(AdPlacement.session, menuMs: fiveMinutes - 1),
        InterstitialVerdict.notDue,
      );
      expect(decide(AdPlacement.session, menuMs: fiveMinutes), InterstitialVerdict.show);
    });

    test('only on a navigation between two menu screens', () {
      expect(sessionNavigation('/', '/history'), isTrue);
      expect(sessionNavigation('/history', '/profile'), isTrue);
      expect(sessionNavigation('/', '/'), isFalse);
      expect(sessionNavigation('/online', '/online/lobby'), isFalse);
      expect(sessionNavigation('/online/lobby', '/'), isFalse);
      expect(sessionNavigation('/match', '/'), isFalse);
      expect(sessionNavigation('/setup/settings', '/match'), isFalse);
      expect(sessionNavigation('/', '/setup/players'), isFalse);
    });

    test('the menu clock runs in the foreground, off gameplay', () {
      var clock = MenuClock.stopped.run(0);
      expect(clock.elapsed(2 * _minute), 2 * _minute);
      clock = clock.pause(2 * _minute); // a match
      expect(clock.elapsed(30 * _minute), 2 * _minute);
      clock = clock.run(30 * _minute);
      expect(clock.elapsed(33 * _minute), 5 * _minute);
      clock = clock.reset(33 * _minute); // a full-screen ad
      expect(clock.elapsed(34 * _minute), _minute);
    });
  });

  group('capabilities', () {
    test('v3 keys are read; an older server keeps them off', () {
      final caps = EconomyCapabilities.fromJson({
        'version': 2,
        'interstitial': {
          'enabled': true,
          'preMatch': true,
          'passAndPlay': false,
          'session': true,
          'sessionAfterSeconds': 600,
          'maxPerDay': 30,
          'gapSeconds': 120,
        },
      });
      expect(caps.interstitial.preMatch, isTrue);
      expect(caps.interstitial.passAndPlay, isFalse);
      expect(caps.interstitial.session, isTrue);
      expect(caps.interstitial.sessionAfter, const Duration(minutes: 10));
      expect(caps.interstitial.maxPerDay, 30);
      final old = EconomyCapabilities.fromJson({
        'version': 2,
        'interstitial': {'enabled': true, 'maxPerDay': 3, 'gapSeconds': 600},
      });
      expect(old.interstitial.preMatch || old.interstitial.session, isFalse);
      expect(old.interstitial.passAndPlay, isFalse);
    });
  });

  group('coordinator', () {
    late _FakeAds ads;
    late _ActiveMatchRepository repository;
    late ProviderContainer container;
    late int now;

    ProviderContainer make({bool adFree = false, InterstitialRules rules = _all}) {
      final caps = EconomyCapabilities(
        adFree: adFree,
        interstitial: rules,
      );
      final c = ProviderContainer(
        overrides: [
          interstitialAdsProvider.overrideWithValue(ads),
          interstitialClockProvider.overrideWithValue(() => now),
          economyCapabilitiesProvider.overrideWith((ref) async => caps),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
          voiceControllerProvider.overrideWithValue(null),
          matchRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      now = noon;
      ads = _FakeAds();
      repository = _ActiveMatchRepository();
      SharedPreferences.setMockInitialValues({
        'interstitial_ledger_v1':
            '{"completedMatches":3,"highWaterMs":${noon - 60 * _minute}}',
      });
    });

    Future<InterstitialCoordinator> ready({bool adFree = false}) async {
      container = make(adFree: adFree);
      await container.read(economyCapabilitiesProvider.future);
      return container.read(interstitialCoordinatorProvider);
    }

    test('pre-match: skipped the first time after launch, then shown', () async {
      final c = await ready();
      expect(await c.beforeOnlineMatch(), InterstitialVerdict.firstAfterLaunch);
      expect(ads.shows, 0);
      now += 2 * _minute;
      expect(await c.beforeOnlineMatch(), InterstitialVerdict.show);
      expect(ads.shows, 1);
      // Straight into another: the 90 s gap holds.
      now += 30 * _second;
      expect(await c.beforeOnlineMatch(), InterstitialVerdict.tooSoon);
    });

    test('an app-open ad counts toward the gap', () async {
      final c = await ready();
      await c.beforeOnlineMatch(); // first of launch
      await c.fullScreenShown(); // the app-open ad
      now += 60 * _second;
      expect(await c.beforeOnlineMatch(), InterstitialVerdict.tooSoon);
      expect(await c.beforeDeal(), InterstitialVerdict.off, reason: 'P6');
    });

    test('a rematch that showed the ad pays for the next Create', () async {
      final c = await ready();
      await c.beforeOnlineMatch(); // first of launch
      now += 5 * _minute;
      expect(await c.beforeRematch(), InterstitialVerdict.show);
      now += 5 * _minute;
      expect(await c.beforeOnlineMatch(), InterstitialVerdict.notDue);
      expect(ads.shows, 1);
    });

    test('after a rewarded ad, no interstitial is stacked', () async {
      final c = await ready();
      await c.beforeOnlineMatch();
      await c.rewardedShown();
      now += _minute;
      expect(
        await c.leftResult(ResultExit.homeAfterCompleted),
        InterstitialVerdict.afterReward,
      );
    });

    test('no consent, no ad', () async {
      ads.consent = false;
      final c = await ready();
      expect(
        await c.leftResult(ResultExit.homeAfterCompleted),
        InterstitialVerdict.noConsent,
      );
      expect(ads.shows, 0);
    });

    test('Quiet Pass owners get none', () async {
      final c = await ready(adFree: true);
      expect(
        await c.leftResult(ResultExit.homeAfterCompleted),
        InterstitialVerdict.adFree,
      );
      expect(ads.preloads, 0);
    });

    test('session: five menu minutes, then only before a forward menu move', () async {
      final c = await ready();
      c.foreground(true);
      c.navigated('/', '/history');
      now += 4 * _minute;
      expect(await c.beforeMenuNavigation('/profile'), InterstitialVerdict.notDue);
      c.navigated('/history', '/');
      // A match pauses the clock: ten minutes in play add nothing.
      c.navigated('/', '/match');
      now += 10 * _minute;
      c.navigated('/match', '/');
      now += 30 * _second;
      expect(await c.beforeMenuNavigation('/online/lobby'), InterstitialVerdict.notThisExit);
      now += 31 * _second;
      expect(await c.beforeMenuNavigation('/profile'), InterstitialVerdict.show);
      expect(ads.shows, 1);
      c.navigated('/', '/profile');
      // The clock starts again after the ad.
      now += _minute * 2;
      expect(await c.beforeMenuNavigation('/'), InterstitialVerdict.notDue);
    });

    test('session: back and pop never show it, however long the menus ran', () async {
      final c = await ready();
      c.foreground(true);
      c.navigated('/', '/history');
      now += 30 * _minute;
      // Router moves — the system back, a back arrow, a pop — only keep the
      // clock; nothing is shown over a screen already on display.
      c.navigated('/history', '/');
      c.navigated('/', '/profile');
      c.navigated('/profile', '/');
      await Future<void>.delayed(Duration.zero);
      expect(ads.shows, 0);
      // The next forward tap is when it is due, once.
      expect(await c.beforeMenuNavigation('/history'), InterstitialVerdict.show);
      c.navigated('/', '/history');
      expect(await c.beforeMenuNavigation('/history/1'), isNot(InterstitialVerdict.show));
      expect(ads.shows, 1);
    });

    test('session: none while a pass-and-play match is paused', () async {
      repository.active = true;
      final c = await ready();
      c.foreground(true);
      now += 30 * _minute;
      expect(await c.beforeMenuNavigation('/history'), InterstitialVerdict.busy);
      expect(ads.shows, 0);
      repository.active = false;
      expect(await c.beforeMenuNavigation('/history'), InterstitialVerdict.show);
    });

    test('pass-and-play result: counted, then shown after Home', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await ready();
      // A brand-new install: the first finished match gets none.
      expect(
        await c.leftPassAndPlayResult('local-1'),
        InterstitialVerdict.grace,
      );
      now += 20 * _minute;
      expect(
        await c.leftPassAndPlayResult('local-2'),
        InterstitialVerdict.show,
      );
      // P6: at most one pass-and-play result-exit per app session.
      now += 60 * _minute;
      expect(
        await c.leftPassAndPlayResult('local-3'),
        InterstitialVerdict.notDue,
      );
      expect(ads.shows, 1);
    });
  });
}

class _FakeAds implements InterstitialAds {
  int shows = 0;
  int preloads = 0;
  bool consent = true;

  @override
  bool get configured => true;

  @override
  bool get ready => true;

  @override
  Future<void> preload() async => preloads++;

  @override
  Future<bool> showIfReady() async {
    shows++;
    return true;
  }

  @override
  Future<bool> canRequestAds() async => consent;

  @override
  void dispose() {}
}

/// Nothing stored, except that [active] says a pass-and-play match is paused.
class _ActiveMatchRepository extends MemoryMatchRepository {
  _ActiveMatchRepository() : super(MemoryMatchStore());
  bool active = false;

  @override
  Future<Match?> loadActiveMatch() async => active ? _PausedMatch() : null;
}

class _PausedMatch implements Match {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
