import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    );
  });

  Future<void> pumpStore(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        ],
        child: localizedApp(const CoinStore()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('earned balance buys a guide once through the server', (
    tester,
  ) async {
    backend.responses['economy'] = {
      'balance': 400,
      'catalog': [
        {'code': 'mastermind_guide', 'price': 400},
      ],
      'owned': <String>[],
    };
    await pumpStore(tester);

    expect(find.text(arStrings.coinsBalance(400)), findsOneWidget);
    expect(find.byKey(CoinStore.buyGuideKey), findsOneWidget);

    backend.responses['economy'] = {
      'balance': 0,
      'catalog': [
        {'code': 'mastermind_guide', 'price': 400},
      ],
      'owned': ['mastermind_guide'],
    };
    await tester.tap(find.byKey(CoinStore.buyGuideKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arStrings.coinsUnlock));
    await tester.pumpAndSettle();

    final buy = backend.calls.where(
      (call) => call.function == 'economy' && call.body['action'] == 'buy',
    );
    expect(buy, hasLength(1));
    expect(find.text(arStrings.coinsBalance(0)), findsOneWidget);
    expect(find.text(arStrings.coinsGuideOpen), findsOneWidget);
  });

  testWidgets('an owned guide reveals useful content', (tester) async {
    backend.responses['economy'] = {
      'balance': 25,
      'catalog': [
        {'code': 'mastermind_guide', 'price': 400},
      ],
      'owned': ['mastermind_guide'],
    };
    await pumpStore(tester);
    await tester.tap(find.text(arStrings.coinsGuideOpen));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.coinsGuideContent), findsOneWidget);
  });
}
