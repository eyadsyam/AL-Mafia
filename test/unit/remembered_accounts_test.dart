import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/remembered_accounts.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SessionAuth extends Fake implements GoTrueClient {
  @override
  User? get currentUser => const User(
    id: 'saved-user', appMetadata: {}, userMetadata: {},
    aud: 'authenticated', createdAt: '2026-10-30T00:00:00Z',
    isAnonymous: false,
  );

  int signOuts = 0;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOuts++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  RememberedAccount account(int n, {DateTime? at}) => RememberedAccount(
    userId: 'u$n',
    email: 'person$n@example.com',
    displayName: 'Player $n',
    provider: n.isEven ? 'google' : 'email',
    lastUsedAt: at ?? DateTime.utc(2026, 1, n),
  );

  test('adds, updates, orders newest first and caps at five', () async {
    final store = RememberedAccounts();
    for (var i = 1; i <= 6; i++) {
      await store.add(account(i));
    }
    expect((await store.load()).map((a) => a.userId), [
      'u6',
      'u5',
      'u4',
      'u3',
      'u2',
    ]);
    await store.add(account(3, at: DateTime.utc(2026, 2, 1)));
    expect((await store.load()).map((a) => a.userId), [
      'u3',
      'u6',
      'u5',
      'u4',
      'u2',
    ]);
    expect((await store.load()).length, 5);
  });

  test('remove affects only the device list', () async {
    final store = RememberedAccounts();
    await store.add(account(1));
    await store.add(account(2));
    await store.remove('u1');
    expect((await store.load()).map((a) => a.userId), ['u2']);
  });

  test(
    'email is masked and no entry is written for anonymous identity',
    () async {
      expect(account(1).maskedEmail, 'p***@example.com');
      final store = RememberedAccounts();
      await store.add(
        RememberedAccount(
          userId: 'anonymous-session-id',
          email: 'guest@example.com',
          displayName: 'Guest',
          provider: 'email',
          lastUsedAt: DateTime.utc(2026),
        ),
        isAnonymous: true,
      );
      expect(await store.load(), isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          RememberedAccounts.key,
        ),
        isNull,
      );
    },
  );

  test('remember defaults on and keeps a restored Supabase session', () async {
    AccountAuth.resetRememberForTest();
    final auth = _SessionAuth();
    expect(await AccountAuth.remember(), isTrue);
    await AccountAuth.applyRemember(auth);
    expect(auth.signOuts, 0);
  });
}
