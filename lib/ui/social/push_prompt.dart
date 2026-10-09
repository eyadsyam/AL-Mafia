import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/push/push_service.dart';
import '../economy/economy_capabilities.dart';
import 'directory.dart';

/// The onboarding and settings notification switch, plus a fallback in an
/// invite context for a player who has never answered. A device that already
/// allows notifications registers silently when the player is ready.
class PushPrompt {
  final Ref _ref;
  PushPrompt(this._ref);

  static const askedKey = 'push_permission_asked_v1';

  /// The settings switch. Absent until the player decides or the in-context
  /// prompt was answered; `false` is an explicit «no» that nothing overrides.
  static const onKey = 'push_on_v1';

  bool _busy = false;

  /// Test hook: how many times the system prompt was requested.
  int prompts = 0;

  bool get _enabled {
    if (!_ref.exists(economyCapabilitiesProvider)) return false;
    final caps = _ref.read(economyCapabilitiesProvider).valueOrNull;
    return caps?.pushInvites ?? false;
  }

  Future<void> unregisterThisDevice() async {
    try {
      final token = await _ref.read(pushServiceProvider).token();
      if (token != null) {
        await _ref.read(directoryApiProvider).unregisterPush(token);
      }
    } catch (_) {
      // A failed cleanup must not prevent signing out or deleting an account.
    }
  }

  Future<void> askInContext() async {
    final push = _ref.read(pushServiceProvider);
    if (_busy || push.platform == null || push.needsInstall || !_enabled) {
      return;
    }
    if (await _explicitlyOff()) return;
    if ((await SharedPreferences.getInstance()).getBool(askedKey) ?? false) {
      return;
    }
    await _ask(push);
  }

  Future<bool> _explicitlyOff() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(onKey) == false;
    } catch (_) {
      return false;
    }
  }

  /// What the settings switch shows: on once permission was granted (or asked
  /// before this switch existed), off after an explicit «no».
  Future<bool> isOn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(onKey) ?? (prefs.getBool(askedKey) ?? false);
    } catch (_) {
      return false;
    }
  }

  /// The settings switch. Turning on asks the system for permission (it only
  /// shows its prompt when it still can) and registers this device; turning
  /// off forgets this device on the server. Returns the resulting state.
  Future<bool> setOn(bool on) async {
    final push = _ref.read(pushServiceProvider);
    if (push.platform == null) return false;
    final prefs = await SharedPreferences.getInstance();
    if (!on) {
      await prefs.setBool(onKey, false);
      try {
        final token = await push.token();
        if (token != null) {
          await _ref.read(directoryApiProvider).unregisterPush(token);
        }
      } catch (_) {
        // The server drops a dead token on its next send anyway.
      }
      return false;
    }
    await prefs.setBool(askedKey, true);
    prompts++;
    final granted = await push.askPermission();
    await prefs.setBool(onKey, granted);
    if (granted) {
      try {
        await _register(push);
      } catch (_) {}
    }
    return granted;
  }

  /// A submitted transfer also needs a notification when the app is closed.
  /// Payment delivery does not depend on the optional invite switch.
  Future<void> askForPayment() async {
    final push = _ref.read(pushServiceProvider);
    if (_busy || push.platform == null) return;
    if (await _explicitlyOff()) return;
    await _ask(push);
  }

  Future<void> _ask(PushService push) async {
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(askedKey) ?? false)) {
        await prefs.setBool(askedKey, true);
        prompts++;
        final granted = await push.askPermission();
        await prefs.setBool(onKey, granted);
      }
      await _register(push);
    } catch (_) {
      // Push is a convenience; the in-app invite still arrives.
    } finally {
      _busy = false;
    }
  }

  /// Called when the player is known to the directory (a name is set, once per
  /// presence beat). Registers a device that already allows notifications,
  /// without asking for permission.
  Future<void> onPlayerReady() async {
    final push = _ref.read(pushServiceProvider);
    if (_busy || push.platform == null || !_enabled) return;
    if (await _explicitlyOff()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final asked = prefs.getBool(askedKey) ?? false;
      if (asked || await push.isGranted()) {
        await _register(push);
      }
    } catch (_) {}
  }

  /// Refreshes this device's token on the server once permission was asked
  /// before (a later session, a rotated token). Never prompts.
  Future<void> refreshIfAsked() async {
    final push = _ref.read(pushServiceProvider);
    if (_busy || push.platform == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getBool(askedKey) ?? false) && prefs.getBool(onKey) != false) {
        await _register(push);
      }
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
