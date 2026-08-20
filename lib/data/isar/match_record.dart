import 'package:isar_community/isar.dart';

part 'match_record.g.dart';

/// One stored match.
///
/// The whole match is kept as a single encoded [payload] rather than being
/// spread across normalised collections. That is a deliberate trade: a match is
/// only ever read or written as a whole, and one row means `persistStep` is a
/// single put inside one transaction — which is what makes it atomic, and a
/// half-written match impossible (repository contract inv. 1).
///
/// The remaining columns exist purely so History can be listed without decoding
/// every payload. None of them carry a role.
@collection
class MatchRecord {
  Id id = Isar.autoIncrement;

  /// `MatchCodec.encode` output, JSON-encoded.
  late String payload;

  @Index()
  late DateTime createdAt;

  /// Whether the match has reached a result. Indexed so the Resume prompt can
  /// find the single unfinished match without a table scan.
  @Index()
  late bool finished;

  late int playerCount;
}

/// The persisted default settings for the next match (FR-005).
///
/// A single-row collection: [id] is always [singletonId].
@collection
class SettingsRecord {
  static const int singletonId = 1;

  Id id = singletonId;

  /// `MatchCodec.encodeSettings` output, JSON-encoded.
  late String payload;
}
