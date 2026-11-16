import 'dart:async';

import 'package:flutter/foundation.dart';

import 'crash_reporting_stub.dart'
    if (dart.library.io) 'crash_reporting_io.dart'
    as platform;

typedef CrashErrorRecorder =
    Future<void> Function(
      Object error,
      StackTrace stack, {
      required bool fatal,
    });

/// Installs Android crash forwarding after Firebase is ready. The optional
/// recorder and guards keep the handlers testable without a Firebase channel.
Future<void> installCrashReporting({
  CrashErrorRecorder? recorder,
  TargetPlatform? targetPlatform,
  bool? isWeb,
  bool? isTest,
}) async {
  if ((isWeb ?? kIsWeb) ||
      (targetPlatform ?? defaultTargetPlatform) != TargetPlatform.android ||
      (isTest ?? platform.isTestEnvironment())) {
    return;
  }

  final record = recorder ?? await platform.createCrashRecorder();
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      record(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: true,
      ),
    );
    previousFlutterHandler?.call(details);
  };

  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(record(error, stack, fatal: true));
    return previousPlatformHandler?.call(error, stack) ?? true;
  };
}
