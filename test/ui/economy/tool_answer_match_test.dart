import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/table_tools.dart';

void main() {
  test('recovered answer belongs to the phase and targets of this use', () {
    const row = {
      'tool': 'sense', 'phaseNumber': 3, 'targets': [2, 4],
      'answer': true,
    };
    expect(recoveredToolAnswerMatches(row, 'sense', 2, [2, 4]), isFalse);
    expect(recoveredToolAnswerMatches(row, 'sense', 3, [2, 5]), isFalse);
    expect(recoveredToolAnswerMatches(row, 'sense', 3, [4, 2]), isTrue);
    expect(recoveredToolAnswerMatches({...row, 'requestId': 'old'},
        'sense', 3, [2, 4], requestId: 'new'), isFalse);
  });
}
