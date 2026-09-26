import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// The longer side of an uploaded payment screenshot, at most.
const int proofMaxSide = 1600;

/// Picks the transfer screenshot and returns it as a JPEG no larger than
/// [proofMaxSide] on its longer side, or null when the player backs out or
/// the file is not a readable image. Overridden in widget tests.
typedef ProofPicker = Future<Uint8List?> Function();

final proofPickerProvider = Provider<ProofPicker>((ref) => pickProofImage);

Future<Uint8List?> pickProofImage() async {
  // The system photo picker: no storage permission, one image the player
  // chose. Android/web scale it first; the re-encode below guarantees JPEG.
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: proofMaxSide.toDouble(),
    maxHeight: proofMaxSide.toDouble(),
    imageQuality: 85,
  );
  if (file == null) return null;
  final raw = await file.readAsBytes();
  return compute(compressProof, raw);
}

/// Re-encodes [bytes] as a JPEG whose longer side is at most [proofMaxSide].
/// Null when the bytes are not an image this can read.
Uint8List? compressProof(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  if (math.max(image.width, image.height) > proofMaxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: proofMaxSide)
        : img.copyResize(image, height: proofMaxSide);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 82));
}
