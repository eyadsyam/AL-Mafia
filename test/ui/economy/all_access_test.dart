import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/all_access.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wallet extends WalletController {
  _Wallet(this.state0);
  final WalletState? state0;

  @override
  Future<WalletState?> build() async => state0;
}

Future<bool> _read(WalletState? wallet, {String? account = 'account-a'}) async {
  final container = ProviderContainer(
    overrides: [
      walletProvider.overrideWith(() => _Wallet(wallet)),
      allAccessAccountProvider.overrideWith((ref) => Stream.value(account)),
    ],
  );
  addTearDown(container.dispose);
  container.read(allAccessProvider);
  await container.read(walletProvider.future);
  await container.read(allAccessAccountProvider.future);
  await pumpEventQueue();
  return container.read(allAccessProvider);
}

void main() {
  test('the wallet answer carries the owner grant', () {
    expect(WalletState.fromJson({'allAccess': true}).allAccess, isTrue);
    expect(WalletState.fromJson({'allAccess': 'true'}).allAccess, isFalse);
    expect(WalletState.fromJson(const {}).allAccess, isFalse);
    expect(
      WalletState.fromJson({'allAccess': true}).withBalance(5).allAccess,
      isTrue,
    );
  });

  test('all access follows the wallet and grants nothing unread', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await _read(null), isFalse);
    expect(await _read(WalletState.fromJson(const {'balance': 3})), isFalse);
    expect(
      await _read(WalletState.fromJson(const {'allAccess': true})),
      isTrue,
    );
  });

  test(
    'cached all access survives an unread wallet only for its account',
    () async {
      SharedPreferences.setMockInitialValues({
        AllAccessController.storageKey: jsonEncode({
          'account': 'account-a',
          'allAccess': true,
        }),
      });
      expect(await _read(null), isTrue);
      expect(await _read(null, account: 'account-b'), isFalse);
    },
  );

  test('reading the grant never resets a wallet that already answered', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        walletProvider.overrideWith(
          () => _Wallet(WalletState.fromJson({'allAccess': true, 'balance': 7})),
        ),
        allAccessAccountProvider.overrideWith(
          (ref) => Stream.value('account-a'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(walletProvider.future);
    expect(container.read(allAccessProvider), isTrue);
    await container.read(allAccessAccountProvider.future);
    await pumpEventQueue();
    expect(container.read(walletProvider).valueOrNull?.balance, 7);
    expect(container.read(allAccessProvider), isTrue);
  });

  test('a switch to another account forgets the grant', () async {
    SharedPreferences.setMockInitialValues({});
    final accounts = StreamController<String?>();
    addTearDown(accounts.close);
    final container = ProviderContainer(
      overrides: [
        walletProvider.overrideWith(
          () => _Wallet(WalletState.fromJson({'allAccess': true})),
        ),
        allAccessAccountProvider.overrideWith((ref) => accounts.stream),
      ],
    );
    addTearDown(container.dispose);
    container.read(allAccessProvider);
    await container.read(walletProvider.future);
    accounts.add('account-a');
    await pumpEventQueue();
    expect(container.read(allAccessProvider), isTrue);
    accounts.add('account-b');
    await pumpEventQueue();
    expect(container.read(allAccessProvider), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AllAccessController.storageKey), isNull);
  });

  test('a false wallet answer replaces a cached true grant', () async {
    SharedPreferences.setMockInitialValues({
      AllAccessController.storageKey: jsonEncode({
        'account': 'account-a',
        'allAccess': true,
      }),
    });
    expect(await _read(WalletState.fromJson({'allAccess': false})), isFalse);
    final saved = (await SharedPreferences.getInstance()).getString(
      AllAccessController.storageKey,
    );
    expect(jsonDecode(saved!)['allAccess'], isFalse);
  });
}
