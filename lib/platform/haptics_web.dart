import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The browser's Vibration API (Chrome on Android; Safari and desktop browsers
/// have none, and the call is then a quiet no-op). Never throws: a browser that
/// wants a user gesture first simply ignores it.
bool vibrate(List<int> timings) {
  try {
    return web.window.navigator.vibrate(
      [for (final t in timings) t.toJS].toJS,
    );
  } catch (_) {
    return false;
  }
}
