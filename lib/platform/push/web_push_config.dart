/// The web app's Firebase config, from `web/firebase-config.js`
/// (`self.MAFIA_FIREBASE`). Public values; null there means push off.
class WebPushConfig {
  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String? authDomain;
  final String? vapidKey;
  const WebPushConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.authDomain,
    this.vapidKey,
  });

  /// The config object as read from the page, or null when push is off:
  /// the object is null, or one of the four values Firebase needs is missing
  /// or blank. A missing `vapidKey` still starts Firebase; the browser then
  /// cannot hand out a token, so push stays quiet.
  static WebPushConfig? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    String? text(String key) {
      final value = map[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final apiKey = text('apiKey'), appId = text('appId');
    final sender = text('messagingSenderId'), project = text('projectId');
    if (apiKey == null || appId == null || sender == null || project == null) {
      return null;
    }
    return WebPushConfig(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: sender,
      projectId: project,
      authDomain: text('authDomain'),
      vapidKey: text('vapidKey'),
    );
  }
}
