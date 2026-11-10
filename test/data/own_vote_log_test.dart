import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/own_vote_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a changed vote replaces the earlier one; a re-vote is its own '
      'ballot; an abstention is not a seat', () async {
    await OwnVoteLog.record(roomId: 'r', day: 1, round: 1, targetSeat: 2);
    await OwnVoteLog.record(roomId: 'r', day: 1, round: 1, targetSeat: 3);
    await OwnVoteLog.record(roomId: 'r', day: 1, round: 2, targetSeat: 4);
    await OwnVoteLog.record(roomId: 'r', day: 2, round: 1, targetSeat: null);
    await OwnVoteLog.record(roomId: 'other', day: 1, round: 1, targetSeat: 5);
    expect(await OwnVoteLog.take('r'), [3, 4]);
    expect(await OwnVoteLog.take('r'), isEmpty, reason: 'read once, forgotten');
    expect(await OwnVoteLog.take('other'), [5]);
  });

  test('accuracy adds up the kept rows and stays quiet below the minimum', () {
    final rows = [
      {'votes': 3, 'onMafia': 2},
      {'votes': 2, 'onMafia': 0},
      {'role': 'mafia'}, // a mafia player's match: not counted
      {'votes': 1, 'onMafia': 4}, // impossible: ignored
    ];
    expect(voteAccuracy(rows), (votes: 5, onMafia: 2));
    expect(voteAccuracy(rows, minimumVotes: 6), isNull);
    expect(voteAccuracy(const []), isNull);
  });
}
