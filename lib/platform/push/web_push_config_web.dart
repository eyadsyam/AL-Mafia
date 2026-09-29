import 'dart:js_interop';

import 'web_push_config.dart';

@JS('MAFIA_FIREBASE')
external _Config? get _mafiaFirebase;

extension type _Config._(JSObject _) implements JSObject {
  external String? get apiKey;
  external String? get appId;
  external String? get messagingSenderId;
  external String? get projectId;
  external String? get authDomain;
  external String? get vapidKey;
}

/// Null while `web/firebase-config.js` still says null (push off).
WebPushConfig? webPushConfig() {
  try {
    final c = _mafiaFirebase;
    if (c == null) return null;
    final apiKey = c.apiKey, appId = c.appId;
    final sender = c.messagingSenderId, project = c.projectId;
    if (apiKey == null || appId == null || sender == null || project == null) {
      return null;
    }
    return WebPushConfig(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: sender,
      projectId: project,
      authDomain: c.authDomain,
      vapidKey: c.vapidKey,
    );
  } catch (_) {
    return null;
  }
}
