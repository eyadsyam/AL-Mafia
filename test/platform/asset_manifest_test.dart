import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/asset_constants.dart';

/// Asset manifest integrity, plus the ink-parity half of the zero-leakage
/// budget (doc 05 rules 3 and 6, acceptance test T4).
///
/// ## Why the ink check lives here and not only in the generator
///
/// `tool/generate_assets.py` solves the four role emblems to equal ink and
/// prints the result. That proves the *generator* is correct at the moment it
/// runs. It proves nothing about the files actually in the repository, which
/// are what ships — someone can re-export one emblem by hand, or a lossy
/// re-compression can eat a thin stroke, and the generator's output would still
/// look perfect in the scrollback.
///
/// This test measures the shipped bytes instead. If the four emblems ever stop
/// laying down the same amount of light, the build fails.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Mean alpha of an image asset, 0..1 — the fraction of the frame it inks.
  Future<double> inkCoverage(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    codec.dispose();

    final rgba = data!.buffer.asUint8List();
    var total = 0.0;
    for (var i = 3; i < rgba.length; i += 4) {
      total += rgba[i] / 255.0;
    }
    return total / (rgba.length / 4);
  }

  group('asset manifest', () {
    test('every declared asset exists on disk', () {
      final missing = <String>[
        for (final path in [
          ...AppImages.values,
          ...AppGallery.values,
          ...AppIcons.values,
          ...AppAudio.values,
        ])
          if (!File(path).existsSync()) path,
      ];
      expect(missing, isEmpty, reason: 'declared but not present: $missing');
    });

    test('every file on disk is declared in asset_constants.dart', () {
      // Catches the opposite drift: an asset added to the folder, shipped in
      // the APK, and reachable only through a hand-typed string.
      final declared = <String>{
        ...AppImages.values,
        ...AppGallery.values,
        ...AppIcons.values,
        ...AppAudio.values,
      };

      final orphans = <String>[];
      for (final dir in [
        'assets/images',
        'assets/images/gallery',
        'assets/icons',
        'assets/audio',
      ]) {
        for (final entity in Directory(dir).listSync()) {
          if (entity is! File) continue;
          final path = entity.path.replaceAll(r'\', '/');
          if (path.endsWith('.gitkeep')) continue;
          if (!declared.contains(path)) orphans.add(path);
        }
      }

      expect(orphans, isEmpty,
          reason: 'present but undeclared — re-run '
              'tool/generate_asset_constants.py: $orphans');
    });

    test('every bundled font file referenced by pubspec exists', () {
      // Comment lines are stripped first. Flutter's pubspec template ships a
      // commented-out `fonts:` example, and matching that would have this test
      // demanding a copy of Trajan Pro.
      final pubspec = File('pubspec.yaml')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('#'))
          .join('\n');
      final assets = RegExp(r'- asset:\s*(\S+)')
          .allMatches(pubspec)
          .map((m) => m.group(1)!)
          .toList();

      expect(assets, isNotEmpty, reason: 'no fonts declared at all');
      final missing = assets.where((a) => !File(a).existsSync()).toList();
      expect(missing, isEmpty, reason: 'declared but missing: $missing');
    });
  });

  group('L-05 role emblem ink parity', () {
    test('all four role emblems ink the frame within ±2%', () async {
      const emblems = <String, String>{
        'mafia': AppIcons.roleMafia,
        'doctor': AppIcons.roleDoctor,
        'detective': AppIcons.roleDetective,
        'citizen': AppIcons.roleCitizen,
      };

      final coverage = <String, double>{};
      for (final entry in emblems.entries) {
        coverage[entry.key] = await inkCoverage(entry.value);
      }

      final mean =
          coverage.values.reduce((a, b) => a + b) / coverage.length;
      expect(mean, greaterThan(0.05),
          reason: 'emblems decoded to nearly nothing — is the alpha channel '
              'surviving compression?');

      for (final entry in coverage.entries) {
        final drift = (entry.value - mean).abs() / mean;
        expect(
          drift,
          lessThanOrEqualTo(0.02),
          reason: 'LEAK: the ${entry.key} emblem is '
              '${(drift * 100).toStringAsFixed(2)}% off the mean ink budget '
              '(${entry.value.toStringAsFixed(5)} vs ${mean.toStringAsFixed(5)}). '
              'A role whose symbol is denser than the others makes its card '
              'measurably brighter. Re-run tool/generate_assets.py.',
        );
      }
    });

    test('all four role emblems share identical pixel dimensions', () async {
      final sizes = <String, String>{};
      for (final path in [
        AppIcons.roleMafia,
        AppIcons.roleDoctor,
        AppIcons.roleDetective,
        AppIcons.roleCitizen,
      ]) {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        sizes[path] = '${frame.image.width}x${frame.image.height}';
        frame.image.dispose();
        codec.dispose();
      }

      expect(sizes.values.toSet(), hasLength(1),
          reason: 'emblems differ in size, which changes their layout box: '
              '$sizes');
    });

    test('there is exactly one card back, and exactly four faces', () {
      // The card *back* keeps the structural guarantee: the strongest possible
      // assurance that no role's back can differ from another's is that there is
      // only one back in the repository.
      //
      // The four faces deliberately gave that up in exchange for real artwork,
      // so what is checked here is the shape of the set — one back, four faces,
      // one per role, no leftovers. A fifth face, or a resurrected shared
      // `card_face_base.webp` still being shipped alongside them, means the
      // architecture is half-migrated and some code path is reading the wrong
      // file. Their *brightness* parity is luminance_budget_test's job.
      final cards = Directory('assets/images')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.startsWith('card_'))
          .toList()
        ..sort();

      expect(
          cards,
          equals([
            'card_back.webp',
            'card_face_citizen.webp',
            'card_face_detective.webp',
            'card_face_doctor.webp',
            'card_face_mafia.webp',
          ]),
          reason: 'the card asset set is not one back plus four named faces: '
              '$cards');
    });

    test('the four faces share identical pixel dimensions', () async {
      // Identical framing is half of the parity claim and the half a luminance
      // measurement cannot see: four cards at the same average brightness but
      // different sizes would still be cropped differently by BoxFit.cover, and
      // one role's figure would sit at a different scale from the rest.
      final sizes = <String, String>{};
      for (final path in <String>[
        AppImages.cardFaceMafia,
        AppImages.cardFaceDoctor,
        AppImages.cardFaceDetective,
        AppImages.cardFaceCitizen,
      ]) {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        sizes[path] = '${frame.image.width}x${frame.image.height}';
        frame.image.dispose();
        codec.dispose();
      }

      expect(sizes.values.toSet(), hasLength(1),
          reason: 'the role faces are not all the same size: $sizes');
    });
  });
}
