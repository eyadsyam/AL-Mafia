import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/asset_constants.dart';
import '../../../engine/balance_guard.dart';
import '../../../platform/audio_director.dart';
import '../../../platform/clipboard.dart';
import '../../../platform/invite_share.dart';
import '../../../engine/models/enums.dart';
import '../../../engine/models/player.dart' show PublicPlayer;
import '../../../platform/reduce_motion.dart';
import '../../../transport/game_snapshot.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/connection_banner.dart';
import '../../widgets/storage_warning_note.dart';
import '../../widgets/experience_surface.dart';

import 'online_session.dart';
import 'safety_center.dart';
import 'voice_session.dart';
import 'room_invite.dart';
import '../../economy/cosmetic_paint.dart';
import '../../economy/cosmetics.dart';
import '../setup/coin_store.dart';
import '../../economy/vault_kit.dart'
    show ClaimedMark, VaultBar, VaultPress, vaultGoldStyle;
import '../../theme/design_tokens.dart';
import '../../widgets/player_avatar.dart';
import 'council/council_band.dart';
import 'council/council_geometry.dart';
import '../../fun/reactions.dart';
import 'host_handover.dart';
import '../../widgets/voice_mic_button.dart';
import 'host_sheet.dart';
import 'invite_sheet.dart';
import 'room_settings_panel.dart';
import 'scene_sheet.dart';
import 'council/seat_status.dart';
import 'table/table_pulse.dart';
import 'table/table_scene.dart';
import '../../economy/waiting_banner.dart';
import '../../economy/economy_capabilities.dart';
import '../../economy/council.dart';
import '../../social/friends.dart';
import '../../social/titles_partner.dart';

/// S-21 — the room, before it is a match (doc 12 §3.1).
///
/// ## What the code is for
///
/// Six characters from an alphabet with no `I/1`, `O/0` or `Z/2` in it (doc 10
/// §10), because the only way a room code is ever transmitted is somebody
/// reading it out to a friend. It is the largest thing on the screen for the
/// same reason, and it is the only place in the app where a wide letter gap is
/// correct: this is a string to be read out one character at a time.
///
/// ## Why the roster is a table and not a list
///
/// Doc 12 §3.1: *"the table, filling live"*, with empty seats as faint
/// outlines. A list of names is a form; the ring is the room the players are
/// about to be in, and it answers "how many more do we need" without a
/// sentence. It is also the same table the whole match is played on, so the
/// lobby is already the first frame of the game rather than a screen before it.
///
/// ## The connected dots, and the one place they are shown
///
/// Here, and nowhere else until the morning. A player who has dropped is
/// marked, so the room can see why nothing is happening — and **not during the
/// night** (doc 10 §6.3): an indicator that updates while roles are acting is a
/// channel that reports on who is acting. The lobby is before any role exists,
/// so it is the one screen where this is unambiguously safe.
///
/// ## The headphones line
///
/// V7. Two players in one room with two open microphones is a feedback loop,
/// and the fix is a sentence in the lobby rather than an echo canceller that
/// will not work.
class LobbyScreen extends ConsumerStatefulWidget {
  /// Where the match itself lives, once the host has started it.
  final VoidCallback onStarted;

  /// Leaving the room, back to somewhere that needs no server.
  final VoidCallback onLeave;

  const LobbyScreen({
    super.key,
    required this.onStarted,
    required this.onLeave,
  });

  static const Key codeText = ValueKey('lobby_code');

  /// The code widget alone, without a room, a session or a server behind it.
  ///
  /// `_StaggeredCode` is private and should stay private — nothing else should
  /// be building one. But its direction is a *rendered* fact, and the only
  /// honest way to assert it is to measure where the characters land, which
  /// needs the shipped widget rather than a copy of it in a test that could
  /// drift. So: one door, named for what it is, taking its type from the same
  /// tokens the real call site does.
  @visibleForTesting
  static Widget codeProbe(BuildContext context, String code) => _StaggeredCode(
    key: codeText,
    code: code,
    style: context.typography.display.copyWith(
      color: context.colors.accentGold,
      letterSpacing: context.spacing.sm,
    ),
  );
  static const Key startButton = ValueKey('lobby_start');
  static const Key leaveButton = ValueKey('lobby_leave');
  static const Key settingsButton = ValueKey('lobby_settings');
  static const Key closeRoomConfirm = ValueKey('lobby_close_room_confirm');
  static const Key headphonesWarning = ValueKey('lobby_headphones');
  static const Key copyButton = ValueKey('lobby_copy');
  static const Key shareButton = ValueKey('lobby_share');
  static const Key friendsButton = ValueKey('lobby_friends');
  static const Key playerCount = ValueKey('lobby_player_count');
  static const Key ghostRule = ValueKey('lobby_ghost_rule');
  static const Key storageWarning = ValueKey('lobby_storage_warning');
  static const Key readyButton = ValueKey('lobby_ready_button');

