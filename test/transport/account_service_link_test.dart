import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/account_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({String? email, bool confirmed = false, bool anonymous = false}) =>
    User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-09-27T00:00:00Z',
      email: email,
      emailConfirmedAt: confirmed ? '2026-09-27T00:01:00Z' : null,
      isAnonymous: anonymous,
    );

/// The auth client as the link fallback sees it: a local session, and a
/// server whose copy of the user changes once the emailed link is opened.
class FakeAuth extends Fake implements GoTrueClient {
  User local;
  User server;
  bool hasSession;
  bool refreshFails = false;
  int refreshes = 0;
  String? otpRedirect;
  final events = StreamController<AuthState>.broadcast();

  FakeAuth(this.local, {User? server, this.hasSession = true})
    : server = server ?? local;

  @override
  User? get currentUser => local;

  @override
  Session? get currentSession => hasSession
      ? Session(accessToken: 'a', tokenType: 'bearer', user: local)
      : null;

  @override
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    refreshes++;
    if (refreshFails) throw const AuthException('stale', code: 'bad_jwt');
    local = server;
    return AuthResponse(session: currentSession);
  }

  @override
  Future<UserResponse> getUser([String? jwt]) async =>
      UserResponse.fromJson(server.toJson());

  @override
  Future<void> signInWithOtp({
    String? email,
    String? phone,
    String? emailRedirectTo,
    bool? shouldCreateUser,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async => otpRedirect = emailRedirectTo;

  @override
  Stream<AuthState> get onAuthStateChange => events.stream;
}

Future<String?> _failure(Future<Object?> step) async {
  try {
    await step;
    return null;
  } on AccountFailure catch (failure) {
    return failure.code;
  }
}

void main() {
  final anonymous = _user(anonymous: true);
  final linked = _user(email: 'p@example.test', confirmed: true);

  group('linking by the emailed link', () {
    test('succeeds once the server has the email confirmed', () async {
      final auth = FakeAuth(anonymous, server: linked);
      final service = SupabaseAccountService.withAuth(() async => auth);
      final status = await service.confirmLinkByLink(' P@example.test ');
      expect(status.recoverable, isTrue);
      expect(status.email, 'p@example.test');
      expect(auth.refreshes, 1);
      // The refreshed session carries it: status() agrees.
      expect((await service.status()).recoverable, isTrue);
    });

    test('link not opened yet: LINK_PENDING', () async {
      final auth = FakeAuth(anonymous);
      final service = SupabaseAccountService.withAuth(() async => auth);
      expect(
        await _failure(service.confirmLinkByLink('p@example.test')),
        'LINK_PENDING',
      );
    });

    test('email change sent but unconfirmed: LINK_PENDING', () async {
      final auth = FakeAuth(
        anonymous,
        server: _user(email: 'p@example.test', anonymous: true),
      );
      final service = SupabaseAccountService.withAuth(() async => auth);
      expect(
        await _failure(service.confirmLinkByLink('p@example.test')),
        'LINK_PENDING',
      );
    });

    test('a different confirmed email is not this link', () async {
      final auth = FakeAuth(
        anonymous,
        server: _user(email: 'other@example.test', confirmed: true),
      );
      final service = SupabaseAccountService.withAuth(() async => auth);
      expect(
        await _failure(service.confirmLinkByLink('p@example.test')),
        'LINK_PENDING',
      );
    });

    test('a refused refresh still trusts the server read', () async {
      final auth = FakeAuth(anonymous, server: linked)..refreshFails = true;
      final service = SupabaseAccountService.withAuth(() async => auth);
      final status = await service.confirmLinkByLink('p@example.test');
      expect(status.recoverable, isTrue);
    });

    test('a bad email never reaches the server', () async {
      final auth = FakeAuth(anonymous, server: linked);
      final service = SupabaseAccountService.withAuth(() async => auth);
      expect(
        await _failure(service.confirmLinkByLink('nope')),
        'INVALID_EMAIL',
      );
      expect(auth.refreshes, 0);
    });
  });

  group('recovery by the emailed link', () {
    test('another device: LINK_ELSEWHERE, the code is the way in', () async {
      final auth = FakeAuth(anonymous);
      final service = SupabaseAccountService.withAuth(() async => auth);
      expect(
        await _failure(service.confirmRecoveryByLink('p@example.test')),
        'LINK_ELSEWHERE',
      );
    });

    test('no session at all: LINK_ELSEWHERE without a refresh', () async {
      final auth = FakeAuth(anonymous, hasSession: false);
      final service = SupabaseAccountService.withAuth(() async => auth);
      expect(
        await _failure(service.confirmRecoveryByLink('p@example.test')),
        'LINK_ELSEWHERE',
      );
      expect(auth.refreshes, 0);
    });

    test('the web page the link opened already holds it', () async {
      final auth = FakeAuth(linked);
      final service = SupabaseAccountService.withAuth(() async => auth);
      final status = await service.confirmRecoveryByLink('p@example.test');
      expect(status.email, 'p@example.test');
    });

    test('the request carries where the link should land', () async {
      final auth = FakeAuth(anonymous);
      final service = SupabaseAccountService.withAuth(() async => auth);
      await service.requestRecovery(
        'p@example.test',
        redirectTo: 'https://almafia.vercel.app/admin',
      );
      expect(auth.otpRedirect, 'https://almafia.vercel.app/admin');
    });
  });

  test('changes() reports a session arriving from the link', () async {
    final auth = FakeAuth(anonymous);
    final service = SupabaseAccountService.withAuth(() async => auth);
    final seen = <AccountStatus>[];
    final sub = service.changes().listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    auth.events.add(
      AuthState(
        AuthChangeEvent.signedIn,
        Session(accessToken: 'b', tokenType: 'bearer', user: linked),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen.single.recoverable, isTrue);
    expect(seen.single.email, 'p@example.test');
  });

  test('changes() is empty when the backend is unavailable', () async {
    final service = SupabaseAccountService.withAuth(
      () async => throw const AccountFailure('UNAVAILABLE'),
    );
    expect(await service.changes().toList(), isEmpty);
  });
}
