import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../economy/interstitial_coordinator.dart';
import '../../../data/player_profile.dart';
import '../../../data/terms_consent.dart';
import '../../economy/wallet.dart';
import '../../../data/online_session_store.dart';
import '../../../engine/models/enums.dart';
import '../../../engine/models/player.dart';
import '../../../platform/voice/web_playout.dart';
import '../../../platform/audio_director.dart';
import '../../../engine/views.dart';
import '../../../transport/game_snapshot.dart';
import '../../../transport/room_codec.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/storage_warning_note.dart';
import '../../widgets/back_action.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/experience_surface.dart';
import '../setup/profile_screen.dart';
import 'online_session.dart';
import 'room_settings_panel.dart';
import 'safety_center.dart';
import '../../economy/waiting_banner.dart';
import '../../social/friends.dart';

/// Public rooms are the front door; identity belongs to the saved profile.
///
/// The player always chooses the room. Nothing on this screen seats anybody
/// automatically: the list only reads, and a room is entered by tapping it,
/// by code, or by creating one.
class OnlineEntryScreen extends ConsumerStatefulWidget {
  final VoidCallback onJoined;

  /// The screen's logical parent — the online/offline choice — not a match
  /// setup. Kept apart from any "play offline" path on purpose.
  final VoidCallback onBack;
  final String? initialCode;
  const OnlineEntryScreen({
    super.key,
    required this.onJoined,
    required this.onBack,
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
  static const backButton = ValueKey('online_back');
  static const staleNotice = ValueKey('online_rooms_stale');
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

  /// The last read failed. [_rooms] is still the last good list, if there was
  /// one, and the screen says it may be out of date instead of emptying it.
  bool _browseFailed = false;
  bool _everLoaded = false;
  bool _nearlyReadyOnly = false;

  /// One read at a time, and one pending timer at most.
  bool _inFlight = false;
  Timer? _poll;
  Duration _wait = MafiaTiming.publicRoomsRefresh;
  bool _foreground = true;
  late final AppLifecycleListener _lifecycle;
  bool _editing = false;
  OnlineRoomResume? _resume;
  RoomOptions _room = const RoomOptions();
  static const _defaultSettings = <String, dynamic>{
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
  final Map<String, dynamic> _settings = {..._defaultSettings};
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _refresh();
    _loadResume();
  }

  void _onLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        final wasAway = !_foreground;
        _foreground = true;
        // Back from the background: the list is at least as old as the
        // absence, so read it now instead of on the next tick.
        if (wasAway) unawaited(_refresh());
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        _foreground = false;
        _poll?.cancel();
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// Reads the list again after [_wait], if the list is still what the player
  /// is looking at. The create panel covers it, and a backgrounded app is not
  /// looking at anything.
  void _schedule() {
    _poll?.cancel();
    if (!mounted || !_foreground || _step == _Step.create) return;
    _poll = Timer(_wait, _refresh);
  }

  Future<void> _loadResume() async {
    final resume = await OnlineSessionStore.load();
    if (mounted) setState(() => _resume = resume);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _lifecycle.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_inFlight || !mounted) return;
    _inFlight = true;
    _poll?.cancel();
    setState(() => _loading = true);
    try {
      final rooms = await ref.read(onlineSessionProvider.notifier).browse();
      _wait = MafiaTiming.publicRoomsRefresh;
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _browseFailed = false;
          _everLoaded = true;
        });
      }
    } catch (_) {
      // Keep what was shown and say it may be stale. Back off, doubling to a
      // cap, so a server that is down is not asked every tick by every phone.
      final doubled = _wait * 2;
      _wait = doubled > MafiaTiming.publicRoomsBackoffCap
          ? MafiaTiming.publicRoomsBackoffCap
          : doubled;
      if (mounted) setState(() => _browseFailed = true);
    } finally {
      _inFlight = false;
      if (mounted) {
        setState(() => _loading = false);
        _schedule();
      }
    }
  }

  Future<void> _enter({
    bool host = false,
    String? code,
    bool resume = false,
  }) async {
    if (!await acceptCommunityRules(context) || !mounted) return;
    final profile = ref.read(playerProfileProvider).valueOrNull;
    if (profile == null) return;
    // Ads v3 (phase 110): the pre-match ad comes here, on the player's own
    // tap and before any room is entered — never in the lobby, never on a
    // resume (that seat may already be in a match). Preloaded-or-skip.
    if (!resume) {
      await ref.read(interstitialCoordinatorProvider).beforeOnlineMatch();
      if (!mounted) return;
    }
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
    if (mounted && ref.read(onlineSessionProvider).isInRoom) {
      // The session exists now, so the queued acceptance can be recorded.
      unawaited(_syncTerms());
      widget.onJoined();
      return;
    }
    // The room filled, started or closed between the list and the tap. The
    // error line says so and the list is read again as it is now. The player
    // is never moved into a different room they did not pick.
    if (mounted &&
        _listRefusals.contains(ref.read(onlineSessionProvider).errorCode)) {
      unawaited(_refresh());
    }
    // The pointer may have just been proven obsolete (the room is gone, or has
    // no seat for this player any more) and dropped; the button follows it.
    if (mounted) await _loadResume();
  }

  /// Records the setup acceptance on the server once. Never blocks play: a
  /// failure (or a server without the table yet) is retried on a later entry
  /// and never makes the player tick the box again.
  Future<void> _syncTerms() async {
    final terms = ref.read(termsAcceptanceProvider).valueOrNull;
    if (terms == null || !terms.current || terms.synced) return;
    final notifier = ref.read(termsAcceptanceProvider.notifier);
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      await backend.call('player_safety', {
        'action': 'accept_terms',
        'version': terms.version,
        'adult': true,
        'acceptedAt': terms.acceptedAt.toUtc().toIso8601String(),
      });
      await notifier.markSynced();
    } catch (_) {}
  }

  static const _listRefusals = {
    'ROOM_FULL',
    'PHASE_CLOSED',
    'ROOM_FINISHED',
    'ROOM_NOT_FOUND',
    'NOT_A_MEMBER',
  };

  /// A host's equipped packs are the default for rooms they create. Only
  /// owned codes can be equipped, and the server checks again on create.
  void _applyEquippedPacks() {
    final equipped = ref.read(walletProvider).valueOrNull?.equipped;
    if (equipped == null) return;
    for (final (slot, key) in [
      ('room_pack', 'presentationPack'),
      ('narrator', 'narratorPack'),
    ]) {
      final code = equipped[slot];
      if (code != null && !_settings.containsKey(key)) _settings[key] = code;
    }
    _room = _room.copyWith(
      presentationPack: _settings['presentationPack'] as String?,
      narratorPack: _settings['narratorPack'] as String?,
    );
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
    final fromCreate = _step == _Step.create;
    if (step == _Step.create) _applyEquippedPacks();
    setState(() => _step = step);
    if (step == _Step.create) {
      _poll?.cancel();
    } else if (fromCreate) {
      unawaited(_refresh());
    }
  }

  String? _error(OnlineSessionState state) => switch (state.errorCode) {
    null => null,
    'ROOM_NOT_FOUND' => context.l10n.onlineRoomNotFound,
    'ROOM_FULL' => context.l10n.onlineRoomFull,
    'NEW_ROOMS_PAUSED' => context.l10n.onlineNewRoomsPaused,
    'ROOM_FINISHED' => context.l10n.onlineRoomFinished,
    'PHASE_CLOSED' => context.l10n.onlineRoomStarted,
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
      return ProfileScreen(
        onSaved: () => setState(() => _editing = false),
        onBack: profile == null
            ? widget.onBack
            : () => setState(() => _editing = false),
      );
    }
    final s = context.spacing;
    final c = context.colors;
    final l = context.l10n;
    final state = ref.watch(onlineSessionProvider);
    final visibleRooms = _nearlyReadyOnly
        ? _rooms
              .where(
                (room) =>
                    !room.isFull &&
                    !room.waiting &&
                    room.missingToStart > 0 &&
                    room.missingToStart <= 2,
              )
              .toList()
        : _rooms;
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
      body: ExperienceSurface(
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
                                        key: OnlineEntryScreen.backButton,
                                        onPressed: _step == _Step.browse
                                            ? widget.onBack
                                            : () => _go(_Step.browse),
                                      ),
                                      Expanded(
                                        child: Text(
                                          l.onlineMatch,
                                          style: context.typography.headline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: s.sm),
                                  // Who the room will see, and the way to
                                  // change it: one target, not a bare name
                                  // under the title and an avatar elsewhere.
                                  _IdentityChip(
                                    name: profile.name,
                                    gender: profile.gender,
                                    onEdit: state.busy
                                        ? null
                                        : () => setState(() => _editing = true),
                                  ),
                                  SizedBox(height: s.md),
                                  // «أصحابك»: invites waiting, friends at a
                                  // table. Nothing while the feature is off.
                                  FriendsStrip(
                                    onJoin: (code) => _enter(code: code),
                                  ),
                                  // The two ways in, at equal width: create
                                  // is the lit one, join its outline.
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          key: OnlineEntryScreen.hostButton,
                                          style: FilledButton.styleFrom(
                                            minimumSize: const Size.fromHeight(
                                              kMinInteractiveDimension,
                                            ),
                                            // Half-width each: the stock
                                            // 24 dp side padding wrapped
                                            // «Create a room» at 390 dp.
                                            padding: EdgeInsets.symmetric(
                                              horizontal: s.sm,
                                            ),
                                          ),
                                          icon: const Icon(Icons.add),
                                          label: Text(l.onlineCreateRoom),
                                          onPressed: state.busy
                                              ? null
                                              : () => _go(_Step.create),
                                        ),
                                      ),
                                      SizedBox(width: s.sm),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          key: OnlineEntryScreen.haveCodeButton,
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size.fromHeight(
                                              kMinInteractiveDimension,
                                            ),
                                            // Half-width each: the stock
                                            // 24 dp side padding wrapped
                                            // «Create a room» at 390 dp.
                                            padding: EdgeInsets.symmetric(
                                              horizontal: s.sm,
                                            ),
                                          ),
                                          icon: const Icon(Icons.login),
                                          label: Text(l.onlineJoinRoom),
                                          onPressed: state.busy
                                              ? null
                                              : () => _go(_Step.join),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_step == _Step.browse &&
                                      _rooms.isEmpty &&
                                      _everLoaded) ...[
                                    SizedBox(height: s.md),
                                    const ExperienceHero(
                                      asset: ExperienceArt.council,
                                      compact: true,
                                    ),
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
                                                    resume: true,
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
                                  // The slot keeps its height either way, so
                                  // a background refresh never moves the list
                                  // under the player's thumb.
                                  // Determinate while hidden, so an idle
                                  // list is not animating an invisible bar.
                                  Opacity(
                                    opacity: _loading ? 1 : 0,
                                    child: LinearProgressIndicator(
                                      value: _loading ? null : 0,
                                    ),
                                  ),
                                  Text(
                                    l.onlineRoomRefreshHint,
                                    style: context.typography.caption.copyWith(
                                      color: c.textSecondary,
                                    ),
                                  ),
                                  SizedBox(height: s.sm),
                                  Wrap(
                                    spacing: s.sm,
                                    runSpacing: s.xs,
                                    children: [
                                      ChoiceChip(
                                        key: const ValueKey('rooms_filter_all'),
                                        label: Text(l.onlineRoomsAll),
                                        selected: !_nearlyReadyOnly,
                                        selectedColor: c.accentGold,
                                        labelStyle: context.typography.caption
                                            .copyWith(
                                              color: !_nearlyReadyOnly
                                                  ? c.surfaceBase
                                                  : c.textPrimary,
                                            ),
                                        onSelected: (_) => setState(
                                          () => _nearlyReadyOnly = false,
                                        ),
                                      ),
                                      ChoiceChip(
                                        key: const ValueKey(
                                          'rooms_filter_nearly',
                                        ),
                                        label: Text(l.onlineRoomsNearlyReady),
                                        selected: _nearlyReadyOnly,
                                        selectedColor: c.accentGold,
                                        labelStyle: context.typography.caption
                                            .copyWith(
                                              color: _nearlyReadyOnly
                                                  ? c.surfaceBase
                                                  : c.textPrimary,
                                            ),
                                        onSelected: (_) => setState(
                                          () => _nearlyReadyOnly = true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_everLoaded &&
                                      !_browseFailed &&
                                      _nearlyReadyOnly &&
                                      visibleRooms.isEmpty)
                                    Text(
                                      l.onlineRoomsNoFilterMatches,
                                      style: context.typography.body,
                                    ),
                                  if (_browseFailed && error == null)
                                    Text(
                                      _everLoaded
                                          ? l.publicRoomsStale
                                          : l.publicRoomsUnavailable,
                                      key: OnlineEntryScreen.staleNotice,
                                      style: context.typography.body.copyWith(
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  // Only after a read that worked: an
                                  // unreachable server is not an empty one.
                                  if (_everLoaded &&
                                      !_browseFailed &&
                                      !_nearlyReadyOnly &&
                                      _rooms.isEmpty)
                                    _EmptyRooms(
                                      title: l.onlineNoPublicRooms,
                                      hint: l.onlineNoPublicRoomsHint,
                                    ),
                                ],
                              ),
                            ),
                            SliverPadding(
                              padding: EdgeInsets.symmetric(
                                horizontal: s.screenMargin,
                              ),
                              sliver: SliverList.builder(
                                itemCount: visibleRooms.length,
                                itemBuilder: (_, index) {
                                  final room = visibleRooms[index];
                                  return _PublicRoomTile(
                                    key: ValueKey('public_room_${room.code}'),
                                    room: room,
                                    onTap: state.busy || room.isFull
                                        ? null
                                        : () => _enter(code: room.code),
                                  );
                                },
                              ),
                            ),
                            // Phase 108: after the room list, never in the
                            // create panel beside its button.
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: s.screenMargin,
                                ),
                                child: const WaitingBanner(),
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
                        presentationPack:
                            _settings['presentationPack'] as String? ??
                            'classic',
                        narratorPack:
                            _settings['narratorPack'] as String? ?? 'classic',
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

/// The player the room will see, and the one tap that changes it.
class _IdentityChip extends StatelessWidget {
  final String name;
  final PlayerGender gender;
  final VoidCallback? onEdit;
  const _IdentityChip({
    required this.name,
    required this.gender,
    required this.onEdit,
  });

  static const Key chipKey = ValueKey('online_identity');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = context.l10n;
    final radius = BorderRadius.circular(context.radii.button);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Material(
        color: c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: c.borderSubtle),
        ),
        child: InkWell(
          key: chipKey,
          borderRadius: radius,
          onTap: onEdit,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: s.xs,
                end: s.sm,
                top: s.xs,
                bottom: s.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerAvatar(
                    name: name,
                    gender: gender,
                    diameter: kListAvatarDiameter,
                  ),
                  SizedBox(width: s.sm),
                  Flexible(
                    child: Text(
                      l.onlinePlayingAs(name),
                      style: context.typography.body.copyWith(
                        color: c.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: s.sm),
                  Tooltip(
                    message: l.profileEdit,
                    child: Icon(
                      Icons.edit_outlined,
                      size: s.md + s.xs,
                      color: c.accentGold,
                      semanticLabel: l.profileEdit,
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

/// An empty list that says what to do next, instead of a bare sentence.
class _EmptyRooms extends StatelessWidget {
  final String title;
  final String hint;
  const _EmptyRooms({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      margin: EdgeInsets.only(top: s.md),
      padding: EdgeInsets.all(s.md),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(context.radii.card),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.meeting_room_outlined, color: c.accentGold),
          SizedBox(width: s.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.typography.body),
                SizedBox(height: s.xs),
                Text(
                  hint,
                  style: context.typography.caption.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One public room: its name, seats taken of seats offered, and what it is
/// waiting for. Nothing private — no names, no host, no roles.
class _PublicRoomTile extends StatelessWidget {
  final PublicRoom room;
  final VoidCallback? onTap;
  const _PublicRoomTile({super.key, required this.room, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final status = room.waiting
        ? l.publicRoomWaitingStatus
        : room.isFull
        ? l.publicRoomFullStatus
        : room.missingToStart > 0
        ? l.publicRoomMissing(room.missingToStart)
        : l.publicRoomReady;
    // Transparent Material, not decoration: the backdrop paints a background
    // between these rows and the Scaffold, and a tile that finds that box
    // before it finds a Material draws its press underneath it — so the one
    // control a player taps to enter a room would answer with nothing at all.
    final spacing = context.spacing;
    final radius = BorderRadius.circular(context.radii.card);
    return Padding(
      padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.xs),
      child: Material(
        color: c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: c.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.xs,
              ),
              enabled: onTap != null,
              title: Text(
                room.waiting
                    ? l.publicRoomWaitingTitle
                    : (room.title ?? '').trim().isEmpty
                    ? l.onlineUntitledRoom
                    : room.title!,
              ),
              subtitle: Text(
                '${l.publicRoomSeats(room.players, room.capacity)} · $status',
                style: context.typography.caption.copyWith(
                  color: room.isFull ? c.textSecondary : null,
                ),
              ),
              leading: Icon(
                room.waiting
                    ? Icons.hourglass_empty
                    : room.voice
                    ? Icons.mic_none
                    : Icons.mic_off,
              ),
              // `chevron_right` mirrors itself in Arabic (matchTextDirection),
              // so it points the way the row reads in both languages. Picking
              // `chevron_left` for RTL mirrored it back to «›», pointing out
              // of the screen (phase 99 render).
              trailing: room.isFull ? null : const Icon(Icons.chevron_right),
              onTap: onTap,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.md,
                0,
                spacing.md,
                spacing.sm,
              ),
              child: Text(
                room.voice ? l.onlineRoomVoiceOn : l.onlineRoomVoiceOff,
                style: context.typography.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ),
            LinearProgressIndicator(
              value: room.capacity > 0
                  ? (room.players / room.capacity).clamp(0.0, 1.0)
                  : 0,
              color: room.isFull ? c.textMuted : c.accentGold,
              backgroundColor: c.borderSubtle,
              semanticsLabel: l.publicRoomSeats(room.players, room.capacity),
            ),
          ],
        ),
      ),
    );
  }
}
