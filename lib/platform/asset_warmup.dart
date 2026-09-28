import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads every bundled asset once, so the first time a screen needs a
/// painting it is already on hand.
///
/// On the web that is the real work: each asset is a network fetch, and the
/// offline service worker keeps what was fetched, so a player who waits
/// through the first preparation never waits on art again. On a phone the
/// assets are in the package; reading them warms the OS page cache and costs
/// little. Decoding is a separate, smaller step (see `WarmupGate`) — decoding
/// every painting at full size would evict the image cache it was meant to
/// fill.
class AssetWarmup {
  final AssetBundle bundle;

  /// Parallel reads per batch: enough to fill a connection, few enough not to
  /// starve the first frames.
  final int batch;

  const AssetWarmup({required this.bundle, this.batch = 6});

  /// The key under which the last fully prepared asset set is remembered.
  static const signatureKey = 'mafia.warmup.signature.v1';

  static const _warmable = ['.webp', '.png', '.jpg', '.jpeg', '.ogg', '.mp3'];

  /// Every warmable asset in the manifest, sorted so the signature is stable.
  Future<List<String>> assets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final all = manifest.listAssets().where((path) {
      final lower = path.toLowerCase();
      return path.startsWith('assets/') && _warmable.any(lower.endsWith);
    }).toList()..sort();
    return all;
  }

  /// A short fingerprint of the asset set. It changes when an update adds,
  /// removes or renames art, which is exactly when preparation is worth
  /// showing again.
  static String signature(List<String> assets) {
    var hash = 0x811c9dc5;
    for (final path in assets) {
      for (final unit in path.codeUnits) {
        hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
      }
    }
    return '${assets.length}-${hash.toRadixString(16)}';
  }

  /// Reads [assets] in batches, reporting (done, total) after each batch. A
  /// read that fails is skipped: preparation is a courtesy, never a gate.
  Future<void> read(
    List<String> assets, {
    void Function(int done, int total)? onProgress,
  }) async {
    var done = 0;
    for (var i = 0; i < assets.length; i += batch) {
      final slice = assets.sublist(
        i,
        i + batch > assets.length ? assets.length : i + batch,
      );
      await Future.wait(
        slice.map(
          (path) => bundle.load(path).then<void>((_) {}, onError: (_) {}),
        ),
      );
      done += slice.length;
      onProgress?.call(done, assets.length);
    }
  }

  /// Whether this asset set has been fully prepared on this device before.
  static Future<bool> prepared(String signature) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(signatureKey) == signature;
    } catch (_) {
      return true; // No storage: never block on a preparation we cannot record.
    }
  }

  static Future<void> markPrepared(String signature) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        signatureKey,
        signature,
      );
    } catch (_) {
      /* Preparing again next launch is the only cost. */
    }
  }
}
