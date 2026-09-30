import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_group.dart';
import 'package:mafia_master/data/prefs_stores.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/scripted_match.dart';

/// Web parity: the browser keeps what the phone keeps. Every test here opens
/// the stores, writes, then opens a SECOND set over the same preferences, which
/// is what a page reload is.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test(
    'an unfinished match survives a reload, and is the one resumed',
    () async {
      final stores = await openPrefsStores(prefs);
      final engine = scriptedMatch(stopAfterNightActions: 2);
      await stores.matches.persistStep(engine.match);

      final reloaded = await openPrefsStores(prefs);
      final resumed = await reloaded.matches.loadActiveMatch();
      expect(resumed, equals(engine.match));
      expect(resumed!.seed, engine.match.seed);
    },
  );

  test('a finished match moves to history and its analytics open', () async {
    final stores = await openPrefsStores(prefs);
    final engine = scriptedMatch(playToEnd: true);
    await stores.matches.persistStep(engine.match);

    final reloaded = await openPrefsStores(prefs);
    expect(await reloaded.matches.loadActiveMatch(), isNull);
    final history = await reloaded.matches.listHistory();
    expect(history, hasLength(1));
    final analytics = await reloaded.matches.loadAnalytics(history.single.id);
    expect(analytics.matchId, engine.match.id);
  });

  test(
    'an unfinished match still refuses analytics after a reload (Doc 05)',
    () async {
      final stores = await openPrefsStores(prefs);
      final engine = scriptedMatch(stopAfterNightActions: 1);
      await stores.matches.persistStep(engine.match);

      final reloaded = await openPrefsStores(prefs);
      expect(
        () => reloaded.matches.loadAnalytics(engine.match.id),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('deleting a match is remembered', () async {
    final stores = await openPrefsStores(prefs);
    final engine = scriptedMatch(playToEnd: true);
    await stores.matches.persistStep(engine.match);
    await stores.matches.deleteMatch(engine.match.id);

    final reloaded = await openPrefsStores(prefs);
    expect(await reloaded.matches.listHistory(), isEmpty);
  });

  test('settings, onboarding and seen hints survive a reload', () async {
    final stores = await openPrefsStores(prefs);
    expect(await stores.matches.hasSeenOnboarding(), isFalse);
    const custom = MatchSettings(speechSeconds: 45);
    await stores.matches.saveDefaultSettings(custom);
    await stores.matches.markOnboardingSeen();
    await stores.matches.markHintSeen('a');
    await stores.matches.markHintSeen('b');

    final reloaded = await openPrefsStores(prefs);
    expect(await reloaded.matches.hasSeenOnboarding(), isTrue);
    expect(
      (await reloaded.matches.loadDefaultSettings()).speechSeconds,
      45,
    );
    expect(await reloaded.matches.loadSeenHints(), {'a', 'b'});

    await reloaded.matches.resetSeenHints();
    final again = await openPrefsStores(prefs);
    expect(await again.matches.loadSeenHints(), isEmpty);
  });

  test('saved groups survive, ids never collide, and deletes stick', () async {
    final stores = await openPrefsStores(prefs);
    final now = DateTime(2026, 9, 30);
    final first = await stores.groups.saveGroup(
      PlayerGroup.create(
        name: 'A',
        memberNames: const ['x', 'y', 'z', 'w'],
        now: now,
      ),
    );
    final second = await stores.groups.saveGroup(
      PlayerGroup.create(
        name: 'B',
        memberNames: const ['x', 'y', 'z', 'w'],
        now: now,
      ),
    );
    await stores.groups.recordGroupPlayed(
      first,
      roleCounts: const {Role.mafia: 1, Role.citizen: 3},
      settings: const MatchSettings(),
    );
    await stores.groups.deleteGroup(second);

    final reloaded = await openPrefsStores(prefs);
    final groups = await reloaded.groups.listGroups();
    expect(groups.map((g) => g.name), ['A']);
    expect(groups.single.playCount, 1);
    final third = await reloaded.groups.saveGroup(
      PlayerGroup.create(
        name: 'C',
        memberNames: const ['x', 'y', 'z', 'w'],
        now: now,
      ),
    );
    expect(third, greaterThan(second), reason: 'a deleted id is not reused');
  });

  test('whispers survive a reload and a purge removes them', () async {
    final stores = await openPrefsStores(prefs);
    await stores.whispers.put(matchId: 7, whisperId: 'w1', body: 'hello');

    final reloaded = await openPrefsStores(prefs);
    expect(await reloaded.whispers.read(matchId: 7, whisperId: 'w1'), 'hello');
    await reloaded.whispers.purge(7);

    final again = await openPrefsStores(prefs);
    expect(await again.whispers.readAll(7), isEmpty);
  });

  test('history is capped so storage cannot fill up', () async {
    final stores = await openPrefsStores(prefs);
    for (var i = 0; i < prefsMatchCap + 5; i++) {
      final engine = scriptedMatch(
        playToEnd: true,
        createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
      );
      await stores.matches.persistStep(engine.match);
    }
    final reloaded = await openPrefsStores(prefs);
    expect(await reloaded.matches.listHistory(), hasLength(prefsMatchCap));
  });

  test(
    'corrupt storage opens as a fresh install instead of throwing',
    () async {
      SharedPreferences.setMockInitialValues({
        PrefsStoreKeys.matches: '{not json',
        PrefsStoreKeys.groups: '[1,2]',
        PrefsStoreKeys.whispers: '"x"',
      });
      final broken = await SharedPreferences.getInstance();
      final stores = await openPrefsStores(broken);
      expect(await stores.matches.loadActiveMatch(), isNull);
      expect(await stores.groups.listGroups(), isEmpty);
      expect(await stores.whispers.readAll(1), isEmpty);
    },
  );
}
