import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/missions/thursday.dart';

void main() {
  test('parses server-owned Thursday state and clamps progress', () {
    final event = ThursdayEvent.fromJson({
      'enabled': true,
      'isThursday': true,
      'inWindow': false,
      'progress': 7,
      'stamp': true,
      'event': '2026-10-29',
    });

    expect(event.enabled, isTrue);
    expect(event.isThursday, isTrue);
    expect(event.inWindow, isFalse);
    expect(event.progress, 2);
    expect(event.stamp, isTrue);
    expect(event.event, '2026-10-29');
  });

  test('banner requires both capability and server Thursday', () {
    const thursday = ThursdayEvent(enabled: true, isThursday: true);
    const fridayWindow = ThursdayEvent(enabled: true, inWindow: true);

    expect(thursdayBannerVisible(capability: true, event: thursday), isTrue);
    expect(thursdayBannerVisible(capability: false, event: thursday), isFalse);
    expect(
      thursdayBannerVisible(capability: true, event: fridayWindow),
      isFalse,
    );
  });

  test('capability parser defaults off and reads Thursday flag', () {
    expect(EconomyCapabilities.fromJson({'version': 2}).thursday, isFalse);
    expect(
      EconomyCapabilities.fromJson({'version': 2, 'thursday': true}).thursday,
      isTrue,
    );
  });
}
