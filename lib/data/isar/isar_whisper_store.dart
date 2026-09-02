import 'package:isar_community/isar.dart';

import '../whisper_store.dart';
import 'whisper_content_record.dart';

/// Isar-backed [WhisperStore].
///
/// Shares the `Isar` instance opened by [IsarMatchRepository] — one database,
/// one open, several collections. See the note on `IsarMatchRepository.open`
/// about why the schema list must be complete there.
class IsarWhisperStore implements WhisperStore {
  final Isar isar;

  IsarWhisperStore(this.isar);

  @override
  Future<void> put({
    required int matchId,
    required String whisperId,
    required String body,
  }) async {
    await isar.writeTxn(() async {
      // The composite index is `unique, replace`, so a repeat send overwrites
      // rather than appending a second row with the same key.
      await isar.whisperContentRecords.put(
        WhisperContentRecord()
          ..matchId = matchId
          ..whisperId = whisperId
          ..body = body,
      );
    });
  }

  @override
  Future<String?> read({
    required int matchId,
    required String whisperId,
  }) async {
    final row = await isar.whisperContentRecords
        .filter()
        .matchIdEqualTo(matchId)
        .whisperIdEqualTo(whisperId)
        .findFirst();
    return row?.body;
  }

  @override
  Future<Map<String, String>> readAll(int matchId) async {
    final rows = await isar.whisperContentRecords
        .filter()
        .matchIdEqualTo(matchId)
        .findAll();
    return {for (final r in rows) r.whisperId: r.body};
  }

  @override
  Future<void> purge(int matchId) async {
    await isar.writeTxn(() async {
      final ids = await isar.whisperContentRecords
          .filter()
          .matchIdEqualTo(matchId)
          .idProperty()
          .findAll();
      await isar.whisperContentRecords.deleteAll(ids);
    });
  }
}
