import 'web_ad_bridge_stub.dart'
    if (dart.library.js_interop) 'web_ad_bridge_browser.dart'
    as impl;

/// Whether Google actually displayed an H5 break. False means house fallback.
/// Always resolves: the page decides within its own timeout, and a result that
/// arrives later is ignored.
Future<bool> tryH5Break(String client, String type, String name) =>
    impl.tryH5Break(client, type, name);

/// Places the Google display unit over the slot Flutter reserved, in CSS
/// pixels (Flutter logical pixels equal CSS pixels on web). [onFilled] fires
/// immediately and on every later change, so a late fill switches the house
/// art off instead of being discarded. An empty or invalid slot never fills.
void showGoogleBanner(
  String client,
  String slot,
  double left,
  double top,
  double width,
  double height,
  void Function(bool filled) onFilled,
) => impl.showGoogleBanner(client, slot, left, top, width, height, onFilled);

/// Makes the Google overlay inert and invisible. Idempotent.
void hideGoogleBanner() => impl.hideGoogleBanner();
