import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_profile.dart' show ProfileStore;

/// Public finished-match summaries only: never a private action, and no role
/// but this device's own, which the result showed to the whole table.
class OnlineMatchHistory {
  static const storageKey = 'mafia.onlineHistory.v1';

  /// See `OnlineSessionStore.writeOverride`.
  @visibleForTesting
  static Future<bool> Function(String key, String value)? writeOverride;

  static String _key(String userId) => '$storageKey.$userId';

  static Future<List<Map<String, dynamic>>> load({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final owner =
          userId ?? prefs.getString(ProfileStore.activeAccountKey) ?? 'guest';
      final key = _key(owner);
      // A legacy device-wide history is claimed once by the first signed-in
      // account that reads it. Guest reads leave it available for that account.
      if (owner != 'guest' && prefs.containsKey(storageKey)) {
        final old = prefs.getString(storageKey);
        if (old != null) {
          List existing;
          List legacy;
          try {
            existing = jsonDecode(prefs.getString(key) ?? '[]') as List;
          } catch (_) {
            existing = [];
          }
          try {
            legacy = jsonDecode(old) as List;
          } catch (_) {
            legacy = [];
          }
          final ids = existing
              .whereType<Map>()
              .map((row) => row['roomId'])
              .toSet();
          final merged = [
            ...existing,
            ...legacy.whereType<Map>().where(
              (row) => !ids.contains(row['roomId']),
            ),
          ];
          if (!await prefs.setString(key, jsonEncode(merged))) {
            throw StateError('History migration unavailable');
          }
        }
        await prefs.remove(storageKey);
      }
      final raw = jsonDecode(prefs.getString(key) ?? '[]') as List;
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
    } on StateError {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  static Future<void> save({
    String? userId,
    required String roomId,
    required List<String> names,
    required String winner,
    required int days,

    /// This device's own role and whether its side won: public at the
    /// result, kept for the profile's record. Older rows have neither.
    String? role,
    bool? won,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final owner =
        userId ?? prefs.getString(ProfileStore.activeAccountKey) ?? 'guest';
    final rows = await load(userId: owner);
    if (rows.any((row) => row['roomId'] == roomId)) return;
    rows.insert(0, {
      'roomId': roomId,
      'names': names,
      'winner': winner,
      'days': days,
      'role': ?role,
      'won': ?won,
    });
    final value = jsonEncode(rows.take(200).toList());
    final written = writeOverride != null
        ? await writeOverride!(_key(owner), value)
        : await prefs.setString(_key(owner), value);
    if (!written) throw StateError('History storage unavailable');
  }
}
