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

/// The persisted app-level singleton: default settings (FR-005), and the flags
/// that describe the *installation* rather than any match.
///
/// A single-row collection: [id] is always [singletonId].
///
/// ## Why the onboarding flag lives here and not in its own collection
///
/// It is one bit, written once in the life of an install, and it belongs to the
/// same thing [payload] belongs to — the app, not a match and not a group. A
/// second collection would mean a second schema, a second entry in the schema
/// list `Isar.open` takes, and a second migration surface, all to hold a
/// boolean.
///
/// The cost of sharing the row is real and is handled in
/// `IsarMatchRepository`: **every writer of this row must read-modify-write.**
/// A `put` that constructs a fresh `SettingsRecord` overwrites the other
/// field with its default, so saving settings would silently un-see the
/// onboarding. Both writers there load first for that reason.
@collection
class SettingsRecord {
  static const int singletonId = 1;

  Id id = singletonId;

  /// `MatchCodec.encodeSettings` output, JSON-encoded.
  ///
  /// Empty means "no settings have been saved yet", which is distinct from a
  /// missing row: the row now also exists to carry [onboardingSeen], so it can
  /// be written before any settings ever are. It was `late String` when this
  /// row could only be created by `saveDefaultSettings`; a `late` field would
  /// now throw on read for a row created by `markOnboardingSeen`.
  String payload = '';

  /// Whether the host has been through (or skipped) the onboarding deck.
  ///
  /// False for every row that predates this field, which is the right answer:
  /// an existing install has never seen onboarding, so it should get it once.
  bool onboardingSeen = false;
}
