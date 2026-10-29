import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/transport/account_service.dart';
import 'package:mafia_master/transport/native_google.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Picker implements NativeGoogle {
  final Object? error;
  _Picker({this.error});
  @override
  Future<NativeGoogleToken> pick() async {
    if (error != null) throw error!;
    return const NativeGoogleToken('id-token');
  }
}

class _Auth implements GoTrueClient {
  _Auth(this.anonymous, {this.linkError});
  final bool anonymous;
  final AuthException? linkError;
  final calls = <String>[];

  @override
  User? get currentUser => User(
    id: 'u',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    isAnonymous: anonymous,
  );

  @override
  Future<AuthResponse> linkIdentityWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
    String? captchaToken,
  }) async {
    calls.add('link:$idToken');
    if (linkError != null) throw linkError!;
    return AuthResponse();
  }

  @override
  Future<AuthResponse> signInWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
    String? captchaToken,
  }) async {
    calls.add('signin:$idToken');
    return AuthResponse();
  }

  // The browser flows (extension methods) reach the server through these;
  // recording them proves the fallback ran without opening a browser.
  @override
  Future<OAuthResponse> getOAuthSignInUrl({
    required OAuthProvider provider,
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    calls.add('browser');
    throw StateError('no browser in tests');
  }

  @override
  Future<OAuthResponse> getLinkIdentityUrl(
    OAuthProvider provider, {
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    calls.add('browser-link');
    throw StateError('no browser in tests');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AccountAuth _make(_Auth auth, NativeGoogle? native) =>
    AccountAuth(() async => auth, ensureSession: () async {}, native: native);

/// The stubbed browser step fails; the player would see the friendly
/// UNAVAILABLE message, never the raw error.
Future<void> _swallow(Future<void> run) async {
  await expectLater(
    run,
    throwsA(isA<AccountFailure>().having((f) => f.code, 'code', 'UNAVAILABLE')),
  );
}

void main() {
  test('a guest links Google through the native picker', () async {
    final auth = _Auth(true);
    await _make(auth, _Picker()).google();
    expect(auth.calls, ['link:id-token']);
  });

  test('an account signs in through the native picker', () async {
    final auth = _Auth(false);
    await _make(auth, _Picker()).google();
    expect(auth.calls, ['signin:id-token']);
  });

  test('googleSignIn never links', () async {
    final auth = _Auth(true);
    await _make(auth, _Picker()).googleSignIn();
    expect(auth.calls, ['signin:id-token']);
  });

  test('backing out of the picker does nothing and says nothing', () async {
    final auth = _Auth(true);
    await _make(auth, _Picker(error: const NativeGoogleCancelled())).google();
    expect(auth.calls, isEmpty);
  });

  test('a picker that cannot run falls back to the browser', () async {
    final auth = _Auth(true);
    await _swallow(
      _make(auth, _Picker(error: StateError('no credential manager'))).google(),
    );
    expect(auth.calls, ['browser-link']);
    final other = _Auth(false);
    await _swallow(
      _make(other, _Picker(error: StateError('x'))).googleSignIn(),
    );
    expect(other.calls, ['browser']);
  });

  test('no native picker (web) goes straight to the browser', () async {
    final auth = _Auth(false);
    await _swallow(_make(auth, null).googleSignIn());
    expect(auth.calls, ['browser']);
  });

  test("a Google account that is another player's is signed in to", () async {
    final auth = _Auth(
      true,
      linkError: const AuthException('exists', code: 'identity_already_exists'),
    );
    await _make(auth, _Picker()).google();
    expect(
      auth.calls,
      ['link:id-token', 'signin:id-token'],
      reason: 'the same picker answer signs in: no second picker, no browser',
    );
  });
}
