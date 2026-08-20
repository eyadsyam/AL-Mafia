import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/asset_constants.dart';

/// The card back must be indistinguishable from its own upside-down self.
///
/// ## Why this is a leakage test and not a styling nicety
///
/// The back is the only thing the table looks at for the entire time a player
/// holds their card, and it is the same file for all four roles — that part is
/// structural (`asset_manifest_test.dart` proves there is exactly one). But a
/// back that is *orientable* reintroduces a visible difference between one
/// player's card and another's: hand the phone over rotated, or hold it the other
/// way up, and the card now looks different from the last one even though nothing
/// about the game changed.
///
/// That is noise a table can learn to read, and it costs nothing to remove: the
/// generator builds the medallion from centred rings, even angular harmonics and
/// a centred halftone screen, and averages every noise field with its own 180
/// degree rotation (`_sym` in `tool/generate_assets.py`).
///
/// Measured from the shipped bytes rather than from the generator, because what
/// ships is what the table sees — and WebP is lossy, so a property that holds in
/// the source array does not automatically survive encoding.
void main() {
  /// Decoded RGBA of a bundled asset, straight off disk.
  Future<({Uint8List pixels, int width, int height})> load(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = (
      pixels: data!.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
    image.dispose();
    codec.dispose();
    return result;
  }

  /// Mean absolute per-channel difference between an image and its half turn.
  double rotationDrift(
      Uint8List pixels, int width, int height) {
    var total = 0;
    var samples = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final a = (y * width + x) * 4;
        final b = ((height - 1 - y) * width + (width - 1 - x)) * 4;
        // RGB only. Alpha is uniform in these assets and would dilute the mean.
        for (var c = 0; c < 3; c++) {
          total += (pixels[a + c] - pixels[b + c]).abs();
          samples++;
        }
      }
    }
    return total / samples;
  }

  // Generous next to the ~0.91 the shipped file actually measures, because the
  // budget has to survive a re-encode at a different WebP quality. Tight enough
  // to be meaningless for any image that is not deliberately symmetric — the
  // card face measures ~11.6 through the same function.
  const budget = 3.0;

  test('the card back is identical turned upside down', () async {
    final img = await load(AppImages.cardBack);
    final drift = rotationDrift(img.pixels, img.width, img.height);

    expect(drift, lessThan(budget),
        reason: 'card_back.webp differs from its own 180-degree rotation by '
            '${drift.toStringAsFixed(3)} levels on average (budget $budget). A '
            'card dealt upside down would be distinguishable from one dealt the '
            'right way up.');
  });

  test('the measurement is not vacuous', () async {
    // If `rotationDrift` were broken — or if the budget were loose enough to
    // pass anything — this would slip through too. A role face is a lit figure
    // with a top and a bottom, so it must fail the same check the back passes.
    final img = await load(AppImages.cardFaceMafia);
    final drift = rotationDrift(img.pixels, img.width, img.height);

    expect(drift, greaterThan(budget),
        reason: 'a role card face measured only ${drift.toStringAsFixed(3)} '
            'levels of rotation drift, so this suite would pass an asymmetric '
            'back too. Either the face art became symmetric or the budget is too '
            'loose to mean anything.');
  });
}
