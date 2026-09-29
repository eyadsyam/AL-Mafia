import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import 'directory.dart';
import 'friends.dart';

/// Profile: the player's handle (changeable, rate-limited, name rules apply)
/// and the two directory switches — «ماتظهرنيش في البحث» and invites from
/// people who are not friends.
///
/// M1: never starts a read. It draws only once «أصحابك» has already been
/// read by something else (the online door) and the server sent this
/// player's entry.
class DirectorySettings extends ConsumerStatefulWidget {
  const DirectorySettings({super.key});

  static const Key handleField = ValueKey('directory_handle_field');
  static const Key handleSave = ValueKey('directory_handle_save');
  static const Key hideSwitch = ValueKey('directory_hide_switch');
  static const Key muteSwitch = ValueKey('directory_mute_switch');

  @override
  ConsumerState<DirectorySettings> createState() => _DirectorySettingsState();
}

class _DirectorySettingsState extends ConsumerState<DirectorySettings> {
  TextEditingController? _handle;
  String? _error;
  bool _busy = false;
  DirectoryMe? _local;

  @override
  void dispose() {
    _handle?.dispose();
    super.dispose();
  }

  Future<void> _saveHandle(DirectoryMe me) async {
    final text = _handle!.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (text == me.handle || _busy) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    final (next, refusal) = await ref
        .read(directoryApiProvider)
        .setHandle(text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (next != null) _local = next;
      _error = switch (refusal) {
        null => null,
        HandleRefusal.taken => l.profileHandleTaken,
        HandleRefusal.tooSoon => l.profileHandleWait,
        HandleRefusal.refused => l.profileHandleRefused,
        HandleRefusal.invalid => l.profileHandleInvalid,
        HandleRefusal.failed => l.inviteFailed,
      };
    });
  }

  Future<void> _prefs({bool? searchable, bool? strangerInvites}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await ref
          .read(directoryApiProvider)
          .prefs(searchable: searchable, strangerInvites: strangerInvites);
      if (mounted) setState(() => _local = next);
    } catch (_) {
      // The switch shows the server's answer; nothing changed.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.exists(friendsProvider)) return const SizedBox.shrink();
    final me = _local ?? ref.watch(friendsProvider).valueOrNull?.me;
    if (me == null || me.handle == null) return const SizedBox.shrink();
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    _handle ??= TextEditingController(text: me.handle);
    return Padding(
      padding: EdgeInsets.only(top: s.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: DirectorySettings.handleField,
                  controller: _handle,
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: l.profileHandleLabel,
                    helperText: l.profileHandleHint,
                    prefixText: '@',
                    errorText: _error,
                    counterText: '',
                  ),
                  onSubmitted: (_) => _saveHandle(me),
                ),
              ),
              SizedBox(width: s.xs),
              TextButton(
                key: DirectorySettings.handleSave,
                onPressed: _busy ? null : () => _saveHandle(me),
                child: Text(l.profileHandleSave),
              ),
            ],
          ),
          SwitchListTile(
            key: DirectorySettings.hideSwitch,
            contentPadding: EdgeInsets.zero,
            title: Text(
              l.profileHideFromSearch,
              style: context.typography.body.copyWith(
                color: colors.textPrimary,
              ),
            ),
            value: !me.searchable,
            onChanged: _busy ? null : (hide) => _prefs(searchable: !hide),
          ),
          SwitchListTile(
            key: DirectorySettings.muteSwitch,
            contentPadding: EdgeInsets.zero,
            title: Text(
              l.profileMuteStrangers,
              style: context.typography.body.copyWith(
                color: colors.textPrimary,
              ),
            ),
            value: !me.strangerInvites,
            onChanged: _busy
                ? null
                : (mute) => _prefs(strangerInvites: !mute),
          ),
        ],
      ),
    );
  }
}
