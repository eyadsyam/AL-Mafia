import 'web_ad_bridge_stub.dart'
    if (dart.library.js_interop) 'web_ad_bridge_browser.dart'
    as impl;

/// Whether Google actually displayed an H5 break. False means house fallback.
Future<bool> tryH5Break(String client, String type, String name) =>
    impl.tryH5Break(client, type, name);

/// A display unit needs an AdSense-issued slot. Empty slot always falls back.
Future<bool> tryH5Banner(String client, String slot) =>
    impl.tryH5Banner(client, slot);

void hideH5Banner() => impl.hideH5Banner();
