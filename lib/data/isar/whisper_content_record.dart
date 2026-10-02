import 'package:isar_community/isar.dart';

part 'whisper_content_record.g.dart';

/// One whisper's body, in a collection of its own.
///
/// ## Why this is not a field on [MatchRecord]
///
/// It is the offline half of doc 09 §5's storage split: *"`WhisperMeta` (the
/// graph) is readable by everyone in the match. `Whisper.content` is readable
/// only by sender and recipient. These are two tables online, two collections
/// offline."*
///
/// Online the split is enforced by RLS. Offline there is no such boundary —
/// one device, one owner — so the split has to earn its keep differently, and
/// it does, in two ways:
///
/// 1. `MatchRecord.payload` is the whole match, and it is what the History and
///    analytics screens decode. A body stored inside it would be one
///    `jsonDecode` away from any screen that opens a finished match, whether or
///    not «كشف الهمسات» was ever switched on. Keeping bodies out of the payload
///    means the reveal setting gates a *read of a different collection*, not a
///    filter somebody has to remember to apply.
/// 2. It makes «امسح الهمسات» a `deleteAll` on one collection rather than a
///    rewrite of every stored match.
///
/// Rows are keyed by `(matchId, whisperId)` where `whisperId` is the
/// deterministic `w:<day>:<from>:<to>` from `WhisperMeta.idFor`. Unique and
/// `replace: true`, so re-sending is an overwrite rather than a duplicate — the
/// same idempotency the online `send_whisper` function gets from its primary
/// key.
@collection
class WhisperContentRecord {
  Id id = Isar.autoIncrement;

  @Index(composite: [CompositeIndex('whisperId')], unique: true, replace: true)
  late int matchId;

  late String whisperId;

  /// At most `WhisperLimits.maxLength` characters. The engine rejects longer
  /// bodies before they reach here; this column does not silently truncate.
  late String body;
}
