import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/voice/microphone_permission.dart';
import '../ui/social/push_prompt.dart';

/// The two system questions, asked by themselves the moment the game opens.
///
/// No page and no «not now» of ours stands before them: the phone's own
/// dialog for the microphone, then the phone's own dialog for notifications.
/// Asked again on the next launch while the answer is not yes; a microphone
/// the phone has blocked for good is left to the lobby's card, which can open
/// the settings page.
///
/// On the web the notification question waits for the first touch: browsers
/// drop (or hide) a request that no gesture started.
class StartupPermissions {
  StartupPermissions(this._ref);
  final Ref _ref;

  bool _ran = false;
  PointerRoute? _firstTap;

  /// Test hook: how far the last [run] got.
  bool micAsked = false;
  bool pushAsked = false;

  Future<void> run() async {
    if (_ran) return;
    _ran = true;
    await _microphone();
    if (kIsWeb) {
      _askPushOnFirstTap();
    } else {
      pushAsked = true;
      await _push();
    }
  }

  Future<void> _microphone() async {
    try {
      final access = _ref.read(microphoneAccessProvider);
      if (!access.supported) return;
      var status = await access.status();
      if (status == MicrophoneStatus.denied) {
        micAsked = true;
        status = await access.request();
      }
      if (status == MicrophoneStatus.unsupported) return;
      await (await SharedPreferences.getInstance()).setBool(
        microphoneAllowedKey,
        status == MicrophoneStatus.granted,
      );
    } catch (_) {
      // The room asks again; a launch never fails over a dialog.
    }
  }

  Future<void> _push() async {
    try {
      await _ref.read(pushPromptProvider).askAtStartup();
    } catch (_) {}
  }

  void _askPushOnFirstTap() {
    final router = GestureBinding.instance.pointerRouter;
    void route(PointerEvent event) {
      if (event is! PointerDownEvent) return;
      final self = _firstTap;
      if (self == null) return;
      _firstTap = null;
      router.removeGlobalRoute(self);
      pushAsked = true;
      unawaited(_push());
    }

    _firstTap = route;
    router.addGlobalRoute(route);
  }
}

final startupPermissionsProvider = Provider<StartupPermissions>(
  StartupPermissions.new,
);
