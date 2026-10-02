import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player_profile.dart';
import '../../../data/online_session_store.dart';
import '../../../engine/models/enums.dart';
import '../../../platform/voice/web_playout.dart';
import '../../../platform/audio_director.dart';
import '../../../engine/views.dart';
import '../../../transport/game_snapshot.dart';
import '../../../transport/room_codec.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/storage_warning_note.dart';
import '../../widgets/back_action.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/textured_surface.dart';
import '../setup/profile_screen.dart';
import 'online_session.dart';
import 'room_settings_panel.dart';
import 'safety_center.dart';
import 'online_welcome_art.dart';

/// Public rooms are the front door; identity belongs to the saved profile.
class OnlineEntryScreen extends ConsumerStatefulWidget {
  final VoidCallback onJoined;
  final VoidCallback onPlayOffline;
  final String? initialCode;
  const OnlineEntryScreen({
    super.key,
    required this.onJoined,
    required this.onPlayOffline,
    this.initialCode,
  });
  static const codeField = ValueKey('online_code');
  static const hostButton = ValueKey('online_host');
  static const haveCodeButton = ValueKey('online_have_code');
  static const joinButton = ValueKey('online_join');
  static const browseButton = ValueKey('online_browse');
  static const browseList = ValueKey('online_browse_list');
  static const errorText = ValueKey('online_error');
  static const resumeButton = ValueKey('online_resume');
  static const discardButton = ValueKey('online_discard_resume');
  static const storageWarning = ValueKey('online_storage_warning');
  static const offlineButton = ValueKey('online_play_offline');
  static const quickMatchButton = ValueKey('online_quick_match');
  @override
  ConsumerState<OnlineEntryScreen> createState() => _OnlineEntryScreenState();
}

enum _Step { browse, join, create }

class _OnlineEntryScreenState extends ConsumerState<OnlineEntryScreen> {
  late final _code = TextEditingController(
    text: widget.initialCode?.toUpperCase() ?? '',
  );
  late _Step _step = widget.initialCode == null ? _Step.browse : _Step.join;
  List<PublicRoom> _rooms = [];
  bool _loading = true;
  bool _browseFailed = false;
  bool _editing = false;
  OnlineRoomResume? _resume;
  RoomOptions _room = const RoomOptions();
  final Map<String, dynamic> _settings = {
    'maxPlayers': 10,
    'voice': true,
    'muteAllAtNight': true,
    'speechSeconds': 45,
    'discussionSeconds': 300,
    'openVoting': false,
    'traceEnabled': true,
    'discussionMode': 'structured',
    'confrontationEnabled': true,
    'whisperEnabled': true,
    'scenarioCode': 'classic',
  };
  @override
  void initState() {
    super.initState();
    _refresh();
    _loadResume();
  }

