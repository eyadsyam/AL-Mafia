import 'package:flutter/services.dart' show Clipboard, ClipboardData;

/// Putting a room code on the clipboard, and nothing else.
///
/// ## Why this is a file rather than two lines in the lobby
///
/// `package:flutter/services.dart` is banned throughout `lib/ui` — not because
/// the clipboard is dangerous, but because that import is what makes the
/// platform's haptic API reachable, and a buzz fired from a screen is a channel
/// that can differ by role (L-10, doc 05). The ban is a proxy for the real
/// rule, and the way to keep a proxy honest is to keep the exceptions few,
/// named, and somewhere a test can see them.
///
/// The `show` clause is the other half of that: this file cannot reach the
/// haptic API even by accident, which is what the guard in
/// `test/platform/haptics_call_site_test.dart` checks before it lets the
/// exemption stand.
///
/// So the clipboard lives here, next to [Haptics], with the same shape: one
/// verb, no state, and nothing in it that could ever depend on what somebody
/// drew.
abstract final class AppClipboard {
  /// Copies [text]. Silent on failure: a clipboard that refuses is a platform
  /// quirk, and the code is still on screen to be read out.
  static Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
