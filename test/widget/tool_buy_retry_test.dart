import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/table_tools.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';

import '../support/fake_backend.dart';

/// A tool purchase the server applied but whose answer was lost, with the
/// shelf unreadable too: the player taps buy again. That tap must be the same
/// attempt, or the server charges twice.
void main() {
  late FakeBackend backend;
  late ProviderContainer container;
  var shelfDown = false;
  BackendException? refusal;

  setUp(() {
    shelfDown = false;
    refusal = null;
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(),
      players: roster(5),
    );
    backend.responders['economy'] = (body) {
      if (body['action'] == 'toolBuy') {
        if (refusal case final r?) throw r;
        throw BackendUnreachable(Exception('answer lost'));
      }
      if (shelfDown) throw BackendUnreachable(Exception('down'));
      return const {'tools': [], 'balance': 0};
    };
    container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      ],
    );
    addTearDown(container.dispose);
  });

  List<Object?> keys() => [
    for (final c in backend.calls)
      if (c.body['action'] == 'toolBuy') c.body['requestId'],
  ];

  Future<void> buy() async {
    try {
      await container.read(tableToolsProvider.notifier).buy('double_vote', 1);
    } on ToolActionFailed {
      // Expected: every buy here fails one way or another.
    }
  }

  test('a lost answer with no shelf to show is retried as itself', () async {
    await container.read(tableToolsProvider.future);
    shelfDown = true;
    await buy();
    await buy();
    expect(keys(), hasLength(2));
    expect(keys().toSet(), hasLength(1));
  });

  test('once the shelf is shown, the next tap is a new attempt', () async {
    await container.read(tableToolsProvider.future);
    await buy();
    await buy();
    expect(keys().toSet(), hasLength(2));
  });

  test('a refusal is an answer: the next tap is a new attempt', () async {
    await container.read(tableToolsProvider.future);
    shelfDown = true;
    refusal = const BackendException('INSUFFICIENT_COINS', 'no');
    await buy();
    await buy();
    expect(keys().toSet(), hasLength(2));
  });
}
