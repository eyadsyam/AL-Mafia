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
