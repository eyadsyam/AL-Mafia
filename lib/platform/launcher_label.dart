import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;

/// What happened to the name under the Android launcher icon.
enum LauncherLabelResult {
  /// Already matches, or switched without touching the running screen.
  applied,

  /// Will change after the game is closed. Switching now would close it.
  pending,

  /// Not Android, or the platform refused. Nothing to tell the player.
  unsupported,
}

/// Makes the name under the Android launcher icon follow the in-game language.
///
/// Android's per-app language does not reach the launcher's label, so the
/// manifest carries one launcher alias per language and `MainActivity.kt`
/// switches which one is enabled. Disabling the alias the game was opened
/// through finishes the running activity, so that switch is left pending and
/// applied natively once the game's screen is gone. Asked at every start (so
/// an interrupted switch heals) and whenever the player changes language.
///
/// Cosmetic, and never allowed to fail loudly: web, desktop, tests and a
/// platform that refuses all come back [LauncherLabelResult.unsupported].
class LauncherLabel {
  static const _channel = MethodChannel('mafia_master/launcher');

  static Future<LauncherLabelResult> apply(String languageCode) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return LauncherLabelResult.unsupported;
    }
    try {
      final answer = await _channel.invokeMethod<String>(
        'setLanguage',
        languageCode,
      );
      return switch (answer) {
        'applied' => LauncherLabelResult.applied,
        'pending' => LauncherLabelResult.pending,
        _ => LauncherLabelResult.unsupported,
      };
    } catch (_) {
      return LauncherLabelResult.unsupported;
    }
  }
}
