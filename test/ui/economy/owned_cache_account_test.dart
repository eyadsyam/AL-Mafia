import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/account/delete_account_sheet.dart';
import 'package:mafia_master/ui/economy/all_access.dart';
import 'package:mafia_master/ui/economy/my_cosmetics.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server as the test sets it: each wallet read answers whatever it holds
/// at that moment (null: the wallet has not been read).
class _Server extends WalletController {
  _Server(this.answer);
  final WalletState? Function() answer;

  @override
  Future<WalletState?> build() async => answer();
}

final _bought = WalletState.fromJson(const {
  'owned': ['role_sniper', 'frame_gilded'],
  'equipped': {'frame': 'frame_gilded'},
});

/// The bought roles and the equipped looks are kept on the phone for the
/// screens that work with no network. They are the account's, not the
/// phone's: a deleted account, a sign-out or another account on the same
/// phone never finds the last account's purchases there.
void main() {
  ({
    ProviderContainer container,
    StreamController<String?> accounts,
    void Function(WalletState?) serve,
  })
  setUp0({WalletState? wallet}) {
    WalletState? held = wallet;
    final accounts = StreamController<String?>();
    final container = ProviderContainer(
      overrides: [
        walletProvider.overrideWith(() => _Server(() => held)),
        allAccessAccountProvider.overrideWith((ref) => accounts.stream),
      ],
    );
    addTearDown(container.dispose);
    // Not awaited: a stream nobody listens to never delivers its close.
    addTearDown(() => unawaited(accounts.close()));
    container.listen(ownedRolesProvider, (_, _) {});
    container.listen(myCosmeticsProvider, (_, _) {});
    return (container: container, accounts: accounts, serve: (w) => held = w);
  }

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  test(
    'a deleted account leaves no bought role or look on the phone',
    () async {
      SharedPreferences.setMockInitialValues({});
      final t = setUp0(wallet: _bought);
      t.accounts.add('account-a');
      await t.container.read(walletProvider.future);
      await pumpEventQueue();
      expect(t.container.read(ownedRolesProvider), {'role_sniper'});
      expect(
        (await prefs()).getString(OwnedRolesController.storageKey),
        isNotNull,
      );

      // What the delete sheet does once the server has removed the account.
      t.serve(null);
      await forgetDeletedAccount();
      t.container.invalidate(walletProvider);
      t.accounts.add(null);
      await t.container.read(walletProvider.future);
      await pumpEventQueue();

      expect(t.container.read(ownedRolesProvider), isEmpty);
      expect(t.container.read(myCosmeticsProvider), MyCosmetics.none);
      expect(
        (await prefs()).getString(OwnedRolesController.storageKey),
        isNull,
      );
      expect(
        (await prefs()).getString(MyCosmeticsController.storageKey),
        isNull,
      );
    },
  );

  test('a sign-out, then another account: the first one\'s purchases stay '
      'with it', () async {
    SharedPreferences.setMockInitialValues({});
    final t = setUp0(wallet: _bought);
    t.accounts.add('account-a');
    await t.container.read(walletProvider.future);
    await pumpEventQueue();
    expect(t.container.read(ownedRolesProvider), {'role_sniper'});

    // Signed out; the new guest's wallet has not been read yet (no network).
    t.serve(null);
    t.container.invalidate(walletProvider);
    t.accounts.add(null);
    await pumpEventQueue();
    t.accounts.add('account-b');
    await t.container.read(walletProvider.future);
    await pumpEventQueue();

    expect(t.container.read(ownedRolesProvider), isEmpty);
    expect(t.container.read(myCosmeticsProvider), MyCosmetics.none);
    expect((await prefs()).getString(OwnedRolesController.storageKey), isNull);
  });

  test('a cold start with no network still opens the same account\'s '
      'purchases', () async {
    SharedPreferences.setMockInitialValues({});
    final first = setUp0(wallet: _bought);
    first.accounts.add('account-a');
    await first.container.read(walletProvider.future);
    await pumpEventQueue();
    first.container.dispose();

    // Next launch: the wallet never answers, the account is the same.
    final again = setUp0();
    again.accounts.add('account-a');
    await again.container.read(walletProvider.future);
    await pumpEventQueue();
    expect(again.container.read(ownedRolesProvider), {'role_sniper'});
  });

  test('a cold start as another account opens nothing of the first', () async {
    SharedPreferences.setMockInitialValues({});
    final first = setUp0(wallet: _bought);
    first.accounts.add('account-a');
    await first.container.read(walletProvider.future);
    await pumpEventQueue();
    first.container.dispose();

    final other = setUp0();
    other.accounts.add('account-b');
    await other.container.read(walletProvider.future);
    await pumpEventQueue();
    expect(other.container.read(ownedRolesProvider), isEmpty);
    expect(other.container.read(myCosmeticsProvider), MyCosmetics.none);
  });
}
