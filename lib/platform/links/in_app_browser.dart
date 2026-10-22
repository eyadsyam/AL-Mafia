import 'in_app_browser_stub.dart'
    if (dart.library.js_interop) 'in_app_browser_browser.dart'
    as impl;

/// The browsers Facebook, Instagram, Messenger, TikTok and Snapchat open
/// links in. Google refuses to sign anyone in from inside them
/// (`disallowed_useragent`), so the app sends the player to a real browser
/// instead of to a Google error page.
final _embedded = RegExp(
  'FBAN|FBAV|FB_IAB|FBIOS|Instagram|Messenger|musical_ly|TikTok|Bytedance|'
  'Snapchat',
  caseSensitive: false,
);

/// Whether [userAgent] is one of those in-app browsers.
bool isEmbeddedBrowser(String userAgent) => _embedded.hasMatch(userAgent);

/// Whether this page runs inside one (always false outside a browser).
bool get inEmbeddedBrowser => isEmbeddedBrowser(impl.userAgent());

/// Whether this page runs on Android (where Chrome can be asked by name).
bool get embeddedOnAndroid =>
    RegExp('Android', caseSensitive: false).hasMatch(impl.userAgent());

/// This page's address, without query or fragment: what the player copies or
/// opens in a real browser.
Uri pageAddress() {
  final base = Uri.base;
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.port,
    path: base.path,
  );
}

/// The Android link that opens [page] in Chrome.
String chromeIntentFor(Uri page) =>
    'intent://${page.host}${page.path}#Intent;scheme=https;'
    'package=com.android.chrome;end';

/// Sends this tab to [url] (an Android intent link included). False where it
/// cannot (not a browser, or the browser refused).
bool openHere(String url) => impl.openHere(url);
