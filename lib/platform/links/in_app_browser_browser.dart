import 'package:web/web.dart' as web;

String userAgent() {
  try {
    return web.window.navigator.userAgent;
  } catch (_) {
    return '';
  }
}

/// Same-tab navigation: an in-app browser hands an `intent://` address to
/// Android, which opens Chrome on it.
bool openHere(String url) {
  try {
    web.window.location.href = url;
    return true;
  } catch (_) {
    return false;
  }
}
