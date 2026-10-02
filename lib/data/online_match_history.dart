import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Public finished-match summaries only. Never stores roles or private actions.
class OnlineMatchHistory {
  static const storageKey = 'mafia.onlineHistory.v1';

  /// See `OnlineSessionStore.writeOverride`.
  @visibleForTesting
  static Future<bool> Function(String key, String value)? writeOverride;

  static Future<List<Map<String, dynamic>>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonDecode(prefs.getString(storageKey) ?? '[]') as List;
      return raw
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where(
            (row) =>
                row['roomId'] is String &&
                row['names'] is List &&
                (row['winner'] == 'mafia' || row['winner'] == 'town') &&
                row['days'] is int,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save({
    required String roomId,
    required List<String> names,
    required String winner,
    required int days,
  }) async {
    final rows = await load();
    if (rows.any((row) => row['roomId'] == roomId)) return;
    rows.insert(0, {
      'roomId': roomId,
      'names': names,
      'winner': winner,
      'days': days,
    });
    final value = jsonEncode(rows.take(200).toList());
    final written = writeOverride != null
        ? await writeOverride!(storageKey, value)
        : await (await SharedPreferences.getInstance()).setString(
            storageKey,
            value,
          );
    if (!written) throw StateError('History storage unavailable');
  }
}
