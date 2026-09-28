import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';

void main() {
  test('lobby ready is server-negotiated and defaults off', () {
    expect(EconomyCapabilities.fromJson({'version': 2}).lobbyReady, isFalse);
    expect(
      EconomyCapabilities.fromJson({
        'version': 2,
        'lobbyReady': true,
        'thursday': true,
      }).lobbyReady,
      isTrue,
    );
  });
}
