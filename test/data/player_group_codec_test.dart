import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_group.dart';
import 'package:mafia_master/data/player_group_codec.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';

/// The saved-roster round trip, and the one property it must never lose.
///
/// `memberNames` is the **seating order**, which is the phone-passing order. A
/// codec that reordered it — through a `Set`, a `Map`, or a helpful sort —
/// would hand the phone to the wrong player on every rematch, and it would do
/// it silently, because every name would still be present and the count would
/// still be right. That is why order gets its own tests here rather than being
/// assumed by a single equality check.
void main() {
  final now = DateTime.utc(2026, 8, 3, 21, 30);

  PlayerGroup sample({
    List<String>? members,
    Map<Role, int>? roleCounts,
    MatchSettings? settings,
  }) =>
      PlayerGroup(
        id: 7,
        name: 'شلة الجمعة',
        memberNames: members ??
            const ['Ahmed', 'Fatima', 'Salem', 'Laila', 'Omar', 'Nada'],
        createdAt: now,
        lastPlayedAt: now.add(const Duration(days: 3)),
        playCount: 12,
        lastRoleCounts: roleCounts,
        lastSettings: settings,
      );

  /// Encodes, stringifies and reads back — the same path storage takes, so a
  /// value that only survives in memory does not pass.
  PlayerGroup roundTrip(PlayerGroup group) => PlayerGroupCodec.decode(
        jsonDecode(jsonEncode(PlayerGroupCodec.encode(group)))
            as Map<String, dynamic>,
        id: group.id,
      );

  group('round trip', () {
    test('every field survives', () {
      final original = sample(
        roleCounts: const {
          Role.mafia: 2,
          Role.detective: 1,
          Role.doctor: 1,
          Role.citizen: 2,
        },
        settings: const MatchSettings.defaults(),
      );
      final restored = roundTrip(original);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.memberNames, equals(original.memberNames));
      expect(restored.createdAt, equals(original.createdAt));
      expect(restored.lastPlayedAt, equals(original.lastPlayedAt));
      expect(restored.playCount, equals(original.playCount));
      expect(restored.lastRoleCounts, equals(original.lastRoleCounts));
      expect(restored.lastSettings?.speechSeconds,
          equals(original.lastSettings?.speechSeconds));
      expect(restored.lastSettings?.dayTieRule,
          equals(original.lastSettings?.dayTieRule));
    });

    test('seating order is preserved exactly, not just as a set', () {
      // A deliberately non-alphabetical order that any accidental sort would
      // rearrange, in both scripts the app ships.
      const seated = ['Zaid', 'Ahmed', 'يوسف', 'Mona', 'أحمد', 'Basel'];
      final restored = roundTrip(sample(members: seated));

      expect(restored.memberNames, orderedEquals(seated),
          reason: 'member order is the seating order and therefore the '
              'phone-passing order — it may never be re-sorted');
    });

    test('a group that has never played round-trips with no configuration', () {
      final restored = roundTrip(sample());

      expect(restored.lastRoleCounts, isNull);
      expect(restored.lastSettings, isNull);
      expect(restored.canQuickStart, isFalse,
          reason: 'a group with no remembered configuration must not offer to '
              'skip the roles and settings screens');
    });

    test('roles are keyed by name, so reordering the enum cannot reinterpret '
        'a stored distribution', () {
      final encoded = PlayerGroupCodec.encode(
        sample(roleCounts: const {Role.mafia: 2, Role.citizen: 4}),
      );
      final counts = encoded['lastRoleCounts'] as Map;

      expect(counts.keys, containsAll(<String>['mafia', 'citizen']));
      for (final key in counts.keys) {
        expect(key, isA<String>());
        expect(int.tryParse(key as String), isNull,
            reason: 'an enum index in storage silently reinterprets every '
                'stored group the day someone reorders `Role`');
      }
    });

    test('an unknown role name is a format error rather than a silent drop', () {
      expect(
        () => PlayerGroupCodec.decode({
          'name': 'x',
          'memberNames': const <String>[],
          'createdAt': now.toIso8601String(),
          'lastPlayedAt': now.toIso8601String(),
          'playCount': 0,
          'lastRoleCounts': const {'jester': 1},
          'lastSettings': null,
        }, id: 1),
        throwsFormatException,
      );
    });
  });

  group('roster comparison', () {
    final group = sample();

    test('hasRoster is order-sensitive', () {
      expect(group.hasRoster(group.memberNames), isTrue);

      final swapped = [...group.memberNames];
      final first = swapped.removeAt(0);
      swapped.insert(1, first);
      expect(group.hasRoster(swapped), isFalse,
          reason: 'the same people seated differently is a change to the '
              'group, which is what lets the app offer to save the new order');
    });

    test('hasSameMembers ignores order', () {
      final shuffled = [...group.memberNames.reversed];
      expect(group.hasSameMembers(shuffled), isTrue,
          reason: 'the save prompt must not offer to re-save people the app '
              'already knows just because they sat down differently');
      expect(group.hasSameMembers([...group.memberNames, 'Karim']), isFalse);
    });
  });

  test('play count is group-level and there is nowhere to put a per-player '
      'role history', () {
    // Not a style point. A stored "Ahmed was mafia four times" survives between
    // evenings and becomes a metagame tell that no in-match leakage test would
    // ever catch, because nothing leaks *during* the match. The defence is that
    // the field does not exist.
    final encoded = PlayerGroupCodec.encode(
      sample(roleCounts: const {Role.mafia: 2, Role.citizen: 4}),
    );

    expect(encoded.keys, contains('playCount'));
    final serialised = jsonEncode(encoded);
    for (final name in sample().memberNames) {
      // A member's name may appear exactly once — in the roster. Anywhere else
      // means something is being recorded *about* them.
      expect(RegExp(RegExp.escape('"$name"')).allMatches(serialised).length,
          equals(1),
          reason: '$name appears more than once in a stored group, which means '
              'the group carries per-player data beyond the roster');
    }
  });
}
