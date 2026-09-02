import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where whisper bodies live, apart from everything else about a match.
///
/// The interface is deliberately narrow: put a body, read a body, drop a
/// match's bodies. There is no "list every body" — a caller that wants the
/// whole set has to name the match, and the post-game reveal is the only caller
/// that does, behind «كشف محتوى الهمسات» (off by default).
///
/// The graph — who wrote to whom, on which day — is not here. It is in the
/// event log, where the whole table can read it. See `WhisperMeta`.
abstract class WhisperStore {
  /// Stores (or replaces) one body.
  Future<void> put({
    required int matchId,
    required String whisperId,
    required String body,
  });

  /// The body, or null if it was never written or has been purged.
  Future<String?> read({required int matchId, required String whisperId});

  /// Every body of one match, keyed by whisper id.
  Future<Map<String, String>> readAll(int matchId);

  /// Deletes every body of one match.
  Future<void> purge(int matchId);
}

/// In-memory store. The default in tests and the fallback when Isar cannot be
/// opened — a match with no whisper persistence still plays; it only forgets
/// the bodies across a force-quit.
class MemoryWhisperStore implements WhisperStore {
  final Map<int, Map<String, String>> _bodies = {};

  @override
  Future<void> put({
    required int matchId,
    required String whisperId,
    required String body,
  }) async {
    (_bodies[matchId] ??= {})[whisperId] = body;
  }

  @override
  Future<String?> read({
    required int matchId,
    required String whisperId,
  }) async =>
      _bodies[matchId]?[whisperId];

  @override
  Future<Map<String, String>> readAll(int matchId) async =>
      Map.unmodifiable(_bodies[matchId] ?? const {});

  @override
  Future<void> purge(int matchId) async {
    _bodies.remove(matchId);
  }
}

/// Overridden in `main` with the Isar-backed store once the database is open.
final whisperStoreProvider = Provider<WhisperStore>(
  (ref) => MemoryWhisperStore(),
);
