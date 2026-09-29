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
}
