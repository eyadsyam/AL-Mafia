import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mafia_master/app/locale_controller.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/ui/screens/setup/profile_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';
import 'package:mafia_master/ui/widgets/language_picker.dart';
import 'package:mafia_master/ui/widgets/settings_kit.dart';
import 'package:mafia_master/ui/widgets/setup_entrance.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'language persists, defaults safely, rejects unsupported values',
    () async {
      expect((await loadSavedLocale()).languageCode, 'ar');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        await container.read(localeProvider.notifier).select('en'),
        isTrue,
      );
      expect((await loadSavedLocale()).languageCode, 'en');
      expect(
        await container.read(localeProvider.notifier).select('xx'),
        isFalse,
      );
      expect(container.read(localeProvider).languageCode, 'en');
      final restarted = ProviderContainer(
        overrides: [
          initialLocaleProvider.overrideWithValue(await loadSavedLocale()),
        ],
      );
      addTearDown(restarted.dispose);
      expect(restarted.read(localeProvider).languageCode, 'en');
    },
  );
  testWidgets('profile preserves input while language and direction change', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: MafiaTheme.dark,
            locale: ref.watch(localeProvider),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Language lives in Settings only; the profile never offers it.
    expect(find.byType(LanguagePicker), findsNothing);
    final name = find.byKey(const ValueKey('profile_name'));
    await tester.enterText(name, 'Eyad');
    final container = ProviderScope.containerOf(tester.element(name));
    await container.read(localeProvider.notifier).select('en');
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(name)), TextDirection.ltr);
    expect(tester.widget<TextField>(name).controller!.text, 'Eyad');
    await container.read(localeProvider.notifier).select('ar');
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(name)), TextDirection.rtl);
    expect(tester.widget<TextField>(name).controller!.text, 'Eyad');
    expect(tester.takeException(), isNull);
  });
  testWidgets('the selected language is gold, not Material green', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: MafiaTheme.dark,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: LanguagePicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The settings kit's track: the lit option is the one on the gold thumb.
    bool lit(Key key) => tester.widget<SettingsSegment>(find.byKey(key)).selected;
    expect(lit(LanguagePicker.arabicKey), isTrue);
    expect(lit(LanguagePicker.englishKey), isFalse);
    final colors = MafiaTheme.dark.extension<MafiaColors>()!;
    final thumb = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == colors.accentGold);
    expect(thumb, isNotEmpty);
  });
  testWidgets('setup entrance honors reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MafiaTheme.dark,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SetupEntrance(child: Text('Ready')),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(SetupEntrance),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    expect(find.text('Ready'), findsOneWidget);
  });
}
