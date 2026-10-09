import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/push/push_service.dart';
import '../economy/economy_capabilities.dart';
import 'directory.dart';

/// Notification permission, never at first launch: asked the first time the
/// player opens the invite sheet or receives an invite in the app, and on
/// Android at the start of their second session — an invite only reaches a
/// closed app on a device that registered *before* it was sent, so waiting for
/// the player to invite somebody left every invitee unreachable. A device
/// where notifications are already allowed registers without any prompt.
/// Invite prompts need `social.pushInvites`; the first result can ask for
/// reminders and room events even when invites are disabled.
/// No prompt is shown where this build has no push configuration.
class PushPrompt {
  final Ref _ref;
  PushPrompt(this._ref);

  static const askedKey = 'push_permission_asked_v1';

  /// The settings switch. Absent until the player decides or the in-context
  /// prompt was answered; `false` is an explicit «no» that nothing overrides.
  static const onKey = 'push_on_v1';

  /// App sessions this device has started with a name set, counted once per
  /// process by [onPlayerReady].
  static const sessionsKey = 'push_sessions_v1';
  static const firstResultKey = 'push_first_result_v1';
  bool _busy = false;
  bool _counted = false;

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

  Future<void> askAfterFirstResult() async {
    final push = _ref.read(pushServiceProvider);
    if (_busy || push.platform == null || push.needsInstall) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(firstResultKey) ?? false) return;
      await prefs.setBool(firstResultKey, true);
      if (prefs.getBool(onKey) == false) return;
      await _ask(push);
    } catch (_) {}
  }

  Future<void> askInContext() async {
    final push = _ref.read(pushServiceProvider);
    if (_busy || push.platform == null || !_enabled) return;
    if (await _explicitlyOff()) return;
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
  /// and on Android asks once from the second session on.
  Future<void> onPlayerReady() async {
    final push = _ref.read(pushServiceProvider);
    if (_busy || push.platform == null || !_enabled) return;
    if (await _explicitlyOff()) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      var sessions = prefs.getInt(sessionsKey) ?? 0;
      if (!_counted) {
        _counted = true;
        sessions++;
        await prefs.setInt(sessionsKey, sessions);
      }
      final asked = prefs.getBool(askedKey) ?? false;
      if (asked || await push.isGranted()) {
        await _register(push);
      } else if (push.platform == 'android' && sessions >= 2) {
        await _ask(push);
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
