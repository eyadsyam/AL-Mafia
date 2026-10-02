import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transport/game_snapshot.dart';
import '../../../transport/online_transport.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../setup/scenario_store.dart';

/// The host's room settings, as a layer over the lobby (task 10).
///
/// ## Why every control says what it does
///
/// A settings screen whose rows are four words each is a screen that gets read
/// once, by the person who wrote it. «الأثر» means nothing to a host who has
/// not yet played a match with it on, and the cost of guessing wrong is nine
/// other people's evening. So each control carries one line underneath saying
/// what turning it does — never what it *is*.
///
/// ## Why numbers are segments and flags are switches
///
/// A number with three sensible values is a choice between three things, and a
/// slider would invite a host to pick 43 seconds and wonder whether that was
/// allowed. The server's allow-list holds exactly these values, so the control
/// offering anything else would be offering a refusal.
///
/// ## Where the decision actually lives
///
/// Not here. `room_settings` re-checks that the caller is the host, that the
/// room is still in the lobby, and that every value is one this offers. This is
/// a form; a modified client sending `speechSeconds: 5` gets `BAD_REQUEST`.
///
/// Every change is sent immediately and lands on the other nine screens through
/// the `rooms` delta — which is why there is no save button to forget.
class RoomSettingsPanel extends ConsumerStatefulWidget {
  final bool visible;
  final GameSnapshot snapshot;
  final OnlineTransport? transport;
  final VoidCallback onClose;
  final void Function({
    String? visibility,
    String? title,
    Map<String, dynamic>? settings,
  })?
  onChanged;
  final Widget? footer;

  const RoomSettingsPanel({
    super.key,
    required this.visible,
    required this.snapshot,
    required this.transport,
    required this.onClose,
    this.onChanged,
    this.footer,
  });

  static const Key panel = ValueKey('room_settings');
  static const Key visibilityPrivate = ValueKey('room_settings_private');
  static const Key visibilityPublic = ValueKey('room_settings_public');
  static const Key titleField = ValueKey('room_settings_title');
  static const Key voiceSwitch = ValueKey('room_settings_voice');
  static const Key muteAtNightSwitch = ValueKey('room_settings_mute_at_night');
  static const Key discussionStructured = ValueKey('room_settings_structured');
  static const Key discussionFree = ValueKey('room_settings_free');

  @override
  ConsumerState<RoomSettingsPanel> createState() => _RoomSettingsPanelState();
}

class _RoomSettingsPanelState extends ConsumerState<RoomSettingsPanel> {
  final TextEditingController _title = TextEditingController();
  String _committed = '';

  @override
  void initState() {
    super.initState();
    _committed = widget.snapshot.room.title ?? '';
    _title.text = _committed;
  }

