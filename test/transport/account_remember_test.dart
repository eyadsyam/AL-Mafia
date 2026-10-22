import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Just enough of the auth client for «تذكّرني»: who is signed in, and
/// whether they were signed out.
class _Auth extends Fake implements GoTrueClient {
  _Auth(this.currentUser);

  @override
  final User? currentUser;
  int signOuts = 0;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async =>
      signOuts++;
}

User _account() => const User(
  id: 'u1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-22T00:00:00Z',
  isAnonymous: false,
);

void main() {
  setUp(AccountAuth.resetRememberForTest);

  Future<_Auth> launch(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final auth = _Auth(_account());
    await AccountAuth.applyRemember(auth);
    return auth;
  }

  test('remember off signs an account out at launch', () async {
    final auth = await launch({AccountAuth.rememberKey: false});
    expect(auth.signOuts, 1);
  });

  test('a fresh return from the browser keeps the account, once', () async {
    final auth = await launch({
      AccountAuth.rememberKey: false,
      AccountAuth.pendingReturnKey: DateTime.now().millisecondsSinceEpoch,
    });
    expect(auth.signOuts, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AccountAuth.pendingReturnKey), isNull);
  });

  test('an old mark does not keep it', () async {
    final old = DateTime.now()
        .subtract(const Duration(hours: 1))
        .millisecondsSinceEpoch;
    final auth = await launch({
      AccountAuth.rememberKey: false,
      AccountAuth.pendingReturnKey: old,
    });
    expect(auth.signOuts, 1);
  });

  test('markPendingReturn writes the mark', () async {
    SharedPreferences.setMockInitialValues({});
    await AccountAuth.markPendingReturn();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AccountAuth.pendingReturnKey), isNotNull);
  });
}
