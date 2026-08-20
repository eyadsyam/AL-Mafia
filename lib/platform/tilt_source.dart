import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// How far the phone is leaning, as a pair of −1..1 fractions.
///
/// `x` is positive when the right edge is lowered, `y` when the top edge is
/// lowered — the direction a marble would roll. Both are clamped, so a phone
/// turned fully on its side reads 1.0 rather than continuing to climb.
@immutable
class Tilt {
  final double x;
  final double y;

  const Tilt(this.x, this.y);

  static const Tilt level = Tilt(0, 0);

  @override
  bool operator ==(Object other) =>
      other is Tilt && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Tilt(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Where tilt comes from. The only file that names the sensor package.
///
/// Same seam as [AudioBackend], for the same reason and with the same test
/// keeping it honest: parallax is a decoration, and a decoration should not be
/// able to spread a platform dependency through the widget layer.
abstract class TiltSource {
  /// A stream of readings, or an empty stream where there is no sensor.
  ///
  /// Callers must handle the empty case rather than waiting for a first value:
  /// desktop, web, the emulator with sensors off, and any phone whose
  /// accelerometer the OS declines to hand over all produce nothing at all,
  /// and a screen that waits for a reading before laying itself out would
  /// simply never appear.
  Stream<Tilt> get tilt;
}

/// Never reports anything. The default, and what tests get.
class LevelTiltSource implements TiltSource {
  const LevelTiltSource();

  @override
  Stream<Tilt> get tilt => const Stream<Tilt>.empty();
}

/// The device accelerometer, normalised and smoothed.
class SensorTiltSource implements TiltSource {
  const SensorTiltSource();

  /// Readings per second. 30 is well under a 60fps frame budget and far more
  /// than a hand-held lean needs; the sensor's own rate is typically much
  /// higher and sampling all of it would burn battery for motion nobody sees.
  static const Duration _interval = Duration(milliseconds: 33);

  /// Gravity is ~9.81 m/s². Dividing by half of it means a lean of about 30°
  /// reaches the full parallax range, which is roughly the most someone tilts a
  /// phone they are still trying to read.
  static const double _fullScale = 4.9;

  /// Exponential smoothing factor. The accelerometer is noisy enough that raw
  /// values make the cards jitter visibly while the phone sits still on a
  /// table; this trades a little latency, which nobody notices in a parallax,
  /// for stillness, which everybody notices.
  static const double _smoothing = 0.12;

  @override
  Stream<Tilt> get tilt {
    double? x, y;
    return accelerometerEventStream(samplingPeriod: _interval)
        .map((event) {
          // The accelerometer reports the reaction to gravity, so the sign is
          // inverted relative to "which way is it leaning".
          final rawX = (-event.x / _fullScale).clamp(-1.0, 1.0);
          final rawY = (event.y / _fullScale).clamp(-1.0, 1.0);
          x = x == null ? rawX : x! + (rawX - x!) * _smoothing;
          y = y == null ? rawY : y! + (rawY - y!) * _smoothing;
          return Tilt(x!, y!);
        })
        // A sensor that errors mid-stream is a phone that no longer has one.
        // The parallax stops where it was rather than taking the screen down.
        .handleError((Object _) {});
  }
}
