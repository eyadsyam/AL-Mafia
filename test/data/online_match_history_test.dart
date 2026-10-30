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
  test(
    'legacy rows belong once to the first account that reads them',
    () async {
      SharedPreferences.setMockInitialValues({
        OnlineMatchHistory.storageKey:
            '[{"roomId":"old","names":["A"],"winner":"town","days":2}]',
      });
      expect(await OnlineMatchHistory.load(userId: 'guest'), isEmpty);
      expect(await OnlineMatchHistory.load(userId: 'alice'), hasLength(1));
      expect(await OnlineMatchHistory.load(userId: 'bob'), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(OnlineMatchHistory.storageKey), isFalse);
    },
  );

  test('new results stay with the account that played them', () async {
    await OnlineMatchHistory.save(
      userId: 'alice',
      roomId: 'one',
      names: ['A'],
      winner: 'town',
      days: 1,
    );
    await OnlineMatchHistory.save(
      userId: 'bob',
      roomId: 'two',
      names: ['B'],
      winner: 'mafia',
      days: 2,
    );
    expect(
      (await OnlineMatchHistory.load(userId: 'alice')).single['roomId'],
      'one',
    );
    expect(
      (await OnlineMatchHistory.load(userId: 'bob')).single['roomId'],
      'two',
    );
  });
  test(
    'legacy rows merge with results already scoped to the first account',
    () async {
      SharedPreferences.setMockInitialValues({
        '${OnlineMatchHistory.storageKey}.alice':
            '[{"roomId":"new","names":["A"],"winner":"mafia","days":1}]',
        OnlineMatchHistory.storageKey:
            '[{"roomId":"old","names":["A"],"winner":"town","days":2}]',
      });
      final rows = await OnlineMatchHistory.load(userId: 'alice');
      expect(rows.map((row) => row['roomId']), ['new', 'old']);
      expect(await OnlineMatchHistory.load(userId: 'bob'), isEmpty);
    },
  );
  test('a damaged legacy key cannot hide valid account rows', () async {
    SharedPreferences.setMockInitialValues({
      '${OnlineMatchHistory.storageKey}.alice':
          '[{"roomId":"new","names":["A"],"winner":"town","days":1}]',
      OnlineMatchHistory.storageKey: '{broken',
    });
    expect(
      (await OnlineMatchHistory.load(userId: 'alice')).single['roomId'],
      'new',
    );
  });
}
