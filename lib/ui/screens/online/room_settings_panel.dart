import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transport/game_snapshot.dart';
import '../../../transport/online_transport.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/experience_surface.dart';
import '../../widgets/settings_kit.dart';
import '../../economy/cosmetics.dart';
import '../../economy/wallet.dart';
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
    if (widget.visible) _loadOwnedPacks();
  }

  /// Which packs this host may dress the room with, read when the panel is
  /// first opened (not while it waits hidden). A failure only hides the
  /// choice; the server checks ownership regardless.
  void _loadOwnedPacks() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(walletProvider).valueOrNull == null) {
        ref.read(walletProvider.notifier).refresh();
      }
    });
  }

  /// Classic, every owned code for [slot], and the room's current code even
  /// if this host does not own it (a hand-over keeps the previous host's).
  List<(String, String, Key?)> _cosmeticOptions(
    CosmeticSlot slot,
    String current,
  ) {
    final l10n = context.l10n;
    final owned = ref.watch(walletProvider).valueOrNull?.ownedFor(slot) ?? [];
    final codes = {...owned, if (current != 'classic') current};
    return [
      ('classic', l10n.cosmeticClassic, null),
      for (final code in codes)
        if (Cosmetics.items[code] != null)
          (code, Cosmetics.items[code]!.name(l10n), ValueKey('room_$code')),
    ];
  }

  @override
  void didUpdateWidget(RoomSettingsPanel old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _loadOwnedPacks();
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
    // A live room: every change is already on the other screens. Before the
    // room exists (the create form) nothing has been sent yet.
    final live = widget.onChanged == null;

    return Positioned.fill(
      key: RoomSettingsPanel.panel,
      // The same painted ground and the same panels as the general settings
      // (owner, 2026-09-24): one settings look across the app.
      child: Material(
        type: MaterialType.transparency,
        child: ExperienceSurface(
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
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        spacing.screenMargin,
                        spacing.md,
                        spacing.sm,
                        spacing.md,
                      ),
                      child: Row(
                        children: [
                          const SettingsBadge(icon: Icons.tune),
                          SizedBox(width: spacing.sm + spacing.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.onlineRoomSettings,
                                  style: type.headline.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                if (live)
                                  Text(
                                    l10n.onlineRoomSettingsHint,
                                    style: type.caption.copyWith(
                                      color: colors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            onPressed: widget.onClose,
                            icon: Icon(
                              Icons.close,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          spacing.screenMargin,
                          0,
                          spacing.screenMargin,
                          spacing.lg,
                        ),
                        children: [
                          SettingsPanel(
                            icon: Icons.meeting_room_outlined,
                            title: l10n.onlineSettingsRoom,
                            children: [
                              SettingsSegments<String>(
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
                              // Only a public room has a name worth typing: a
                              // private one is never listed anywhere the name
                              // could be read.
                              if (room.isPublic)
                                _titleField(
                                  l10n.onlineRoomTitle,
                                  l10n.onlineRoomTitleHint,
                                ),
                              SettingsSegments<int>(
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
                              if (ref.watch(scenarioPurchaseProvider).owned ||
                                  room.scenarioCode == 'shadows')
                                SettingsSegments<String>(
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
                              for (final (slot, key, label, current) in [
                                (
                                  CosmeticSlot.roomPack,
                                  'presentationPack',
                                  l10n.roomPackLabel,
                                  room.presentationPack,
                                ),
                                (
                                  CosmeticSlot.narrator,
                                  'narratorPack',
                                  l10n.roomNarratorLabel,
                                  room.narratorPack,
                                ),
                              ])
                                if (_cosmeticOptions(slot, current).length > 1)
                                  SettingsSegments<String>(
                                    label: label,
                                    hint: l10n.storeHostPackNote,
                                    value: current,
                                    options: _cosmeticOptions(slot, current),
                                    onChanged: (value) =>
                                        _send(settings: {key: value}),
                                  ),
                            ],
                          ),
                          SettingsPanel(
                            icon: Icons.mic_none_outlined,
                            title: l10n.onlineSettingsVoice,
                            children: [
                              SettingsSwitchRow(
                                switchKey: RoomSettingsPanel.voiceSwitch,
                                label: l10n.onlineVoiceEnabled,
                                hint: l10n.onlineVoiceEnabledHint,
                                value: room.voice,
                                onChanged: (value) =>
                                    _send(settings: {'voice': value}),
                              ),
                              SettingsSwitchRow(
                                switchKey: RoomSettingsPanel.muteAtNightSwitch,
                                label: l10n.onlineMuteAtNight,
                                hint: l10n.onlineNightPrivacyHint,
                                value: room.muteAllAtNight,
                                onChanged: (value) =>
                                    _send(settings: {'muteAllAtNight': value}),
                              ),
                            ],
                          ),
                          SettingsPanel(
                            icon: Icons.timer_outlined,
                            title: l10n.onlineSettingsPlay,
                            children: [
                              SettingsSegments<int>(
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
                              SettingsSegments<int>(
                                label:
                                    '${l10n.onlineDiscussDuration} (${l10n.onlineMinutes})',
                                hint: l10n.onlineDiscussDurationHint,
                                value: match.discussionSeconds,
                                options: const [
                                  (180, '3', null),
                                  (300, '5', null),
                                  (420, '7', null),
                                ],
                                onChanged: (value) => _send(
                                  settings: {'discussionSeconds': value},
                                ),
                              ),
                              // Not cosmetic online: structured discussion is
                              // what lets the mic policy hand the floor to one
                              // speaker at a time. A host who could not choose
                              // it here would get turn-taking they never asked
                              // for, and a table that reads two silent players
                              // as a broken call.
                              SettingsSegments<String>(
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
                              SettingsSwitchRow(
                                label: l10n.onlineOpenVoting,
                                hint: l10n.onlineOpenVotingHint,
                                value: match.openVoting,
                                onChanged: (value) =>
                                    _send(settings: {'openVoting': value}),
                              ),
                            ],
                          ),
                          SettingsPanel(
                            icon: Icons.manage_search_outlined,
                            title: l10n.onlineSettingsInfo,
                            children: [
                              SettingsSwitchRow(
                                label: l10n.onlineTrace,
                                hint: l10n.onlineTraceHint,
                                value: match.traceEnabled,
                                onChanged: (value) =>
                                    _send(settings: {'traceEnabled': value}),
                              ),
                              SettingsSwitchRow(
                                label: l10n.onlineConfrontation,
                                hint: l10n.onlineConfrontationHint,
                                value: match.confrontationEnabled,
                                onChanged: (value) => _send(
                                  settings: {'confrontationEnabled': value},
                                ),
                              ),
                              SettingsSwitchRow(
                                label: l10n.onlineWhispers,
                                hint: l10n.onlineWhispersHint,
                                value: match.whisperEnabled,
                                onChanged: (value) =>
                                    _send(settings: {'whisperEnabled': value}),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.footer != null)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceBase,
                          border: Border(
                            top: BorderSide(color: colors.borderSubtle),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(spacing.md),
                          child: widget.footer!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleField(String label, String hint) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
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
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              hint,
              style: context.typography.caption.copyWith(
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
