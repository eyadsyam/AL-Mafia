import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/onboarding_account_step.dart';
import 'package:mafia_master/ui/account/profile_panels.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

class _FakeAuth extends AccountAuth {
  _FakeAuth()
    : super(() => throw UnimplementedError(), ensureSession: () async {});

  final calls = <String>[];

  @override
  Future<void> google() async => calls.add('google');

  @override
  Future<void> startSignUp(String email, String password) async =>
      calls.add('startSignUp:$email');
}

Widget _host(
  Widget child, {
  bool accounts = true,
  AccountProfile profile = AccountProfile.guest,
  required _FakeAuth auth,
}) => ProviderScope(
  overrides: [
    accountsAvailableProvider.overrideWithValue(accounts),
    accountAuthProvider.overrideWithValue(auth),
    accountProfileProvider.overrideWith((ref) => Stream.value(profile)),
  ],
  child: localizedApp(child),
);

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('guest: the choice offers sign-in and «كمّل من غير تسجيل»', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(const FirstRunScreen(), auth: auth));
    await tester.pumpAndSettle();
    // Language first, then the account chapter: five chapters in all.
    await _tap(tester, FirstRunScreen.nextKey);
    expect(find.byKey(OnboardingAccountChoice.signInKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.guestKey), findsOneWidget);
    expect(find.text(arStrings.onboardAccountGuest), findsOneWidget);
    expect(find.bySemanticsLabel(arStrings.arrivalStep(2, 5)), findsOneWidget);

    // Guest keeps the anonymous session and goes on to the name.
    await _tap(tester, FirstRunScreen.guestKey);
    expect(find.byKey(FirstRunScreen.nameKey), findsOneWidget);
    expect(auth.calls, isEmpty, reason: 'nothing was signed in or linked');

    // Back returns to the choice; it is never a one-way door.
    await _tap(tester, FirstRunScreen.backKey);
    expect(find.byKey(OnboardingAccountChoice.signInKey), findsOneWidget);
  });

  testWidgets('sign in: the choice opens the account sheet (Google, email)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(const FirstRunScreen(), auth: auth));
    await tester.pumpAndSettle();
    await _tap(tester, FirstRunScreen.nextKey);
    await _tap(tester, OnboardingAccountChoice.signInKey);
    expect(find.byKey(AccountSheet.googleKey), findsOneWidget);
    expect(find.byKey(AccountSheet.createKey), findsOneWidget);
    expect(find.byKey(AccountSheet.haveKey), findsOneWidget);
    await tester.tap(find.byKey(AccountSheet.googleKey));
    await tester.pumpAndSettle();
    expect(auth.calls, ['google']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('already signed in: the chapter says so and just continues', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeAuth();
    await tester.pumpWidget(
      _host(
        const FirstRunScreen(),
        auth: auth,
        profile: const AccountProfile(
          signedIn: true,
          email: 'eyad@example.com',
          emailConfirmed: true,
          google: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, FirstRunScreen.nextKey);
    expect(find.byKey(OnboardingAccountChoice.signedInKey), findsOneWidget);
    expect(
      find.text(arStrings.onboardAccountSignedIn('eyad@example.com')),
      findsOneWidget,
    );
    expect(find.byKey(FirstRunScreen.guestKey), findsNothing);
    await _tap(tester, FirstRunScreen.nextKey);
    expect(find.byKey(FirstRunScreen.nameKey), findsOneWidget);
  });

  testWidgets('a build with no server keeps the original four chapters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(const FirstRunScreen(), accounts: false, auth: _FakeAuth()),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(arStrings.arrivalStep(1, 4)), findsOneWidget);
    await _tap(tester, FirstRunScreen.nextKey);
    expect(find.byKey(OnboardingAccountChoice.signInKey), findsNothing);
    expect(find.byKey(FirstRunScreen.nameKey), findsOneWidget);
  });

  testWidgets('later: a guest links an account from the profile card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeAuth();
    await tester.pumpWidget(
      _host(const Scaffold(body: AccountCard()), auth: auth),
    );
    await tester.pumpAndSettle();
    expect(find.text(arStrings.authGuestTitle), findsOneWidget);
    await tester.tap(find.byKey(AccountCard.cardKey));
    await tester.pumpAndSettle();
    // The same sheet, linking to the identity the guest already has.
    expect(find.byKey(AccountSheet.googleKey), findsOneWidget);
    expect(find.byKey(AccountSheet.createKey), findsOneWidget);
    await tester.tap(find.byKey(AccountSheet.googleKey));
    await tester.pumpAndSettle();
    expect(auth.calls, ['google']);
  });

  testWidgets('the profile card stays away when the build has no accounts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Scaffold(body: AccountCard()),
        accounts: false,
        auth: _FakeAuth(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(AccountCard.cardKey), findsNothing);
  });
}
