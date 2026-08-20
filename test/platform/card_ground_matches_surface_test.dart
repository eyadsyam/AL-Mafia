import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/core/theme/app_colors.dart';

/// The colour the card art is letterboxed against must vanish into the art.
///
/// # Why this is the invariant, and why it used to be phrased differently
///
/// The four paintings are never cropped and they are not the same shape: three
/// are 0.7467 aspect and the mafia is 0.8733. Scaled whole into one fixed card
/// box they cover 89.3% and 76.4% of it, so every card has letterbox bars — and
/// the mafia card has visibly more of them.
///
/// While the bars are the same colour as the painting's own dark outer edge,
/// none of that is visible: the card reads as one dark rectangle with a picture
/// in it. The moment they differ, the bars become a *frame*, thicker on one
/// role's card than on the other three. That is a role tell, and no luminance
/// budget would catch it — `normalise_art.py` gains the ground along with the
/// art, so all four boxes still measure identical while looking obviously
/// different.
///
/// # Two assertions, and why both are needed
///
/// The bars have to agree with two different things at once:
///
///  * **the screen behind the card** — otherwise the card box is a visible
///    rectangle, deeper on the mafia card than on the other three. That is what
///    `card_ground == AppColors.groundBase` plus the exact-value probe cover,
///    and it is the one that was shipping broken;
///  * **the painting's own outer edge** — otherwise the bars are a frame *inside*
///    the card. That is the 12-level budget at the bottom.
///
/// An intermediate revision of this file dropped the first pair, on the grounds
/// that the app's ground had become warm leather while the card's stayed
/// near-black, so the two could not agree. Reverting the ground removed the
/// conflict: there is one ground now, and the card is letterboxed against it.
void main() {
  const faces = <String>[
    'assets/images/card_face_mafia.webp',
    'assets/images/card_face_doctor.webp',
    'assets/images/card_face_detective.webp',
    'assets/images/card_face_citizen.webp',
  ];

  List<num> manifestGround() {
    final manifest = jsonDecode(File('tool/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    return (manifest['card_ground'] as List).cast<num>();
  }

  double luminance(num r, num g, num b) =>
      0.2126 * r + 0.7152 * g + 0.0722 * b;

  /// Mean luminance of the outermost [band] pixels of a shipped face — the part
  /// of the picture the bars actually touch.
  Future<double> edgeLuminance(String path, {int band = 6}) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();

    final rgba = data!.buffer.asUint8List();
    var total = 0.0;
    var n = 0;
    void sample(int x, int y) {
      final i = (y * width + x) * 4;
      total += luminance(rgba[i], rgba[i + 1], rgba[i + 2]);
      n++;
    }

    for (var x = 0; x < width; x++) {
      for (var d = 0; d < band; d++) {
        sample(x, d);
        sample(x, height - 1 - d);
      }
    }
    for (var y = 0; y < height; y++) {
      for (var d = 0; d < band; d++) {
        sample(d, y);
        sample(width - 1 - d, y);
      }
    }
    return total / n;
  }

  test('card_ground is the surface the card sits on', () {
    // The Python pipeline and the Dart theme hold this number in two different
    // languages in two different files; nothing but this test can keep them
    // together.
    //
    // It is `groundBase` — the app's own `surfaceBase` — and not the measured
    // near-black it used to be. The bars have to match *the screen behind the
    // card*, because that is what they are seen against.
    final ground = manifestGround().map((c) => c.round()).toList();
    final expected = [
      (AppColors.groundBase.r * 255).round(),
      (AppColors.groundBase.g * 255).round(),
      (AppColors.groundBase.b * 255).round(),
    ];

    expect(ground, equals(expected),
        reason: 'tool/manifest.json letterboxes against rgb$ground while '
            'AppColors.groundBase is rgb$expected. Fix the manifest and '
            're-run `python tool/normalise_art.py`.');
  });

  test('the letterbox bars ship as exactly the ground colour', () async {
    // # The probe that actually proves the frame is gone
    //
    // Every one of the four paintings is wider than the 2:3 card box, so all
    // four are fitted by width and letterboxed **top and bottom**. The mafia's
    // bars are 182px deep and the other three are 82px — the asymmetry that
    // makes this a role tell rather than a cosmetic problem.
    //
    // It stops being either the moment the bars are the same colour as the
    // screen. `normalise_art.py` now gains only the art and composites onto a
    // constant ground, so the bars ship as literally `card_ground`. Before that
    // they shipped as `card_ground × gain`, and the gains differ per role — so
    // the mafia's bars were a different value from everyone else's *and* there
    // were more of them.
    //
    // Sampled 4px in from the top and bottom edges. Left and right are
    // deliberately not sampled: the painting spans the full width, so those
    // pixels are artwork and have no reason to match anything.
    const tolerance = 2;

    final ground = manifestGround().map((c) => c.round()).toList();

    for (final face in faces) {
      final bytes = await File(face).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      codec.dispose();

      final rgba = data!.buffer.asUint8List();
      var worst = 0;
      var worstAt = '';
      for (var x = 0; x < width; x++) {
        for (final y in <int>[0, 1, 2, 3, height - 4, height - 3, height - 2,
          height - 1]) {
          final i = (y * width + x) * 4;
          for (var c = 0; c < 3; c++) {
            final delta = (rgba[i + c] - ground[c]).abs();
            if (delta > worst) {
              worst = delta;
              worstAt = '($x,$y) channel $c: ${rgba[i + c]} vs ${ground[c]}';
            }
          }
        }
      }

      expect(worst, lessThanOrEqualTo(tolerance),
          reason: 'the letterbox bars of $face are up to $worst levels off '
              'rgb$ground — worst at $worstAt. They must be the ground exactly, '
              'or the card draws a frame against the screen behind it, and the '
              "mafia's frame is more than twice as deep as the other three. "
              'Re-run `python tool/normalise_art.py`.');
    }
  });

  test('the bars are indistinguishable from the art they sit against',
      () async {
    // The property that actually prevents the tell. A few levels is far below
    // what anyone can see on a phone at a dark table; a couple of dozen would
    // draw a rectangle around the mafia card.
    const budget = 12.0;

    final ground = manifestGround();
    final groundLuminance = luminance(ground[0], ground[1], ground[2]);

    for (final face in faces) {
      final edge = await edgeLuminance(face);
      expect((edge - groundLuminance).abs(), lessThan(budget),
          reason: 'the outer edge of $face measures '
              '${edge.toStringAsFixed(1)}/255 while the letterbox bars measure '
              '${groundLuminance.toStringAsFixed(1)}. At that difference the '
              'bars are a visible frame — and the mafia painting covers 76% of '
              'the card box against 89% for the others, so its frame is '
              'thicker. That is readable from across the table.');
    }
  });
}
