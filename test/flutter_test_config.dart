import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every test file runs through here.
///
/// The permission plugin has no native side under `flutter test`: an
/// unanswered call waits forever. Entering an online room now asks for the
/// microphone first, so every room test would hang on that call. The phone
/// answers "allowed" here; a test about the question itself overrides
/// `microphoneAccessProvider` with its own fake.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async => switch (call.method) {
            // PermissionStatus.granted travels as 1.
            'checkPermissionStatus' => 1,
            'requestPermissions' => <int, int>{
              for (final p in (call.arguments as List).cast<int>()) p: 1,
            },
            _ => null,
          },
        );
  });
  await testMain();
}
