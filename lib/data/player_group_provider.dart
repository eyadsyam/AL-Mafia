import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/engine/models/match_settings.dart';

import 'memory_player_group_repository.dart';
import 'player_group.dart';
import 'player_group_repository.dart';

/// The app's group storage.
///
/// Overridden at startup with an [IsarPlayerGroupRepository] once the database
/// is open, exactly as `matchRepositoryProvider` is. The default is an
/// in-memory store so widget tests get a working repository rather than a null
/// one.
final playerGroupRepositoryProvider = Provider<PlayerGroupRepository>(
  (ref) => MemoryPlayerGroupRepository(MemoryPlayerGroupStore()),
);

/// The saved groups, most recently played first.
///
/// ## Why this is loaded eagerly rather than at the moment it is needed
///
/// The decision this feeds — picker or straight to the empty players screen —
/// is taken *synchronously*, inside the Home screen's tap handler, because a
/// router callback cannot await. So the list has to already be in hand when the
/// host taps "مباراة جديدة", and it is: the app reads this provider once at
/// startup, and a local database read of a handful of rows resolves long before
/// anyone has crossed the home screen.
///
/// If it somehow has not resolved, the caller treats that as "no groups" and
/// goes to the empty players screen — which is exactly today's behaviour, so
/// the degraded path is the shipped path rather than a broken one.
class PlayerGroupsNotifier extends AsyncNotifier<List<PlayerGroup>> {
  @override
  Future<List<PlayerGroup>> build() =>
      ref.read(playerGroupRepositoryProvider).listGroups();

  PlayerGroupRepository get _repository =>
      ref.read(playerGroupRepositoryProvider);

  /// Saves [group] and refreshes the list. Returns the stored id.
  Future<int> save(PlayerGroup group) async {
    final id = await _repository.saveGroup(group);
    await _refresh();
    return id;
  }

  Future<void> delete(int groupId) async {
    await _repository.deleteGroup(groupId);
    await _refresh();
  }

  Future<void> rename(PlayerGroup group, String name) async {
    await _repository.saveGroup(group.copyWith(name: name));
    await _refresh();
  }

  /// Bumps play count and remembers the configuration this group just started
  /// a match with. Leaves the roster alone — see [PlayerGroupRepository].
  Future<void> recordPlayed(
    int groupId, {
    required Map<Role, int> roleCounts,
    required MatchSettings settings,
  }) async {
    await _repository.recordGroupPlayed(
      groupId,
      roleCounts: roleCounts,
      settings: settings,
    );
    await _refresh();
  }

  Future<void> _refresh() async {
    state = AsyncData(await _repository.listGroups());
  }
}

final playerGroupsProvider =
    AsyncNotifierProvider<PlayerGroupsNotifier, List<PlayerGroup>>(
  PlayerGroupsNotifier.new,
);
