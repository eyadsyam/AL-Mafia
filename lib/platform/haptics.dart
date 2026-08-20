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
}
