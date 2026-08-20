import 'dart:convert';

import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/engine/models/match_settings.dart';

import 'player_group.dart';
import 'player_group_codec.dart';
import 'player_group_repository.dart';

/// Backing store for [MemoryPlayerGroupRepository], kept separate from the
/// repository for the same reason [MemoryMatchStore] is: a test can throw the
/// repository away and build a new one over the same store, which is a process
/// death without a platform channel — the "groups survive a force-quit" case.
class MemoryPlayerGroupStore {
  /// groupId -> encoded group JSON.
  final Map<int, String> groups = {};

  int nextId = 1;

  void clear() {
    groups.clear();
    nextId = 1;
  }
}

/// A [PlayerGroupRepository] over a [MemoryPlayerGroupStore].
///
/// Used by the test suite and as the app's fallback when Isar's native library
/// is unavailable — the same bargain the match store makes. Losing saved groups
/// for a session is a degraded evening; refusing to boot is a lost one.
///
/// Writes go through [PlayerGroupCodec] and are held as encoded strings rather
/// than live objects, so a caller cannot mutate stored state by keeping hold of
/// the object it wrote. That matters more here than it looks: `memberNames` is
/// the seating order, and a caller that could reorder the stored list in place
/// would silently change the phone-passing order of every future match.
class MemoryPlayerGroupRepository implements PlayerGroupRepository {
  final MemoryPlayerGroupStore store;

  MemoryPlayerGroupRepository(this.store);

  @override
  Future<List<PlayerGroup>> listGroups() async {
    final groups = <PlayerGroup>[
      for (final entry in store.groups.entries)
        PlayerGroupCodec.decode(
          jsonDecode(entry.value) as Map<String, dynamic>,
          id: entry.key,
        ),
    ];
    // Most recently played first. Ties broken by id descending so the order is
    // total and a test that saves two groups in one tick still gets a stable
    // answer.
    groups.sort((a, b) {
      final byDate = b.lastPlayedAt.compareTo(a.lastPlayedAt);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
    return groups;
  }

  @override
  Future<int> saveGroup(PlayerGroup group) async {
    final id = group.isSaved ? group.id : store.nextId++;
    store.groups[id] = jsonEncode(PlayerGroupCodec.encode(group));
    return id;
  }

  @override
  Future<void> deleteGroup(int groupId) async {
    store.groups.remove(groupId);
  }

  @override
  Future<void> recordGroupPlayed(
    int groupId, {
    required Map<Role, int> roleCounts,
    required MatchSettings settings,
  }) async {
    final encoded = store.groups[groupId];
    if (encoded == null) return;

    final existing = PlayerGroupCodec.decode(
      jsonDecode(encoded) as Map<String, dynamic>,
      id: groupId,
    );
    final updated = existing.copyWith(
      lastPlayedAt: DateTime.now(),
      playCount: existing.playCount + 1,
      lastRoleCounts: roleCounts,
      lastSettings: settings,
    );
    store.groups[groupId] = jsonEncode(PlayerGroupCodec.encode(updated));
  }
}
