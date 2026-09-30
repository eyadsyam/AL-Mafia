import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/platform/links/external_link.dart';
import 'package:mafia_master/platform/monetization/web_ad_rules.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/web_ads.dart';
import 'package:mafia_master/ui/social/invite_privacy.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';

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

  Widget banner({
    required Future<bool> Function(String, String) attempt,
    bool private = false,
    bool adFree = false,
    bool breakActive = false,
  }) => ProviderScope(
    overrides: [
      webAdsPlatformProvider.overrideWithValue(true),
      webBannerSlotProvider.overrideWithValue('1234567890'),
      webBannerAttemptProvider.overrideWithValue(attempt),
      externalLinkOpenerProvider.overrideWithValue((_) => true),
      privateMomentProvider.overrideWith((_) => private),
      webBreakActiveProvider.overrideWith((_) => breakActive),
      economyCapabilitiesProvider.overrideWith(
        (_) async => EconomyCapabilities(
          adFree: adFree,
          webAds: const WebAdRules(enabled: true, provider: 'adsense'),
        ),
      ),
    ],
    child: MaterialApp(
      theme: MafiaTheme.dark,
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(bottomNavigationBar: WebAdBanner()),
    ),
  );

  testWidgets('Google no fill paints the house app CTA in the same slot', (
    tester,
  ) async {
    var requested = false;
    await tester.pumpWidget(
      banner(
        attempt: (client, slot) async {
          requested = client.startsWith('ca-pub-') && slot == '1234567890';
          return false;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(requested, isTrue);
    expect(find.byKey(WebAdBanner.slotKey), findsOneWidget);
    expect(find.byKey(WebAdBanner.appCtaKey), findsOneWidget);
    expect(find.text('نزّل التطبيق — إعلانات أقل'), findsOneWidget);
  });

  testWidgets('a Google fill owns the banner slot', (tester) async {
    await tester.pumpWidget(banner(attempt: (_, _) async => true));
    await tester.pumpAndSettle();
    expect(find.byKey(WebAdBanner.slotKey), findsOneWidget);
    expect(find.byKey(WebAdBanner.appCtaKey), findsNothing);
  });

  testWidgets('a blocked Google banner keeps the house CTA', (tester) async {
    await tester.pumpWidget(
      banner(attempt: (_, _) async => throw StateError('blocked')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(WebAdBanner.appCtaKey), findsOneWidget);
  });

  testWidgets('private phase and Quiet Pass have no banner', (tester) async {
    await tester.pumpWidget(
      banner(private: true, attempt: (_, _) async => false),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(WebAdBanner.slotKey), findsNothing);
    await tester.pumpWidget(
      banner(breakActive: true, attempt: (_, _) async => false),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(WebAdBanner.slotKey), findsNothing);
    await tester.pumpWidget(
      banner(adFree: true, attempt: (_, _) async => false),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(WebAdBanner.slotKey), findsNothing);
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
}