  Future<void> _loadResume() async {
    final resume = await OnlineSessionStore.load();
    if (mounted) setState(() => _resume = resume);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _browseFailed = false;
      });
    }
    try {
      final rooms = await ref.read(onlineSessionProvider.notifier).browse();
      if (mounted) setState(() => _rooms = rooms);
    } catch (_) {
      if (mounted) setState(() => _browseFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enter({bool host = false, String? code}) async {
    if (!await acceptCommunityRules(context) || !mounted) return;
    final profile = ref.read(playerProfileProvider).valueOrNull;
    if (profile == null) return;
    // Capture the user's room-entry gesture before authentication and the
    // network round trip. Without this, Chrome/Edge may allow getUserMedia but
    // reject the later remote audio element until the player taps playback.
    unawaited(primeWebPlayout());
    final online = ref.read(onlineSessionProvider.notifier);
    if (host) {
      await online.host(
        profile.name,
        gender: profile.gender.name,
        configuration: {
          'visibility': _room.visibility,
          'title': _room.title,
          'settings': _settings,
        },
      );
    } else {
      await online.join(
        code: code ?? _code.text,
        name: profile.name,
        gender: profile.gender.name,
      );
    }
    if (mounted && ref.read(onlineSessionProvider).isInRoom) widget.onJoined();
    // The pointer may have just been proven obsolete (the room is gone, or has
    // no seat for this player any more) and dropped; the button follows it.
    if (mounted) await _loadResume();
  }

  Future<void> _quickMatch() async {
    if (!await acceptCommunityRules(context) || !mounted) return;
    final profile = ref.read(playerProfileProvider).valueOrNull;
    if (profile == null) return;
    unawaited(primeWebPlayout());
    await ref
        .read(onlineSessionProvider.notifier)
        .quickMatch(name: profile.name, gender: profile.gender.name);
    if (mounted && ref.read(onlineSessionProvider).isInRoom) widget.onJoined();
  }

  Future<void> _discard() async {
    final resume = _resume;
    if (resume == null) return;
    await ref.read(onlineSessionProvider.notifier).discardResume(resume);
    if (mounted) await _loadResume();
  }

  void _go(_Step step) {
    if (_step != step) ref.read(audioDirectorProvider).playCardTurn();
    ref.read(onlineSessionProvider.notifier).clearError();
    setState(() => _step = step);
  }

  String? _error(OnlineSessionState state) => switch (state.errorCode) {
    null => null,
    'ROOM_NOT_FOUND' => context.l10n.onlineRoomNotFound,
    'ROOM_FULL' => context.l10n.onlineRoomFull,
    'NEW_ROOMS_PAUSED' => context.l10n.onlineNewRoomsPaused,
    'ROOM_FINISHED' || 'PHASE_CLOSED' => context.l10n.onlineRoomFinished,
    'NOT_A_MEMBER' => context.l10n.onlineKickedByHost,
    'UNREACHABLE' =>
      state.projectPaused
          ? context.l10n.onlineProjectPaused
          : context.l10n.onlineUnreachable,
    _ => context.l10n.onlineUnreachable,
  };

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    if (profile == null || _editing) {
      return ProfileScreen(onSaved: () => setState(() => _editing = false));
    }
    final s = context.spacing;
    final c = context.colors;
    final l = context.l10n;
    final state = ref.watch(onlineSessionProvider);
    final error = _error(state);
    final notice = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: s.md),
            child: Text(
              error,
              key: OnlineEntryScreen.errorText,
              style: context.typography.body.copyWith(color: c.accentCrimson),
            ),
          ),
        if (state.storageWarning)
          StorageWarningNote(
            key: OnlineEntryScreen.storageWarning,
            onDismiss: () => ref
                .read(onlineSessionProvider.notifier)
                .dismissStorageWarning(),
          ),
      ],
    );
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints.expand(),
              child: Stack(
                children: [
                  // One reading column on a wide screen (E-4): the title
                  // used to sit at the far right and the refresh icon at the
                  // far left of a 1280px desktop window, with the offline
                  // button floating between them. The same column every other
                  // screen reads in; a phone is narrower than it and unchanged.
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: s.maxContentWidth),
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: CustomScrollView(
                          key: OnlineEntryScreen.browseList,
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.all(s.screenMargin),
                              sliver: SliverList.list(
                                children: [
                                  Row(
                                    children: [
                                      BackAction(
                                        onPressed: _step == _Step.browse
                                            ? widget.onPlayOffline
                                            : () => _go(_Step.browse),
                                      ),
                                      Expanded(
                                        child: Text(
                                          l.onlineMatch,
                                          style: context.typography.headline,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: l.profileEdit,
                                        onPressed: state.busy
                                            ? null
                                            : () => setState(
                                                () => _editing = true,
                                              ),
                                        icon: PlayerAvatar(
                                          name: profile.name,
                                          gender: profile.gender,
                                          diameter: kListAvatarDiameter,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: s.md),
                                  Text(
                                    profile.name,
                                    style: context.typography.body.copyWith(
                                      color: c.textSecondary,
                                    ),
                                  ),
                                  SizedBox(height: s.md),
                                  if (_step == _Step.browse) ...[
                                    FilledButton.icon(
                                      key: OnlineEntryScreen.quickMatchButton,
                                      icon: const Icon(Icons.bolt_outlined),
                                      label: Text(
                                        state.busy
                                            ? l.quickMatchSearching
                                            : l.quickMatch,
                                      ),
                                      onPressed: state.busy
                                          ? null
                                          : _quickMatch,
                                    ),
                                    SizedBox(height: s.xs),
                                    Text(
                                      l.quickMatchHint,
                                      style: context.typography.caption,
                                    ),
                                    SizedBox(height: s.md),
                                  ],
                                  Wrap(
                                    spacing: s.sm,
                                    runSpacing: s.sm,
                                    children: [
                                      FilledButton.icon(
                                        key: OnlineEntryScreen.hostButton,
                                        icon: const Icon(Icons.add),
                                        label: Text(l.onlineCreateRoom),
                                        onPressed: state.busy
                                            ? null
                                            : () => _go(_Step.create),
                                      ),
                                      OutlinedButton.icon(
                                        key: OnlineEntryScreen.haveCodeButton,
                                        icon: const Icon(Icons.login),
                                        label: Text(l.onlineJoinRoom),
                                        onPressed: state.busy
                                            ? null
                                            : () => _go(_Step.join),
                                      ),
                                    ],
                                  ),
                                  if (_step == _Step.browse) ...[
                                    SizedBox(height: s.md),
                                    const OnlineWelcomeArt(),
                                  ],
                                  if (_step == _Step.join) ...[
                                    SizedBox(height: s.lg),
                                    TextField(
                                      key: OnlineEntryScreen.codeField,
                                      controller: _code,
                                      maxLength: 6,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      textDirection: TextDirection.ltr,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        labelText: l.onlineRoomCode,
                                        hintText: l.onlineRoomCodeHint,
                                      ),
                                    ),
                                    FilledButton.icon(
                                      key: OnlineEntryScreen.joinButton,
                                      icon: const Icon(Icons.login),
                                      label: Text(l.onlineJoinRoom),
                                      onPressed:
                                          state.busy ||
                                              !RegExp(
                                                r'^[A-Za-z0-9]{6}$',
                                              ).hasMatch(_code.text.trim())
                                          ? null
                                          : () => _enter(),
                                    ),
                                  ],
                                  if (_resume != null &&
                                      _step == _Step.browse &&
                                      !state.isInRoom) ...[
                                    SizedBox(height: s.sm),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            key: OnlineEntryScreen.resumeButton,
                                            icon: const Icon(Icons.history),
                                            label: Text(l.resumeAction),
                                            onPressed: state.busy
                                                ? null
                                                : () => _enter(
                                                    code: _resume!.code,
                                                  ),
                                          ),
                                        ),
                                        SizedBox(width: s.sm),
                                        // The way to drop a room this device
                                        // remembers but the player does not want
                                        // back: the seat is given up properly and
                                        // the pointer goes.
                                        TextButton(
                                          key: OnlineEntryScreen.discardButton,
                                          onPressed: state.busy
                                              ? null
                                              : _discard,
                                          child: Text(l.onlineDiscardResume),
                                        ),
                                      ],
                                    ),
                                  ],
                                  notice,
                                  SizedBox(height: s.lg),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l.onlinePublicRooms,
                                          style: context.typography.title,
                                        ),
                                      ),
                                      IconButton(
                                        key: OnlineEntryScreen.browseButton,
                                        tooltip: l.onlinePublicRooms,
                                        onPressed: _loading ? null : _refresh,
                                        icon: const Icon(Icons.refresh),
                                      ),
                                    ],
                                  ),
                                  if (_loading) const LinearProgressIndicator(),
                                  if (_browseFailed && error == null)
                                    Text(
                                      l.onlineUnreachable,
                                      style: context.typography.body,
                                    ),
                                  if (!_loading &&
                                      !_browseFailed &&
                                      _rooms.isEmpty)
                                    Text(
                                      l.onlineNoPublicRooms,
                                      style: context.typography.body,
                                    ),
                                ],
                              ),
                            ),
                            SliverPadding(
                              padding: EdgeInsets.symmetric(
                                horizontal: s.screenMargin,
                              ),
                              sliver: SliverList.builder(
                                itemCount: _rooms.length,
                                itemBuilder: (_, index) {
                                  final room = _rooms[index];
                                  // Transparent Material, not decoration: the backdrop paints a
                                  // background between these rows and the Scaffold, and a tile
                                  // that finds that box before it finds a Material draws its
                                  // press underneath it — so the one control a player taps to
                                  // enter a room would answer with nothing at all.
                                  return Material(
                                    type: MaterialType.transparency,
                                    child: ListTile(
                                      key: ValueKey('public_room_${room.code}'),
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        (room.title ?? '').trim().isEmpty
                                            ? l.onlineUntitledRoom
                                            : room.title!,
                                      ),
                                      subtitle: Text(
                                        l.onlinePublicRoomPlayers(room.players),
                                      ),
                                      leading: Icon(
                                        room.voice
                                            ? Icons.mic_none
                                            : Icons.mic_off,
                                      ),
                                      trailing: const Icon(Icons.chevron_left),
                                      onTap: state.busy
                                          ? null
                                          : () => _enter(code: room.code),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(s.screenMargin),
                                child: TextButton(
                                  key: OnlineEntryScreen.offlineButton,
                                  onPressed: state.busy
                                      ? null
                                      : widget.onPlayOffline,
                                  child: Text(l.onlinePlayOffline),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  RoomSettingsPanel(
                    visible: _step == _Step.create,
                    snapshot: GameSnapshot(
                      public: const PublicMatchView(
                        phase: GamePhase.setup,
                        dayNumber: 0,
                        players: [],
                      ),
                      room: _room,
                      settings: settingsFromJson(_settings),
                    ),
                    transport: null,
                    onClose: () => _go(_Step.browse),
                    onChanged: ({visibility, title, settings}) => setState(() {
                      if (settings != null) _settings.addAll(settings);
                      _room = _room.copyWith(
                        visibility: visibility,
                        title: title,
                        maxPlayers: _settings['maxPlayers'] as int,
                        voice: _settings['voice'] as bool,
                        muteAllAtNight: _settings['muteAllAtNight'] as bool,
                        scenarioCode:
                            _settings['scenarioCode'] as String? ?? 'classic',
                      );
                    }),
                    footer: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        notice,
                        FilledButton.icon(
                          key: const ValueKey('online_create_confirm'),
                          icon: const Icon(Icons.add),
                          onPressed: state.busy
                              ? null
                              : () => _enter(host: true),
                          label: Text(l.onlineCreateRoom),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
