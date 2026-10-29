import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/onboarding_account_step.dart';
import 'package:mafia_master/ui/account/profile_panels.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/terms_consent.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/screens/onboarding/permissions_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/first_run_steps.dart';
import '../support/localized.dart';

class _FakeAuth extends AccountAuth {
  _FakeAuth()
    : super(() => throw UnimplementedError(), ensureSession: () async {});

  final calls = <String>[];

  @override
  Future<void> google() async => calls.add('google');

  @override
  Future<void> googleSignIn() async => calls.add('googleSignIn');

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

  Future<void> toSaveStep(WidgetTester tester) async {
    await passIntro(tester);
    await answerKind(tester);
    await typeName(tester, 'Eyad');
    await _tap(tester, FirstRunScreen.nextKey);
    await _tap(tester, PermissionsStep.continueKey);
  }

  testWidgets('guest: Google, email, and play later as a guest', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(const FirstRunScreen(), auth: auth));
    await toSaveStep(tester);
    expect(find.byKey(FirstRunScreen.googleKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.emailKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.guestKey), findsOneWidget);
    expect(find.text(arStrings.firstRunGuest), findsOneWidget);
    // Three dots with a server.
    expect(find.bySemanticsLabel(arStrings.arrivalStep(4, 4)), findsOneWidget);

    // Guest keeps the anonymous session: the profile is saved, nothing signed.
    await _tap(tester, FirstRunScreen.guestKey);
    expect(auth.calls, isEmpty, reason: 'nothing was signed in or linked');
    expect((await ProfileStore().load())!.name, 'Eyad');
    expect((await TermsStore().load())!.adult, isTrue);
  });

  testWidgets('email: opens the account sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(const FirstRunScreen(), auth: auth));
    await toSaveStep(tester);
    await _tap(tester, FirstRunScreen.emailKey);
    expect(find.byKey(AccountSheet.googleKey), findsOneWidget);
    expect(find.byKey(AccountSheet.createKey), findsOneWidget);
    expect(find.byKey(AccountSheet.notNowKey), findsOneWidget);
    await tester.tap(find.byKey(AccountSheet.googleKey));
    await tester.pumpAndSettle();
    // First run links too: the anonymous user id must stay the same.
    expect(auth.calls, ['google']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google: one tap starts the link', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(const FirstRunScreen(), auth: auth));
    await toSaveStep(tester);
    await _tap(tester, FirstRunScreen.googleKey);
    expect(auth.calls, ['google']);
  });

  testWidgets('already signed in: the step is skipped and setup completes', (
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
    await toSaveStep(tester);
    expect((await ProfileStore().load())!.name, 'Eyad');
    expect((await TermsStore().load())!.adult, isTrue);
  });

  testWidgets('a build with no server has two steps and no save step', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(const FirstRunScreen(), accounts: false, auth: _FakeAuth()),
    );
    await passIntro(tester);
    await answerKind(tester);
    expect(find.bySemanticsLabel(arStrings.arrivalStep(2, 3)), findsOneWidget);
    expect(find.byKey(FirstRunScreen.nextKey), findsNothing);
    expect(find.byKey(FirstRunScreen.continueKey), findsOneWidget);
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
    expect(find.text(arStrings.authAccount), findsOneWidget);
    expect(find.text(arStrings.authGuestBadge), findsOneWidget);
    await tester.tap(find.byKey(AccountCard.cardKey));
    await tester.pumpAndSettle();
    // A sheet from the bottom, with both Google and email choices.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text(arStrings.authAccount), findsWidgets);
    expect(find.byKey(AccountSheet.googleKey), findsOneWidget);
    expect(find.byKey(AccountSheet.createKey), findsOneWidget);
    expect(find.byKey(AccountSheet.notNowKey), findsOneWidget);
    expect(find.text(arStrings.accountGuestIntro), findsOneWidget);
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
