import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Prints frame-time percentiles, on demand, from inside the engine.
///
/// ## Why this exists rather than `adb shell dumpsys gfxinfo`
///
/// `gfxinfo` reads the Android view hierarchy's rendering stats. Flutter does
/// not draw into that hierarchy — it renders to its own surface — so `gfxinfo`
/// reports one frame and 100% jank for an app that is running perfectly. Every
/// number it gives for a Flutter app is meaningless, and it is meaningless in a
/// way that looks like a catastrophic result, which is worse than no number.
///
/// [SchedulerBinding.addTimingsCallback] is the engine's own measurement: build
/// time on the UI thread and raster time on the GPU thread, per frame, as the
/// engine saw them.
///
/// ## Off unless asked for
///
/// Gated on a compile-time define so it is tree-shaken out of a normal build:
///
///     flutter run --profile --dart-define=FRAME_REPORT=true
///
/// It reports on a rolling window rather than cumulatively, because the
/// interesting question is "is *this* screen smooth", not "what was the average
/// since launch" — and the launch frames, which include decoding every image on
/// the home screen, would dominate a cumulative average forever.
abstract final class FrameReport {
  static const bool enabled =
      bool.fromEnvironment('FRAME_REPORT', defaultValue: false);

  /// Frames per report. At 60fps this is a report every ~5 seconds.
  static const int _window = 300;

  static final List<FrameTiming> _frames = [];
  static bool _installed = false;

  /// Starts reporting, if [enabled]. Safe to call unconditionally.
  static void install() {
    if (!enabled || _installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    // `debugPrint` rather than `dart:developer`'s `log`: this is read off
    // `adb logcat`, and only `debugPrint` reaches it.
    debugPrint('FRAMES armed: reporting every $_window frames');
  }

  static void _onTimings(List<FrameTiming> timings) {
    _frames.addAll(timings);
    if (_frames.length < _window) return;

    final build = _frames.map((f) => f.buildDuration.inMicroseconds).toList()
      ..sort();
    final raster = _frames.map((f) => f.rasterDuration.inMicroseconds).toList()
      ..sort();
    final total = _frames.map((f) => f.totalSpan.inMicroseconds).toList()
      ..sort();

    // A frame misses 60fps when the *total* span exceeds 16.67ms — build and
    // raster overlap across frames, so summing them would over-report.
    final missed = total.where((us) => us > 16667).length;

    debugPrint(
      'FRAMES n=${_frames.length}  '
      'build p50=${_ms(build, 50)} p90=${_ms(build, 90)} p99=${_ms(build, 99)}  '
      'raster p50=${_ms(raster, 50)} p90=${_ms(raster, 90)} p99=${_ms(raster, 99)}  '
      'total p50=${_ms(total, 50)} p90=${_ms(total, 90)} p99=${_ms(total, 99)}  '
      'over-16.7ms=$missed (${(missed * 100 / _frames.length).toStringAsFixed(1)}%)',
    );
    _frames.clear();
  }

  static String _ms(List<int> sortedMicros, int percentile) {
    if (sortedMicros.isEmpty) return '-';
    final i = ((sortedMicros.length - 1) * percentile / 100).round();
    return (sortedMicros[i] / 1000).toStringAsFixed(1);
  }
}
