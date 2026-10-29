import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Release resource shrinking deletes every resource the Kotlin/Java code does
/// not reference. The push icon and the invite sound are named only by
/// strings (the FCM payload, the channel, the local-notifications init), so
/// keep.xml must list them: without the icon the push service failed to start
/// in every release build and Android push was silently off (2026-10-09).
void main() {
  test('release keeps the push icon and the invite sound', () {
    final keep = File(
      'android/app/src/main/res/raw/keep.xml',
    ).readAsStringSync();
    expect(keep, contains('@drawable/ic_stat_mafia'));
    expect(keep, contains('@raw/invite_knock'));
    final push = File(
      'lib/platform/push/firebase_push_service.dart',
    ).readAsStringSync();
    expect(push, contains("'ic_stat_mafia'"));
  });
}
