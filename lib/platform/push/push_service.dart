import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a tapped notification carries: the whole invite payload (Doc 05: a
/// room code, the sender's name and handle, the invite id — nothing else).
class PushOpen {
  final String kind;
  final String code;
  final String? inviteId;
  final String? fromName;
  const PushOpen({
    required this.kind,
    required this.code,
    this.inviteId,
    this.fromName,
  });

  static final _code = RegExp(r'^[A-Za-z0-9]{6}$');

  /// Null for anything that is not a well-formed invite payload.
  static PushOpen? fromData(Map<String, Object?> data) {
    final code = data['code'];
    if (data['kind'] != 'invite' || code is! String || !_code.hasMatch(code)) {
      return null;
    }
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

  /// Creates the notification channels. Safe to call more than once.
  Future<void> init();

  /// The runtime permission prompt (Android 13+, the browser). Only ever
  /// called in context: opening the invite sheet or receiving an invite.
  Future<bool> askPermission();

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
  Future<void> init() async {}
  @override
  Future<bool> askPermission() async => false;
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
