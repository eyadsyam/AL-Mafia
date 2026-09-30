import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';

import '../support/fake_backend.dart';

/// Audit B3: a purchase whose answer was lost.
///
/// The server charges and grants in one transaction. If the connection drops
/// after that, the client used to keep showing the balance from before and an
/// "it failed" message: the player retried blind, or believed coins were lost.
void main() {
  test('a lost answer is followed by a read of the server truth', () async {
    final backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    );
    var applied = false;
    backend.responders['economy'] = (body) {
      switch (body['action']) {
        case 'buy':
          // Landed on the server; the answer never came back.
          applied = true;
          throw const BackendUnreachable('timeout');
        case 'summary':
          return {
            'balance': applied ? 800 : 1000,
            'catalog': const [],
            'owned': applied ? ['frame_gilded'] : const [],
          };
        default:
          return {'balance': 1000, 'catalog': const [], 'owned': const []};
      }
    };
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      ],
    );
    addTearDown(container.dispose);
    final wallet = container.read(walletProvider.notifier);
    await wallet.refresh();
    expect(container.read(walletProvider).value!.balance, 1000);

    await expectLater(
      wallet.buy('frame_gilded'),
      throwsA(isA<WalletActionFailed>()),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(walletProvider).value!;
    expect(state.balance, 800, reason: 'the balance the server now holds');
    expect(state.owned, contains('frame_gilded'));
    expect(
      backend.calls.where((c) => c.body['action'] == 'summary'),
      isNotEmpty,
    );
  });

  test('a refusal is not followed by a re-read', () async {
    final backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    );
    backend.responders['economy'] = (body) {
      if (body['action'] == 'buy') {
        throw const BackendException('INSUFFICIENT_COINS', 'not enough coins');
      }
      return {'balance': 10, 'catalog': const [], 'owned': const []};
    };
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      ],
    );
    addTearDown(container.dispose);
    final wallet = container.read(walletProvider.notifier);
    await wallet.refresh();
    await expectLater(
      wallet.buy('frame_gilded'),
      throwsA(
        isA<WalletActionFailed>().having(
          (e) => e.code,
          'code',
          'INSUFFICIENT_COINS',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      backend.calls.where((c) => c.body['action'] == 'summary'),
      isEmpty,
    );
  });
}
