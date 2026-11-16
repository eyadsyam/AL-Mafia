import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/social/push_prompt.dart';

/// The one system question asked by itself as the game opens: notifications.
///
/// No page and no «not now» of ours stands before it: the phone's own dialog.
/// Asked again on the next launch while the answer is not yes.
///
/// The microphone is not asked here any more. It is asked on the tap that
/// enters an online room (`askMicrophoneForRoom`), the only place the game
/// uses it: Google Play's audio policy flags a launch-time microphone request
/// that is repeated for players who never go online.
///
/// On the web the notification question waits for the first touch: browsers
/// drop (or hide) a request that no gesture started.
class StartupPermissions {
  StartupPermissions(this._ref);
  final Ref _ref;

  bool _ran = false;
  PointerRoute? _firstTap;

  /// Test hook: how far the last [run] got.
  bool pushAsked = false;

  Future<void> run() async {
    if (_ran) return;
    _ran = true;
    if (kIsWeb) {
      _askPushOnFirstTap();
    } else {
      pushAsked = true;
      await _push();
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
