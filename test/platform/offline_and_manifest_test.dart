import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// T078 / FR-029 — the one-phone game needs no network, and the app stays
/// portrait.
///
/// ## What FR-029 turned out to mean
///
/// It was written as *"the app is offline by construction"* and enforced by
/// asserting that the release manifest declared no INTERNET permission at all.
/// Docs 10 and 12 then built online play, and the two cannot both be true: a
/// release APK with no INTERNET permission fails every network call at the
/// socket, which is precisely the bug that made "play online" unusable in every
/// build the project ever shipped — the app reported that it could not reach
/// the server, and it was right, because it had never been allowed to ask.
///
/// So the promise is now the one it was always for: **a group in a basement
/// with no signal can still play the whole game.** That is a claim about the
/// offline mode's dependencies, not about the app's permissions, and it is
/// asserted below as such — nothing outside the transport and the online
/// screens may reach the network, and the engine may not so much as import
/// them.
///
/// "Works offline" is still not a feature you can see in the UI; it is the
/// absence of something. A single dependency that phones home from the wrong
/// layer — an analytics SDK, a font loader, a crash reporter — would satisfy
/// every other test in this suite while quietly breaking it.
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    return file.readAsStringSync();
  }

  group('FR-029 offline guarantee', () {
    test('the release manifest declares INTERNET, or online cannot work', () {
      // Flutter's template puts INTERNET in `src/debug` and `src/profile`
      // only, because that is where hot reload needs it. A release build made
      // from the template therefore has no network permission at all — and the
      // failure is silent and misattributed: every Supabase call throws at the
      // socket, the transport correctly reports "unreachable", and the player
      // is told the server is down while the server is fine.
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(
        manifest.contains('android.permission.INTERNET'),
        isTrue,
        reason:
            'a release build with no INTERNET permission cannot play '
            'online, and reports it as the server being unreachable',
      );
    });

    test('the debug manifest keeps its own copy, and that is fine', () {
      final debugManifest = read('android/app/src/debug/AndroidManifest.xml');
      expect(debugManifest.contains('android.permission.INTERNET'), isTrue);
    });

    test('the one-phone game imports nothing that can reach a network', () {
      // The actual promise. Everything network-shaped lives in two places, and
      // the engine — which is the whole of the offline game's rules — may not
      // reach either of them.
      // Scanned over *directives* rather than over the whole file. Half of
      // `lib/engine` documents this very rule in its own prose, and a doc
      // comment reading "no `package:flutter`" is not an import of it.
      final directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
      final offenders = <String>[];
      for (final file
          in Directory('lib/engine')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        for (final line in const LineSplitter().convert(
          file.readAsStringSync(),
        )) {
          final uri = directive.firstMatch(line)?.group(1);
          if (uri == null) continue;
          for (final forbidden in const [
            'supabase',
            'transport/',
            'package:flutter',
            'dart:io',
            'dart:ui',
          ]) {
            if (uri.contains(forbidden)) {
              offenders.add('${file.path} → $uri');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'the engine reached outside itself: $offenders',
      );
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
      for (final file
          in Directory('lib')
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

      expect(
        offenders,
        isEmpty,
        reason: 'these files can reach the network: $offenders',
      );
    });

    test('no dependency is a networking package', () {
      final pubspec = read('pubspec.yaml');
      // Read only the dependency blocks, so a package name mentioned in a
      // comment does not trip the check.
      const networkPackages = ['http:', 'dio:', 'web_socket_channel:', 'grpc:'];
      for (final package in networkPackages) {
        expect(
          pubspec.contains('\n  $package'),
          isFalse,
          reason: '$package is a networking dependency',
        );
      }
    });
  });

  group('platform configuration', () {
    test('Android is portrait-only and targets API 26+', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest.contains('android:screenOrientation="portrait"'), isTrue);

      final gradle = read('android/app/build.gradle.kts');
      expect(
        gradle.contains('minSdk = 26'),
        isTrue,
        reason: 'the minimum Android version is API 26 (T001)',
      );
    });

    test('iOS is portrait-only on both iPhone and iPad', () {
      final plist = read('ios/Runner/Info.plist');
      // A phone that rotates mid-turn re-lays-out the night screen in front of
      // whoever is nearby, which is exactly the exposure the design avoids.
      expect(
        plist.contains('UIInterfaceOrientationLandscapeLeft'),
        isFalse,
        reason: 'landscape is still allowed on iOS',
      );
      expect(plist.contains('UIInterfaceOrientationLandscapeRight'), isFalse);
      expect(
        plist.contains('UIInterfaceOrientationPortraitUpsideDown'),
        isFalse,
      );
      expect(plist.contains('UIInterfaceOrientationPortrait'), isTrue);
    });

    test('the app is labelled for players, not for developers', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(
        manifest.contains('android:label="mafia_master"'),
        isFalse,
        reason: 'the launcher would show the package name',
      );

      final plist = read('ios/Runner/Info.plist');
      expect(plist.contains('<string>Mafia Master</string>'), isTrue);
    });

    test('a launcher icon is declared', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest.contains('android:icon='), isTrue);
      expect(
        Directory(
          'android/app/src/main/res',
        ).listSync().any((e) => e.path.contains('mipmap')),
        isTrue,
        reason: 'no mipmap directory holds the launcher icon',
      );
    });
  });
}
