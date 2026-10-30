import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/asset_constants.dart';
import '../../../platform/reduce_motion.dart';
import '../../../transport/game_snapshot.dart';
import '../../../transport/online_transport.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/experience_surface.dart';
import '../../widgets/settings_kit.dart';
import '../../economy/cosmetics.dart';
import '../../economy/my_cosmetics.dart';
import '../../economy/store_art.dart';
import '../../economy/wallet.dart';
import '../setup/optional_roles.dart';
import '../setup/role_deal_grid.dart' show roleFace;
import '../setup/role_rows.dart' show StoreDoor;
import '../setup/scenario_store.dart';
import 'lobby_deal.dart';
import 'room_look_picker.dart';

/// The host's room settings, as a layer over the lobby (task 10).
///
/// ## Why the words are where they are
///
/// A sentence under every control is a wall nobody reads (owner, 2026-10-30), so
/// a control whose name already says it carries none. «الأثر» means nothing to a
/// host who has not played with it on, so that one, and its like, keep theirs.
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

  /// The host's deal at a glance, opening the deal editor (owner,
  /// 2026-10-29). Built by the lobby, which owns the split.
  final Widget? dealEntry;
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
    this.dealEntry,
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
  static const Key revealWhispersKey = ValueKey(
    'room_settings_reveal_whispers',
  );
  static const Key silencerKey = ValueKey('room_settings_silencer');
  static const Key elderKey = ValueKey('room_settings_elder');
  static const Key sniperKey = ValueKey('room_settings_sniper');
  static Key section(String id) => ValueKey('room_settings_section_$id');

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

  /// One bought role: its card, what it does, and its switch. A host may switch
  /// on a role they own before the seats are here (a room fills up after it is
  /// set); it joins the deal when the table can take it, and the row says when.
  /// A role not bought opens the store instead.
  Widget _roleRow({
    required OptionalRole role,
    required String label,
    required String hint,
    required bool on,
    required Key switchKey,
    required String flag,
  }) {
    final l10n = context.l10n;
    final owns = ref.watch(hostOwnedRolesProvider).contains(role.code);
    final room = widget.snapshot.room;
    final live = widget.onChanged == null;
    final seats = lobbyDealSeats(widget.snapshot.public.players.length);
    final words = !owns && !on
        ? l10n.roleLockedHint
        : on && room.maxPlayers < role.minPlayers
        ? l10n.roomRoleNeedsBiggerRoom(role.minPlayers)
        : on && live && seats < role.minPlayers
        ? l10n.rolesWaitSeats(role.minPlayers)
        : hint;
    Widget row(VoidCallback? store) => SettingsSwitchRow(
      switchKey: switchKey,
      label: label,
      hint: words,
      pill: owns || on ? null : l10n.roleLockedPill,
      value: on,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
        child: Opacity(
          opacity: owns || on ? 1 : RolesTokens.dealLockedAlpha,
          child: Image.asset(
            roleFace(role.role),
            width: RoomLookTokens.roleCard,
            height: RoomLookTokens.roleCardHeight,
            fit: BoxFit.cover,
            alignment: RolesTokens.dealFocus,
            excludeFromSemantics: true,
          ),
        ),
      ),
      onChanged: owns || on ? (value) => _send(settings: {flag: value}) : null,
      onDisabledTap: store,
    );
    if (owns || on) return row(null);
    return StoreDoor(builder: (context, open) => row(open));
  }

  /// The one group open. A room is set from the top, so that one starts open.
  String? _open = 'room';
  final _sectionKeys = <String, GlobalKey>{};

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
    final spacing = context.spacing;
    final room = widget.snapshot.room;
    final match = widget.snapshot.settings;

    String look(String code) =>
        Cosmetics.items[code]?.name(l10n) ?? l10n.cosmeticClassic;
    final wantedRoles = [
      if (match.silencerEnabled) l10n.settingSilencer,
      if (match.elderEnabled) l10n.settingElder,
      if (match.sniperEnabled) l10n.settingSniper,
    ];
    final infoOn = [
      match.traceEnabled,
      match.confrontationEnabled,
      match.whisperEnabled,
      match.revealWhisperContent,
    ].where((on) => on).length;

    return Positioned.fill(
      key: RoomSettingsPanel.panel,
      child: Material(
        type: MaterialType.transparency,
        child: ExperienceSurface(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _hero(context),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          spacing.screenMargin,
                          0,
                          spacing.screenMargin,
                          spacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _section(
                              id: 'room',
                              icon: Icons.meeting_room_outlined,
                              title: l10n.onlineSettingsRoom,
                              summary: [
                                room.isPublic
                                    ? l10n.onlineRoomPublic
                                    : l10n.onlineRoomPrivate,
                                l10n.playerCountShort(room.maxPlayers),
                              ].join(' · '),
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
                                  onChanged: (value) =>
                                      _send(visibility: value),
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
                                      (
                                        'shadows',
                                        l10n.premiumScenarioUse,
                                        null,
                                      ),
                                    ],
                                    onChanged: (value) => _send(
                                      settings: {'scenarioCode': value},
                                    ),
                                  ),
                              ],
                            ),
                            _section(
                              id: 'roles',
                              icon: Icons.style_outlined,
                              title: l10n.rolesTitle,
                              summary: wantedRoles.isEmpty
                                  ? l10n.roomRolesBasic
                                  : wantedRoles.join('، '),
                              children: [
                                if (widget.dealEntry != null) ...[
                                  widget.dealEntry!,
                                  SizedBox(height: spacing.sm),
                                ],
                                _roleRow(
                                  role: OptionalRole.silencer,
                                  label: l10n.settingSilencer,
                                  hint: l10n.roomSilencerHint,
                                  on: match.silencerEnabled,
                                  switchKey: RoomSettingsPanel.silencerKey,
                                  flag: 'silencerEnabled',
                                ),
                                _roleRow(
                                  role: OptionalRole.elder,
                                  label: l10n.settingElder,
                                  hint: l10n.settingElderHint,
                                  on: match.elderEnabled,
                                  switchKey: RoomSettingsPanel.elderKey,
                                  flag: 'elderEnabled',
                                ),
                                _roleRow(
                                  role: OptionalRole.sniper,
                                  label: l10n.settingSniper,
                                  hint: l10n.settingSniperHint,
                                  on: match.sniperEnabled,
                                  switchKey: RoomSettingsPanel.sniperKey,
                                  flag: 'sniperEnabled',
                                ),
                              ],
                            ),
                            _section(
                              id: 'look',
                              icon: Icons.auto_awesome_outlined,
                              title: l10n.roomLookSection,
                              summary: {
                                look(room.presentationPack),
                                look(room.narratorPack),
                              }.join(' · '),
                              children: [
                                RoomLookPicker(
                                  slot: CosmeticSlot.roomPack,
                                  title: l10n.roomPackLabel,
                                  current: room.presentationPack,
                                  onChanged: (value) => _send(
                                    settings: {'presentationPack': value},
                                  ),
                                ),
                                RoomLookPicker(
                                  slot: CosmeticSlot.narrator,
                                  title: l10n.roomNarratorLabel,
                                  current: room.narratorPack,
                                  onChanged: (value) =>
                                      _send(settings: {'narratorPack': value}),
                                ),
                                Text(
                                  l10n.storeHostPackNote,
                                  style: context.typography.caption.copyWith(
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            _section(
                              id: 'play',
                              icon: Icons.timer_outlined,
                              title: l10n.onlineSettingsPlay,
                              summary: l10n.roomPlaySummary(
                                match.speechSeconds,
                                match.discussionSeconds ~/ 60,
                                match.discussionMode.name == 'free'
                                    ? l10n.discussionFree
                                    : l10n.discussionStructured,
                              ),
                              children: [
                                SettingsSegments<int>(
                                  label:
                                      '${l10n.onlineSpeakDuration} (${l10n.onlineSeconds})',
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
                                // speaker at a time.
                                SettingsSegments<String>(
                                  label: l10n.discussionModeLabel,
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
                                  onChanged: (value) => _send(
                                    settings: {'discussionMode': value},
                                  ),
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
                            _section(
                              id: 'voice',
                              icon: Icons.mic_none_outlined,
                              title: l10n.onlineSettingsVoice,
                              summary: room.voice
                                  ? l10n.roomVoiceOn
                                  : l10n.roomVoiceOff,
                              children: [
                                SettingsSwitchRow(
                                  switchKey: RoomSettingsPanel.voiceSwitch,
                                  label: l10n.onlineVoiceEnabled,
                                  value: room.voice,
                                  onChanged: (value) =>
                                      _send(settings: {'voice': value}),
                                ),
                                SettingsSwitchRow(
                                  switchKey:
                                      RoomSettingsPanel.muteAtNightSwitch,
                                  label: l10n.onlineMuteAtNight,
                                  value: room.muteAllAtNight,
                                  onChanged: (value) => _send(
                                    settings: {'muteAllAtNight': value},
                                  ),
                                ),
                              ],
                            ),
                            _section(
                              id: 'info',
                              icon: Icons.manage_search_outlined,
                              title: l10n.onlineSettingsInfo,
                              summary: l10n.roomInfoOn(infoOn),
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
                                  onChanged: (value) => _send(
                                    settings: {'whisperEnabled': value},
                                  ),
                                ),
                                // Doc 09 §7, default off. Every seat sees the
                                // choice in the lobby and on the composer.
                                SettingsSwitchRow(
                                  switchKey:
                                      RoomSettingsPanel.revealWhispersKey,
                                  label: l10n.settingRevealWhispers,
                                  hint: l10n.settingRevealWhispersHint,
                                  value: match.revealWhisperContent,
                                  onChanged: match.whisperEnabled
                                      ? (value) => _send(
                                          settings: {
                                            'revealWhisperContent': value,
                                          },
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
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

  /// The room as it will look: the scene the host chose fading into the ground,
  /// and the narrator's portrait on it. It answers «how does my room look» before
  /// a single row is read, and changes the moment a choice does.
  Widget _hero(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final room = widget.snapshot.room;
    final short = MediaQuery.sizeOf(context).height < RolesTokens.fanShort;
    final art =
        StoreArt.forCode(room.presentationPack) ?? AppCouncilArt.backdropDay;
    final narrator = StoreArt.forCode(room.narratorPack);
    return SizedBox(
      height: short ? RoomLookTokens.heroShort : RoomLookTokens.hero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.surfaceBase.withValues(
                  alpha: RoomLookTokens.heroArtAlpha,
                ),
                colors.surfaceBase.withValues(alpha: 0),
              ],
            ).createShader(bounds),
            child: Image.asset(
              art,
              key: ValueKey(art),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          PositionedDirectional(
            top: spacing.xs,
            end: spacing.xs,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: widget.onClose,
              icon: Icon(Icons.close, color: colors.textPrimary),
            ),
          ),
          PositionedDirectional(
            start: spacing.screenMargin,
            end: spacing.screenMargin,
            bottom: spacing.sm,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    l10n.onlineRoomSettings,
                    style: type.headline.copyWith(color: colors.textPrimary),
                  ),
                ),
                if (narrator != null && !short)
                  Container(
                    width: EntranceTokens.medallion,
                    height: EntranceTokens.medallion,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: VaultTokens.gold,
                        width: EntranceTokens.ring,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      narrator,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One group of settings: a plain row saying what it is and what it is set to,
  /// opening in place. One is open at a time, so the screen stays a short list
  /// and a host never hunts through six full groups for one switch.
  Widget _section({
    required String id,
    required IconData icon,
    required String title,
    required String summary,
    required List<Widget> children,
  }) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final open = _open == id;
    final duration = ReduceMotion.of(context)
        ? Duration.zero
        : context.motion.standard;
    return Column(
      key: _sectionKeys.putIfAbsent(id, GlobalKey.new),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            key: RoomSettingsPanel.section(id),
            onTap: () {
              setState(() => _open = open ? null : id);
              if (open) return;
              // A group opened near the foot of a short phone comes up to be read.
              final row = _sectionKeys[id]?.currentContext;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || row == null || !row.mounted) return;
                Scrollable.ensureVisible(row, duration: duration);
              });
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: RoomLookTokens.sectionRow,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: spacing.sm),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: SettingsTokens.iconSize,
                      color: open ? colors.accentGold : colors.textSecondary,
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: type.title.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          if (!open)
                            Text(
                              summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: duration,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: context.motion.standardCurve,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: EdgeInsets.only(bottom: spacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Divider(height: 1, color: colors.borderSubtle),
      ],
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
