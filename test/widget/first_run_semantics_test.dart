import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('gender and agreement each have one complete semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final l = await AppLocalizations.delegate.load(const Locale('ar'));
    final agreement =
        '${l.firstRunAgreePrefix}${l.firstRunAgreeTerms}${l.firstRunAgreeAnd}${l.firstRunAgreePrivacy}';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: MafiaTheme.dark,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const FirstRunScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(FirstRunScreen.agreeKey)),
      isSemantics(label: agreement, hasCheckedState: true, isChecked: false),
    );
    await tester.tap(find.byKey(FirstRunScreen.agreeKey));
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(FirstRunScreen.agreeKey)),
      isSemantics(label: agreement, hasCheckedState: true, isChecked: true),
    );
    expect(find.byKey(FirstRunScreen.termsLinkKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.privacyLinkKey), findsOneWidget);
    await tester.tap(find.byKey(FirstRunScreen.continueKey));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(l.firstRunBoy), findsOneWidget);
    expect(find.bySemanticsLabel(l.firstRunGirl), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(FirstRunScreen.boyKey)),
      isSemantics(
        label: l.firstRunBoy,
        hasSelectedState: true,
        isSelected: false,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(FirstRunScreen.girlKey)),
      isSemantics(
        label: l.firstRunGirl,
        hasSelectedState: true,
        isSelected: false,
      ),
    );
    semantics.dispose();
  });
}
