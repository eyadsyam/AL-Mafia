import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// T078 / FR-029 — the app is offline by construction, and stays portrait.
///
/// ## Why this is tested rather than trusted
///
/// "Works offline" is not a feature you can see in the UI; it is the absence of
/// something. A single dependency that phones home — an analytics SDK, a font
/// loader, a crash reporter — would satisfy every other test in this suite
/// while quietly breaking the promise that a group can play in a basement with
/// no signal. The only durable check is to assert that the shipped app declares
/// no network permission and that nothing in the source opens a socket.
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    return file.readAsStringSync();
  }

  group('FR-029 offline guarantee', () {
    test('the release Android manifest declares no INTERNET permission', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest.contains('android.permission.INTERNET'), isFalse,
          reason: 'the shipped app must not be able to reach the network');
      expect(manifest.contains('android.permission.ACCESS_NETWORK_STATE'),
          isFalse);
    });

    test('the debug manifest may keep INTERNET, and that is fine', () {
      // Flutter's tooling needs it for hot reload. It is a debug-only overlay
      // and is not merged into a release build — asserting it is *present*
      // documents that the absence above was deliberate, not accidental.
      final debugManifest = read('android/app/src/debug/AndroidManifest.xml');
      expect(debugManifest.contains('android.permission.INTERNET'), isTrue);
    });

    test('no source file opens a network connection', () {
      const networkApis = [
        'dart:io\'',
        'HttpClient',
        'Socket.connect',
        'package:http/',
        'WebSocket',
      ];

      final offenders = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        for (final api in networkApis) {
          if (source.contains(api)) {
            offenders.add('${file.path} → $api');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'these files can reach the network: $offenders');
    });

    test('no dependency is a networking package', () {
      final pubspec = read('pubspec.yaml');
      // Read only the dependency blocks, so a package name mentioned in a
      // comment does not trip the check.
      const networkPackages = ['http:', 'dio:', 'web_socket_channel:', 'grpc:'];
      for (final package in networkPackages) {
        expect(pubspec.contains('\n  $package'), isFalse,
            reason: '$package is a networking dependency');
      }
    });
  });

  group('platform configuration', () {
    test('Android is portrait-only and targets API 26+', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest.contains('android:screenOrientation="portrait"'), isTrue);

      final gradle = read('android/app/build.gradle.kts');
      expect(gradle.contains('minSdk = 26'), isTrue,
          reason: 'the minimum Android version is API 26 (T001)');
    });

    test('iOS is portrait-only on both iPhone and iPad', () {
      final plist = read('ios/Runner/Info.plist');
      // A phone that rotates mid-turn re-lays-out the night screen in front of
      // whoever is nearby, which is exactly the exposure the design avoids.
      expect(plist.contains('UIInterfaceOrientationLandscapeLeft'), isFalse,
          reason: 'landscape is still allowed on iOS');
      expect(plist.contains('UIInterfaceOrientationLandscapeRight'), isFalse);
      expect(plist.contains('UIInterfaceOrientationPortraitUpsideDown'), isFalse);
      expect(plist.contains('UIInterfaceOrientationPortrait'), isTrue);
    });

    test('the app is labelled for players, not for developers', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest.contains('android:label="mafia_master"'), isFalse,
          reason: 'the launcher would show the package name');

      final plist = read('ios/Runner/Info.plist');
      expect(plist.contains('<string>Mafia Master</string>'), isTrue);
    });

    test('a launcher icon is declared', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest.contains('android:icon='), isTrue);
      expect(
        Directory('android/app/src/main/res').listSync().any(
              (e) => e.path.contains('mipmap'),
            ),
        isTrue,
        reason: 'no mipmap directory holds the launcher icon',
      );
    });
  });
}
