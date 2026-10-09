import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a tapped notification carries. Invites keep their existing code and
/// sender fields; every other event is routed using only its kind.
enum PushDestination { invite, onlineRoom, onlineEntry, daily, orders, friends }

class PushOpen {
  PushDestination get destination => switch (kind) {
    'room_start' || 'night' => PushDestination.onlineRoom,
    'thursday' || 'comeback' => PushDestination.onlineEntry,
    'daily' => PushDestination.daily,
    'order_paid' || 'order_rejected' => PushDestination.orders,
    'friend_request' || 'friend_accepted' => PushDestination.friends,
    _ => PushDestination.invite,
  };
  final String kind;
  final String code;
  final String? inviteId;
  final String? fromName;
  const PushOpen({
    required this.kind,
    this.code = '',
    this.inviteId,
    this.fromName,
  });

  static final _code = RegExp(r'^[A-Za-z0-9]{6}$');

  /// Invite data is validated separately; all other supported events use
  /// their kind alone, without carrying any match information.
  static PushOpen? fromData(Map<String, Object?> data) {
    final kind = data['kind'];
    if (kind != 'invite') {
      return switch (kind) {
        'room_start' || 'night' || 'daily' || 'thursday' || 'comeback' ||
        'order_paid' || 'order_rejected' || 'friend_request' ||
        'friend_accepted' => PushOpen(kind: kind as String),
        _ => null,
      };
    }
    final code = data['code'];
    if (code is! String || !_code.hasMatch(code)) return null;
    return PushOpen(
      kind: 'invite',
      code: code.toUpperCase(),
      inviteId: data['inviteId'] is String ? data['inviteId'] as String : null,
      fromName: data['fromName'] is String ? data['fromName'] as String : null,
    );
  }
}

/// The phone's push plumbing. The default does nothing, so a build without
/// Firebase configuration (and every test) runs with push simply off.
abstract class PushService {
  /// 'android' or 'web'; null where push is not offered.
  String? get platform;

  /// True on a browser that only delivers push to an installed web app (iOS
  /// Safari, until the site is on the Home Screen).
  bool get needsInstall => false;

  /// Creates the notification channels. Safe to call more than once.
  Future<void> init();

  /// The runtime permission prompt (Android 13+, the browser). Never on the
  /// first launch: from the second session on Android, or in context
  /// (opening the invite sheet, receiving an invite).
  Future<bool> askPermission();

  /// Whether notifications are already allowed, without prompting: Android
  /// below 13 always, or a player who allowed them in the system settings.
  Future<bool> isGranted();

  /// This device's push token, or null.
  Future<String?> token();

  /// Notifications tapped while the app was alive (background/foreground).
  Stream<PushOpen> get opened;

  /// A push arrived while the app is in front (no notification is drawn
  /// then; the in-app popup takes over).
  Stream<void> get foreground;

  /// The notification that launched the app from closed, once.
  Future<PushOpen?> initialOpen();
}

class NoPushService implements PushService {
  const NoPushService();
  @override
  String? get platform => null;
  @override
  bool get needsInstall => false;
  @override
  Future<void> init() async {}
  @override
  Future<bool> askPermission() async => false;
  @override
  Future<bool> isGranted() async => false;
  @override
  Future<String?> token() async => null;
  @override
  Stream<PushOpen> get opened => const Stream.empty();
  @override
  Stream<void> get foreground => const Stream.empty();
  @override
  Future<PushOpen?> initialOpen() async => null;
}

/// Overridden in `main.dart` when Firebase is configured.
final pushServiceProvider = Provider<PushService>((_) => const NoPushService());

/// Bumped when an online table reaches its result. The table cannot import
/// the social layer (leakage closure), so the always-mounted invite host
/// listens and asks for notifications after the first finished match.
final matchResultReachedProvider = StateProvider<int>((_) => 0);
