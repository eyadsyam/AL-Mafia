import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/platform/links/external_link.dart';
import 'package:mafia_master/platform/monetization/web_ad_rules.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/web_ads.dart';
import 'package:mafia_master/ui/economy/web_banner_controller.dart';
import 'package:mafia_master/ui/social/invite_privacy.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';

class FakeBannerHost implements WebBannerHost {
  final shows = <({String client, String slot, Rect rect})>[];
  var hides = 0;
  var visible = false;
  void Function(bool filled)? _onFilled;

  @override
  void show(
    String client,
    String slot,
    Rect rect,
    void Function(bool filled) onFilled,
  ) {
    shows.add((client: client, slot: slot, rect: rect));
    visible = true;
    _onFilled = onFilled;
  }

  @override
  void hide() {
    hides++;
    visible = false;
    _onFilled = null;
  }

  /// What the page's MutationObserver does on `data-ad-status`.
  void fill(bool filled) => _onFilled?.call(filled);
}

void main() {
  test('an H5 no-fill or blocked request falls back to house', () async {
    const rules = WebAdRules(enabled: true, provider: 'adsense');
    expect(
      await needsHouseInterstitial(
        rules,
        WebAdMoment.afterMatch,
        (_, _, _) async => false,
      ),
      isTrue,
    );
    expect(
      await needsHouseInterstitial(
        rules,
        WebAdMoment.afterMatch,
        (_, _, _) async => true,
      ),
      isFalse,
    );
    expect(
      await needsHouseInterstitial(
        rules,
        WebAdMoment.afterMatch,
        (_, _, _) async => throw StateError('blocked'),
      ),
      isTrue,
    );
  });

  test('a house provider never waits on Google', () async {
    var asked = false;
    expect(
      await needsHouseInterstitial(
        const WebAdRules(enabled: true),
        WebAdMoment.afterMatch,
        (_, _, _) async {
          asked = true;
          return true;
        },
      ),
      isTrue,
    );
    expect(asked, isFalse);
  });

  testWidgets('the Google attempt is awaited, then times out into house', (
    tester,
  ) async {
    final late = Completer<bool>();
    bool? answer;
    unawaited(
      needsHouseInterstitial(
        const WebAdRules(enabled: true, provider: 'adsense'),
        WebAdMoment.afterMatch,
        (_, _, _) => late.future,
        timeout: const Duration(seconds: 3),
      ).then((v) => answer = v),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(answer, isNull, reason: 'waits for Google, no house flash');
    await tester.pump(const Duration(seconds: 2));
    expect(answer, isTrue, reason: 'timeout shows house');
    late.complete(true); // late fill: nothing is listening, nothing stacks
    await tester.pump();
    expect(answer, isTrue);
  });

  Widget scope({
    required FakeBannerHost host,
    Widget? home,
    bool private = false,
    bool adFree = false,
    bool breakActive = false,
    String buildSlot = '1234567890',
    String serverSlot = '',
    String provider = 'adsense',
  }) => ProviderScope(
    overrides: [
      webAdsPlatformProvider.overrideWithValue(true),
      webBannerSlotProvider.overrideWithValue(buildSlot),
      webBannerHostProvider.overrideWithValue(host),
      externalLinkOpenerProvider.overrideWithValue((_) => true),
      privateMomentProvider.overrideWith((_) => private),
      webBreakActiveProvider.overrideWith((_) => breakActive),
      economyCapabilitiesProvider.overrideWith(
        (_) async => EconomyCapabilities(
          adFree: adFree,
          webAds: WebAdRules(
            enabled: true,
            provider: provider,
            bannerSlot: serverSlot,
          ),
        ),
      ),
    ],
    child: MaterialApp(
      theme: MafiaTheme.dark,
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home ?? const Scaffold(bottomNavigationBar: WebAdBanner()),
    ),
  );

  testWidgets('Google no fill keeps the house CTA in the reserved slot', (
    tester,
  ) async {
    final host = FakeBannerHost();
    await tester.pumpWidget(scope(host: host));
    await tester.pumpAndSettle();
    expect(host.shows, isNotEmpty);
    final shown = host.shows.last;
    expect(shown.client, startsWith('ca-pub-'));
    expect(shown.slot, '1234567890');
    expect(shown.rect.height, WebAdTokens.bannerHeight);
    host.fill(false);
    await tester.pump();
    expect(find.byKey(WebAdBanner.slotKey), findsOneWidget);
    expect(find.byKey(WebAdBanner.appCtaKey), findsOneWidget);
    expect(find.text('نزّل التطبيق — إعلانات أقل'), findsOneWidget);
  });

  testWidgets('a late Google fill switches the house art off', (tester) async {
    final host = FakeBannerHost();
    await tester.pumpWidget(scope(host: host));
    await tester.pumpAndSettle();
    expect(find.byKey(WebAdBanner.appCtaKey), findsOneWidget);
    host.fill(true);
    await tester.pump();
    expect(find.byKey(WebAdBanner.slotKey), findsOneWidget);
    expect(find.byKey(WebAdBanner.appCtaKey), findsNothing);
    host.fill(false);
    await tester.pump();
    expect(find.byKey(WebAdBanner.appCtaKey), findsOneWidget);
  });

  testWidgets('a slot from the server wins over the build-time slot', (
    tester,
  ) async {
    final host = FakeBannerHost();
    await tester.pumpWidget(scope(host: host, serverSlot: '9876543210'));
    await tester.pumpAndSettle();
    expect(host.shows.last.slot, '9876543210');
  });

  testWidgets('no slot anywhere means no Google request, house only', (
    tester,
  ) async {
    final host = FakeBannerHost();
    await tester.pumpWidget(scope(host: host, buildSlot: ''));
    await tester.pumpAndSettle();
    expect(host.shows, isEmpty);
    expect(find.byKey(WebAdBanner.appCtaKey), findsOneWidget);
  });

  testWidgets('house provider never claims the Google overlay', (tester) async {
    final host = FakeBannerHost();
    await tester.pumpWidget(scope(host: host, provider: 'house'));
    await tester.pumpAndSettle();
    expect(host.shows, isEmpty);
    expect(find.byKey(WebAdBanner.appCtaKey), findsOneWidget);
  });

  testWidgets('private phase, break and Quiet Pass have no banner', (
    tester,
  ) async {
    final host = FakeBannerHost();
    await tester.pumpWidget(scope(host: host, private: true));
    await tester.pumpAndSettle();
    expect(find.byKey(WebAdBanner.slotKey), findsNothing);
    await tester.pumpWidget(scope(host: host, breakActive: true));
    await tester.pumpAndSettle();
    expect(find.byKey(WebAdBanner.slotKey), findsNothing);
    await tester.pumpWidget(scope(host: host, adFree: true));
    await tester.pumpAndSettle();
    expect(find.byKey(WebAdBanner.slotKey), findsNothing);
    expect(host.shows, isEmpty);
  });

  testWidgets('a screen over a banner takes the host and gives it back', (
    tester,
  ) async {
    final host = FakeBannerHost();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webAdsPlatformProvider.overrideWithValue(true),
          webBannerSlotProvider.overrideWithValue('1234567890'),
          webBannerHostProvider.overrideWithValue(host),
          externalLinkOpenerProvider.overrideWithValue((_) => true),
          privateMomentProvider.overrideWith((_) => false),
          webBreakActiveProvider.overrideWith((_) => false),
          economyCapabilitiesProvider.overrideWith(
            (_) async => const EconomyCapabilities(
              webAds: WebAdRules(enabled: true, provider: 'adsense'),
            ),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: MafiaTheme.dark,
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Text('home'),
            bottomNavigationBar: WebAdBanner(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('home')),
    );
    final controller = container.read(webBannerControllerProvider);
    expect(controller.claimCount, 1);
    host.fill(true);
    await tester.pump();
    expect(find.byKey(WebAdBanner.appCtaKey), findsNothing);

    // Settings opens over Home: Home must let go of the overlay.
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Text('settings'),
            bottomNavigationBar: WebAdBanner(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.claimCount, 1, reason: 'only the top banner claims');
    host.fill(true);
    await tester.pump();

    // Settings closes: Home owns the overlay again and is told it is filled.
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(controller.claimCount, 1);
    expect(host.visible, isTrue, reason: 'Home owns the overlay again');
    host.fill(true);
    await tester.pump();
    expect(find.byKey(WebAdBanner.appCtaKey), findsNothing);
  });

  test('the newest claim owns the host and the one beneath gets it back', () {
    final host = FakeBannerHost();
    final controller = WebBannerController(host);
    final filled = <String, bool>{};
    WebBannerClaim claim(String name, Rect rect) => WebBannerClaim(
      client: 'ca-pub-1234567890123456',
      slot: '1234567890',
      rect: () => rect,
      onFilled: (f) => filled[name] = f,
    );
    const homeRect = Rect.fromLTWH(0, 700, 400, 90);
    const settingsRect = Rect.fromLTWH(0, 600, 400, 90);
    final home = claim('home', homeRect);
    final settings = claim('settings', settingsRect);
    controller.claim(home);
    controller.sync();
    expect(host.shows.last.rect, homeRect);
    controller.claim(settings);
    controller.sync();
    expect(host.shows.last.rect, settingsRect);
    expect(filled['home'], isFalse, reason: 'beneath falls back to house art');
    host.fill(true);
    expect(filled['settings'], isTrue);
    controller.release(settings);
    controller.sync();
    expect(host.shows.last.rect, homeRect, reason: 'restored, not hidden');
    expect(host.hides, 0);
    host.fill(true);
    expect(filled['home'], isTrue);
    controller.release(home);
    controller.sync();
    expect(host.hides, 1);
    controller.dispose();
  });

  testWidgets('house interstitial closes after the token countdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MafiaTheme.dark,
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HouseWebInterstitial(moment: WebAdMoment.afterMatch),
      ),
    );
    expect(find.text('نزّل التطبيق — إعلانات أقل'), findsOneWidget);
    final close = tester.widget<TextButton>(
      find.byKey(HouseWebInterstitial.closeKey),
    );
    expect(close.onPressed, isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester
          .widget<TextButton>(find.byKey(HouseWebInterstitial.closeKey))
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<TextButton>(find.byKey(HouseWebInterstitial.closeKey))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('the hold shows no creative', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MafiaTheme.dark,
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WebAdHold(),
      ),
    );
    expect(find.byKey(WebAdHold.holdKey), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Text), findsNothing);
  });
}
