import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/supabase_backend.dart';

void main() {
  const tonight = 3;
  final reveal = {'night': tonight, 'action': 'reveal', 'target_id': null};
  final protect = {'night': tonight, 'action': 'protect', 'target_id': 'u'};
  final lastNight = {'night': tonight - 1, 'action': 'reveal'};

  test('the Elder\'s reveal choice is not the night\'s move', () {
    expect(ownActedThisNight([reveal], tonight), isFalse);
    expect(ownActedThisNight([reveal, protect], tonight), isTrue);
    expect(ownActedThisNight([lastNight], tonight), isFalse);
  });

  test(
    'a reconnect reads back tonight\'s reveal choice, and only tonight\'s',
    () {
      expect(ownElderRevealChosen([reveal], 'night', tonight), isTrue);
      expect(ownElderRevealChosen([lastNight], 'night', tonight), isFalse);
      expect(ownElderRevealChosen(const [], 'night', tonight), isFalse);
      expect(ownElderRevealChosen([reveal], 'morning', tonight), isFalse);
    },
  );
}
