import 'dart:js_interop';

import 'web_push_config.dart';

@JS('MAFIA_FIREBASE')
external JSAny? get _mafiaFirebase;

/// Null while `web/firebase-config.js` still says null (push off).
WebPushConfig? webPushConfig() {
  try {
    final value = _mafiaFirebase.dartify();
    return WebPushConfig.fromMap(value is Map ? value : null);
  } catch (_) {
    return null;
  }
}

@JS('navigator.userAgent')
external String get _userAgent;

@JS('navigator.standalone')
external bool? get _iosStandalone;

@JS('matchMedia')
external _MediaQuery _matchMedia(String query);

extension type _MediaQuery(JSObject _) implements JSObject {
  external bool get matches;
}

/// iPhone/iPad Safari delivers web push only to an installed web app: true
/// while the site is still a plain browser tab there.
bool webNeedsInstall() {
  try {
    final ua = _userAgent;
    final ios = RegExp(r'iPhone|iPad|iPod').hasMatch(ua);
    if (!ios) return false;
    final installed =
        (_iosStandalone ?? false) ||
        _matchMedia('(display-mode: standalone)').matches;
    return !installed;
  } catch (_) {
    return false;
  }
}
