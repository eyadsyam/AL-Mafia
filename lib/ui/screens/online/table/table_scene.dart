import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/asset_constants.dart';
import '../../../../engine/models/enums.dart'
    show GamePhase, PlayerStatus, RoleX;
import '../../../../engine/models/player.dart' show PublicPlayer;
import '../../../../platform/reduce_motion.dart';
import '../../../../transport/game_snapshot.dart';
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';
import '../council/council_band.dart';
import '../../../widgets/player_avatar.dart';
import '../../../widgets/ambient_media.dart';
import '../../../../engine/models/enums.dart' as engine;
import '../council/card_rise.dart' show faceFor;
import '../council/seat_status.dart';
import 'table_mood.dart';
import 'table_pulse.dart';
import '../safety_center.dart';
import '../../../economy/cosmetic_paint.dart';
import '../../../economy/cosmetics.dart';
import 'room_presentation.dart';

/// The single four-band online council described by doc 15 §1.1.
///
/// ## Why four bands and not a table seen from above
///
/// Doc 15 Part 0: an ellipse on a 9:19.5 viewport puts seats at four corners
/// and leaves a dead centre — about 60% of the screen empty. This is the
/// corrected shape: **a council seen from your seat**, in four bands with fixed
/// proportions, and every online screen uses the same four. That is what makes
/// the match feel like one place instead of a slideshow.
///
///   header 56dp · council 36% · voice 34% · your hand 24%
///
/// The one screen that legitimately breaks the bands is the role reveal, which
/// is a full-screen takeover for the length of the card.
class TableScene extends StatelessWidget {
  final GameSnapshot snapshot;
  final int? selectedSeat;
  final Set<int> selectableSeats;
  final ValueChanged<int>? onSeatTap;

  /// Band 3. One idea, at most two elements — see [CouncilVoice].
  final Widget? centre;

  /// Band 4. The one primary action, in the thumb zone.
  final Widget? footer;

  /// A whisper crossing the council.
  final CouncilSpark? spark;

  /// The seat whose ring is cracking this morning, and how far through.
  final int? tearingSeat;
  final double tearProgress;

  /// How open the confrontation spotlight is, 0 to 1.
  final double spotlight;

  /// Doc 15 §S-O13 beat 2: how far through the simultaneous ring flip.
  ///
  /// One number for the whole council, and that is the entire mechanism. The
  /// simultaneity is the drama, so there is deliberately nothing per-seat here
  /// to stagger — no map, no offset, no index. A caller that wanted a stagger
  /// would have to add a parameter, which is the point.
  final double revealProgress;

  /// Safe local voice levels by seat for the speaking pulse.
  final Map<int, double> speakingLevels;

  /// The host's explicit ending (task 5), or null for everybody else.
  ///
  /// In band 1 rather than band 4, because band 4 is the one primary action of
  /// the phase and closing the room is never that — it is a thing the host may
  /// do *instead of* playing, and it lives with the clock and the phase label
  /// where the room's chrome is.
  final VoidCallback? onCloseRoom;

  /// Opens the host's sheet for one seat (task 6), or null for everybody else.
  final ValueChanged<int>? onSeatInspect;

  /// Every seat's role, for an eliminated viewer only — what the server's
  /// `witness_view` answered. Empty for every living player, always.
  final Map<int, engine.Role> witnessRoles;

  /// Marks on seats, for an eliminated viewer only (see `witness_layer.dart`).
  final Map<int, Widget> seatMarks;

  const TableScene({
    super.key,
    required this.snapshot,
    this.selectedSeat,
    this.selectableSeats = const {},
    this.onSeatTap,
    this.centre,
    this.footer,
    this.spark,
    this.tearingSeat,
    this.tearProgress = 0,
    this.spotlight = 0,
    this.revealProgress = 0,
    this.speakingLevels = const {},
    this.onCloseRoom,
    this.onSeatInspect,
    this.witnessRoles = const {},
    this.seatMarks = const {},
  });

  static const Key surface = ValueKey('table_scene');
  static const Key header = ValueKey('council_header');
  static const Key council = ValueKey('council_band');
  static const Key voice = ValueKey('council_voice');
  static const Key hand = ValueKey('council_hand');
  static const Key headerTimer = ValueKey('council_header_timer');
  static const Key exitRoomButton = ValueKey('council_exit_room');

