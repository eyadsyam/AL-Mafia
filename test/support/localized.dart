import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';

/// Wraps [home] in the same localisation and theme setup the real app uses.
///
/// Widget tests that pump a bare `MaterialApp` get a null `AppLocalizations`,
/// and every screen that reads its copy from the l10n layer then trips an
/// assertion. Rather than repeat the delegate list in each test, they all go
/// through here — which also means a test cannot accidentally exercise a
/// different locale or a different theme from the one that ships.
///
/// [locale] defaults to Arabic because Arabic is the product's primary language
/// (FR-034); pass `Locale('en')` to check the English strings.
Widget localizedApp(
  Widget home, {
  Locale locale = const Locale('ar'),
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: MafiaTheme.dark,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}

/// The Arabic strings, for tests that need to assert on copy without
/// hardcoding it. Using this instead of a literal means a translation change
/// updates the test with the app.
AppLocalizations get arStrings => lookupAppLocalizations(const Locale('ar'));

/// The English strings.
AppLocalizations get enStrings => lookupAppLocalizations(const Locale('en'));
