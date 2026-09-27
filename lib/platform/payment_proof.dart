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

/// The longer side on the web: the browser scales the picked image (a canvas
/// redraw, which also drops its metadata) so no Dart decode runs on the web's
/// only thread.
const int proofWebMaxSide = 1280;

/// Largest proof the server takes (coin_payments.ts `PROOF_MAX_BYTES`).
const int proofMaxBytes = 3 * 1024 * 1024;

Future<Uint8List?> pickProofImage() async {
  // The system photo picker: no storage permission, one image the player
  // chose. Android/web scale it first; the re-encode below guarantees JPEG.
  final side = (kIsWeb ? proofWebMaxSide : proofMaxSide).toDouble();
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: side,
    maxHeight: side,
    imageQuality: 85,
  );
  if (file == null) return null;
  return _finish(file);
}

Future<Uint8List?> _finish(XFile file) async {
  final raw = await file.readAsBytes();
  if (kIsWeb) {
    // The browser already scaled and re-encoded it (its picker names the
    // result `scaled_…`): sent as is. Anything else (a failed browser resize)
    // is re-encoded here, capped at the web size.
    if (file.name.startsWith('scaled_') &&
        raw.length <= proofMaxBytes &&
        _isProofImage(raw)) {
      return raw;
    }
    return compressWebProof(raw);
  }
  return compute(compressProof, raw);
}

/// Android only: a screenshot picked just before the system killed the app,
/// handed back on the next start. Null anywhere else, or when there is none.
typedef LostProofRecovery = Future<Uint8List?> Function();

final lostProofProvider = Provider<LostProofRecovery>(
  (ref) => recoverLostProof,
);

Future<Uint8List?> recoverLostProof() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final lost = await ImagePicker().retrieveLostData();
    final file = lost.file ?? lost.files?.firstOrNull;
    if (lost.isEmpty || file == null) return null;
    return _finish(file);
  } catch (_) {
    return null;
  }
}

/// JPEG, PNG or WebP, by the leading bytes (what the server checks).
bool _isProofImage(Uint8List b) =>
    (b.length > 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) ||
    (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4e) ||
    (b.length > 12 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[8] == 0x57 &&
        b[9] == 0x45);

/// [compressProof] capped at [proofWebMaxSide].
Uint8List? compressWebProof(Uint8List bytes) =>
    compressProof(bytes, maxSide: proofWebMaxSide);

/// Re-encodes [bytes] as a JPEG whose longer side is at most [maxSide].
/// Null when the bytes are not an image this can read.
Uint8List? compressProof(Uint8List bytes, {int maxSide = proofMaxSide}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  if (math.max(image.width, image.height) > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide)
        : img.copyResize(image, height: maxSide);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 82));
}
