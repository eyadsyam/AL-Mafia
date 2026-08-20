import 'dart:convert';

import 'package:mafia_master/engine/analytics_builder.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';

import 'match_codec.dart';
import 'match_repository.dart';
import 'repository_types.dart';
import 'resume_resolver.dart';

/// Backing store for [MemoryMatchRepository], kept separate from the repository
/// itself.
///
/// That separation is the point: a test can build a repository, write to it,
/// throw the repository away (simulating a process death) and build a *new*
/// repository over the same store — which is precisely the crash-resume path,
/// minus the platform channel (T7).
class MemoryMatchStore {
  /// matchId -> encoded match JSON.
  final Map<int, String> matches = {};

  /// Encoded default settings, or null if none saved.
  String? defaultSettings;

  void clear() {
    matches.clear();
    defaultSettings = null;
  }
}

/// A [MatchRepository] that keeps everything in a [MemoryMatchStore].
///
/// Used by the test suite, and as the app's fallback when the Isar native
/// library is unavailable. Writes go through [MatchCodec] and are stored as
/// encoded strings rather than live objects, so a caller cannot mutate stored
/// state by holding onto the object it wrote — the same guarantee a real
/// database gives.
class MemoryMatchRepository implements MatchRepository {
  final MemoryMatchStore store;

  MemoryMatchRepository(this.store);

  @override
  Future<void> persistStep(Match match) async {
    // Encode fully before touching the store: a throw mid-encode must not leave
    // a half-written row behind (inv. 1).
    final encoded = jsonEncode(MatchCodec.encode(match));
    store.matches[match.id] = encoded;
  }

  @override
  Future<Match?> loadActiveMatch() async {
    Match? newest;
    for (final encoded in store.matches.values) {
      final match = _decode(encoded);
      if (!ResumeResolver.isActive(match)) continue;
      if (newest == null || match.createdAt.isAfter(newest.createdAt)) {
        newest = match;
      }
    }
    return newest;
  }

  @override
  Future<ResumeTarget> resolveResume(Match match) async =>
      ResumeResolver.resolve(match);

  @override
  Future<List<MatchSummary>> listHistory() async {
    final finished = <Match>[
      for (final encoded in store.matches.values)
        if (!ResumeResolver.isActive(_decode(encoded))) _decode(encoded),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return [for (final m in finished) _summarize(m)];
  }

  @override
  Future<MatchAnalytics> loadAnalytics(int matchId) async {
    final encoded = store.matches[matchId];
    if (encoded == null) {
      throw StateError('loadAnalytics: no stored match with id $matchId');
    }
    final match = _decode(encoded);
    if (ResumeResolver.isActive(match)) {
      // Analytics is the only role-exposing read, and only for finished
      // matches (inv. 6). Serving it mid-match would leak every role at once.
      throw StateError('loadAnalytics: match $matchId is still in progress');
    }
    return MatchAnalytics(
      matchId: matchId,
      playerNames: {for (final p in match.players) p.seat: p.name},
      data: AnalyticsBuilder.build(match),
    );
  }

  @override
  Future<void> deleteMatch(int matchId) async {
    store.matches.remove(matchId);
  }

  @override
  Future<MatchSettings> loadDefaultSettings() async {
    final encoded = store.defaultSettings;
    if (encoded == null) return const MatchSettings.defaults();
    return MatchCodec.decodeSettings(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> saveDefaultSettings(MatchSettings settings) async {
    store.defaultSettings = jsonEncode(MatchCodec.encodeSettings(settings));
  }

  static Match _decode(String encoded) =>
      MatchCodec.decode(jsonDecode(encoded) as Map<String, dynamic>);

  static MatchSummary _summarize(Match match) => MatchSummary(
        id: match.id,
        createdAt: match.createdAt,
        playerNames: [for (final p in match.players) p.name],
        winner: match.outcome?.winner,
        nights: AnalyticsBuilder.build(match).nightsPlayed,
      );
}
