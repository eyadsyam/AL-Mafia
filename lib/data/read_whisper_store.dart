import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local read receipts for the one online room this device is using.
class ReadWhisperStore {
  static const _key = 'mafia.readWhispers.v1';
  static const _limit = 128;

  static Future<Set<String>> load(String roomId, String userId) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return {};
      final record = jsonDecode(raw);
      if (record is! Map ||
          record['roomId'] != roomId ||
          record['userId'] != userId) {
        return {};
      }
      final ids = record['ids'];
      if (ids is! List) return {};
      return ids.whereType<String>().take(_limit).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(
    String roomId,
    String userId,
    Set<String> ids,
  ) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode({
          'roomId': roomId,
          'userId': userId,
          'ids': ids
              .toList()
              .skip(ids.length > _limit ? ids.length - _limit : 0)
              .toList(),
        }),
      );
    } catch (_) {
      // A storage failure must not interrupt a match.
    }
  }

  static Future<void> clear(String roomId, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final record = jsonDecode(raw);
        if (record is Map &&
            record['roomId'] == roomId &&
            record['userId'] == userId) {
          await prefs.remove(_key);
        }
      }
    } catch (_) {}
  }
}
