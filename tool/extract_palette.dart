import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Reads the four shipped card faces and prints the palette the app is built
/// from.
///
///     flutter test tool/extract_palette.dart
///
/// Written as a test because decoding an image needs `dart:ui`, and `dart:ui`
/// needs a Flutter binding. There is nothing under test here; the output is the
/// point. Nothing in `lib/` imports it.
///
/// # Why the palette is measured rather than chosen
///
/// The four paintings are the product. A theme invented alongside them would
/// drift from them the first time the art was regenerated, and the drift would
/// show up as the app looking *almost* like the cards — which reads worse than
/// an obvious mismatch, because the eye keeps trying to reconcile it.
///
/// So every colour in `lib/ui/theme/design_tokens.dart` traces to a number
/// printed here.
///
/// # How the bands are chosen
///
/// Every pixel of all four faces goes into one pile, sorted by Rec. 709
/// luminance. Six bands are cut from that pile at fixed percentiles, and each
/// band's colour is the **mean of the pixels around that percentile**, not the
/// single pixel that happens to sit on it. A lone pixel is codec noise; a mean
/// over a percent of the image is the colour a person would name if you pointed
/// at that part of the painting.
///
/// Pooling all four faces is deliberate. The palette has to be one palette — if
/// the mafia card contributed a colour the citizen card did not, the app would
/// be wearing one role's clothes. The per-role table printed underneath is the
/// check on that: the four columns should agree closely, and where they do not,
/// the pooled value is what ships.
void main() {
  const faces = <String, String>{
    'mafia': 'assets/images/card_face_mafia.webp',
    'doctor': 'assets/images/card_face_doctor.webp',
    'detective': 'assets/images/card_face_detective.webp',
    'citizen': 'assets/images/card_face_citizen.webp',
  };

  /// Rec. 709, the standard perceptual weighting: green carries far more
  /// apparent brightness than blue, so a channel average would sort the pile
  /// wrongly.
  double luminance(int r, int g, int b) =>
      0.2126 * r + 0.7152 * g + 0.0722 * b;

  /// The six bands, by percentile through the luminance-sorted pile, with the
  /// name each one has in the design vocabulary.
  const bands = <String, double>{
    'deepestShadow': 0.03,
    'midCharcoal': 0.22,
    'graphite': 0.45,
    'paleSilver': 0.72,
    'mutedGrey': 0.84,
    'secondaryGrey': 0.92,
    'agedParchment': 0.965,
    'boneWhite': 0.998,
  };

  /// Half-width of the averaging window, as a fraction of the pile.
  const spread = 0.005;

  Future<List<({int r, int g, int b, double y})>> readPixels(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();

    final rgba = data!.buffer.asUint8List();
    final out = <({int r, int g, int b, double y})>[];
    // Every fourth pixel. A 1024x1536 face is 1.5M pixels and the bands do not
    // move in the fourth decimal place for the sake of reading all of them.
    for (var i = 0; i < rgba.length; i += 16) {
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      out.add((r: r, g: g, b: b, y: luminance(r, g, b)));
    }
    return out;
  }

  /// The mean colour of the pixels sitting around [percentile] in [pile].
  ({int r, int g, int b}) bandColour(
      List<({int r, int g, int b, double y})> pile, double percentile) {
    final centre = (pile.length * percentile).round();
    final half = (pile.length * spread).round().clamp(1, pile.length);
    final lo = (centre - half).clamp(0, pile.length - 1);
    final hi = (centre + half).clamp(1, pile.length);

    var r = 0.0, g = 0.0, b = 0.0;
    for (var i = lo; i < hi; i++) {
      r += pile[i].r;
      g += pile[i].g;
      b += pile[i].b;
    }
    final n = hi - lo;
    return (r: (r / n).round(), g: (g / n).round(), b: (b / n).round());
  }

  String hex(({int r, int g, int b}) c) =>
      '0xFF${c.r.toRadixString(16).padLeft(2, '0')}'
              '${c.g.toRadixString(16).padLeft(2, '0')}'
              '${c.b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase()
          .replaceFirst('0XFF', '0xFF');

  test('extract palette', () async {
    final pooled = <({int r, int g, int b, double y})>[];
    final perRole = <String, List<({int r, int g, int b, double y})>>{};

    for (final entry in faces.entries) {
      if (!File(entry.value).existsSync()) {
        // ignore: avoid_print
        print('MISSING ${entry.value} — run tool/normalise_art.py first');
        continue;
      }
      final pixels = await readPixels(entry.value);
      pixels.sort((a, b) => a.y.compareTo(b.y));
      perRole[entry.key] = pixels;
      pooled.addAll(pixels);
    }

    if (pooled.isEmpty) {
      // ignore: avoid_print
      print('nothing to sample');
      return;
    }
    pooled.sort((a, b) => a.y.compareTo(b.y));

    final buffer = StringBuffer()
      ..writeln('')
      ..writeln('measured from ${perRole.length} faces, '
          '${pooled.length} sampled pixels')
      ..writeln('')
      ..writeln('  ${'band'.padRight(16)}${'pooled'.padRight(12)}'
          '${'lum'.padLeft(6)}   per-role hex')
      ..writeln('  ${'-' * 68}');

    for (final band in bands.entries) {
      final c = bandColour(pooled, band.value);
      final perRoleHex = [
        for (final role in faces.keys)
          if (perRole.containsKey(role))
            '${role.substring(0, 2)}:${hex(bandColour(perRole[role]!, band.value)).substring(4)}',
      ].join(' ');
      buffer.writeln('  ${band.key.padRight(16)}${hex(c).padRight(12)}'
          '${luminance(c.r, c.g, c.b).toStringAsFixed(1).padLeft(6)}   '
          '$perRoleHex');
    }

    buffer
      ..writeln('')
      ..writeln('// paste into lib/ui/theme/design_tokens.dart');
    for (final band in bands.entries) {
      final c = bandColour(pooled, band.value);
      buffer.writeln('  static const Color ${band.key} = '
          'Color(${hex(c)});');
    }

    // ignore: avoid_print
    print(buffer);
  });
}
