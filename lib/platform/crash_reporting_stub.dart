import 'crash_reporting.dart' show CrashErrorRecorder;

bool isTestEnvironment() => true;

Future<CrashErrorRecorder> createCrashRecorder() async =>
    throw UnsupportedError('Crash reporting is Android only');
