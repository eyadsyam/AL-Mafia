import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/motion_preference.dart';
import '../../../data/repository_provider.dart';
import '../../../engine/models/match_settings.dart';
import '../../../platform/voice/microphone_permission.dart';
import '../../l10n_ext.dart';
import '../../social/push_toggle.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_buttons.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/settings_kit.dart';
import '../setup/setup_draft.dart';

const permissionsDoneKey = 'mafia.permissions.onboarding.v1';

final permissionsDoneProvider = FutureProvider<bool>(
  (ref) async =>
      (await SharedPreferences.getInstance()).getBool(permissionsDoneKey) ??
      false,
);

abstract class MicrophonePermission {
  bool get supported;
  Future<bool> request();
}

class DeviceMicrophonePermission implements MicrophonePermission {
  const DeviceMicrophonePermission();

  @override
  bool get supported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<bool> request() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      final allowed = stream.getAudioTracks().isNotEmpty;
      for (final track in stream.getTracks()) {
        track.stop();
      }
      await stream.dispose();
      return allowed;
    } catch (_) {
      return false;
    }
  }
}

final microphonePermissionProvider = Provider<MicrophonePermission>(
  (_) => const DeviceMicrophonePermission(),
);

class MicrophoneSettingsRow extends ConsumerStatefulWidget {
  const MicrophoneSettingsRow({super.key});

  static const requestKey = ValueKey('settings.microphone');

  @override
  ConsumerState<MicrophoneSettingsRow> createState() =>
      _MicrophoneSettingsRowState();
}

class _MicrophoneSettingsRowState extends ConsumerState<MicrophoneSettingsRow> {
  bool _allowed = false;
  bool _asked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _allowed = prefs.getBool(microphoneAllowedKey) ?? false;
          _asked = prefs.containsKey(microphoneAllowedKey);
        });
      }
    });
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    final allowed = await ref.read(microphonePermissionProvider).request();
    await (await SharedPreferences.getInstance()).setBool(
      microphoneAllowedKey,
      allowed,
    );
    if (mounted) {
      setState(() {
        _allowed = allowed;
        _asked = true;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(microphonePermissionProvider).supported) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.permissionMicrophone,
                  style: context.typography.body.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
                Text(
                  _allowed ? l.permissionAllowed : l.permissionNotAllowed,
                  style: context.typography.caption.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                Text(
                  l.permissionMicrophoneHint,
                  style: context.typography.caption.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                if (_asked && !_allowed)
                  Text(
                    l.permissionDeniedHint,
                    style: context.typography.caption.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            key: MicrophoneSettingsRow.requestKey,
            onPressed: _busy ? null : _request,
            child: Text(_asked ? l.permissionRetry : l.permissionAsk),
          ),
        ],
      ),
    );
  }
}

class PermissionsStep extends ConsumerStatefulWidget {
  const PermissionsStep({
    super.key,
    required this.onContinue,
    this.failed = false,
  });
  final FutureOr<void> Function() onContinue;
  final bool failed;

  static const continueKey = ValueKey('permissions_continue');

  @override
  ConsumerState<PermissionsStep> createState() => _PermissionsStepState();
}

class _PermissionsStepState extends ConsumerState<PermissionsStep> {
  MatchSettings? _settings;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    MatchSettings settings;
    try {
      settings = await ref.read(matchRepositoryProvider).loadDefaultSettings();
    } catch (_) {
      settings = ref.read(setupDraftProvider).settings;
    }
    if (mounted) setState(() => _settings = settings);
  }

  void _edit(MatchSettings Function(MatchSettings) change) {
    final next = change(_settings!);
    setState(() => _settings = next);
    ref.read(setupDraftProvider.notifier).setSettings(next);
    unawaited(ref.read(matchRepositoryProvider).saveDefaultSettings(next));
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      await (await SharedPreferences.getInstance()).setBool(
        permissionsDoneKey,
        true,
      );
      ref.invalidate(permissionsDoneProvider);
      await widget.onContinue();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = context.l10n;
    final cur = _settings;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              s.screenMargin,
              s.xl,
              s.screenMargin,
              s.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.permissionsTitle,
                  style: context.typography.title.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
                SizedBox(height: s.sm),
                Text(
                  l.permissionsHint,
                  style: context.typography.body.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                if (widget.failed)
                  Text(
                    l.profileSaveFailed,
                    key: const ValueKey('first_run_failed'),
                    style: context.typography.caption.copyWith(
                      color: context.colors.accentCrimson,
                    ),
                  ),
                SizedBox(height: s.lg),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: s.md,
                    vertical: s.xs,
                  ),
                  decoration: BoxDecoration(
                    color: DeckTokens.panel,
                    borderRadius: BorderRadius.circular(
                      SettingsSheetTokens.groupRadius,
                    ),
                    border: Border.all(color: DeckTokens.line),
                  ),
                  child: const Column(
                    children: [
                      PushSettingsRow(compact: true),
                      Divider(color: DeckTokens.line),
                      MicrophoneSettingsRow(),
                    ],
                  ),
                ),
                SizedBox(height: s.md),
                if (cur != null) ...[
                  const LanguagePicker(),
                  SettingsSwitchRow(
                    label: l.muteAllAudio,
                    value: cur.muteAllAudio,
                    onChanged: (v) => _edit((x) => x.copyWith(muteAllAudio: v)),
                  ),
                  SettingsSwitchRow(
                    label: l.settingsNarratorOn,
                    value: cur.narrationEnabled && !cur.muteAllAudio,
                    onChanged: cur.muteAllAudio
                        ? null
                        : (v) => _edit((x) => x.copyWith(narrationEnabled: v)),
                  ),
                  SettingsSwitchRow(
                    label: l.scoreEnabledLabel,
                    value: cur.scoreEnabled && !cur.muteAllAudio,
                    onChanged: cur.muteAllAudio
                        ? null
                        : (v) => _edit((x) => x.copyWith(scoreEnabled: v)),
                  ),
                  SettingsSwitchRow(
                    label: l.prefReduceMotion,
                    value: ref.watch(reduceMotionPreferenceProvider),
                    onChanged: (v) => ref
                        .read(reduceMotionPreferenceProvider.notifier)
                        .set(v),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(s.screenMargin),
          child: BoneButton(
            key: PermissionsStep.continueKey,
            label: l.continueAction,
            onPressed: _busy ? null : _continue,
          ),
        ),
      ],
    );
  }
}
