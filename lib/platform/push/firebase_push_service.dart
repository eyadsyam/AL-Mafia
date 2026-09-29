import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_service.dart';
import 'web_push_config_stub.dart'
    if (dart.library.js_interop) 'web_push_config_web.dart';

/// Channel wording, in the player's language, for the Android settings page.
class PushChannelText {
  final String invites;
  final String invitesDescription;
  final String social;
  final String socialDescription;
  const PushChannelText({
    required this.invites,
    required this.invitesDescription,
    required this.social,
    required this.socialDescription,
  });
}

/// Firebase Cloud Messaging on Android and the web.
///
/// Built only by [FirebasePushService.start], which returns null — push
/// simply off — when this build has no Firebase configuration: no
/// `android/app/google-services.json` on Android, `MAFIA_FIREBASE` still null
/// in `web/firebase-config.js` on the web (docs/PUSH-SETUP.md).
class FirebasePushService implements PushService {
  final FirebaseMessaging _messaging;
  final String? _vapidKey;
  final _opened = StreamController<PushOpen>.broadcast();
  FlutterLocalNotificationsPlugin? _local;
  PushChannelText? _text;

  FirebasePushService._(this._messaging, this._vapidKey) {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final open = PushOpen.fromData(message.data);
      if (open != null) _opened.add(open);
    });
  }

  /// Our two Android channels.
  static const invitesChannel = 'mafia_invites';
  static const socialChannel = 'mafia_social';

  static Future<FirebasePushService?> start({
    required List<int> inviteVibration,
    required List<int> socialVibration,
    required PushChannelText text,
  }) async {
    try {
      if (kIsWeb) {
        final config = webPushConfig();
        if (config == null) return null;
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: config.apiKey,
            appId: config.appId,
            messagingSenderId: config.messagingSenderId,
            projectId: config.projectId,
            authDomain: config.authDomain,
          ),
        );
        return FirebasePushService._(
          FirebaseMessaging.instance,
          config.vapidKey,
        );
      }
      if (defaultTargetPlatform != TargetPlatform.android) return null;
      // Reads the values the google-services Gradle plugin generated from
      // google-services.json; throws when that file was not in the build.
      await Firebase.initializeApp();
      final service = FirebasePushService._(FirebaseMessaging.instance, null)
        .._text = text;
      await service._channels(inviteVibration, socialVibration);
      return service;
    } catch (_) {
      return null;
    }
  }

  Future<void> _channels(List<int> invite, List<int> social) async {
    final text = _text;
    if (text == null) return;
    final local = FlutterLocalNotificationsPlugin();
    await local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_mafia'),
      ),
    );
    final android = local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        invitesChannel,
        text.invites,
        description: text.invitesDescription,
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('invite_knock'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList(invite),
      ),
    );
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        socialChannel,
        text.social,
        description: text.socialDescription,
        importance: Importance.defaultImportance,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(social),
      ),
    );
    _local = local;
  }

  @override
  String? get platform => kIsWeb ? 'web' : 'android';

  @override
  Future<void> init() async {}

  @override
  Future<bool> askPermission() async {
    try {
      final android = _local
          ?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final settings = await _messaging.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> token() async {
    try {
      return await _messaging.getToken(vapidKey: _vapidKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<PushOpen> get opened => _opened.stream;

  @override
  Stream<void> get foreground => FirebaseMessaging.onMessage.map((_) {});

  @override
  Future<PushOpen?> initialOpen() async {
    try {
      final message = await _messaging.getInitialMessage();
      return message == null ? null : PushOpen.fromData(message.data);
    } catch (_) {
      return null;
    }
  }
}
