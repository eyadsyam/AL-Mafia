import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/engine/models/match_settings.dart';

import '../player_group.dart';
import '../player_group_codec.dart';
import '../player_group_repository.dart';
import 'player_group_record.dart';

/// Isar-backed [PlayerGroupRepository].
///
/// Takes an already-open [Isar] rather than opening one, because the app has
/// exactly one database and `IsarMatchRepository.open` is what opens it. Two
/// `Isar.open` calls against the same directory is an error, and a second
/// database file would put the groups somewhere the match history is not.
class IsarPlayerGroupRepository implements PlayerGroupRepository {
  final Isar isar;

  IsarPlayerGroupRepository(this.isar);

  @override
  Future<List<PlayerGroup>> listGroups() async {
    // Sorted by the indexed column, descending: most recently played first.
    // Note this sorts the *groups*; it never touches member order.
    final records =
        await isar.playerGroupRecords.where().sortByLastPlayedAtDesc().findAll();
    return [for (final record in records) _decode(record)];
  }

  @override
  Future<int> saveGroup(PlayerGroup group) async {
    final payload = jsonEncode(PlayerGroupCodec.encode(group));

    late int id;
    await isar.writeTxn(() async {
      final record = PlayerGroupRecord()
        ..payload = payload
        ..lastPlayedAt = group.lastPlayedAt;
      // `unsaved` is 0; Isar treats `autoIncrement` as the sentinel for a new
      // row, so an existing id is assigned and anything else is left to insert.
      if (group.isSaved) record.id = group.id;
      id = await isar.playerGroupRecords.put(record);
    });
    return id;
  }

  @override
  Future<void> deleteGroup(int groupId) async {
    await isar.writeTxn(() async {
      await isar.playerGroupRecords.delete(groupId);
    });
  }

  @override
  Future<void> recordGroupPlayed(
    int groupId, {
    required Map<Role, int> roleCounts,
    required MatchSettings settings,
  }) async {
    await isar.writeTxn(() async {
      final record = await isar.playerGroupRecords.get(groupId);
      // A group deleted between starting a match and this write is not an
      // error worth failing a match start over.
      if (record == null) return;

      final now = DateTime.now();
      final existing = _decode(record);
      final updated = existing.copyWith(
        lastPlayedAt: now,
        playCount: existing.playCount + 1,
        lastRoleCounts: roleCounts,
        lastSettings: settings,
      );

      await isar.playerGroupRecords.put(
        PlayerGroupRecord()
          ..id = groupId
          ..payload = jsonEncode(PlayerGroupCodec.encode(updated))
          ..lastPlayedAt = now,
      );
    });
  }

  static PlayerGroup _decode(PlayerGroupRecord record) =>
      PlayerGroupCodec.decode(
        jsonDecode(record.payload) as Map<String, dynamic>,
        id: record.id,
      );
}
