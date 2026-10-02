import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/monetization/purchase_store.dart';
import 'package:mafia_master/platform/optional_service.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/scenario_store.dart';

import '../support/fake_backend.dart';

/// A store that behaves like Play on connect: the moment it opens, it replays
/// a purchase that was restored or left unfinished last session.
class _ReplayingStore implements PurchaseStore {
  _ReplayingStore({this.failFirstStart = false});

  bool failFirstStart;
  int starts = 0;
  final completed = <String>[];
  final _events = StreamController<StorePurchaseEvent>.broadcast(sync: true);

  @override
  bool get configured => true;
  @override
  Stream<StorePurchaseEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    starts++;
    if (failFirstStart) {
      failFirstStart = false;
      throw StateError('billing unavailable');
    }
    _events.add(
      const StorePurchaseEvent(
        state: StorePurchaseState.restored,
        productId: 'mafia_scenario_mastermind',
        token: 'restored-token',
      ),
    );
  }

  @override
  Future<StoreProduct?> product() async => null;
  @override
  Future<bool> buy() async => false;
  @override
  Future<void> restore() async {}
  @override
  Future<void> complete(String token) async => completed.add(token);
  @override
  void dispose() {}
}

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    );
    backend.responses['play_purchase'] = {
      'state': 'active',
      'owned': ['scenario_shadows'],
    };
  });

  ProviderContainer container(PurchaseStore store) {
    final c = ProviderContainer(
      overrides: [
        purchaseStoreProvider.overrideWithValue(store),
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'a purchase replayed as the store connects is verified, not lost',
    () async {
      final store = _ReplayingStore();
      final c = container(store);

      await c.read(scenarioPurchaseProvider.notifier).start();
      await pumpEventQueue();

      final verify = backend.calls.where(
        (call) =>
            call.function == 'play_purchase' && call.body['action'] == 'verify',
      );
      expect(verify, hasLength(1));
      expect(verify.single.body['token'], 'restored-token');
      expect(c.read(scenarioPurchaseProvider).owned, isTrue);
      expect(store.completed, ['restored-token']);
    },
  );

  test('a store that fails to start is reported and can start again', () async {
    final store = _ReplayingStore(failFirstStart: true);
    final c = container(store);
    final notifier = c.read(scenarioPurchaseProvider.notifier);

    expect(await runOptionalService('purchases', notifier.start), isFalse);
    expect(await runOptionalService('purchases', notifier.start), isTrue);
    await pumpEventQueue();

    expect(store.starts, 2);
    expect(c.read(scenarioPurchaseProvider).owned, isTrue);
  });
}
