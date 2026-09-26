import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Reuses a fully cached film for offline playback. On a first visit, returns
/// immediately so the player can stream instead of downloading the entire film.
Future<String?> downloadVideoAsset(
  String assetPath, {
  required void Function(double progress) onProgress,
}) async {
  try {
    final url = Uri.parse(web.document.baseURI).resolve('assets/$assetPath');
    final cached = await web.window.caches.match(url.toString().toJS).toDart;
    if (cached == null || !cached.ok) return null;
    final blob = await cached.blob().toDart;
    if (blob.size == 0) return null;
    onProgress(1);
    return web.URL.createObjectURL(blob);
  } catch (_) {
    // Cache storage may be unavailable in private browsing. Streaming works
    // without it and still starts from the user's explicit play gesture.
    return null;
  }
}

void releaseVideoUrl(String url) {
  try {
    web.URL.revokeObjectURL(url);
  } catch (_) {}
}
