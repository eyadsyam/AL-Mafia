import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/transport/account_service.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthState;

import '../support/localized.dart';

class _FakeAuth extends AccountAuth {
  _FakeAuth()
    : super(() => throw UnimplementedError(), ensureSession: () async {});

  final calls = <String>[];
  String? failWith;

  Future<T> _step<T>(String call, T value) async {
    calls.add(call);
    if (failWith != null) throw AccountFailure(failWith!);
    return value;
  }

  static const _signed = AccountProfile(
    signedIn: true,
    email: 'eyad@example.com',
    emailConfirmed: true,
    password: true,
  );

  @override
  Future<void> startSignUp(String email, String password) =>
      _step('startSignUp:$email', null);
  @override
  Future<AccountProfile> finishSignUp(String e, String code, String p) =>
      _step('finishSignUp:$code', _signed);
  @override
  Future<AccountProfile> signIn(String email, String password) =>
      _step('signIn:$email', _signed);
  @override
  Future<void> sendReset(String email) => _step('sendReset:$email', null);
  @override
  Future<AccountProfile> finishReset(String e, String code, String p) =>
      _step('finishReset:$code', _signed);
  @override
  Future<void> google() => _step('google', null);
  @override
  Future<void> googleSignIn() => _step('googleSignIn', null);
}

