import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_service.dart';
import 'web_push_config_stub.dart'
    if (dart.library.js_interop) 'web_push_config_web.dart';

/// Android creates a background isolate for data delivery. Notification
/// payloads are drawn by the OS, while this handler makes the data half safe
/// to receive when the app process is suspended or has been recreated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage _) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
}

/// Channel wording, in the player's language, for the Android settings page.
class PushChannelText {
  final String invites;
  final String invitesDescription;
  final String social;
  final String socialDescription;
  final String game;
  final String gameDescription;
  final String daily;
  final String dailyDescription;
  const PushChannelText({
    required this.invites,
    required this.invitesDescription,
    required this.social,
    required this.socialDescription,
    required this.game,
    required this.gameDescription,
    required this.daily,
    required this.dailyDescription,
  });
}

/// Firebase Cloud Messaging on Android and the web.
///
/// Built only by [FirebasePushService.start], which returns null — push
/// simply off — when this build has no Firebase configuration: no
/// `android/app/google-services.json` on Android, `MAFIA_FIREBASE` still null
/// in `web/firebase-config.js` on the web (docs/setup/PUSH-SETUP.md).
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
    FirebaseMessaging.onMessage.listen(_showForeground);
  }

  /// Our two Android channels.
  static const invitesChannel = 'mafia_invites';
  static const socialChannel = 'mafia_social';

  /// The room starting, the night falling: high importance, short buzz.
  static const gameChannel = 'mafia_game';

  /// The wheel, Thursday night, comeback: default importance, no urgency.
  static const dailyChannel = 'mafia_daily';

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
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
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
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is! Map) return;
          final open = PushOpen.fromData(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
          if (open != null) _opened.add(open);
        } catch (_) {}
      },
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
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        gameChannel,
        text.game,
        description: text.gameDescription,
        importance: Importance.high,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(const [0, 250, 120, 250]),
      ),
    );
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        dailyChannel,
        text.daily,
        description: text.dailyDescription,
        importance: Importance.defaultImportance,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(social),
      ),
    );
    _local = local;
  }

  Future<void> _showForeground(RemoteMessage message) async {
    if (kIsWeb) return;
    final notification = message.notification;
    final local = _local;
    final text = _text;
    if (notification == null || local == null || text == null) return;
    final kind = message.data['kind'];
    final (channel, name, description) = switch (kind) {
      'invite' => (invitesChannel, text.invites, text.invitesDescription),
      'room_start' || 'night' => (gameChannel, text.game, text.gameDescription),
      'daily' ||
      'thursday' ||
      'comeback' => (dailyChannel, text.daily, text.dailyDescription),
      _ => (socialChannel, text.social, text.socialDescription),
    };
    await local.show(
      id: message.messageId?.hashCode ?? message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          name,
          channelDescription: description,
          icon: 'ic_stat_mafia',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  @override
  String? get platform => kIsWeb ? 'web' : 'android';

  @override
  Future<void> init() async {}

  @override
  bool get needsInstall => kIsWeb && webNeedsInstall();

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
  Future<bool> isGranted() async {
    try {
      final android = _local
          ?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      final settings = await _messaging.getNotificationSettings();
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
