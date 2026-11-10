import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The seats this device voted for in one online room, kept on this device
/// only, for the profile's «دقة تصويتك» once the room's result makes every
/// role public.
///
/// One entry per ballot (day and round): a changed vote replaces the earlier
/// one, a re-vote round is its own ballot. An abstention is kept as null so a
/// ballot is never counted twice. Never sent anywhere; read once at the result
/// and cleared.
abstract final class OwnVoteLog {
  static const _prefix = 'mafia.ownVotes.v1.';

  static Future<void> record({
    required String roomId,
    required int day,
    required int round,
    required int? targetSeat,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$roomId';
      final log = _read(prefs.getString(key));
      log['$day:$round'] = targetSeat;
      await prefs.setString(key, jsonEncode(log));
    } catch (_) {
      // A missed ballot only makes the record a little shorter.
    }
  }

  /// The seats voted for (abstentions left out), and the log is forgotten.
  static Future<List<int>> take(String roomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$roomId';
      final log = _read(prefs.getString(key));
      await prefs.remove(key);
      return [
        for (final seat in log.values)
          if (seat != null) seat,
      ];
    } catch (_) {
      return const [];
    }
  }

  static Map<String, int?> _read(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && (entry.value == null || entry.value is int))
            entry.key as String: entry.value as int?,
      };
    } catch (_) {
      return {};
    }
  }
}

/// «دقة تصويتك» across this player's kept online matches: votes cast as a
/// town player, and how many of them landed on a mafia seat. Null below
/// [minimumVotes], where a percentage would say more about luck than about
/// the player.
({int votes, int onMafia})? voteAccuracy(
  List<Map<String, dynamic>> rows, {
  int minimumVotes = 5,
}) {
  var votes = 0;
  var onMafia = 0;
  for (final row in rows) {
    final v = row['votes'];
    final m = row['onMafia'];
    if (v is int && m is int && v > 0 && m >= 0 && m <= v) {
      votes += v;
      onMafia += m;
    }
  }
  if (votes < minimumVotes) return null;
  return (votes: votes, onMafia: onMafia);
}