void main() {
  late _FakeAuth auth;

  Future<void> pump(WidgetTester tester, {AccountProfile? profile}) async {
    SharedPreferences.setMockInitialValues({});
    auth = _FakeAuth();
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountAuthProvider.overrideWithValue(auth),
          accountProfileProvider.overrideWith(
            (ref) => Stream.value(profile ?? AccountProfile.guest),
          ),
        ],
        child: localizedApp(const Scaffold(body: AccountSheet())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, Key key, String text) async {
    await tester.enterText(find.byKey(key), text);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(AccountSheet.submitKey));
    await tester.tap(find.byKey(AccountSheet.submitKey));
    await tester.pumpAndSettle();
  }

  testWidgets('a guest is offered Google, a new account and sign-in', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(AccountSheet.googleKey), findsOneWidget);
    expect(find.byKey(AccountSheet.createKey), findsOneWidget);
    expect(find.byKey(AccountSheet.haveKey), findsOneWidget);
    await tester.tap(find.byKey(AccountSheet.googleKey));
    await tester.pumpAndSettle();
    expect(auth.calls, ['google']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-up asks for matching passwords, then a code', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(AccountSheet.createKey));
    await tester.pumpAndSettle();
    await type(tester, AccountSheet.emailKey, 'eyad@example.com');
    await type(tester, AccountSheet.passwordKey, 'secret123');
    await type(tester, AccountSheet.confirmKey, 'secret124');
    await submit(tester);
    expect(find.byKey(AccountSheet.errorKey), findsOneWidget);
    expect(auth.calls, isEmpty);

    await type(tester, AccountSheet.confirmKey, 'secret123');
    await submit(tester);
    expect(auth.calls, ['startSignUp:eyad@example.com']);
    // The confirmation screen names the address and takes the code.
    expect(find.textContaining('eyad@example.com'), findsOneWidget);
    expect(find.byKey(AccountSheet.codeKey), findsOneWidget);
    // Resend waits out its cooldown.
    final resend = tester.widget<TextButton>(
      find.byKey(AccountSheet.resendKey),
    );
    expect(resend.onPressed, isNull);

    await type(tester, AccountSheet.codeKey, '123456');
    await submit(tester);
    expect(auth.calls.last, 'finishSignUp:123456');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  });

  testWidgets('a wrong code says so and stays on the code', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(AccountSheet.createKey));
    await tester.pumpAndSettle();
    await type(tester, AccountSheet.emailKey, 'eyad@example.com');
    await type(tester, AccountSheet.passwordKey, 'secret123');
    await type(tester, AccountSheet.confirmKey, 'secret123');
    await submit(tester);
    auth.failWith = 'INVALID_CODE';
    await type(tester, AccountSheet.codeKey, '000000');
    await submit(tester);
    expect(find.byKey(AccountSheet.errorKey), findsOneWidget);
    expect(find.byKey(AccountSheet.codeKey), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  });

  testWidgets('forgot password: code, then a new password', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(AccountSheet.haveKey));
    await tester.pumpAndSettle();
    expect(find.byKey(AccountSheet.rememberKey), findsOneWidget);
    await tester.ensureVisible(find.byKey(AccountSheet.forgotKey));
    await tester.tap(find.byKey(AccountSheet.forgotKey));
    await tester.pumpAndSettle();
    await type(tester, AccountSheet.emailKey, 'eyad@example.com');
    await submit(tester);
    expect(auth.calls, ['sendReset:eyad@example.com']);
    await type(tester, AccountSheet.codeKey, '654321');
    await type(tester, AccountSheet.passwordKey, 'newsecret1');
    await type(tester, AccountSheet.confirmKey, 'newsecret1');
    await submit(tester);
    expect(auth.calls.last, 'finishReset:654321');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  });

  testWidgets('an account sees its email, remember-me and sign out', (
    tester,
  ) async {
    await pump(
      tester,
      profile: const AccountProfile(
        signedIn: true,
        email: 'eyad@example.com',
        emailConfirmed: true,
        google: true,
      ),
    );
    expect(find.text('eyad@example.com'), findsOneWidget);
    expect(find.byKey(AccountSheet.signOutKey), findsOneWidget);
    expect(find.byKey(AccountSheet.rememberKey), findsOneWidget);
  });

  test('auth refusals map to the words the sheet speaks', () {
    String code(String c, [String message = '']) =>
        AccountAuth.codeFor(AuthException(message, code: c));
    expect(code('invalid_credentials'), 'WRONG_PASSWORD');
    expect(code('email_not_confirmed'), 'NOT_CONFIRMED');
    expect(code('weak_password'), 'WEAK_PASSWORD');
    expect(code('identity_already_exists'), 'EMAIL_TAKEN');
    expect(code('otp_expired'), 'INVALID_CODE');
    expect(code('over_email_send_rate_limit'), 'RATE_LIMITED');
    expect(code('manual_linking_disabled'), 'PROVIDER_OFF');
    expect(code('something_else'), 'UNAVAILABLE');
  });

  // D1 — a Google return that failed arrives on the auth stream, not from the
  // call that opened the browser.
  test('a refusal on the auth stream becomes the failure the sheet reads', () {
    final states = StreamController<AuthState>();
    addTearDown(states.close);
    final profiles = AccountAuth.profileChanges(states.stream, () => null);
    expect(
      profiles,
      emitsError(
        isA<AccountFailure>().having((f) => f.code, 'code', 'EMAIL_TAKEN'),
      ),
    );
    states.addError(
      const AuthException(
        'Identity is already linked to another user',
        code: 'identity_already_exists',
      ),
    );
  });

  testWidgets(
    "a Google account that is another player's is said, and offered",
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      auth = _FakeAuth();
      final profiles = StreamController<AccountProfile>();
      addTearDown(profiles.close);
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountAuthProvider.overrideWithValue(auth),
            accountProfileProvider.overrideWith((ref) => profiles.stream),
          ],
          child: localizedApp(const Scaffold(body: AccountSheet())),
        ),
      );
      profiles.add(AccountProfile.guest);
      await tester.pumpAndSettle();
      expect(find.byKey(AccountSheet.googleExistingKey), findsNothing);

      profiles.addError(const AccountFailure('EMAIL_TAKEN'));
      await tester.pumpAndSettle();
      expect(find.byKey(AccountSheet.errorKey), findsOneWidget);
      expect(
        find.byKey(AccountSheet.googleKey),
        findsOneWidget,
        reason: 'the guest hub is still there, not an empty sheet',
      );

      await tester.ensureVisible(find.byKey(AccountSheet.googleExistingKey));
      await tester.tap(find.byKey(AccountSheet.googleExistingKey));
      await tester.pumpAndSettle();
      expect(auth.calls, ['googleSignIn']);
      expect(find.byKey(AccountSheet.googleExistingKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('passwords shorter than eight are refused before any request', () {
    expect(
      () => AccountAuth.checkPassword('short'),
      throwsA(isA<AccountFailure>()),
    );
    expect(AccountAuth.checkPassword('long enough'), 'long enough');
  });
}
