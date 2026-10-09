import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/terms_consent.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';
import 'package:mafia_master/ui/widgets/deck/deck_buttons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/first_run_steps.dart';

final _log = <String>[];

class _LoggedTerms extends TermsStore {
  @override
  Future<void> save(TermsAcceptance acceptance) async {
    _log.add('terms');
    await super.save(acceptance);
  }
}

class _LoggedProfile extends ProfileStore {
  @override
  Future<void> save(PlayerProfile profile) async {
    _log.add('profile:${profile.name}');
    await super.save(profile);
  }
}

Widget _app() => ProviderScope(
  overrides: [
    termsStoreProvider.overrideWithValue(_LoggedTerms()),
    profileStoreProvider.overrideWithValue(_LoggedProfile()),
  ],
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
    home: const SetupRequired(child: Text('HOME')),
  ),
);

bool _continueEnabled(WidgetTester tester) =>
    tester
        .widget<BoneButton>(find.byKey(FirstRunScreen.continueKey))
        .onPressed !=
    null;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _log.clear();
  });

  testWidgets('the consent is recorded before the profile is saved', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await completeFirstRun(tester, name: 'Eyad');
    expect(find.text('HOME'), findsOneWidget);
    expect(_log, ['terms', 'profile:Eyad']);
  });

  testWidgets('a name of invisible marks is not a name', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await passIntro(tester);
    await answerKind(tester);
    await typeName(tester, '​​​');
    expect(_continueEnabled(tester), isFalse);
    await typeName(tester, 'M​');
    // One visible character is still short of the minimum.
    expect(_continueEnabled(tester), isFalse);
    await typeName(tester, 'Mona');
    expect(_continueEnabled(tester), isTrue);
  });

  testWidgets('a saved tick is not replayed when first run is restored', (
    tester,
  ) async {
    await const FirstRunProgress(
      chapter: 'name',
      name: 'Zed Zed',
      gender: PlayerGender.male,
      agreed: true,
    ).save();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    // Back at the chapter that holds the box, unticked, with the name kept.
    expect(find.byKey(FirstRunScreen.agreeKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.nameKey), findsNothing);
    expect(_log, isEmpty);
  });
}
