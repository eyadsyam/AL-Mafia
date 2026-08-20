import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:mafia_master/engine/analytics_builder.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';

import '../match_codec.dart';
import '../match_repository.dart';
import '../repository_types.dart';
import '../resume_resolver.dart';
import 'match_record.dart';
import 'player_group_record.dart';

/// Isar-backed [MatchRepository].
///
/// Everything interesting — how a match becomes bytes, and where a resumed
/// match re-enters — lives in [MatchCodec] and [ResumeResolver], which are pure
/// and directly tested. What is left here is transaction management, so the
/// storage layer stays small enough to read in one sitting.
///
/// No method in this class opens a socket. Offline operation is a hard product
/// requirement (FR-029), and the absence of any network dependency in the
/// storage path is the load-bearing part of that guarantee.
class IsarMatchRepository implements MatchRepository {
  final Isar isar;

  IsarMatchRepository(this.isar);

  /// Opens the database in [directory].
  ///
  /// Every collection the app uses is registered here, including the ones this
  /// class does not touch: `Isar.open` takes the full schema list, and a second
  /// `open` against the same directory to add a collection is an error. Adding
  /// [PlayerGroupRecordSchema] is additive — Isar creates the new collection on
  /// first open and leaves existing `MatchRecord` rows untouched, so stored
  /// history survives the change.
  static Future<IsarMatchRepository> open({required String directory}) async {
    final isar = await Isar.open(
      [MatchRecordSchema, SettingsRecordSchema, PlayerGroupRecordSchema],
      directory: directory,
    );
    return IsarMatchRepository(isar);
  }

  @override
  Future<void> persistStep(Match match) async {
    final finished = !ResumeResolver.isActive(match);
    final payload = jsonEncode(MatchCodec.encode(match));

    await isar.writeTxn(() async {
      final record = MatchRecord()
        // The engine owns the id, so every step of a match overwrites one row.
        ..id = match.id
        ..payload = payload
        ..createdAt = match.createdAt
        ..finished = finished
        ..playerCount = match.players.length;
      await isar.matchRecords.put(record);
    });
  }

  @override
  Future<Match?> loadActiveMatch() async {
    final record = await isar.matchRecords
        .filter()
        .finishedEqualTo(false)
        .sortByCreatedAtDesc()
        .findFirst();
    if (record == null) return null;
    return _decode(record);
  }

  @override
  Future<ResumeTarget> resolveResume(Match match) async =>
      ResumeResolver.resolve(match);

  @override
  Future<List<MatchSummary>> listHistory() async {
    final records = await isar.matchRecords
        .filter()
        .finishedEqualTo(true)
        .sortByCreatedAtDesc()
        .findAll();

    return [
      for (final record in records)
        _summarize(record.id, _decode(record)),
    ];
  }

  @override
  Future<MatchAnalytics> loadAnalytics(int matchId) async {
    final record = await isar.matchRecords.get(matchId);
    if (record == null) {
      throw StateError('loadAnalytics: no stored match with id $matchId');
    }
    if (!record.finished) {
      // The only role-exposing read, and only once the match is over (inv. 6).
      throw StateError('loadAnalytics: match $matchId is still in progress');
    }
    final match = _decode(record);
    return MatchAnalytics(
      matchId: matchId,
      playerNames: {for (final p in match.players) p.seat: p.name},
      data: AnalyticsBuilder.build(match),
    );
  }

  @override
  Future<void> deleteMatch(int matchId) async {
    await isar.writeTxn(() async {
      await isar.matchRecords.delete(matchId);
    });
  }

  @override
  Future<MatchSettings> loadDefaultSettings() async {
    final record = await isar.settingsRecords.get(SettingsRecord.singletonId);
    // An empty payload means the row exists only to carry a flag — see
    // [SettingsRecord]. Treat it exactly like a missing row.
    if (record == null || record.payload.isEmpty) {
      return const MatchSettings.defaults();
    }
    return MatchCodec.decodeSettings(
      jsonDecode(record.payload) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> saveDefaultSettings(MatchSettings settings) async {
    final payload = jsonEncode(MatchCodec.encodeSettings(settings));
    await _updateSettingsRow((record) => record..payload = payload);
  }

  @override
  Future<bool> hasSeenOnboarding() async {
    try {
      final record = await isar.settingsRecords.get(SettingsRecord.singletonId);
      return record?.onboardingSeen ?? false;
    } catch (_) {
      // Contract: never throw here. Storage that cannot be read on the very
      // first frame must degrade to "show the deck", not to a crash.
      return false;
    }
  }

  @override
  Future<void> markOnboardingSeen() async {
    await _updateSettingsRow((record) => record..onboardingSeen = true);
  }

  /// Read-modify-write of the app singleton row.
  ///
  /// The row carries two independent things (see [SettingsRecord]), so a writer
  /// that constructs a fresh record clobbers whichever one it does not set.
  /// Loading inside the transaction is what makes the two writers safe to
  /// interleave; doing it outside would reintroduce the same lost update with a
  /// smaller window.
  Future<void> _updateSettingsRow(
    SettingsRecord Function(SettingsRecord) change,
  ) async {
    await isar.writeTxn(() async {
      final existing =
          await isar.settingsRecords.get(SettingsRecord.singletonId) ??
              (SettingsRecord()..id = SettingsRecord.singletonId);
      await isar.settingsRecords.put(change(existing));
    });
  }

  /// Decodes a record, restoring the row id onto the match.
  ///
  /// The id matters: `persistStep` uses it to overwrite the same row instead of
  /// appending a new one on every step.
  Match _decode(MatchRecord record) {
    final match =
        MatchCodec.decode(jsonDecode(record.payload) as Map<String, dynamic>);
    return match.id == record.id ? match : match.copyWith(id: record.id);
  }

  static MatchSummary _summarize(int id, Match match) => MatchSummary(
        id: id,
        createdAt: match.createdAt,
        playerNames: [for (final p in match.players) p.name],
        winner: match.outcome?.winner,
        nights: AnalyticsBuilder.build(match).nightsPlayed,
      );
}