  @override
  void didUpdateWidget(RoomSettingsPanel old) {
    super.didUpdateWidget(old);
    // Somebody else's change to the title — there is only one host, so in
    // practice this is a resync — should not fight a host who is mid-word.
    final server = widget.snapshot.room.title ?? '';
    if (server != _committed && !_title.selection.isValid) {
      _committed = server;
      _title.text = server;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _send({
    String? visibility,
    String? title,
    Map<String, dynamic>? settings,
  }) {
    if (widget.onChanged != null) {
      widget.onChanged!(
        visibility: visibility,
        title: title,
        settings: settings,
      );
      return;
    }
    widget.transport?.setRoomSettings(
      visibility: visibility,
      title: title,
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final room = widget.snapshot.room;
    final match = widget.snapshot.settings;

    return Positioned.fill(
      key: RoomSettingsPanel.panel,
      child: ColoredBox(
        color: colors.surfaceBase,
        // The same reading column the door and the lobby keep on a wide
        // screen: a full-screen sheet that ran the whole width of a desktop
        // put its segments and switches a screen's breadth apart.
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: spacing.md),
                          child: Text(
                            l10n.onlineRoomSettings,
                            style: type.title.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: widget.onClose,
                        icon: Icon(Icons.close, color: colors.textSecondary),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(horizontal: spacing.md),
                      children: [
                        _section(l10n.onlineSettingsRoom),
                        if (ref.watch(scenarioPurchaseProvider).owned ||
                            room.scenarioCode == 'shadows')
                          _segments<String>(
                            label: l10n.premiumScenarioUse,
                            hint: l10n.premiumScenarioUseHint,
                            value: room.scenarioCode,
                            options: [
                              ('classic', l10n.presetClassic, null),
                              ('shadows', l10n.premiumScenarioUse, null),
                            ],
                            onChanged: (value) =>
                                _send(settings: {'scenarioCode': value}),
                          ),
                        _segments<String>(
                          label: l10n.onlineRoomVisibility,
                          hint: l10n.onlineRoomVisibilityHint,
                          value: room.visibility,
                          options: [
                            (
                              'private',
                              l10n.onlineRoomPrivate,
                              RoomSettingsPanel.visibilityPrivate,
                            ),
                            (
                              'public',
                              l10n.onlineRoomPublic,
                              RoomSettingsPanel.visibilityPublic,
                            ),
                          ],
                          onChanged: (value) => _send(visibility: value),
                        ),
                        // Only a public room has a name worth typing: a private one
                        // is never listed anywhere the name could be read.
                        if (room.isPublic)
                          _titleField(
                            l10n.onlineRoomTitle,
                            l10n.onlineRoomTitleHint,
                          ),
                        _segments<int>(
                          label: l10n.onlineMaxPlayers,
                          hint: l10n.onlineMaxPlayersHint,
                          value: room.maxPlayers,
                          options: const [
                            (5, '5', null),
                            (8, '8', null),
                            (10, '10', null),
                            (15, '15', null),
                          ],
                          onChanged: (value) =>
                              _send(settings: {'maxPlayers': value}),
                        ),
                        _section(l10n.onlineSettingsVoice),
                        _flag(
                          key: RoomSettingsPanel.voiceSwitch,
                          label: l10n.onlineVoiceEnabled,
                          hint: l10n.onlineVoiceEnabledHint,
                          value: room.voice,
                          onChanged: (value) =>
                              _send(settings: {'voice': value}),
                        ),
                        _flag(
                          key: RoomSettingsPanel.muteAtNightSwitch,
                          label: l10n.onlineMuteAtNight,
                          hint: l10n.onlineNightPrivacyHint,
                          value: room.muteAllAtNight,
                          onChanged: (value) =>
                              _send(settings: {'muteAllAtNight': value}),
                        ),
                        _section(l10n.onlineSettingsPlay),
                        _segments<int>(
                          label:
                              '${l10n.onlineSpeakDuration} (${l10n.onlineSeconds})',
                          hint: l10n.onlineSpeakDurationHint,
                          value: match.speechSeconds,
                          options: const [
                            (30, '30', null),
                            (45, '45', null),
                            (60, '60', null),
                          ],
                          onChanged: (value) =>
                              _send(settings: {'speechSeconds': value}),
                        ),
                        _segments<int>(
                          label:
                              '${l10n.onlineDiscussDuration} (${l10n.onlineMinutes})',
                          hint: l10n.onlineDiscussDurationHint,
                          value: match.discussionSeconds,
                          options: const [
                            (180, '3', null),
                            (300, '5', null),
                            (420, '7', null),
                          ],
                          onChanged: (value) =>
                              _send(settings: {'discussionSeconds': value}),
                        ),
                        // Not cosmetic online: structured discussion is what lets
                        // the mic policy hand the floor to one speaker at a time.
                        // A host who could not choose it here would get turn-taking
                        // they never asked for, and a table that reads two silent
                        // players as a broken call.
                        _segments<String>(
                          label: l10n.discussionModeLabel,
                          hint: l10n.settingDiscussionModeHint,
                          value: match.discussionMode.name,
                          options: [
                            (
                              'structured',
                              l10n.discussionStructured,
                              RoomSettingsPanel.discussionStructured,
                            ),
                            (
                              'free',
                              l10n.discussionFree,
                              RoomSettingsPanel.discussionFree,
                            ),
                          ],
                          onChanged: (value) =>
                              _send(settings: {'discussionMode': value}),
                        ),
                        _flag(
                          label: l10n.onlineOpenVoting,
                          hint: l10n.onlineOpenVotingHint,
                          value: match.openVoting,
                          onChanged: (value) =>
                              _send(settings: {'openVoting': value}),
                        ),
                        _section(l10n.onlineSettingsInfo),
                        _flag(
                          label: l10n.onlineTrace,
                          hint: l10n.onlineTraceHint,
                          value: match.traceEnabled,
                          onChanged: (value) =>
                              _send(settings: {'traceEnabled': value}),
                        ),
                        _flag(
                          label: l10n.onlineConfrontation,
                          hint: l10n.onlineConfrontationHint,
                          value: match.confrontationEnabled,
                          onChanged: (value) =>
                              _send(settings: {'confrontationEnabled': value}),
                        ),
                        _flag(
                          label: l10n.onlineWhispers,
                          hint: l10n.onlineWhispersHint,
                          value: match.whisperEnabled,
                          onChanged: (value) =>
                              _send(settings: {'whisperEnabled': value}),
                        ),
                        SizedBox(height: spacing.xl),
                        SizedBox(height: spacing.lg),
                      ],
                    ),
                  ),
                  if (widget.footer != null)
                    Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: widget.footer!,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String label) {
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.only(top: spacing.lg, bottom: spacing.sm),
      child: Text(
        label,
        style: context.typography.caption.copyWith(
          color: context.colors.accentGold,
        ),
      ),
    );
  }

  Widget _hintLine(String hint) => Padding(
    padding: EdgeInsets.only(top: context.spacing.xs),
    child: Text(
      hint,
      style: context.typography.caption.copyWith(
        color: context.colors.textMuted,
      ),
    ),
  );

  Widget _flag({
    Key? key,
    required String label,
    required String hint,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.only(top: spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.typography.body.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              // Themed, not coloured here: the panel used to paint the lit
              // track `accentGold`, the same colour the theme gives the lit
              // thumb, so an "on" switch was one flat pill with no thumb in it
              // (E-5). The theme's lit track is the pressed gold; the thumb
              // reads against it.
              Switch(key: key, value: value, onChanged: onChanged),
            ],
          ),
          _hintLine(hint),
        ],
      ),
    );
  }

  Widget _segments<T>({
    required String label,
    required String hint,
    required T value,
    required List<(T, String, Key?)> options,
    required ValueChanged<T> onChanged,
  }) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    return Padding(
      padding: EdgeInsets.only(top: spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.typography.body.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: spacing.xs),
          Row(
            children: [
              for (final (option, text, key) in options)
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(end: spacing.xs),
                    child: OutlinedButton(
                      key: key,
                      onPressed: option == value
                          ? null
                          : () => onChanged(option),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: option == value
                            ? colors.accentGold
                            : Colors.transparent,
                        disabledForegroundColor: colors.surfaceBase,
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.borderSubtle),
                        padding: EdgeInsets.symmetric(vertical: spacing.sm),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radii.button),
                        ),
                      ),
                      child: Text(text),
                    ),
                  ),
                ),
            ],
          ),
          _hintLine(hint),
        ],
      ),
    );
  }

  Widget _titleField(String label, String hint) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.only(top: spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: RoomSettingsPanel.titleField,
            controller: _title,
            maxLength: 40,
            textInputAction: TextInputAction.done,
            style: context.typography.body.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: label,
              counterText: '',
              labelStyle: context.typography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
            onSubmitted: (value) {
              _committed = value.trim();
              _send(title: _committed);
            },
            onChanged: widget.onChanged == null
                ? null
                : (value) => _send(title: value.trim()),
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              final value = _title.text.trim();
              if (value == _committed) return;
              _committed = value;
              _send(title: value);
            },
          ),
          _hintLine(hint),
        ],
      ),
    );
  }
}
