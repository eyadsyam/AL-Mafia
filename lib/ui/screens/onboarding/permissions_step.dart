import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../platform/voice/microphone_permission.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';

/// The microphone row of the settings sheet. There is no permissions page:
/// the system dialog opens by itself on the tap that enters an online room
/// (`askMicrophoneForRoom`) and again from the lobby's microphone card; this
/// row is where a player can look and try again.
class MicrophoneSettingsRow extends ConsumerStatefulWidget {
  const MicrophoneSettingsRow({super.key});

  static const requestKey = ValueKey('settings.microphone');

  @override
  ConsumerState<MicrophoneSettingsRow> createState() =>
      _MicrophoneSettingsRowState();
}

class _MicrophoneSettingsRowState extends ConsumerState<MicrophoneSettingsRow> {
  MicrophoneStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final access = ref.read(microphoneAccessProvider);
    var status = await access.status();
    // The web cannot be asked quietly; the last real answer stands in.
    if (status == MicrophoneStatus.denied) {
      final saved = (await SharedPreferences.getInstance()).getBool(
        microphoneAllowedKey,
      );
      if (saved == true) status = MicrophoneStatus.granted;
    }
    if (mounted) setState(() => _status = status);
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    final access = ref.read(microphoneAccessProvider);
    var status = _status;
    if (status == MicrophoneStatus.blocked) {
      await access.openSettings();
    } else {
      status = await access.request();
      await (await SharedPreferences.getInstance()).setBool(
        microphoneAllowedKey,
        status == MicrophoneStatus.granted,
      );
    }
    if (mounted) {
      setState(() {
        _status = status;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(microphoneAccessProvider).supported) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final allowed = _status == MicrophoneStatus.granted;
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
                  allowed ? l.permissionAllowed : l.permissionNotAllowed,
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
              ],
            ),
          ),
          if (!allowed)
            TextButton(
              key: MicrophoneSettingsRow.requestKey,
              onPressed: _busy || _status == null ? null : _request,
              child: Text(
                _status == MicrophoneStatus.blocked
                    ? l.micOpenSettings
                    : l.permissionAsk,
              ),
            ),
        ],
      ),
    );
  }
}
