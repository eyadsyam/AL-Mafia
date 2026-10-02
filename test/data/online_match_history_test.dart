import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mafia_master/data/online_match_history.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'completed online summary is durable and duplicate results are ignored',
    () async {
      await OnlineMatchHistory.save(
        roomId: 'room',
        names: ['A', 'B'],
        winner: 'town',
        days: 3,
      );
      await OnlineMatchHistory.save(
        roomId: 'room',
        names: ['A', 'B'],
        winner: 'town',
        days: 3,
      );
      final rows = await OnlineMatchHistory.load();
      expect(rows, hasLength(1));
      expect(rows.single.keys.toSet(), {'roomId', 'names', 'winner', 'days'});
      expect(rows.single['winner'], 'town');
    },
  );
  test('corrupt storage does not break history', () async {
    SharedPreferences.setMockInitialValues({
      OnlineMatchHistory.storageKey: '{broken',
    });
    expect(await OnlineMatchHistory.load(), isEmpty);
  });
}
