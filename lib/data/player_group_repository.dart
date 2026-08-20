import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/engine/models/match_settings.dart';

import 'player_group.dart';

/// Persistence for saved rosters.
///
/// ## Why this is its own interface rather than four more methods on
/// `MatchRepository`
///
/// `MatchRepository` has a written contract with six invariants, all of them
/// about roles and when they may be read. Groups carry no roles at all — a
/// roster is a list of names the whole table can already see — so folding them
/// into that interface would put a role-free concern behind a set of role
/// guarantees it neither needs nor tests. Two interfaces, one database.
///
/// Local only. No account, no sync, no network — the same offline-first rule
/// the match store follows (FR-029).
abstract interface class PlayerGroupRepository {
  /// All saved groups, **most recently played first**.
  ///
  /// The ordering is the feature: the group you played last is the group you
  /// are about to play, so it must be the one under the host's thumb.
  Future<List<PlayerGroup>> listGroups();

  /// Inserts or updates, and returns the stored id.
  ///
  /// A group with [PlayerGroup.unsaved] as its id is inserted; anything else
  /// overwrites that row. Member order is stored exactly as given.
  Future<int> saveGroup(PlayerGroup group);

  Future<void> deleteGroup(int groupId);

  /// Records that [groupId] just started a match: bumps `playCount`, stamps
  /// `lastPlayedAt`, and remembers the configuration it was played with so the
  /// next rematch can skip the roles and settings screens.
  ///
  /// Deliberately does **not** touch `memberNames`. Tonight's absences are not
  /// a change to the group — that is the entire point of the attendance
  /// toggle — so the roster is only ever rewritten through [saveGroup], by an
  /// explicit host action.
  Future<void> recordGroupPlayed(
    int groupId, {
    required Map<Role, int> roleCounts,
    required MatchSettings settings,
  });
}
