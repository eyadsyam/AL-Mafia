import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'crash_reporting.dart' show CrashErrorRecorder;

/// Tests never run `main()`, the only caller, so no environment probe is
/// needed here (and none that would import `dart:io`, which the offline
/// guarantee test keeps out of lib/).
bool isTestEnvironment() => false;

Future<CrashErrorRecorder> createCrashRecorder() async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  return (error, stack, {required fatal}) =>
      crashlytics.recordError(error, stack, fatal: fatal);
}
