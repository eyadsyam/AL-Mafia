import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/daily_rewards.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';

import '../support/fake_backend.dart';

class _Wallet extends WalletController {
  final credits = <int>[];

  @override
  Future<void> settle({int credited = 0}) async => credits.add(credited);
}

/// Today's spin, made already on another device or tab, comes back with the
/// prize and `granted: 0`. The wheel shows the prize; the balance must not
/// count it a second time.
void main() {
  for (final (granted, credit) in const [(35, 35), (0, 0)]) {
    test('a spin answered with granted $granted credits $credit', () async {
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(),
        players: roster(5),
      );
      backend.responders['economy'] = (body) => switch (body['action']) {
        'daily_spin' => {'slot': 2, 'amount': 35, 'granted': granted},
        _ => {'day': '2026-10-23'},
      };
      final wallet = _Wallet();
      final container = ProviderContainer(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          walletProvider.overrideWith(() => wallet),
        ],
      );
      addTearDown(container.dispose);
      await container.read(dailyProvider.notifier).refresh();

      final grant = await container.read(dailyProvider.notifier).spin();
      await Future<void>.delayed(Duration.zero);

      expect((grant.slot, grant.granted), (2, 35));
      expect(wallet.credits, [credit]);
    });
  }
}
