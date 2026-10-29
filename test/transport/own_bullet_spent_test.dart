import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/supabase_backend.dart';

void main() {
  test(
    'mafia own seat uses team bullet state without a personal bullet row',
    () {
      final own = OwnSeat(
        seat: 1,
        role: 'mafia',
        bulletSpent: ownBulletSpent('mafia', const [], true),
      );
      expect(own.bulletSpent, isTrue);
    },
  );

  test('doctor own seat never uses Mafia team bullet state', () {
    final own = OwnSeat(
      seat: 2,
      role: 'doctor',
      bulletSpent: ownBulletSpent('doctor', const [], true),
    );
    expect(own.bulletSpent, isFalse);
  });
}
