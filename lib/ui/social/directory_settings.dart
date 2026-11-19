import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/public_web_origin.dart';
import '../../platform/invite_share.dart';
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
  static const Key shareHandle = ValueKey('directory_share_handle');
  static const Key onlineSwitch = ValueKey('directory_online_switch');
  static const Key shareSwitch = ValueKey('directory_share_switch');
  static Key whoCanAdd(String value) => ValueKey('directory_who_$value');

  @override
  ConsumerState<DirectorySettings> createState() => _DirectorySettingsState();
}

class _DirectorySettingsState extends ConsumerState<DirectorySettings> {
  TextEditingController? _handle;
  String? _error;
  bool _busy = false;
  DirectoryMe? _local;
  bool _locked = false;

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
      if (refusal == HandleRefusal.locked) _locked = true;
      _error = switch (refusal) {
        null => null,
        HandleRefusal.taken => l.profileHandleTaken,
        HandleRefusal.tooSoon => l.profileHandleWait,
        HandleRefusal.refused => l.profileHandleRefused,
        HandleRefusal.invalid => l.profileHandleInvalid,
        // Shown as the field's own note once the field is read-only.
        HandleRefusal.locked => null,
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

  FriendPrivacy? _privacy;

  Future<void> _setPrivacy({
    String? whoCanAdd,
    bool? showOnline,
    bool? shareActivity,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await ref
          .read(directoryApiProvider)
          .privacy(
            whoCanAdd: whoCanAdd,
            showOnline: showOnline,
            shareActivity: shareActivity,
          );
      if (mounted) setState(() => _privacy = next);
    } catch (_) {
      // The control keeps the server's last answer.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// S1: «ابعت اليوزرنيم» — the handle and the site, through the share sheet.
  Future<void> _share(String handle) async {
    final l = context.l10n;
    final outcome = await ref
        .read(inviteSharerProvider)
        .share(
          text: '${l.friendShareHandle(handle)}\n$kPublicWebOrigin',
          subject: l.appTitle,
        );
    if (!mounted) return;
    final note = switch (outcome) {
      InviteShareOutcome.handedOver => null,
      InviteShareOutcome.copied => l.shareTextCopied,
      InviteShareOutcome.failed => l.shareUnavailable,
    };
    if (note != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(note)));
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
    final locked = _locked || me.handleLocked;
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
                  readOnly: locked,
                  decoration: InputDecoration(
                    labelText: l.profileHandleLabel,
                    helperText: locked
                        ? l.profileHandleLocked
                        : l.profileHandleHint,
                    helperMaxLines: 2,
                    prefixText: '@',
                    errorText: _error,
                    counterText: '',
                  ),
                  onSubmitted: locked ? null : (_) => _saveHandle(me),
                ),
              ),
              if (!locked) ...[
                SizedBox(width: s.xs),
                TextButton(
                  key: DirectorySettings.handleSave,
                  onPressed: _busy ? null : () => _saveHandle(me),
                  child: Text(l.profileHandleSave),
                ),
              ],
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: DirectorySettings.shareHandle,
              onPressed: () => _share(me.handle!),
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(l.friendShareHandleAction),
            ),
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
            onChanged: _busy ? null : (mute) => _prefs(strangerInvites: !mute),
          ),
          ..._privacyControls(context),
        ],
      ),
    );
  }

  /// S6: «مين يقدر يبعتلك طلب صداقة» and «أصحابي يشوفوني أونلاين».
  List<Widget> _privacyControls(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final me = ref.watch(friendsProvider).valueOrNull?.me;
    final privacy = _privacy ?? me?.privacy;
    if (privacy == null) return const [];
    return [
      Padding(
        padding: EdgeInsets.only(top: s.sm, bottom: s.xs),
        child: Text(
          l.friendWhoCanAdd,
          style: type.body.copyWith(color: colors.textPrimary),
        ),
      ),
      Wrap(
        spacing: s.sm,
        runSpacing: s.xs,
        children: [
          for (final (value, label) in [
            ('everyone', l.friendWhoEveryone),
            ('tablemates', l.friendWhoTablemates),
            ('nobody', l.friendWhoNobody),
          ])
            ChoiceChip(
              key: DirectorySettings.whoCanAdd(value),
              label: Text(label),
              selected: privacy.whoCanAdd == value,
              onSelected: _busy || privacy.whoCanAdd == value
                  ? null
                  : (_) => _setPrivacy(whoCanAdd: value),
            ),
        ],
      ),
      SwitchListTile(
        key: DirectorySettings.onlineSwitch,
        contentPadding: EdgeInsets.zero,
        title: Text(
          l.friendShowOnline,
          style: type.body.copyWith(color: colors.textPrimary),
        ),
        value: privacy.showOnline,
        onChanged: _busy ? null : (on) => _setPrivacy(showOnline: on),
      ),
      SwitchListTile(
        key: DirectorySettings.shareSwitch,
        contentPadding: EdgeInsets.zero,
        title: Text(
          l.friendShareActivity,
          style: type.body.copyWith(color: colors.textPrimary),
        ),
        value: privacy.shareActivity,
        onChanged: _busy ? null : (on) => _setPrivacy(shareActivity: on),
      ),
    ];
  }

}
