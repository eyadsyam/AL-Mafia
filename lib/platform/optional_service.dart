import 'package:flutter/foundation.dart';

/// Runs a service the game can live without (ads, purchases) at startup.
///
/// A failure is reported, never rethrown: an ad SDK or a store connection that
/// cannot start must not take the game down or hold its first screen. The
/// service itself stays retryable, because each one resets its own state on
/// failure and is started again the next time a player reaches for it.
///
/// Only the error's type is logged. Messages from these SDKs can carry device
/// or account detail, and the log is readable on a connected device.
Future<bool> runOptionalService(
  String name,
  Future<void> Function() start,
) async {
  try {
    await start();
    return true;
  } catch (error) {
    debugPrint(
      'optional service "$name" failed to start: ${error.runtimeType}',
    );
    return false;
  }
}