  /// The seat a player occupies in the lobby's council.
  ///
  /// The same key the match uses, because it is the same band: doc 15 §S-O3
  /// is the council with empty chairs in it, not a second widget that
  /// happens to look like one.
  static Key seatTile(int seat) => CouncilBand.seatKey(seat);

  /// A chair nobody has taken yet, by slot.
  static Key emptySeat(int slot) => CouncilBand.seatKey(slot);

  /// How many seats the ring is drawn for before anybody joins.
  ///
  /// The largest roster S1 permits is fifteen; ten is what a table this game is
  /// actually played at looks like, and drawing fifteen outlines for a room of
  /// six would make every lobby feel empty. The ring grows if more arrive.
  static const int defaultCapacity = 10;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<GameSnapshot>? _feed;
  GameSnapshot? _snapshot;

  /// True once this device has been told to go home and has asked to.
  bool _leaving = false;

  /// The seat whose host sheet is open, and whether the close-room
  /// confirmation is showing. Both are layers in this screen's Stack rather
  /// than routes (doc 12 §2.1).
  int? _inspect;
  bool _closing = false;
  bool _settings = false;

  /// «ادعي صحابك», in the scene.
  bool _inviting = false;

  /// Doc 15 §S-O3: an arriving player's dashed chair **draws itself solid**
  /// over 500ms and only then shows their initial.
  ///
  /// One controller for the whole room rather than one per chair. Two people
  /// joining inside half a second share the run — which is what the room
  /// actually saw — and anybody already seated is simply solid, so a late
  /// joiner never re-draws the people who were there before them.
  late final AnimationController _join = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  /// Chairs already drawn solid, and the chairs the current run is drawing.
  Set<int> _settled = const {};
  Set<int> _arriving = const {};

  /// Which seats were in the room at the last push, so an arrival and a
  /// departure can be heard (doc 12 §3.1, §8).
  Set<int> _seatsHeard = const {};

