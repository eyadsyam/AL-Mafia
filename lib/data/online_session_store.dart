import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The non-secret pointer needed to rejoin an online room after an app restart.
/// It deliberately contains no role, action, voice credential, or auth token.
class OnlineRoomResume {
  final String roomId;
  final String code;

  const OnlineRoomResume({required this.roomId, required this.code});

  Map<String, String> toJson() => {'roomId': roomId, 'code': code};

  static OnlineRoomResume? fromJson(Object? value) {
    if (value is! Map) return null;
    final roomId = value['roomId'];
    final code = value['code'];
    if (roomId is! String || roomId.isEmpty || code is! String) return null;
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalized)) return null;
    return OnlineRoomResume(roomId: roomId, code: normalized);
  }
}

class OnlineSessionStore {
  static const key = 'mafia.onlineActiveRoom.v1';

  /// The one write this store makes, replaceable so a test can make the
  /// device's storage refuse without a platform to refuse on. The real
  /// preferences plugin reports a failed write as `false`, and that is what
  /// `save` turns into the error the session shows.
  @visibleForTesting
  static Future<bool> Function(String key, String value)? writeOverride;

  static Future<OnlineRoomResume?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return OnlineRoomResume.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(OnlineRoomResume resume) async {
    final value = jsonEncode(resume.toJson());
    final written = writeOverride != null
        ? await writeOverride!(key, value)
        : await (await SharedPreferences.getInstance()).setString(key, value);
    if (!written) throw StateError('Online room storage unavailable');
  }

  static Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(key);
    } catch (_) {
      // Storage cleanup is best effort; it must never interrupt the match.
    }
  }
}