  /// Your own chair, in band 4 rather than in the council (doc 15 §1.1).
  static const Key viewerSeat = ValueKey('council_viewer_seat');
  static Key seatKey(int seat) => CouncilBand.seatKey(seat);

  /// The public status of one seat, with the phase's leakage rule applied.
  ///
  /// [TableMood.showsPerSeatStatus] is doc 12 §2.3's binding rule and doc 15
  /// did not touch it: at night every seat renders identically, whatever the
  /// snapshot happens to be carrying.
  static SeatStatus statusFor(
    GameSnapshot snapshot,
    PublicPlayer player, {
    required TableMood mood,
  }) {
    final raw = player.status == PlayerStatus.dead
        ? SeatStatus.dead
        : mood.kind == TableMoodKind.confrontation &&
              snapshot.confrontation?.targetSeat == player.seat
        ? SeatStatus.confronted
        : snapshot.activeSpeakerSeat == player.seat
        ? SeatStatus.speaking
        : snapshot.connectedSeats[player.seat] == false
        ? SeatStatus.disconnected
        : SeatStatus.idle;
    return effectiveSeatStatus(raw, showsStatus: mood.showsPerSeatStatus);
  }

  /// The council's seats for [snapshot], viewer excluded.
  ///
  /// The viewer is not in the council: doc 15 §1.1 puts *you* at the bottom,
  /// under your own hand, because the whole layout is the room seen from your
  /// seat rather than from above.
  static List<CouncilSeatData> seatsFor(
    GameSnapshot snapshot, {
    required TableMood mood,
    Map<int, double> speakingLevels = const {},
    Map<int, engine.Role> witnessRoles = const {},
  }) {
    // Doc 15 §S-O13 beat 3, and the one line in this file that touches a role.
    //
    // It is safe here and nowhere else because it is gated on the *outcome*
    // existing: the standings are what the server publishes when the match is
    // over, every role in them is already public, and until then this map is
    // empty and every seat's `winner` is null. There is no phase in which a
    // side is known to this function and not to the room.
    final winner = snapshot.outcome?.winner;
    final sides = winner == null
        ? const <int, bool>{}
        : {
            for (final standing in snapshot.standings)
              standing.seat: standing.role.alignment == winner,
          };

    // The result shows faces, not marks: the standings' roles become each
    // seat's card portrait, turned over by the same beat-2 flip.
    const roles = <int, String>{};
    final resultRoles = winner == null
        ? const <int, engine.Role>{}
        : {
            for (final standing in snapshot.standings)
              standing.seat: standing.role,
          };

    // Purchased frames and plates: public phases only (doc 05 rule 3).
    final dressed = cosmeticsVisibleIn(snapshot.phase);
    return [
      for (final player in snapshot.public.players)
        if (player.seat != snapshot.viewerSeat)
          CouncilSeatData(
            frame: dressed ? snapshot.seatCosmetics[player.seat]?.frame : null,
            plate: dressed ? snapshot.seatCosmetics[player.seat]?.plate : null,
            // The Council rank rides with the frame: public phases only.
            rank: dressed ? snapshot.seatCosmetics[player.seat]?.rank : null,
            seat: player.seat,
            name: player.name,
            status: statusFor(snapshot, player, mood: mood),
            // Collapsed for the whole night by the same gate every other
            // per-seat fact goes through (doc 10 §6.3). Presence is not a
            // fact about a role, but "which seats changed while the room was
            // dark" is a channel, and the answer to a channel is to have one
            // rule rather than an exception.
            muted: snapshot.mutedSeats.contains(player.seat),
            avatar: AvatarArt.forGender(player.gender),
            presence: mood.showsPerSeatStatus
                ? (snapshot.presence[player.seat] ?? SeatPresence.connected)
                : SeatPresence.connected,
            winner: sides[player.seat],
            // Beat 2's mark, from the same already-public standings that beat
            // 3's sides come from — and null for the whole match until they
            // exist. The band cannot read it: it is an asset path, and the
            // mapping that produced it lives in `role_glyph.dart`.
            roleGlyph: roles[player.seat],
            // The character, not an icon: at the result every seat turns over
            // to its card's face (owner, 2026-09-23); for a witness, during
            // play as well.
            rolePortrait: witnessRoles[player.seat] != null
                ? faceFor(witnessRoles[player.seat]!)
                : resultRoles[player.seat] == null
                ? null
                : faceFor(resultRoles[player.seat]!),
            speakingLevel: mood.showsPerSeatStatus
                ? (speakingLevels[player.seat] ?? 0)
                : 0,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final mood = TableMood.of(snapshot.phase);
    final viewer = snapshot.public.players
        .where((player) => player.seat == snapshot.viewerSeat)
        .firstOrNull;

    return TablePulse(
      child: Stack(
        key: surface,
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colors.surfaceBase),
          _Backdrop(
            mood: mood,
            winner: snapshot.outcome?.winner,
            pack: cosmeticsVisibleIn(snapshot.phase)
                ? Cosmetics.packs[snapshot.room.presentationPack]
                : null,
          ),
          if (mood.kind == TableMoodKind.morning)
            _MorningSweep(day: snapshot.dayNumber),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.screenMargin),
              child: Column(
                children: [
                  SizedBox(
                    key: header,
                    height: CouncilTokens.headerHeight,
                    child: _CouncilHeader(
                      snapshot: snapshot,
                      onCloseRoom: onCloseRoom,
                    ),
                  ),
                  const BandDivider(),
                  Expanded(
                    flex: CouncilTokens.councilFlex,
                    child: CouncilBand(
                      key: council,
                      seats: seatsFor(
                        snapshot,
                        mood: mood,
                        speakingLevels: speakingLevels,
                        witnessRoles: witnessRoles,
                      ),
                      totalPlayers: snapshot.public.players.length,
                      selectedSeat: selectedSeat,
                      selectableSeats: selectableSeats,
                      onSeatTap: onSeatTap,
                      onSeatInspect: onSeatInspect,
                      crackingSeat: tearingSeat,
                      crackProgress: tearProgress,
                      spark: spark,
                      spotlight: spotlight,
                      revealProgress: revealProgress,
                      leftLabel: context.l10n.onlineLeftRoom,
                      seatMarks: seatMarks,
                    ),
                  ),
                  Expanded(
                    key: voice,
                    flex: CouncilTokens.voiceFlex,
                    child: AnimatedSwitcher(
                      duration: ReduceMotion.of(context)
                          ? Duration.zero
                          : context.motion.band,
                      switchInCurve: context.motion.standardCurve,
                      switchOutCurve: context.motion.standardCurve,
                      transitionBuilder: bandTransition,
                      child: KeyedSubtree(
                        key: ValueKey(snapshot.phase),
                        child: centre ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  Expanded(
                    key: hand,
                    flex: CouncilTokens.handFlex,
                    child: _HandBand(
                      footer: footer,
                      viewer: viewer,
                      speakingLevel: mood.showsPerSeatStatus
                          ? (speakingLevels[snapshot.viewerSeat] ?? 0)
                          : 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (Cosmetics.packs.containsKey(snapshot.room.presentationPack) ||
              Cosmetics.narrators.containsKey(snapshot.room.narratorPack))
            RoomPresentationLayer(snapshot: snapshot),
        ],
      ),
    );
  }
}

class _CouncilHeader extends StatelessWidget {
  final GameSnapshot snapshot;
  final VoidCallback? onCloseRoom;

  const _CouncilHeader({required this.snapshot, this.onCloseRoom});

  String _label(BuildContext context) {
    final l10n = context.l10n;
    return switch (snapshot.phase) {
      GamePhase.night ||
      GamePhase.nightResolving ||
      GamePhase.preNightLobby => l10n.nightNumbered(snapshot.dayNumber),
      GamePhase.morning ||
      GamePhase.openingRound ||
      GamePhase.confrontation ||
      GamePhase.discussion ||
      GamePhase.voting ||
      GamePhase.voteResolving ||
      GamePhase.reveal ||
      GamePhase.winCheck => l10n.dayNumbered(snapshot.dayNumber),
      GamePhase.result || GamePhase.analytics => l10n.gameOver,
      _ => l10n.onlineRoomCode,
    };
  }

  @override
  Widget build(BuildContext context) {
    final type = context.typography;
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            _label(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.caption.copyWith(color: colors.textSecondary),
          ),
        ),
        if (snapshot.phaseDeadline != null)
          HeaderTimer(deadline: snapshot.phaseDeadline!),
        const SafetyButton(),
        if (onCloseRoom != null)
          IconButton(
            key: TableScene.exitRoomButton,
            tooltip: context.l10n.onlineLeave,
            onPressed: onCloseRoom,
            icon: Icon(Icons.logout, color: colors.textSecondary),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

/// The match clock, in Band 1 and nowhere else (doc 15 §1.2).
///
/// **Under ten seconds it does not turn red.** Doc 12 §5 reserves red for
/// elimination, and doc 15 restates it: the digits gain weight and nothing
/// else. A timer that changes colour is a second, louder channel for a fact the
/// number already carries, and in a room where everybody is watching each
/// other's faces it is the panic that leaks, not the time.
class HeaderTimer extends StatefulWidget {
  final DateTime deadline;

  const HeaderTimer({super.key, required this.deadline});

  /// Seconds left on [deadline], floored at zero.
  ///
  /// Pure, so the "never red, weight only" rule can be asserted without a
  /// wall clock.
  static int secondsLeft(DateTime deadline, DateTime now) {
    final left = deadline.difference(now);
    return left.isNegative ? 0 : left.inSeconds;
  }

  static const int urgentBelow = 10;

  static String format(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  State<HeaderTimer> createState() => _HeaderTimerState();
}

class _HeaderTimerState extends State<HeaderTimer> {
  Timer? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticker?.cancel();
    _ticker = Timer.periodic(context.motion.tick, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = HeaderTimer.secondsLeft(widget.deadline, DateTime.now());
    final style = context.typography.title.copyWith(
      color: context.colors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: seconds < HeaderTimer.urgentBelow
          ? FontWeight.w900
          : FontWeight.w600,
    );
    // The stopwatch is an icon: «⏱» is in none of the bundled faces and drew
    // as an empty box wherever the system has no fallback for it.
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        Icon(
          Icons.timer_outlined,
          size: style.fontSize,
          color: context.colors.textPrimary,
        ),
        SizedBox(width: context.spacing.xs),
        Text(
          HeaderTimer.format(seconds),
          key: TableScene.headerTimer,
          textDirection: TextDirection.ltr,
          style: style,
        ),
      ],
    );
  }
}

/// Doc 15 Band 4. One primary action, always in the same place, and your own
/// seat under it so you never lose track of who you are.
class _HandBand extends StatelessWidget {
  final Widget? footer;
  final PublicPlayer? viewer;
  final double speakingLevel;

  const _HandBand({
    required this.footer,
    required this.viewer,
    required this.speakingLevel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    return Column(
      children: [
        // The hand changes with the phase — a hold pad, a ballot button, the
        // witness panel — and it used to change in one frame. It now moves the
        // way band 3 does, so the whole screen re-dresses as one gesture.
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: ReduceMotion.of(context)
                  ? Duration.zero
                  : context.motion.band,
              switchInCurve: context.motion.standardCurve,
              switchOutCurve: context.motion.standardCurve,
              transitionBuilder: bandTransition,
              // Only the incoming hand is ever on screen. A control fading out
              // is still a control, and a thumb landing on yesterday's button
              // while today's rises is a move nobody meant to make.
              layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
              child: footer ?? const SizedBox.shrink(),
            ),
          ),
        ),
        if (viewer != null)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.xs),
            child: Row(
              key: TableScene.viewerSeat,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Task 7 — your own chair carries the same face the council
                // draws for everybody else, from the same one mapping.
                PlayerAvatar(
                  name: viewer!.name,
                  gender: viewer!.gender,
                  diameter: CouncilTokens.viewerSeatSize,
                  ringColor: colors.textPrimary,
                  speakingLevel: speakingLevel,
                ),
                SizedBox(width: spacing.sm),
                Flexible(
                  child: Text(
                    '${viewer!.name} · ${context.l10n.onlineYou}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Doc 15 §S-O6 beat 1: light sweeps down from the header over 1.4s.
///
/// A gradient wipe rather than a brightness change, so the *ground* stays at
/// the same luminance the budget test measures.
class _MorningSweep extends StatefulWidget {
  final int day;

  const _MorningSweep({required this.day});

  @override
  State<_MorningSweep> createState() => _MorningSweepState();
}

class _MorningSweepState extends State<_MorningSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sweep.duration = context.motion.reveal;
    if (ReduceMotion.of(context)) {
      _sweep.value = 1;
    } else if (!_sweep.isAnimating && _sweep.value == 0) {
      _sweep.forward();
    }
  }

  @override
  void didUpdateWidget(_MorningSweep old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day && !ReduceMotion.of(context)) {
      _sweep.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, _) {
          final t = context.motion.revealCurve.transform(_sweep.value);
          if (t >= 1) return const SizedBox.shrink();
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [t, (t + 0.25).clamp(0.0, 1.0)],
                colors: [
                  colors.textPrimary.withValues(alpha: 0.10 * (1 - t)),
                  colors.textPrimary.withValues(alpha: 0),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  final TableMood mood;
  final engine.Alignment? winner;

  /// The host's presentation pack, already null outside public phases.
  final PresentationPack? pack;

  const _Backdrop({required this.mood, this.winner, this.pack});

  @override
  Widget build(BuildContext context) {
    final result = mood.kind == TableMoodKind.result && winner != null;
    final asset = result
        ? (winner == engine.Alignment.mafia
              ? AppImages.outcomeMafiaWin
              : AppImages.outcomeTownWin)
        : switch (mood.kind) {
            TableMoodKind.night ||
            TableMoodKind.reveal => AppCouncilArt.backdropNight,
            TableMoodKind.morning => AppCouncilArt.backdropDawn,
            TableMoodKind.discussion ||
            TableMoodKind.lobby => AppCouncilArt.backdropDay,
            TableMoodKind.confrontation ||
            TableMoodKind.vote ||
            TableMoodKind.result => AppCouncilArt.backdropVerdict,
          };
    // Only public phases gain motion. Private night/reveal surfaces keep
    // their existing neutral ground, independent of role and action state.
    final loop = result
        ? (winner == engine.Alignment.mafia
              ? AppVideo.outcomeMafiaWinLoop
              : AppVideo.outcomeTownWinLoop)
        : switch (mood.kind) {
            TableMoodKind.lobby => AppVideo.bgHomeLoop,
            TableMoodKind.vote => AppVideo.bgVoteLoop,
            _ => null,
          };
    return AnimatedSwitcher(
      duration: ReduceMotion.of(context) ? Duration.zero : context.motion.phase,
      child: Opacity(
        key: ValueKey(asset),
        opacity: CouncilTokens.backdropOpacity,
        child: PackBackdrop(
          pack: pack,
          // The result keeps its outcome picture; the pack only grades it.
          showArt: !result,
          child: AmbientMedia(still: asset, loop: loop),
        ),
      ),
    );
  }
}

bool tableIsAvailableFor(GameSnapshot snapshot) =>
    snapshot.viewerSeat != null && snapshot.phase != GamePhase.setup;

/// The rule under the header, with doc 15 A4's corner ornament at each end.
///
/// One asset, mirrored. It is the only decoration in the band system, and it
/// is there because a bare 1px rule across a noir table reads as a divider in
/// a settings screen — the ornament is what says *this is the same room the
/// cards came out of*. Tinted at runtime like every other mask, so it costs one
/// file and never carries a colour of its own.
class BandDivider extends StatelessWidget {
  const BandDivider({super.key});

  static const Key rule = ValueKey('council_band_divider');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget corner({required bool mirrored}) => Transform.flip(
      flipX: mirrored,
      child: Image.asset(
        AppCouncilArt.panelCorner,
        width: CouncilTokens.cornerSize,
        height: CouncilTokens.cornerSize,
        color: colors.borderSubtle,
        excludeFromSemantics: true,
      ),
    );

    return SizedBox(
      key: rule,
      height: CouncilTokens.cornerSize,
      child: Row(
        children: [
          corner(mirrored: false),
          Expanded(
            child: Divider(
              height: CouncilTokens.hairline,
              thickness: CouncilTokens.hairline,
              color: colors.borderSubtle,
            ),
          ),
          corner(mirrored: true),
        ],
      ),
    );
  }
}

/// How band 3 and the hand swap what they hold: the new content fades in while
/// rising a few points and settling from a hair under full size; the old one
/// does the same in reverse. Small distances on purpose — the eye should read
/// "the same place, re-dressed", not "a new screen".
Widget bandTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, CouncilTokens.bandSwapRise),
        end: Offset.zero,
      ).animate(animation),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: CouncilTokens.bandSwapScale,
          end: 1,
        ).animate(animation),
        child: child,
      ),
    ),
  );
}
