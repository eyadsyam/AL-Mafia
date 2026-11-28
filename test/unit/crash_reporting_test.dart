import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/crash_reporting.dart';

void main() {
  late FlutterExceptionHandler? originalFlutterHandler;
  late bool Function(Object, StackTrace)? originalPlatformHandler;

  setUp(() {
    originalFlutterHandler = FlutterError.onError;
    originalPlatformHandler = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    resetCrashReportingForTest();
    FlutterError.onError = originalFlutterHandler;
    PlatformDispatcher.instance.onError = originalPlatformHandler;
  });

  test(
    'web and unsupported platforms leave error handlers untouched',
    () async {
      var calls = 0;
      Future<void> record(
        Object _,
        StackTrace __, {
        required bool fatal,
      }) async {
        calls++;
      }

      await installCrashReporting(
        recorder: record,
        targetPlatform: TargetPlatform.android,
        isWeb: true,
        isTest: false,
      );
      expect(FlutterError.onError, same(originalFlutterHandler));
      expect(
        PlatformDispatcher.instance.onError,
        same(originalPlatformHandler),
      );

      await installCrashReporting(
        recorder: record,
        targetPlatform: TargetPlatform.iOS,
        isWeb: false,
        isTest: false,
      );
      expect(FlutterError.onError, same(originalFlutterHandler));
      expect(
        PlatformDispatcher.instance.onError,
        same(originalPlatformHandler),
      );
      expect(calls, 0);
    },
  );

  test('Android forwarding preserves the previous Flutter handler', () async {
    final reported = <Object>[];
    var previousCalls = 0;
    FlutterError.onError = (_) => previousCalls++;

    await installCrashReporting(
      recorder: (error, _, {required fatal}) async {
        expect(fatal, isTrue);
        reported.add(error);
      },
      targetPlatform: TargetPlatform.android,
      isWeb: false,
      isTest: false,
    );

    final error = StateError('test error');
    FlutterError.reportError(FlutterErrorDetails(exception: error));
    await Future<void>.delayed(Duration.zero);
    expect(previousCalls, 1);
    expect(reported, [same(error)]);
  });

  test('non-fatal reports do nothing before installation', () async {
    await reportNonFatal(StateError('ignored'), StackTrace.current);
  });

  test('non-fatal reports reach the installed recorder', () async {
    final reported = <(Object, bool)>[];
    await installCrashReporting(
      recorder: (error, _, {required fatal}) async {
        reported.add((error, fatal));
      },
      targetPlatform: TargetPlatform.android,
      isWeb: false,
      isTest: false,
    );

    final error = StateError('persistStep retry failed: IsarError');
    await reportNonFatal(error, StackTrace.current);
    expect(reported, hasLength(1));
    expect(reported.single.$1, same(error));
    expect(reported.single.$2, isFalse);
  });

  test('a failing recorder never throws from a non-fatal report', () async {
    await installCrashReporting(
      recorder: (_, _, {required fatal}) async => throw Exception('offline'),
      targetPlatform: TargetPlatform.android,
      isWeb: false,
      isTest: false,
    );
    await expectLater(
      reportNonFatal(StateError('x'), StackTrace.current),
      completes,
    );
  });
}
