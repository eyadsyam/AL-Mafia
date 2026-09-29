import 'package:shared_preferences/shared_preferences.dart';

import '../../transport/online_backend.dart';

/// The sharer's referral code carried by a room link
/// (`/join/<ROOM>?ref=<CODE>`, see `RoomInvite.webLink`).
///
/// Opening the link remembers the code on this device; the first room this
/// player then enters records it on the server (`invite_redeem`), where the
/// existing settlement pays both sides once the new player finishes their
/// first online match. A code the server answered — recorded, unknown, or
/// refused (self, not new, expired, already used) — is forgotten; a code that
/// never reached the server waits for the next room. Typing the code in the
/// vault stays the manual fallback.
abstract final class RoomReferral {
  static const storageKey = 'room_referral_pending_v1';

  static Future<void> remember(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, code);
    } catch (_) {}
  }

  static Future<String?> pending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(storageKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> forget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {}
  }

  /// Records [fromLink] (or a code a previous link left waiting) after the
  /// player has taken a seat. Never load-bearing: every failure is silent.
  ///
  /// Takes the backend factory rather than a `ref`, because the entry screen
  /// that calls it is gone by the time the answer arrives.
  static Future<void> redeemAfterJoin(
    Future<OnlineBackend> Function() backend, {
    String? fromLink,
  }) async {
    final code = fromLink ?? await pending();
    if (code == null) return;
    try {
      final server = await backend();
      await server.ensureSession();
      await server.call('economy', {'action': 'invite_redeem', 'code': code});
      await forget();
    } on BackendException {
      await forget();
    } catch (_) {
      // Unreachable: the code waits for the next room.
    }
  }
}
