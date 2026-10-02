import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/asset_constants.dart';

/// The film has to be there when there is no connection.
///
/// A group plays this game sitting in one room, and the room is as likely to be
/// a chalet with no signal as a flat with fibre. The explanation is the one
/// screen a new group cannot skip past and still play, so it ships inside the
/// app on a phone and inside a service worker cache on the web.
///
/// Neither of those is expressed in Dart, and none of the four files below
/// imports another: the asset list is in `pubspec.yaml`, the precache list is a
/// string in a JavaScript file, the registration is in a second JavaScript file
/// and the workaround that makes the picture visible at all is a CSS rule in
/// `index.html`. Rename the film, or the worker, and everything still compiles
/// and every test still passes — the site just quietly stops working offline,
/// which is the failure nobody notices until they are somewhere without signal.
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    return file.readAsStringSync();
  }

  group('the film ships with the app', () {
    test('pubspec bundles the video directory', () {
      // `VideoPlayerController.asset` reads from the installed app, so this one
      // line is the whole of offline playback on a phone.
      expect(read('pubspec.yaml'), contains('- assets/video/'));
    });

    test('the service worker precaches the same file the player asks for', () {
      final worker = read('web/offline_service_worker.js');
      // Flutter serves an asset from `assets/` + its declared path, and the
      // browser download resolves exactly that. A worker that precaches
      // anything else caches a file nobody requests.
      expect(worker, contains("'./assets/${AppVideo.onboarding}'"));
      // Reinstalled per deploy, or a cache-first worker pins the site forever.
      expect(worker, contains('__BUILD_VERSION__'));
      // Assets are served immutable for a year; without this the worker would
      // precache the previous build's film out of the HTTP cache.
      expect(worker, contains("cache: 'reload'"));
    });

    test('the build stamps the worker and publishes it as sw.js', () {
      final script = read('tool/build_web.ps1');
      expect(script, contains('web/offline_service_worker.js'));
      expect(script, contains("__BUILD_VERSION__"));
      expect(script, contains("'sw.js'"));
    });

    test('the bootstrap registers it, and asks Flutter for no worker', () {
      final bootstrap = read('web/flutter_bootstrap.js');
      expect(bootstrap, contains("register('sw.js')"));
      // Loaded with no settings at all. Flutter's own worker is a stub that
      // unregisters itself, and the loader installs nothing on a browser that
      // has never had one; handing it a worker to register would replace ours
      // on every load.
      expect(bootstrap, contains("canvasKitBaseUrl: 'canvaskit/'"));
      expect(bootstrap, contains('{{flutter_js}}'));
      expect(bootstrap, contains('{{flutter_build_config}}'));
    });
  });

  test('the composited surface is pinned left-to-right', () {
    // A platform view is placed with a translate from its static position, and
    // in an RTL containing block that position is the right edge — the video
    // ended up past the right of the window and the intro was an empty panel.
    // The document stays RTL; only the surface Flutter composites is pinned.
    final html = read('web/index.html');
    expect(html, contains('flt-glass-pane { direction: ltr; }'));
    expect(html, contains('dir="rtl"'));
  });
}
