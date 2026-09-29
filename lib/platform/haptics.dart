import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized haptic feedback API.
class Haptics {
  /// Light selection click for UI interactions.
  static void select() {
    HapticFeedback.selectionClick();
  }

  /// Light impact for confirmations or state changes.
  static void confirm() {
    HapticFeedback.lightImpact();
  }

  static const _channel = MethodChannel('mafia_master/haptics');

  /// A long pattern (ms: wait, buzz, pause, buzz …), e.g.
  /// `InviteTokens.longVibration`. Android plays it as one waveform through
  /// the platform vibrator; elsewhere (or if that fails) each buzz is a
  /// heavy impact at its start. Never throws.
  static Future<void> pattern(List<int> timings) async {
    if (timings.length < 2) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final done = await _channel.invokeMethod<bool>('vibrate', timings);
        if (done == true) return;
      } catch (_) {}
    }
    for (var i = 0; i < timings.length; i++) {
      if (i.isOdd) {
        unawaited(HapticFeedback.heavyImpact());
      }
      await Future<void>.delayed(Duration(milliseconds: timings[i]));
    }
  }
}
