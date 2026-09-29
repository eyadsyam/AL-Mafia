import 'package:flutter/widgets.dart';

/// A deliberately cheap launch-time classification. It performs no I/O and
/// allocates no probes; callers provide the product's pixel budget token.
abstract final class DeviceClass {
  static bool? debugLowEndOverride;

  static bool isLowEnd({required int maxPhysicalPixels}) {
    final override = debugLowEndOverride;
    if (override != null) return override;
    // Through the binding, so a test's view size is the size classified.
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return false;
    final size = view.physicalSize;
    if (size.isEmpty) return false;
    return size.width * size.height <= maxPhysicalPixels;
  }
}
