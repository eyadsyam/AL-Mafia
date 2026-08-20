import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_player_group_repository.dart';
import 'package:mafia_master/data/player_group.dart';
import 'package:mafia_master/data/player_group_repository.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';

/// The group store, at the repository seam.
///
/// The store is separated from the repository so a test can throw the
/// repository away and build a new one over the same bytes. That is a process
/// death without a platform channel, and it is how "groups survive a
/// force-quit" gets asserted without an emulator in the loop.
void main() {
  late MemoryPlayerGroupStore store;
  late PlayerGroupRepository repository;

  setUp(() {
    store = MemoryPlayerGroupStore();
    repository = MemoryPlayerGroupRepository(store);
  });

  PlayerGroup group(String name, List<String> members, {DateTime? at}) =>
      PlayerGroup.create(
        name: name,
        memberNames: members,
        now: at ?? DateTime.utc(2026, 8, 3),
      );

  const friday = ['Ahmed', 'Fatima', 'Salem', 'Laila', 'Omar', 'Nada'];

  test('a saved group comes back with its roster in the saved order', () async {
    await repository.saveGroup(group('شلة الجمعة', friday));

    final groups = await repository.listGroups();
    expect(groups, hasLength(1));
    expect(groups.single.memberNames, orderedEquals(friday));
    expect(groups.single.isSaved, isTrue);
  });

  test('groups survive the repository being thrown away and rebuilt', () async {
    await repository.saveGroup(group('شلة الجمعة', friday));

    // The app process dies here. The bytes do not.
    final afterRelaunch = MemoryPlayerGroupRepository(store);
    final groups = await afterRelaunch.listGroups();

    expect(groups, hasLength(1));
    expect(groups.single.name, equals('شلة الجمعة'));
    expect(groups.single.memberNames, orderedEquals(friday));
  });

  test('the list is ordered most recently played first', () async {
    final old = await repository.saveGroup(
      group('شلة الشغل', const ['A', 'B', 'C', 'D', 'E'],
          at: DateTime.utc(2026, 1, 1)),
    );
    final recent = await repository.saveGroup(
      group('شلة الجمعة', friday, at: DateTime.utc(2026, 8, 1)),
    );

    final groups = await repository.listGroups();
    expect(groups.map((g) => g.id).toList(), equals([recent, old]),
        reason: 'the group you played last is the group you are about to '
            'play, so it has to be the row under the host\'s thumb');
  });

  test('recording a play bumps the count and remembers the configuration',
      () async {
    final id = await repository.saveGroup(group('شلة الجمعة', friday));
    const counts = {
      Role.mafia: 2,
      Role.detective: 1,
      Role.doctor: 1,
      Role.citizen: 2,
    };

    await repository.recordGroupPlayed(
      id,
      roleCounts: counts,
      settings: const MatchSettings.defaults(),
    );

    final saved = (await repository.listGroups()).single;
    expect(saved.playCount, equals(1));
    expect(saved.lastRoleCounts, equals(counts));
    expect(saved.lastSettings, isNotNull);
    expect(saved.canQuickStart, isTrue,
        reason: 'remembering the configuration is what makes the *next* '
            'rematch a three-tap job');
  });

  test('recording a play does not touch the roster', () async {
    // The load-bearing case. Attendance is a property of one evening; a member
    // who was away on Friday is still a member on Saturday. Nothing on the
    // match-start path may write the roster.
    final id = await repository.saveGroup(group('شلة الجمعة', friday));

    await repository.recordGroupPlayed(
      id,
      // Only five played — someone was away.
      roleCounts: const {Role.mafia: 1, Role.detective: 1, Role.doctor: 1, Role.citizen: 2},
      settings: const MatchSettings.defaults(),
    );

    final saved = (await repository.listGroups()).single;
    expect(saved.memberNames, orderedEquals(friday),
        reason: 'a five-player night must not shrink a six-player group — '
            'losing the absent member is the exact failure saved groups exist '
            'to prevent');
  });

  test('recording a play for a deleted group is not an error', () async {
    final id = await repository.saveGroup(group('شلة الجمعة', friday));
    await repository.deleteGroup(id);

    // A match start must not fail because the group was deleted from under it.
    await expectLater(
      repository.recordGroupPlayed(
        id,
        roleCounts: const {Role.mafia: 1, Role.citizen: 4},
        settings: const MatchSettings.defaults(),
      ),
      completes,
    );
    expect(await repository.listGroups(), isEmpty);
  });

  test('saving an existing group overwrites it rather than duplicating',
      () async {
    final id = await repository.saveGroup(group('شلة الجمعة', friday));
    final saved = (await repository.listGroups()).single;

    await repository.saveGroup(saved.copyWith(name: 'شلة السبت'));

    final groups = await repository.listGroups();
    expect(groups, hasLength(1));
    expect(groups.single.id, equals(id));
    expect(groups.single.name, equals('شلة السبت'));
  });

  test('deleting removes only the named group', () async {
    final a = await repository.saveGroup(group('A', friday));
    await repository.saveGroup(group('B', const ['P', 'Q', 'R', 'S', 'T']));

    await repository.deleteGroup(a);

    final groups = await repository.listGroups();
    expect(groups, hasLength(1));
    expect(groups.single.name, equals('B'));
  });

  test('a stored roster cannot be mutated through the object that wrote it',
      () async {
    // Seating order is the phone-passing order. A caller that could reorder the
    // stored list in place would silently change every future match.
    final mutable = ['Ahmed', 'Fatima', 'Salem', 'Laila', 'Omar'];
    await repository.saveGroup(
      PlayerGroup.create(
        name: 'g',
        memberNames: mutable,
        now: DateTime.utc(2026, 8, 3),
      ),
    );

    mutable
      ..clear()
      ..add('Impostor');

    final saved = (await repository.listGroups()).single;
    expect(saved.memberNames,
        orderedEquals(['Ahmed', 'Fatima', 'Salem', 'Laila', 'Omar']));
  });
}
