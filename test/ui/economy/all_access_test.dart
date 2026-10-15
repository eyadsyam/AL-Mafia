import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/all_access.dart';
import 'package:mafia_master/ui/economy/wallet.dart';

class _Wallet extends WalletController {
  _Wallet(this.state0);
  final WalletState? state0;

  @override
  Future<WalletState?> build() async => state0;
}

Future<bool> _read(WalletState? wallet) async {
  final container = ProviderContainer(
    overrides: [walletProvider.overrideWith(() => _Wallet(wallet))],
  );
  addTearDown(container.dispose);
  await container.read(walletProvider.future);
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
    expect(await _read(null), isFalse);
    expect(await _read(WalletState.fromJson(const {'balance': 3})), isFalse);
    expect(
      await _read(WalletState.fromJson(const {'allAccess': true})),
      isTrue,
    );
  });
}
