import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/push/push_service.dart';
import '../economy/economy_capabilities.dart';
import 'directory.dart';

/// Notification permission, asked in context and never on first launch: the
/// first time the player opens the invite sheet or receives an invite in the
/// app. Nothing happens while push is off on the server (`social.pushInvites`),
/// before the capabilities were read by something else, or where this build
/// has no push (no Firebase configuration).
class PushPrompt {
  final Ref _ref;
  PushPrompt(this._ref);

  static const askedKey = 'push_permission_asked_v1';
  bool _busy = false;

  /// Test hook: how many times the system prompt was requested.
  int prompts = 0;

  bool get _enabled {
    if (!_ref.exists(economyCapabilitiesProvider)) return false;
    final caps = _ref.read(economyCapabilitiesProvider).valueOrNull;
    return caps?.pushInvites ?? false;
  }

  Future<void> askInContext() async {
    final push = _ref.read(pushServiceProvider);
    if (_busy || push.platform == null || !_enabled) return;
    await _ask(push);
  }

  /// A submitted transfer also needs a notification when the app is closed.
  /// Payment delivery does not depend on the optional invite switch.
  Future<void> askForPayment() async {
    final push = _ref.read(pushServiceProvider);
    if (_busy || push.platform == null) return;
    await _ask(push);
  }

  Future<void> _ask(PushService push) async {
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(askedKey) ?? false)) {
        await prefs.setBool(askedKey, true);
        prompts++;
        await push.askPermission();
      }
      await _register(push);
    } catch (_) {
      // Push is a convenience; the in-app invite still arrives.
    } finally {
      _busy = false;
    }
  }

  /// Refreshes this device's token on the server once permission was asked
  /// before (a later session, a rotated token). Never prompts.
  Future<void> refreshIfAsked() async {
    final push = _ref.read(pushServiceProvider);
    if (_busy || push.platform == null || !_enabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(askedKey) ?? false) await _register(push);
    } catch (_) {}
  }

  Future<void> _register(PushService push) async {
    final token = await push.token();
    final platform = push.platform;
    if (token == null || platform == null) return;
    await _ref.read(directoryApiProvider).registerPush(token, platform);
  }
}

final pushPromptProvider = Provider<PushPrompt>(PushPrompt.new);
