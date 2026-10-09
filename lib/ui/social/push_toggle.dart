import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/push/push_service.dart';
import '../l10n_ext.dart';
import '../widgets/settings_kit.dart';
import 'push_prompt.dart';

/// «الإشعارات» in settings: the one switch for every notification this device
/// gets (invites, the room starting, the night falling, daily rewards,
/// Thursday night, a comeback nudge).
///
/// Hidden where this build has no push. On an iPhone's browser tab the switch
/// is disabled and the row explains the Home Screen step instead, since Safari
/// delivers web push only to an installed web app.
class PushSettingsRow extends ConsumerStatefulWidget {
  const PushSettingsRow({super.key, this.compact = false});
  final bool compact;

  static const switchKey = Key('settings.push');

  @override
  ConsumerState<PushSettingsRow> createState() => _PushSettingsRowState();
}

class _PushSettingsRowState extends ConsumerState<PushSettingsRow> {
  bool _on = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(pushPromptProvider).isOn().then((value) {
      if (mounted) setState(() => _on = value);
    });
  }

  Future<void> _change(bool value) async {
    setState(() => _busy = true);
    final result = await ref.read(pushPromptProvider).setOn(value);
    if (mounted) {
      setState(() {
        _on = result;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final push = ref.watch(pushServiceProvider);
    if (push.platform == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final install = push.needsInstall;
    return SettingsSwitchRow(
      switchKey: PushSettingsRow.switchKey,
      label: l10n.pushSettingsTitle,
      hint: install
          ? l10n.pushSettingsIosHint
          : widget.compact
          ? l10n.permissionNotificationsHint
          : l10n.pushSettingsHint,
      value: _on && !install,
      onChanged: install || _busy ? null : _change,
    );
  }
}
