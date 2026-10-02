import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../theme/design_tokens.dart';
import 'store_art.dart';

/// The six frame and plate images, decoded once at the size the table and
/// the store preview draw them (about 2.7 MB together) and kept for the
/// process lifetime. A cosmetic that fails to load never blocks play: its
/// vector style is drawn instead, and the next [load] tries it again.
abstract final class CosmeticArtCache {
  static final Map<String, ui.Image> images = {};

  /// Bumped whenever an image arrives, so painters can repaint on it.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static Future<void>? _loading;

  static Iterable<String> get _codes => StoreArt.codes.where(
    (code) => code.startsWith('frame_') || code.startsWith('plate_'),
  );

  static Future<void> load(Future<ByteData> Function(String) readAsset) =>
      _loading ??= _load(readAsset);

  static Future<void> _load(Future<ByteData> Function(String) readAsset) async {
    await Future.wait(
      _codes
          .where((code) => !images.containsKey(code))
          .map((code) => _decode(code, readAsset)),
    );
    // Anything that failed is retried on the next call instead of never.
    if (_codes.any((code) => !images.containsKey(code))) _loading = null;
  }

  static Future<void> _decode(
    String code,
    Future<ByteData> Function(String) readAsset,
  ) async {
    try {
      final data = await readAsset(StoreArt.forCode(code)!);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        targetWidth: code.startsWith('frame_')
            ? StoreTokens.frameDecodeWidth
            : StoreTokens.plateDecodeWidth,
      );
      try {
        images[code] = (await codec.getNextFrame()).image;
        revision.value++;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // The vector style remains as the fallback.
    }
  }
}
