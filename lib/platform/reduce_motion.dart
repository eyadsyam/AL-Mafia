import 'package:flutter/material.dart';

/// Detect if reduced motion is enabled on the device.
class ReduceMotion {
  static bool of(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }
}
