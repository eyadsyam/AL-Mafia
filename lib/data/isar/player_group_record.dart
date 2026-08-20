import 'package:isar_community/isar.dart';

part 'player_group_record.g.dart';

/// One saved roster.
///
/// Same shape as [MatchRecord]: the group lives as a single encoded [payload],
/// with only the columns the picker needs to sort and count promoted out of it.
/// A group is only ever read or written whole, so one row keeps every write a
/// single put and makes a half-written group impossible.
///
/// [lastPlayedAt] is indexed because the picker's ordering — most recently
/// played first — is the feature, and it should not be a table scan.
///
/// Nothing in this collection carries a role. The saved role *counts* live
/// inside the payload and describe the match configuration, not any person.
@collection
class PlayerGroupRecord {
  Id id = Isar.autoIncrement;

  /// `PlayerGroupCodec.encode` output, JSON-encoded.
  late String payload;

  @Index()
  late DateTime lastPlayedAt;
}