  @override
  void initState() {
    super.initState();
    final transport = ref.read(onlineSessionProvider).transport;
    _snapshot = transport?.snapshot;
    _seatsHeard = {
      for (final p in _snapshot?.public.players ?? const []) p.seat,
    };
    // Whoever is already here was already here. Only arrivals are drawn.
    _settled = _seatsHeard;
    _join.addListener(() {
      if (mounted) setState(() {});
    });
    _feed = transport?.watch().listen((snapshot) {
      if (!mounted) return;
      _sound(snapshot);
      _syncArrivals(snapshot);
      setState(() => _snapshot = snapshot);
      // The host started it; every other device finds out here, from the same
      // push, and goes to the same screen. Nobody is told anything early.
      if (snapshot.phase != GamePhase.setup) widget.onStarted();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _join.duration = context.motion.rise;
  }

  @override
  void dispose() {
    _feed?.cancel();
    _join.dispose();
    super.dispose();
  }

  /// Starts the draw-itself-solid run for whoever has just arrived.
  ///
  /// Set difference rather than a "player joined" event, for the same reason
  /// [_sound] uses one: a reconnecting client is handed the whole room at
  /// once, and an event-shaped implementation would draw every chair again.
  void _syncArrivals(GameSnapshot snapshot) {
    final now = {for (final p in snapshot.public.players) p.seat};
    final fresh = now.difference(_settled).difference(_arriving);
    if (fresh.isEmpty) {
      // Somebody left. Their chair goes back to being an outline, which means
      // forgetting they were ever drawn.
      _settled = _settled.intersection(now);
      _arriving = _arriving.intersection(now);
      return;
    }
    _settled = {..._settled, ..._arriving}.intersection(now);
    _arriving = fresh;
    if (ReduceMotion.of(context)) {
      _join.value = 1;
      _settled = {..._settled, ..._arriving};
      _arriving = const {};
      return;
    }
    _join.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _settled = {..._settled, ..._arriving};
        _arriving = const {};
      });
    });
  }

  /// One chime per arrival, one per departure.
  ///
  /// Compared against the previous roster rather than fired from a "player
  /// joined" push, because the transport's recovery path is a *full read*: a
  /// client that reconnects gets everybody at once, and an event-shaped
  /// implementation would greet the whole room again. A set difference cannot
  /// do that.
  ///
  /// Unambiguously safe here for the reason the connection dots are: the lobby
  /// is before any role exists.
  void _sound(GameSnapshot snapshot) {
    final now = {for (final p in snapshot.public.players) p.seat};
    if (_seatsHeard.isEmpty && now.isEmpty) return;

    final audio = ref.read(audioDirectorProvider);
    if (now.difference(_seatsHeard).isNotEmpty) {
      audio.play(AudioCue.joinChime);
    } else if (_seatsHeard.difference(now).isNotEmpty) {
      audio.play(AudioCue.leaveChime);
    }
    _seatsHeard = now;
  }

  Future<void> _start() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final count = snapshot.public.players.length;
    // The recommended distribution for this many players, and the host's own
    // default rules — plus the one setting that is a property of *this room*
    // rather than of this device.
    final started = await ref
        .read(onlineSessionProvider.notifier)
        .start(
          roleCounts: BalanceGuard.recommended(count),
          settings: snapshot.settings,
        );
    if (started && mounted) widget.onStarted();
  }

  Future<void> _setReady(bool ready) async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    await ref
        .read(onlineSessionProvider.notifier)
        .setLobbyReady(ready: ready, revision: snapshot.lobbyRevision);
  }

  Future<void> _copyCode(String code) async {
    final copied = await AppClipboard.copy(code);
    if (!mounted || !copied) return;
    _say(context.l10n.onlineCodeCopied);
  }

  /// Doc 12 §3.1's share: the OS share sheet (share_plus), from this tap.
  ///
  /// Android opens the system chooser, and the chosen app may come to the
  /// front; closing it returns to this same lobby. Nothing here leaves the
  /// room: presence goes "away" while the sheet is up and back on return, and
  /// voice follows the room, not the screen. On the web it is the Web Share
  /// API, and a browser without it gets the link copied instead. The lobby
  /// never announces "sent": the sheet does not report delivery.
  ///
  /// The link is the https one, so a phone without the app opens the room on
  /// the site with the code already answered.
  Future<void> _shareInvite(
    String code,
    String? referralCode,
    BuildContext button,
  ) async {
    final box = button.findRenderObject() as RenderBox?;
    final outcome = await ref
        .read(inviteSharerProvider)
        .share(
          text: RoomInvite.text(
            referralCode == null
                ? context.l10n.onlineShareInvite(code)
                : '${context.l10n.onlineShareInvite(code)}\n${context.l10n.onlineReferralOffer}',
            code,
            referralCode: referralCode,
          ),
          subject: context.l10n.appTitle,
          // iPad/tablet sheets anchor to the button that opened them.
          origin: box == null || !box.hasSize
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        );
    if (!mounted) return;
    switch (outcome) {
      case InviteShareOutcome.handedOver:
        break;
      case InviteShareOutcome.copied:
        _say(context.l10n.onlineLinkCopied);
      case InviteShareOutcome.failed:
        _say(context.l10n.onlineShareFailed);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;
    final l10n = context.l10n;

    final session = ref.watch(onlineSessionProvider);
    final voice = ref.watch(voiceStateProvider).valueOrNull;
    final snapshot = _snapshot;
    final code = session.transport?.code ?? session.room?.code ?? '';
    final players = snapshot?.public.players ?? const [];
    final lobbyReadyEnabled =
        ref.watch(economyCapabilitiesProvider).valueOrNull?.lobbyReady ?? false;
    final referralsEnabled =
        ref.watch(economyCapabilitiesProvider).valueOrNull?.council.invites ??
        false;
    final referralCode = referralsEnabled
        ? ref.watch(inviteProvider).valueOrNull?.code
        : null;
    final connectedSeats = players
        .where(
          (player) =>
              snapshot?.presence[player.seat] == SeatPresence.connected &&
              snapshot?.connectedSeats[player.seat] != false,
        )
        .map((player) => player.seat)
        .toSet();
    final readySeats = snapshot?.lobbyReadySeats ?? const <int>{};
    final readyRuleHolds =
        connectedSeats.length >= PublicRoom.defaultMinPlayers &&
        connectedSeats.every(readySeats.contains);
    final canStart =
        (snapshot?.canAdvance ?? false) &&
        (lobbyReadyEnabled ? readyRuleHolds : players.length >= 5);
    final isHost = snapshot?.canAdvance ?? false;
    final viewerReady = readySeats.contains(snapshot?.viewerSeat);

    // Task 5. The host closed it: there is no winner and no result screen, so
    // every other device goes home and says so.
    if ((snapshot?.viewerKicked ?? false) && !_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(l10n.onlineKickedByHost)));
        await ref.read(onlineSessionProvider.notifier).leave();
        if (mounted) widget.onLeave();
      });
    }
    if ((snapshot?.roomClosed ?? false) && !_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(onlineSessionProvider.notifier).leave();
        if (mounted) widget.onLeave();
      });
    }

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: ExperienceSurface(
        child: Stack(
          children: [
            // The host's presentation pack dresses the lobby as it will the
            // table's public phases.
            if (Cosmetics.packs[snapshot?.room.presentationPack] != null)
              Positioned.fill(
                child: Opacity(
                  opacity: CouncilTokens.backdropOpacity,
                  child: PackBackdrop(
                    pack: Cosmetics.packs[snapshot?.room.presentationPack],
                    child: Image.asset(
                      AppCouncilArt.backdropDay,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  ConnectionBanner(
                    quality:
                        snapshot?.connection ?? ConnectionQuality.connected,
                  ),
                  if (session.storageWarning)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacing.md,
                      ),
                      child: StorageWarningNote(
                        key: LobbyScreen.storageWarning,
                        onDismiss: () => ref
                            .read(onlineSessionProvider.notifier)
                            .dismissStorageWarning(),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.screenMargin,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: double.infinity,
                        ),
                        // ## Why the lobby is the match's own four bands
                        //
                        // It used to be a scrolling column with an ellipse in the
                        // middle of it, sized by an arithmetic that existed to stop
                        // ten cards overlapping on a short phone. Doc 15 §1.1
                        // removed the problem rather than the symptom: the room is
                        // the council band, at the same proportion it will have all
                        // match, so the first frame of the lobby and the first
                        // frame of the game are the same picture with people added.
                        child: Column(
                          children: [
                            SizedBox(
                              height: CouncilTokens.headerHeight,
                              // Seven 48 dp icons are 336 dp: on a 320 dp
                              // phone they draw tighter (the tap target
                              // stays 48 dp), rather than overflow.
                              child: IconButtonTheme(
                                data: IconButtonThemeData(
                                  style: IconButton.styleFrom(
                                    visualDensity:
                                        MediaQuery.sizeOf(context).width <
                                            VaultTokens.narrowHeaderWidth
                                        ? VisualDensity.compact
                                        : null,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Task 9b — the «كود الأوضة» label is gone.
                                    // The code is six gold characters in the middle
                                    // of the screen; naming it was a caption on a
                                    // thing nobody was mistaking for anything else.
                                    const Spacer(),
                                    // Out of the match only: the lobby is the
                                    // last place the store is reachable from.
                                    const CoinStoreButton(compact: true),
                                    const SafetyButton(),
                                    // Task 10 — the room's rules, while everybody
                                    // watches. Host only, and the server checks that
                                    // rather than trusting this.
                                    if (isHost)
                                      IconButton(
                                        key: LobbyScreen.settingsButton,
                                        tooltip: l10n.onlineRoomSettings,
                                        onPressed: () =>
                                            setState(() => _settings = true),
                                        icon: Icon(
                                          Icons.tune,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    IconButton(
                                      key: LobbyScreen.leaveButton,
                                      tooltip: l10n.onlineLeave,
                                      onPressed: () async {
                                        if (isHost) {
                                          setState(() => _closing = true);
                                          return;
                                        }
                                        await ref
                                            .read(
                                              onlineSessionProvider.notifier,
                                            )
                                            .leave();
                                        if (context.mounted) widget.onLeave();
                                      },
                                      icon: Icon(
                                        Icons.logout,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    // Task 9a — the lobby's whole voice surface. Last
                                    // in the row, so it is the far edge of the header
                                    // once the RTL layout has run.
                                    const VoiceMicButton(),
                                  ],
                                ),
                              ),
                            ),
                            const BandDivider(),
                            Expanded(
                              flex: CouncilTokens.councilFlex,
                              // Phase 109: a reaction rises from its sender's
                              // chair. The lobby is before any role exists.
                              child: ReactionScope(
                                roomId: session.room?.roomId,
                                backend: session.transport?.backend,
                                open: reactionsOpen(snapshot?.phase),
                                anchor: (seat, size) =>
                                    _chairCentre(players, snapshot, seat, size),
                                child: TablePulse(
                                  child: CouncilBand(
                                    seats: _chairs(
                                      players,
                                      snapshot,
                                      speakingLevels:
                                          voice?.speakingLevels ?? const {},
                                    ),
                                    totalPlayers: math.max(
                                      snapshot?.room.maxPlayers ??
                                          LobbyScreen.defaultCapacity,
                                      players.length,
                                    ),
                                    joinProgress: {
                                      for (final seat in _arriving)
                                        seat: _join.value,
                                    },
                                    leftLabel: l10n.onlineLeftRoom,
                                    onSeatInspect: isHost && snapshot != null
                                        ? (seat) =>
                                              setState(() => _inspect = seat)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: CouncilTokens.voiceFlex,
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    SizedBox(height: spacing.sm),
                                    // Doc 12 §3.1: the letters stagger in on first
                                    // render. The code is public and identical on
                                    // every device in the room, so staggering it
                                    // carries nothing — which is exactly the
                                    // condition `StaggeredEntrance` exists under.
                                    GestureDetector(
                                      onTap: code.isEmpty
                                          ? null
                                          : () => _copyCode(code),
                                      child: _StaggeredCode(
                                        key: LobbyScreen.codeText,
                                        code: code,
                                        style: type.display.copyWith(
                                          color: colors.accentGold,
                                          letterSpacing: spacing.sm,
                                        ),
                                      ),
                                    ),
                                    // Task 12 — two glyphs everybody already knows,
                                    // under a code that is already the loudest
                                    // thing on the screen. The words stay as
                                    // tooltips and as the labels a screen reader
                                    // reads, which is the part that was carrying
                                    // the meaning for anybody who needed it.
                                    // Phase 99: inviting is the host's one
                                    // useful move in an empty room, and the
                                    // hint below asks for it by name — so the
                                    // share is a labelled button, not a bare
                                    // glyph. Same native share, same session;
                                    // copy stays a glyph beside it.
                                    SizedBox(height: spacing.xs),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Builder(
                                          builder: (button) =>
                                              OutlinedButton.icon(
                                                key: LobbyScreen.shareButton,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      colors.accentGold,
                                                  side: BorderSide(
                                                    color: colors.accentGold,
                                                  ),
                                                  minimumSize: const Size(
                                                    kMinInteractiveDimension,
                                                    kMinInteractiveDimension,
                                                  ),
                                                ),
                                                onPressed: code.isEmpty
                                                    ? null
                                                    : () => _shareInvite(
                                                        code,
                                                        referralCode,
                                                        button,
                                                      ),
                                                icon: const Icon(
                                                  Icons.ios_share,
                                                ),
                                                label: Text(
                                                  l10n.lobbyInviteFriends,
                                                ),
                                              ),
                                        ),
                                        SizedBox(width: spacing.xs),
                                        IconButton(
                                          key: LobbyScreen.copyButton,
                                          tooltip: l10n.onlineCopy,
                                          onPressed: code.isEmpty
                                              ? null
                                              : () => _copyCode(code),
                                          icon: Icon(
                                            Icons.copy_all_outlined,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                        // «أصحابك»: invite a friend straight
                                        // into this lobby. Absent while off.
                                        if (session.room?.roomId != null &&
                                            ref
                                                    .watch(friendsProvider)
                                                    .valueOrNull !=
                                                null)
                                          IconButton(
                                            key: LobbyScreen.friendsButton,
                                            tooltip: l10n.friendsInviteToRoom,
                                            onPressed: () => setState(
                                              () => _inviting = true,
                                            ),
                                            icon: Icon(
                                              Icons.group_add_rounded,
                                              color: colors.accentGold,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (isHost && referralsEnabled) ...[
                                      SizedBox(height: spacing.xs),
                                      Text(
                                        l10n.onlineReferralOffer,
                                        textAlign: TextAlign.center,
                                        style: type.caption.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                    Text(
                                      key: LobbyScreen.playerCount,
                                      l10n.onlinePlayersOfMax(
                                        players.length,
                                        snapshot?.room.maxPlayers ??
                                            LobbyScreen.defaultCapacity,
                                      ),
                                      style: type.body.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    // Phase 109: quick reactions, lobby only.
                                    if (session.room?.roomId != null &&
                                        session.transport?.backend != null)
                                      Center(
                                        child: ReactionBar(
                                          roomId: session.room!.roomId,
                                          backend: session.transport!.backend,
                                          open: reactionsOpen(snapshot?.phase),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: CouncilTokens.handFlex,
                              child: SingleChildScrollView(
                                // The council band is as wide as the room (doc
                                // 15's wide council); the button under it is not.
                                // A start button 1240px wide on a desktop window
                                // was E-4; it takes the reading column instead.
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: spacing.maxContentWidth,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // F8 Ready, in the vault's hand: a
                                        // struck-gold press until you are
                                        // ready, then the gold mark with a
                                        // quiet way back; the room's count
                                        // as a metal bar under it.
                                        // F10: equipped titles on the pre-deal
                                        // roster (the server answers only for
                                        // a lobby or a finished room).
                                        if (snapshot != null &&
                                            session.transport != null)
                                          LobbyTitlesStrip(
                                            key: ValueKey(
                                              'titles-${snapshot.lobbyRevision}-${players.length}',
                                            ),
                                            backend: session.transport!.backend,
                                            roomId: session.transport!.roomId,
                                            names: {
                                              for (final p in players)
                                                p.seat: p.name,
                                            },
                                          ),
                                        if (lobbyReadyEnabled &&
                                            snapshot != null) ...[
                                          if (viewerReady)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                ClaimedMark(
                                                  l10n.lobbyReadyAction,
                                                ),
                                                SizedBox(width: spacing.sm),
                                                TextButton(
                                                  key: LobbyScreen.readyButton,
                                                  onPressed: session.busy
                                                      ? null
                                                      : () => _setReady(false),
                                                  child: Text(
                                                    l10n.lobbyUnreadyAction,
                                                    style: type.caption
                                                        .copyWith(
                                                          color: colors
                                                              .textSecondary,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            VaultPress(
                                              child: TextButton(
                                                key: LobbyScreen.readyButton,
                                                style: vaultGoldStyle(context),
                                                onPressed: session.busy
                                                    ? null
                                                    : () => _setReady(true),
                                                child: Text(
                                                  l10n.lobbyReadyAction,
                                                  style: type.title,
                                                ),
                                              ),
                                            ),
                                          // F8 + D9: this seat's one 45 s
                                          // deadline, on the local clock.
                                          if (!viewerReady &&
                                              snapshot.viewerSeat != null)
                                            ReadyCountdown(
                                              deadline: session.transport
                                                  ?.onLocalClock(
                                                    snapshot
                                                        .lobbyReadyDeadlines[snapshot
                                                        .viewerSeat],
                                                  ),
                                            ),
                                          SizedBox(height: spacing.sm),
                                          VaultBar(
                                            value: connectedSeats.isEmpty
                                                ? 0
                                                : readySeats.length /
                                                      connectedSeats.length,
                                          ),
                                          SizedBox(height: spacing.xs),
                                          Text(
                                            l10n.lobbyReadyCount(
                                              readySeats.length,
                                              connectedSeats.length,
                                            ),
                                            textAlign: TextAlign.center,
                                            style: type.caption.copyWith(
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                          SizedBox(height: spacing.md),
                                        ],
                                        if (isHost)
                                          FilledButton(
                                            key: LobbyScreen.startButton,
                                            onPressed: session.busy || !canStart
                                                ? null
                                                : _start,
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  colors.accentGold,
                                              foregroundColor:
                                                  colors.surfaceBase,
                                              padding: EdgeInsets.symmetric(
                                                vertical: spacing.md,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      radii.button,
                                                    ),
                                              ),
                                            ),
                                            child: Text(
                                              canStart
                                                  ? l10n.onlineStartMatch
                                                  : l10n.onlineNeedFivePlayers,
                                              style: type.title,
                                            ),
                                          )
                                        else
                                          Text(
                                            l10n.onlineWaitingForHost,
                                            style: type.body.copyWith(
                                              color: colors.textSecondary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        SizedBox(height: spacing.sm),
                                        Text(
                                          players.length <
                                                  PublicRoom.defaultMinPlayers
                                              ? l10n.publicRoomMissing(
                                                  PublicRoom.defaultMinPlayers -
                                                      players.length,
                                                )
                                              : isHost
                                              ? l10n.onlineLobbyHostReadyHint
                                              : l10n.onlineLobbyGuestReadyHint,
                                          key: const ValueKey(
                                            'lobby_readiness_hint',
                                          ),
                                          style: type.caption.copyWith(
                                            color: colors.textSecondary,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        if (players.length <
                                            PublicRoom.defaultMinPlayers)
                                          Text(
                                            l10n.onlineLobbyInviteHint,
                                            style: type.caption.copyWith(
                                              color: colors.textSecondary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Phase 108: the waiting room is a waiting surface. Below
                  // the hints, never beside the start button: a filled
                  // banner keeps AdTokens.bannerActionClearance (72dp) clear
                  // of it inside its frame; zero size unless switched on and
                  // filled. A screen too short for that clearance (a phone
                  // on its side) gets no banner at all.
                  if (MediaQuery.sizeOf(context).height >=
                      AdTokens.bannerMinLobbyHeight)
                    const WaitingBanner(belowPrimaryAction: true),
                ],
              ),
            ),
            // Task 6 — the host's two moderation actions, in the scene.
            if (snapshot != null)
              HostSheet(
                snapshot: snapshot,
                transport: session.transport,
                seat: _inspect,
                onDismiss: () => setState(() => _inspect = null),
              ),
            // Task 5 — the deliberate ending, two taps apart from leaving.
            SceneSheet(
              visible: _closing,
              title: l10n.onlineHostExitTitle,
              body: l10n.onlineHostExitBody,
              onDismiss: () => setState(() => _closing = false),
              actions: [
                SceneAction(
                  key: const ValueKey('lobby_leave_keep_room'),
                  label: l10n.onlineLeaveKeepRoom,
                  emphasised: true,
                  onTap: () async {
                    setState(() => _closing = false);
                    await ref.read(onlineSessionProvider.notifier).leave();
                    if (mounted) widget.onLeave();
                  },
                ),
                SceneAction(
                  key: LobbyScreen.closeRoomConfirm,
                  label: l10n.onlineCloseRoomConfirm,
                  emphasised: true,
                  onTap: () {
                    setState(() => _closing = false);
                    ref.read(onlineSessionProvider).transport?.closeRoom();
                  },
                ),
              ],
            ),
            // Task 10 — the whole settings screen, in the scene.
            if (snapshot != null)
              RoomSettingsPanel(
                visible: _settings && isHost,
                snapshot: snapshot,
                transport: session.transport,
                onClose: () => setState(() => _settings = false),
              ),
            // «ادعي صحابك»: friends, search by name, people near you.
            if (session.room?.roomId != null)
              InviteSheet(
                visible: _inviting,
                roomId: session.room!.roomId,
                roomCode: code,
                onDismiss: () => setState(() => _inviting = false),
              ),
            // Task 5 — one line, three seconds, over the lobby.
            if (snapshot != null) HostHandover(snapshot: snapshot),
          ],
        ),
      ),
    );
  }

  /// The council's chairs: the people here, then the chairs still empty.
  ///
  /// Doc 12 §3.1 wants the *shape of the finished room* rather than a list of
  /// who turned up, so the empties are drawn up to the room's capacity — a host
  /// can see how many more they need without counting names.
  ///
  /// Presence is shown here and nowhere else until the morning (doc 10 §6.3).
  /// The lobby is before any role exists, so "who has dropped" cannot correlate
  /// with anything; every other table state routes the question through
  /// `TableMood.showsPerSeatStatus`, which refuses it for the whole night.
  /// Where [seat]'s chair sits inside the council band, by the band's own
  /// geometry — the same chairs, in the same order, as [_chairs] draws.
  Offset? _chairCentre(
    List<PublicPlayer> players,
    GameSnapshot? snapshot,
    int seat,
    Size size,
  ) {
    final chairs = _chairs(players, snapshot);
    final index = chairs.indexWhere((c) => c.seat == seat);
    if (index < 0) return null;
    final layout = CouncilGeometry.layout(
      size: size,
      seatCount: chairs.length,
      totalPlayers: math.max(
        snapshot?.room.maxPlayers ?? LobbyScreen.defaultCapacity,
        players.length,
      ),
    );
    return index < layout.length ? layout[index].centre : null;
  }

  List<CouncilSeatData> _chairs(
    List<PublicPlayer> players,
    GameSnapshot? snapshot, {
    Map<int, double> speakingLevels = const {},
  }) {
    // Task 4: a player who left the lobby loses their chair outright. Before
    // the deal a seat is only a place to stand — nothing has been dealt
    // against it and the server re-packs the numbers — so keeping a cracked
    // ring for somebody who is not coming back would be the lobby lying about
    // how full it is to the one person who needs that number to be true.
    final here = [
      for (final player in players)
        if (snapshot?.presence[player.seat] != SeatPresence.left) player,
    ];
    final capacity = math.max(
      snapshot?.room.maxPlayers ?? LobbyScreen.defaultCapacity,
      here.length,
    );
    return [
      for (final player in here)
        CouncilSeatData(
          seat: player.seat,
          name: player.name,
          isViewer: player.seat == snapshot?.viewerSeat,
          // Absent rather than false when the transport is not reporting:
          // "we do not know" and "they have gone" are different, and only one
          // of them belongs on a chair.
          status: snapshot?.connectedSeats[player.seat] == false
              ? SeatStatus.disconnected
              : SeatStatus.idle,
          presence: snapshot?.presence[player.seat] ?? SeatPresence.connected,
          muted: snapshot?.mutedSeats.contains(player.seat) ?? false,
          avatar: AvatarArt.forGender(player.gender),
          speakingLevel: speakingLevels[player.seat] ?? 0,
          // The lobby is public: what each player wears shows here first.
          frame: snapshot?.seatCosmetics[player.seat]?.frame,
          plate: snapshot?.seatCosmetics[player.seat]?.plate,
          rank: snapshot?.seatCosmetics[player.seat]?.rank,
          lobbyReady: snapshot?.lobbyReadySeats.contains(player.seat) ?? false,
          lobbyReadyExpired:
              snapshot?.lobbyReadyExpiredSeats.contains(player.seat) ?? false,
        ),
      // Numbered past the last real seat rather than from the count. A player
      // who aged out to `left` without saying so leaves a hole in the seat
      // numbers, and an empty chair that reused one of those numbers would
      // collide with a real chair's key.
      for (var slot = 0; slot < capacity - here.length; slot++)
        CouncilSeatData(
          seat:
              here.fold<int>(-1, (top, p) => math.max(top, p.seat)) + 1 + slot,
          name: null,
          isEmpty: true,
        ),
    ];
  }
}

/// F8: the seconds this seat has left to confirm, already on the local clock
/// (the transport's `onLocalClock`, D9), so every phone shows the same number
/// whatever its own clock says. Nothing without a deadline or once it passes.
class ReadyCountdown extends StatefulWidget {
  final DateTime? deadline;
  const ReadyCountdown({super.key, required this.deadline});

  static const Key countdownKey = ValueKey('lobby_ready_countdown');

  @override
  State<ReadyCountdown> createState() => _ReadyCountdownState();
}

class _ReadyCountdownState extends State<ReadyCountdown> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(ReadyCountdown old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline) _arm();
  }

  void _arm() {
    _tick?.cancel();
    if (widget.deadline == null) return;
    _tick = Timer.periodic(StoreTruthTokens.countdownTick, (_) {
      if (!mounted) return;
      setState(() {});
      final left = widget.deadline?.difference(DateTime.now());
      if (left == null || left.isNegative) _tick?.cancel();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deadline = widget.deadline;
    if (deadline == null) return const SizedBox.shrink();
    final left = deadline.difference(DateTime.now());
    if (left.isNegative) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xs),
      child: Text(
        context.l10n.lobbyReadyCountdown(left.inSeconds + 1),
        key: ReadyCountdown.countdownKey,
        textAlign: TextAlign.center,
        style: context.typography.caption.copyWith(
          color: context.colors.accentGold,
        ),
      ),
    );
  }
}

/// The room code, its characters arriving one after another.
///
/// Doc 12 §3.1: *"letters stagger in on first render, 60ms apart."* Safe to
/// stagger for the reason `MafiaMotion.stagger` names — the code is public,
/// identical on every device in the room, and derived from nothing about
/// anybody. It is also the one string in the app a player has to *read out*, and
/// letters that land one at a time are letters somebody says one at a time.
///
/// The whole code is in the tree from the first frame; only its opacity moves.
/// A screen reader therefore gets the code immediately, and Reduce Motion
/// degrades to it simply being there.
class _StaggeredCode extends StatefulWidget {
  final String code;
  final TextStyle style;

  const _StaggeredCode({super.key, required this.code, required this.style});

  // The gap between characters is `MafiaMotion.codeStagger`.

  @override
  State<_StaggeredCode> createState() => _StaggeredCodeState();
}

class _StaggeredCodeState extends State<_StaggeredCode> {
  int _shown = 0;
  Timer? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticker ??= Timer.periodic(context.motion.codeStagger, (timer) {
      if (!mounted || _shown >= widget.code.length) {
        timer.cancel();
        return;
      }
      setState(() => _shown++);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final reduced = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: widget.code,
      excludeSemantics: true,
      child: Row(
        // ## The code read backwards
        //
        // A `Row` lays its children out along the ambient `Directionality`, and
        // this app's is RTL. So a six-character code went into the tree in
        // order and came out of it mirrored: the screen said `XQ2K7A` while
        // «نسخ» put `A7K2QX` on the clipboard — the one number a player reads
        // out loud, wrong, and wrong only on the device that owns it.
        //
        // A room code is not Arabic text. It is an identifier in a Latin
        // alphabet with no bidirectional behaviour of its own, and it is
        // written left to right in every place it can be typed back in. Pinned
        // here rather than at the call site because the mirroring belongs to
        // this widget's decision to lay characters out itself; a plain `Text`
        // of the same string was never affected.
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < widget.code.length; i++)
            AnimatedOpacity(
              duration: motion.standard,
              curve: motion.quickCurve,
              opacity: reduced || i < _shown ? 1 : 0,
              child: Text(widget.code[i], style: widget.style),
            ),
        ],
      ),
    );
  }
}
