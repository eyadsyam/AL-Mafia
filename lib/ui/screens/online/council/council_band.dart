import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/asset_constants.dart';
import '../../../../platform/reduce_motion.dart';
import '../../../../transport/game_snapshot.dart' show SeatPresence;
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';
import '../../../economy/cosmetic_paint.dart';
import '../../../economy/cosmetic_art_cache.dart';
import '../../../economy/cosmetics.dart';
import '../../../economy/council_art.dart' show paintSeatRank;
import '../table/table_pulse.dart';
import 'seat_status.dart';
import 'council_geometry.dart';

/// One seat's worth of public fact.
///
/// Value-equal on purpose: [CouncilPainter.shouldRepaint] compares lists of
/// these, and a data class without `==` makes every rebuild a repaint — which
/// is the exact thing doc 15 §3's performance budget forbids.
@immutable
class CouncilSeatData {
  final int seat;
  final String? name;
  final SeatStatus status;

  /// How present this player is (task 4).
  ///
  /// Drawn, not written: `connected` gets a ring with a face in it, `away`
  /// gets the ring and nothing inside at 45%, and `left` gets a cracked ring
  /// at 30% with «خرج» under the name. Only the last one has words, because
  /// leaving is final and stepping away is not — an empty ring is a question
  /// the table is meant to ask itself.
  final SeatPresence presence;

  /// Whether the host has silenced this player for the whole room (task 6).
  ///
  /// Drawn as a struck-through microphone on the ring. Public by construction
  /// and safe to be: the host did it in front of everybody, and a room that
  /// could not see who had been muted would spend the discussion waiting for
  /// somebody who cannot answer.
  final bool muted;

  /// A slot nobody has claimed yet. Lobby only.
  final bool isEmpty;

  /// This device's own seat. Doc 15 §1.3: a thin cream hairline, always.
  final bool isViewer;

  /// Public pre-deal confirmation. Lobby callers are the only ones that set it.
  final bool lobbyReady;
  final bool lobbyReadyExpired;

  /// Whether this seat ended the match on the winning side.
  ///
  /// Null in every phase but the result, and that is the whole safety
  /// argument: a side is a fact about a role, so it exists exactly when every
  /// role in the match is already public and at no other moment. Doc 15
  /// §S-O13 beat 3 — *"winners' rings warm to cream; losers dim to 30%."*
  final bool? winner;

  /// The asset path of this player's character art, or null when they did not
  /// say (task 7).
  ///
  /// A path and not a gender, for exactly the reason [roleGlyph] is a path and
  /// not a role: this file must be unable to name either. The mapping lives in
  /// `player_avatar.dart`, which is also what the offline lists read, so there
  /// is one answer to "what does this person look like" in the app.
  final String? avatar;

  /// The asset path of the role mark this seat carries, or null.
  ///
  /// A path and not a `Role`, deliberately. This file must not be able to name
  /// a role — there is a test that fails if it ever does — so the mapping lives
  /// in `role_glyph.dart` and what arrives here is something the painter can
  /// only draw. Non-null for the first time at `GamePhase.result`, off
  /// standings the server has already published (doc 15 §S-O13 beat 2).
  final String? roleGlyph;

  /// The asset path of this seat's *character card*, for an eliminated viewer
  /// only, or null.
  ///
  /// A path for the same reason as [roleGlyph]. Non-null only when the server's
  /// `witness_view` has answered, which it does for the dead alone (owner
  /// decision 2026-09-23, doc 12 §4.1). Drawn as the card's face inside the
  /// ring, in place of the avatar or the initial.
  final String? rolePortrait;

  /// Local audio telemetry used only for the speaking pulse. It is not game
  /// state and is never sent to another player.
  final double speakingLevel;

  /// The frame and nameplate this player chose in the store, or null.
  ///
  /// Codes, not styles: the painter looks them up. The caller passes null for
  /// every seat outside the public phases (doc 05 rule 3: no purchased colour
  /// on a night surface), so at night every ring is the plain ring again.
  final String? frame;
  final String? plate;

  /// The Council level this player sat down with, or null (phase 107).
  /// Public identity earned from finished matches; the caller passes null
  /// outside the public phases, like the frame.
  final int? rank;

  const CouncilSeatData({
    required this.seat,
    required this.name,
    this.status = SeatStatus.idle,
    this.presence = SeatPresence.connected,
    this.muted = false,
    this.avatar,
    this.isEmpty = false,
    this.isViewer = false,
    this.lobbyReady = false,
    this.lobbyReadyExpired = false,
    this.winner,
    this.roleGlyph,
    this.rolePortrait,
    this.speakingLevel = 0,
    this.frame,
    this.plate,
    this.rank,
  });

  @override
  bool operator ==(Object other) =>
      other is CouncilSeatData &&
      other.seat == seat &&
      other.name == name &&
      other.winner == winner &&
      other.status == status &&
      other.presence == presence &&
      other.muted == muted &&
      other.avatar == avatar &&
      other.isEmpty == isEmpty &&
      other.isViewer == isViewer &&
      other.lobbyReady == lobbyReady &&
      other.lobbyReadyExpired == lobbyReadyExpired &&
      other.roleGlyph == roleGlyph &&
      other.rolePortrait == rolePortrait &&
      other.speakingLevel == speakingLevel &&
      other.frame == frame &&
      other.plate == plate &&
      other.rank == rank;

  @override
  int get hashCode => Object.hash(
    seat,
    name,
    status,
    presence,
    muted,
    avatar,
    isEmpty,
    isViewer,
    lobbyReady,
    lobbyReadyExpired,
    winner,
    roleGlyph,
    rolePortrait,
    speakingLevel,
    frame,
    plate,
    rank,
  );
}

/// A light crossing the council, seat to seat (doc 15 §S-O9).
///
/// Everybody sees the light; nobody sees the words. Carries seats rather than
/// list indices so a seat leaving the council mid-flight cannot re-point it at
/// somebody else.
@immutable
class CouncilSpark {
  final int fromSeat;
  final int toSeat;
  final double progress;

  const CouncilSpark({
    required this.fromSeat,
    required this.toSeat,
    required this.progress,
  });

  @override
  bool operator ==(Object other) =>
      other is CouncilSpark &&
      other.fromSeat == fromSeat &&
      other.toSeat == toSeat &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(fromSeat, toSeat, progress);
}

/// Doc 15 Band 2: the council, drawn by exactly one painter.
///
/// ## Why one painter and not one widget per seat
///
/// Doc 15 §3: *"Band 2 is one `CustomPainter` for rings and glows. Seats do not
/// each own a widget with its own animation controller."* Fifteen controllers
/// is fifteen tickers and fifteen independent phases, and two seats breathing
/// out of step is a difference somebody at the table can see — which at night
/// is a channel. Every animated quantity here comes from one of two sources:
/// the shared [TablePulse], or the single controller this widget owns for
/// selection changes.
///
/// The taps are a separate, thin layer of [GestureDetector]s positioned over
/// the paint. They draw nothing.
class CouncilBand extends StatefulWidget {
  final List<CouncilSeatData> seats;

  /// The size the council is laid out for — the whole match, not just the
  /// seats drawn here. Keeps seat size stable as players die.
  final int totalPlayers;

  final int? selectedSeat;
  final Set<int> selectableSeats;
  final ValueChanged<int>? onSeatTap;

  /// Opens whatever a seat's *moderation* is, as opposed to its game action
  /// (task 6). Fires on a tap when the seat has no game action to take, and on
  /// a long press when it does — a host who is choosing a target and a host
  /// who is about to remove somebody must not share a gesture.
  final ValueChanged<int>? onSeatInspect;

  /// The seat whose ring is tearing, and how far through the tear it is.
  final int? crackingSeat;
  final double crackProgress;

  /// A whisper in flight.
  final CouncilSpark? spark;

  /// How open the confrontation spotlight is, 0 to 1.
  final double spotlight;

  /// Doc 15 §S-O13 beat 2: one number, every ring, no stagger.
  ///
  /// At 0 the council is as it was. Through 0.5 every ring turns edge-on
  /// together; coming back out of it each one carries its occupant's
  /// [CouncilSeatData.roleGlyph] where the initial was. It is driven from
  /// outside because the band owns exactly one controller and doc 15 §3's
  /// frame budget is the reason it owns only one.
  final double revealProgress;

  /// Per-seat join progress, 0 (dashed and empty) to 1 (solid). Lobby only.
  final Map<int, double> joinProgress;

  /// Drawn under the name of the viewer's own seat.
  final String? youLabel;

  /// Drawn under the name of a seat whose player has left (task 4).
  ///
  /// A parameter rather than a lookup, for the same reason [youLabel] is: the
  /// painter has no `BuildContext` and no business having one.
  final String? leftLabel;

  const CouncilBand({
    super.key,
    required this.seats,
    required this.totalPlayers,
    this.selectedSeat,
    this.selectableSeats = const {},
    this.onSeatTap,
    this.onSeatInspect,
    this.crackingSeat,
    this.crackProgress = 0,
    this.spark,
    this.spotlight = 0,
    this.revealProgress = 0,
    this.joinProgress = const {},
    this.youLabel,
    this.leftLabel,
  });

  static Key seatKey(int seat) => ValueKey('council_seat_$seat');

  @override
  State<CouncilBand> createState() => _CouncilBandState();
}

class _CouncilBandState extends State<CouncilBand>
    with SingleTickerProviderStateMixin {
  ui.Image? _idle;
  ui.Image? _cracked;
  ui.Image? _empty;
  ui.Image? _mote;
  ui.Image? _spotlight;

  /// Role marks, by asset path. Empty for the whole match and loaded once at
  /// the result — there are at most four distinct marks however many seats
  /// there are, so this is four decodes, not fifteen.
  Map<String, ui.Image> _glyphs = const {};
  Set<String> _glyphsWanted = const {};

  /// Drives the hand-off between the seat that was chosen and the one that is.
  late final AnimationController _shift = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );
  int? _previousSelected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shift.duration = ReduceMotion.of(context)
        ? Duration.zero
        : context.motion.quick;

    if (_idle == null) unawaited(_loadArt());
    _syncGlyphs();
  }

  /// Decode any role mark the council is about to need and does not have.
  ///
  /// Keyed on the set of paths rather than on the phase: the band does not
  /// know what a phase is, and "the seats are carrying marks I have not
  /// decoded" is the only condition that matters.
  void _syncGlyphs() {
    final wanted = {
      for (final seat in widget.seats)
        if (seat.roleGlyph != null) seat.roleGlyph!,
      // The character art rides the same cache. There are at most two distinct
      // faces however many seats there are, so this is two decodes rather than
      // fifteen — the same argument that put the role marks here.
      for (final seat in widget.seats)
        if (seat.avatar != null) seat.avatar!,
      // Four card faces at most, whatever the table size.
      for (final seat in widget.seats)
        if (seat.rolePortrait != null) seat.rolePortrait!,
    };
    if (setEquals(wanted, _glyphsWanted)) return;
    _glyphsWanted = wanted;
    if (wanted.isEmpty) {
      setState(() => _glyphs = const {});
      return;
    }
    unawaited(() async {
      final decoded = await Future.wait(wanted.map(_load));
      if (!mounted) return;
      setState(() {
        _glyphs = {
          for (var i = 0; i < wanted.length; i++)
            wanted.elementAt(i): decoded[i],
        };
      });
    }());
  }

  @override
  void didUpdateWidget(CouncilBand old) {
    super.didUpdateWidget(old);
    _syncGlyphs();
    if (old.selectedSeat != widget.selectedSeat) {
      _previousSelected = old.selectedSeat;
      _shift.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shift.dispose();
    super.dispose();
  }

  Future<ui.Image> _load(String asset) async {
    final data = await DefaultAssetBundle.of(context).load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  Future<void> _loadArt() async {
    // Frame and plate art decodes alongside the ring art (not ahead of it),
    // and the one setState below paints both.
    final cosmetics = CosmeticArtCache.load(
      DefaultAssetBundle.of(context).load,
    );
    final images = await Future.wait([
      _load(AppCouncilArt.seatRingIdle),
      _load(AppCouncilArt.seatRingCracked),
      _load(AppCouncilArt.seatRingEmpty),
      _load(AppCouncilArt.lightMote),
      _load(AppCouncilArt.spotlight),
    ]);
    await cosmetics;
    if (!mounted) return;
    setState(() {
      _idle = images[0];
      _cracked = images[1];
      _empty = images[2];
      _mote = images[3];
      _spotlight = images[4];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final direction = Directionality.of(context);
    final breath = TablePulse.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final positions = CouncilGeometry.layout(
          size: constraints.biggest,
          seatCount: widget.seats.length,
          totalPlayers: widget.totalPlayers,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                // The witness's portraits fade in together the first time they
                // arrive — outside the band's one controller (doc 15 §3).
                tween: Tween<double>(
                  end:
                      widget.seats.any(
                        (seat) => _glyphs[seat.rolePortrait] != null,
                      )
                      ? 1
                      : 0,
                ),
                duration: ReduceMotion.of(context)
                    ? Duration.zero
                    : context.motion.phase,
                builder: (context, portraitIn, _) => AnimatedBuilder(
                  animation: Listenable.merge([breath, _shift]),
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: CouncilPainter(
                      seats: widget.seats,
                      positions: positions,
                      selectedSeat: widget.selectedSeat,
                      previousSelected: _previousSelected,
                      shift: _shift.isAnimating || _shift.isCompleted
                          ? _shift.value
                          : 1.0,
                      crackingSeat: widget.crackingSeat,
                      crackProgress: widget.crackProgress,
                      spark: widget.spark,
                      spotlightOpen: widget.spotlight,
                      revealProgress: widget.revealProgress,
                      portraitIn: portraitIn,
                      glyphs: _glyphs,
                      joinProgress: widget.joinProgress,
                      youLabel: widget.youLabel,
                      leftLabel: widget.leftLabel,
                      idle: _idle,
                      cracked: _cracked,
                      empty: _empty,
                      mote: _mote,
                      spotlightArt: _spotlight,
                      textDirection: direction,
                      ringColor: colors.borderSubtle,
                      viewerColor: colors.textPrimary,
                      textColor: colors.textPrimary,
                      secondaryColor: colors.textSecondary,
                      gold: colors.accentGold,
                      breath: breath.value,
                      caption: type.caption,
                      initial: type.title,
                    ),
                  ),
                ),
              ),
            ),
            for (var index = 0; index < positions.length; index++)
              Positioned.fromRect(
                rect: positions[index].hitRect,
                child: Semantics(
                  label: widget.seats[index].name,
                  button: widget.selectableSeats.contains(
                    widget.seats[index].seat,
                  ),
                  selected: widget.selectedSeat == widget.seats[index].seat,
                  child: GestureDetector(
                    key: CouncilBand.seatKey(widget.seats[index].seat),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final seat = widget.seats[index].seat;
                      if (widget.onSeatTap != null &&
                          widget.selectableSeats.contains(seat)) {
                        widget.onSeatTap!(seat);
                        return;
                      }
                      if (widget.seats[index].isEmpty) return;
                      widget.onSeatInspect?.call(seat);
                    },
                    onLongPress: widget.seats[index].isEmpty
                        ? null
                        : () => widget.onSeatInspect?.call(
                            widget.seats[index].seat,
                          ),
                    // Nothing is drawn here. The whole seat, including the
                    // acknowledgement a tap produces, belongs to the painter.
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Draws every seat, every glow, the spotlight and the whisper in flight.
class CouncilPainter extends CustomPainter {
  final List<CouncilSeatData> seats;
  final List<CouncilSeatLayout> positions;
  final int? selectedSeat;
  final int? previousSelected;

  /// 0 at the instant the selection changed, 1 once the hand-off is done.
  final double shift;

  final int? crackingSeat;
  final double crackProgress;
  final CouncilSpark? spark;
  final double spotlightOpen;

  /// 0 to 1, shared by every seat. See [CouncilBand.revealProgress].
  final double revealProgress;

  /// How far the witness portraits have faded in, 0 to 1.
  final double portraitIn;

  /// The decoded role marks, by the path [CouncilSeatData.roleGlyph] carries.
  final Map<String, ui.Image> glyphs;

  final Map<int, double> joinProgress;
  final String? youLabel;
  final String? leftLabel;

  final ui.Image? idle;
  final ui.Image? cracked;
  final ui.Image? empty;
  final ui.Image? mote;
  final ui.Image? spotlightArt;

  final TextDirection textDirection;
  final Color ringColor;
  final Color viewerColor;
  final Color textColor;
  final Color secondaryColor;
  final Color gold;
  final double breath;
  final TextStyle caption;
  final TextStyle initial;

  const CouncilPainter({
    required this.seats,
    required this.positions,
    required this.selectedSeat,
    required this.previousSelected,
    required this.shift,
    required this.crackingSeat,
    required this.crackProgress,
    required this.spark,
    required this.spotlightOpen,
    this.revealProgress = 0,
    this.portraitIn = 1,
    this.glyphs = const {},
    required this.joinProgress,
    required this.youLabel,
    this.leftLabel,
    required this.idle,
    required this.cracked,
    required this.empty,
    required this.mote,
    required this.spotlightArt,
    required this.textDirection,
    required this.ringColor,
    required this.viewerColor,
    required this.textColor,
    required this.secondaryColor,
    required this.gold,
    required this.breath,
    required this.caption,
    required this.initial,
  });

  bool get _anyConfronted =>
      seats.any((seat) => seat.status == SeatStatus.confronted);

  /// How emphasised a seat is right now, 0 (dimmed away) to 1 (chosen).
  ///
  /// Doc 15 §1.6: selection is made **by subtraction**. The chosen seat lifts
  /// and every other seat drops — and when the choice moves, the old seat comes
  /// back up while the new one lifts, over the same window.
  double _emphasis(int seat) {
    double at(int? chosen) {
      if (chosen == null) return 1;
      return seat == chosen ? 1 : 0;
    }

    if (previousSelected == selectedSeat) return at(selectedSeat);
    return ui.lerpDouble(at(previousSelected), at(selectedSeat), shift)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (spotlightOpen > 0 && spotlightArt != null) {
      final target = seats.indexWhere(
        (seat) => seat.status == SeatStatus.confronted,
      );
      if (target >= 0 && target < positions.length) {
        _paintSpotlight(canvas, size, positions[target]);
      }
    }
    for (var index = 0; index < positions.length; index++) {
      _paintSeat(canvas, seats[index], positions[index]);
    }
    _paintSpark(canvas);
  }

  void _paintSpotlight(Canvas canvas, Size size, CouncilSeatLayout on) {
    final reach = math.max(size.width, size.height) * spotlightOpen;
    if (reach <= 0) return;
    paintImage(
      canvas: canvas,
      rect: Rect.fromCenter(center: on.centre, width: reach, height: reach),
      image: spotlightArt!,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(
        gold.withValues(alpha: 0.18 * spotlightOpen),
        BlendMode.srcIn,
      ),
      filterQuality: FilterQuality.low,
    );
  }

  void _paintSeat(
    Canvas canvas,
    CouncilSeatData seat,
    CouncilSeatLayout layout,
  ) {
    final chosen = selectedSeat == seat.seat;
    final emphasis = _emphasis(seat.seat);
    final tearing = crackingSeat == seat.seat ? crackProgress : 0.0;
    final joining = joinProgress[seat.seat] ?? 1.0;

    // Task 4. Presence outranks the seat's game status for the *dimming*,
    // because a player who is not there is not there whatever the phase thinks
    // they are doing. It does not outrank death: a dead player who also closed
    // the app is drawn dead, and the two happen to look the same anyway.
    final presenceOpacity = switch (seat.presence) {
      SeatPresence.away => CouncilTokens.awayOpacity,
      SeatPresence.left => CouncilTokens.leftOpacity,
      SeatPresence.connected => 1.0,
    };
    final statusOpacity = switch (seat.status) {
      SeatStatus.dead => CouncilTokens.deadOpacity,
      SeatStatus.disconnected => CouncilTokens.disconnectedOpacity,
      _ => math.min(1.0, presenceOpacity),
    };
    // Three subtractive rules, applied in the order doc 15 states them: an
    // explicit choice wins, a confrontation next, and the seat's own state
    // last. Only ever one of them is doing the dimming.
    final opacity = selectedSeat != null
        ? ui.lerpDouble(
            CouncilTokens.selectedOthersOpacity,
            statusOpacity,
            emphasis,
          )!
        : _anyConfronted && seat.status != SeatStatus.confronted
        ? CouncilTokens.confrontedOthersOpacity
        // Doc 15 §S-O13 beat 3. Last in the chain and only ever set at the
        // result, so it cannot compete with a selection or a confrontation —
        // by the time it is non-null there is nothing left to select.
        : seat.winner == false
        ? CouncilTokens.loserOpacity
        : statusOpacity;

    final scale = ui.lerpDouble(1.0, CouncilTokens.selectedScale, emphasis)!;
    final dead = seat.status == SeatStatus.dead || tearing > 0;

    canvas.save();
    canvas.translate(layout.centre.dx, layout.centre.dy);
    if (tearing > 0 && tearing < 1) {
      // Doc 15 §S-O6 beat 2: the ring cracks and shakes, then settles tilted.
      canvas.translate(
        math.sin(tearing * math.pi * CouncilTokens.crackShakeCycles) *
            CouncilTokens.crackShakeAmplitude *
            (1 - tearing),
        0,
      );
    }
    canvas.scale(scale);
    // Doc 15 §S-O13 beat 2. A half-turn about the vertical axis, and the whole
    // council does it on the same frame — `revealProgress` is one number for
    // every seat, so there is nothing here that could stagger even by mistake.
    //
    // The floor of 0.04 is not a rounding fudge: a ring scaled to exactly zero
    // is a ring that vanishes for a frame, and fifteen of them vanishing
    // together reads as a dropped frame rather than as a turn.
    if (revealProgress > 0) {
      canvas.scale(math.max(math.cos(revealProgress * math.pi).abs(), 0.04), 1);
    }
    if (dead) {
      canvas.rotate(
        CouncilTokens.deadTiltRadians * math.min(1, tearing == 0 ? 1 : tearing),
      );
    }

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: layout.diameter,
      height: layout.diameter,
    );
    final speaking = seat.status == SeatStatus.speaking;
    // A ring that cracks for a player who left, exactly as it cracks for a
    // player who died — the seat is out of the argument either way, and one
    // shape for "not coming back" is one shape to learn.
    final gone = seat.presence == SeatPresence.left;
    final ringArt = seat.isEmpty && joining <= 0
        ? empty
        : dead || gone
        ? cracked
        : idle;
    final tint = chosen || speaking || seat.lobbyReady
        ? gold
        // Cream rather than gold: gold is the colour of a choice being made,
        // and the match is over. Warmth is what is left when there is nothing
        // more to press.
        : seat.winner == true
        ? viewerColor
        : seat.isViewer
        ? viewerColor
        : ringColor;

    if (!seat.isEmpty && seat.presence == SeatPresence.connected) {
      _paintVoicePulse(canvas, layout.diameter, seat.speakingLevel, opacity);
    }

    if ((chosen || speaking) && emphasis > 0) {
      canvas.drawCircle(
        Offset.zero,
        layout.diameter * CouncilTokens.glowRadiusRatio,
        Paint()
          ..color = gold.withValues(
            alpha:
                (chosen
                    ? CouncilTokens.selectedGlowAlpha
                    : CouncilTokens.breathingGlowBase +
                          CouncilTokens.breathingGlowSwing * breath) *
                emphasis,
          )
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            CouncilTokens.outerGlowBlur,
          ),
      );
    }

    void ring(ui.Image? art, double alpha, {double sweep = 1}) {
      if (alpha <= 0) return;
      if (art == null) {
        canvas.drawCircle(
          Offset.zero,
          layout.diameter / 2 - CouncilTokens.hairline,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = chosen
                ? CouncilTokens.selectedRingWidth
                : CouncilTokens.hairline
            ..color = tint.withValues(alpha: alpha),
        );
        return;
      }
      canvas.save();
      if (sweep < 1) {
        // Doc 15 §S-O3: the dashed ring *draws itself solid*.
        canvas.clipPath(
          Path()
            ..addArc(
              rect.inflate(rect.width),
              -math.pi / 2,
              sweep * 2 * math.pi,
            )
            ..lineTo(0, 0)
            ..close(),
        );
      }
      paintImage(
        canvas: canvas,
        rect: rect,
        image: art,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          tint.withValues(alpha: alpha),
          BlendMode.srcIn,
        ),
        filterQuality: FilterQuality.medium,
      );
      canvas.restore();
    }

    if (seat.isEmpty) {
      ring(empty, CouncilTokens.emptySeatOpacity * (1 - joining));
      ring(idle, opacity * joining, sweep: joining);
    } else {
      ring(ringArt, opacity, sweep: joining);
      final frame = Cosmetics.frames[seat.frame];
      if (frame != null) {
        paintCosmeticFrame(
          canvas,
          Offset.zero,
          layout.diameter,
          frame,
          maxSide: layout.diameter * CosmeticTokens.tableFrameExtent,
          opacity: opacity * joining,
        );
      }
    }

    // Past halfway the ring has turned edge-on and come back, and what it
    // carries now is the mark rather than the letter. Before halfway it is
    // still the initial: the turn is what swaps them, which is why there is no
    // cross-fade here and nothing to tune.
    // Task 4: the empty ring *is* the signal. Nothing is drawn inside a seat
    // whose player is not looking at their phone — no face, no initial, no
    // badge — because a label would answer the question the emptiness is
    // supposed to ask.
    final frameStyle = Cosmetics.frames[seat.frame];
    final avatarRatio =
        frameStyle != null &&
            CosmeticArtCache.images.containsKey(frameStyle.artCode)
        ? math.min(
            CouncilTokens.avatarSizeRatio,
            frameStyle.aperture *
                CosmeticTokens.tableFrameExtent *
                CosmeticTokens.avatarApertureInset,
          )
        : CouncilTokens.avatarSizeRatio;
    final inhabited = seat.presence == SeatPresence.connected;
    final mark = revealProgress >= 0.5 ? glyphs[seat.roleGlyph] : null;
    if (mark != null) {
      final side = layout.diameter * CouncilTokens.glyphSizeRatio;
      paintImage(
        canvas: canvas,
        rect: Rect.fromCenter(center: Offset.zero, width: side, height: side),
        image: mark,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          tint.withValues(alpha: opacity),
          BlendMode.srcIn,
        ),
        filterQuality: FilterQuality.medium,
      );
    } else if (!seat.isEmpty &&
        glyphs[seat.rolePortrait] != null &&
        // At the result the face waits for the ring to turn past edge-on,
        // like the mark it replaced; a witness's faces need no turn.
        (seat.winner == null || revealProgress >= 0.5)) {
      // The witness's view: the character's face, lifted out of its card.
      // The card is drawn larger than the ring and shifted so its face sits
      // in the middle — the ornate border falls outside the clip, and what is
      // left inside is the person the card depicts.
      final side = layout.diameter * avatarRatio;
      final width = side * CouncilTokens.portraitZoom;
      final height = width / CouncilTokens.cardArtAspect;
      canvas.save();
      canvas.clipPath(
        Path()..addOval(
          Rect.fromCenter(center: Offset.zero, width: side, height: side),
        ),
      );
      paintImage(
        canvas: canvas,
        rect: Rect.fromCenter(
          center: Offset(0, (0.5 - CouncilTokens.portraitFaceY) * height),
          width: width,
          height: height,
        ),
        image: glyphs[seat.rolePortrait]!,
        fit: BoxFit.fill,
        opacity: opacity * joining * portraitIn,
        filterQuality: FilterQuality.medium,
      );
      canvas.restore();
    } else if (inhabited && !seat.isEmpty && glyphs[seat.avatar] != null) {
      // Task 7 — the person, not their initial. Clipped to the ring's inner
      // circle so the art cannot spill over the ornament, and drawn without a
      // colour filter: this is the one thing on a seat that is allowed to
      // carry its own colour, because a face rendered as a silhouette is not a
      // face.
      final side = layout.diameter * avatarRatio;
      canvas.save();
      canvas.clipPath(
        Path()..addOval(
          Rect.fromCenter(center: Offset.zero, width: side, height: side),
        ),
      );
      paintImage(
        canvas: canvas,
        rect: Rect.fromCenter(center: Offset.zero, width: side, height: side),
        image: glyphs[seat.avatar]!,
        fit: BoxFit.cover,
        opacity: opacity * joining,
        filterQuality: FilterQuality.medium,
      );
      canvas.restore();
    } else if (inhabited && !seat.isEmpty && (seat.name?.isNotEmpty ?? false)) {
      final initialPainter = TextPainter(
        text: TextSpan(
          text: seat.name!.characters.first,
          style: initial.copyWith(
            color: textColor.withValues(
              alpha: opacity * joining * (chosen ? 1.0 : 0.8),
            ),
          ),
        ),
        textDirection: textDirection,
        textAlign: TextAlign.center,
      )..layout(maxWidth: layout.diameter * CouncilTokens.initialWidthRatio);
      initialPainter.paint(
        canvas,
        Offset(-initialPainter.width / 2, -initialPainter.height / 2),
      );
    }
    // Task 6 — the host silenced this seat. Drawn on the ring rather than
    // written under the name, because it is a state the room needs at a
    // glance and the space under a chair already holds two lines.
    if (seat.muted) _paintMutedMic(canvas, layout.diameter, opacity);
    if ((seat.lobbyReady || seat.lobbyReadyExpired) &&
        inhabited &&
        !seat.isEmpty) {
      final readyPainter = TextPainter(
        text: TextSpan(
          // An icon glyph, not '✓': the table's text fonts have no check mark.
          text: String.fromCharCode(
            seat.lobbyReady
                ? Icons.check.codePoint
                : Icons.priority_high.codePoint,
          ),
          style: caption.copyWith(
            fontFamily: Icons.check.fontFamily,
            package: Icons.check.fontPackage,
            color: (seat.lobbyReady ? gold : secondaryColor).withValues(
              alpha: opacity,
            ),
          ),
        ),
        textDirection: textDirection,
      )..layout();
      final at = layout.diameter * CouncilLifeTokens.seatBadgeOffset;
      readyPainter.paint(
        canvas,
        Offset(at - readyPainter.width / 2, -at - readyPainter.height / 2),
      );
    }
    // Phase 107: the Council rank, a small crest on the ring's lower edge.
    final rank = seat.rank;
    if (rank != null && !seat.isEmpty && opacity * joining > 0) {
      final side = math.min(
        CouncilLifeTokens.emblemSeat,
        layout.diameter * CouncilLifeTokens.seatBadgeOffset,
      );
      final at = layout.diameter * CouncilLifeTokens.seatBadgeOffset;
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity * joining),
      );
      paintSeatRank(canvas, Offset(at, at), side, rank);
      canvas.restore();
    }

    canvas.restore();

    if (seat.isEmpty || (seat.name?.isEmpty ?? true)) return;
    final label = seat.isViewer && youLabel != null
        ? '${seat.name} · $youLabel'
        : seat.name!;
    final plate = Cosmetics.plates[seat.plate];
    final namePainter = TextPainter(
      text: TextSpan(
        text: label,
        style: caption.copyWith(
          color:
              (plate == null
                      ? (seat.isViewer ? viewerColor : secondaryColor)
                      : plateTextColor(plate))
                  .withValues(alpha: opacity * joining),
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: textDirection,
      textAlign: TextAlign.center,
    )..layout(maxWidth: layout.diameter * CouncilTokens.nameWidthRatio);
    final nameOrigin = Offset(
      layout.centre.dx - namePainter.width / 2,
      layout.centre.dy + layout.diameter / 2,
    );
    if (plate != null) {
      paintCosmeticPlate(
        canvas,
        nameOrigin,
        namePainter.size,
        plate,
        opacity: opacity * joining,
      );
    }
    namePainter.paint(canvas, nameOrigin);

    // The one presence state that gets a word. Leaving is final, and a room
    // that is arguing about somebody who has gone home deserves to be told
    // once — whereas an empty ring is a thing to notice, not a thing to read.
    if (!gone || leftLabel == null) return;
    final leftPainter = TextPainter(
      text: TextSpan(
        text: leftLabel,
        style: caption.copyWith(
          color: secondaryColor.withValues(alpha: opacity * joining),
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: textDirection,
      textAlign: TextAlign.center,
    )..layout(maxWidth: layout.diameter * CouncilTokens.nameWidthRatio);
    leftPainter.paint(
      canvas,
      Offset(
        layout.centre.dx - leftPainter.width / 2,
        layout.centre.dy + layout.diameter / 2 + namePainter.height,
      ),
    );
  }

  /// Draws measured speech as expanding rings around a connected seat.
  /// [breath] is the council's one shared animation clock; the level controls
  /// how far and how brightly the waves travel.
  void _paintVoicePulse(
    Canvas canvas,
    double diameter,
    double rawLevel,
    double opacity,
  ) {
    final level = rawLevel.clamp(0.0, 1.0).toDouble();
    if (level <= CouncilTokens.voicePulseThreshold) return;
    final strength =
        ((level - CouncilTokens.voicePulseThreshold) /
                (1 - CouncilTokens.voicePulseThreshold))
            .clamp(0.0, 1.0)
            .toDouble();
    final base = diameter / 2;
    for (var wave = 0; wave < 3; wave++) {
      final progress = (breath + wave / 3) % 1.0;
      final radius =
          base +
          diameter *
              (CouncilTokens.voicePulseSpacingRatio * (wave + 1) +
                  CouncilTokens.voicePulseMaxRadiusRatio * progress * strength);
      final alpha =
          opacity *
          CouncilTokens.voicePulseAlpha *
          strength *
          (1 - progress) *
          (1 - wave * 0.18);
      if (alpha <= 0) continue;
      canvas.drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = CouncilTokens.voicePulseWidth
          ..color = gold.withValues(alpha: alpha),
      );
    }
  }

  /// A struck-through microphone, low on the ring.
  ///
  /// Drawn rather than shipped: it is four primitives at three sizes, and an
  /// asset for it would be a fourth thing to keep in step with the ring art it
  /// sits on. Called inside the seat's own transform, so it scales, tilts and
  /// dims with everything else.
  void _paintMutedMic(Canvas canvas, double diameter, double alpha) {
    final side = diameter * CouncilTokens.mutedMicRatio;
    final at = Offset(0, diameter / 2 - side * 0.7);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, side * 0.12)
      ..strokeCap = StrokeCap.round
      ..color = secondaryColor.withValues(alpha: alpha);

    // The capsule, its stand, and the bar it stands on.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: at.translate(0, -side * 0.18),
          width: side * 0.42,
          height: side * 0.62,
        ),
        Radius.circular(side * 0.21),
      ),
      stroke,
    );
    canvas.drawLine(
      at.translate(0, side * 0.16),
      at.translate(0, side * 0.42),
      stroke,
    );
    canvas.drawLine(
      at.translate(-side * 0.26, side * 0.42),
      at.translate(side * 0.26, side * 0.42),
      stroke,
    );
    // The slash. Left-to-right in both directions: it is a symbol, not text.
    canvas.drawLine(
      at.translate(-side * 0.42, -side * 0.5),
      at.translate(side * 0.42, side * 0.5),
      stroke,
    );
  }

  void _paintSpark(Canvas canvas) {
    final flight = spark;
    if (flight == null || mote == null) return;
    final from = _centreOf(flight.fromSeat);
    final to = _centreOf(flight.toSeat);
    if (from == null || to == null) return;

    final t = flight.progress.clamp(0.0, 1.0);
    final straight = Offset.lerp(from, to, t)!;
    // Lift it off the straight line, so it reads as travelling over the
    // council rather than through it.
    final lift =
        math.sin(t * math.pi) *
        (to - from).distance *
        CouncilTokens.whisperArcLift;
    final at = straight.translate(0, -lift);
    const size = CouncilTokens.moteSize;
    paintImage(
      canvas: canvas,
      rect: Rect.fromCenter(center: at, width: size, height: size),
      image: mote!,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(
        gold.withValues(alpha: math.sin(t * math.pi).clamp(0.0, 1.0)),
        BlendMode.srcIn,
      ),
      filterQuality: FilterQuality.low,
    );
  }

  Offset? _centreOf(int seat) {
    for (
      var index = 0;
      index < seats.length && index < positions.length;
      index++
    ) {
      if (seats[index].seat == seat) return positions[index].centre;
    }
    return null;
  }

  @override
  bool shouldRepaint(CouncilPainter old) =>
      !listEquals(old.seats, seats) ||
      !listEquals(old.positions, positions) ||
      old.selectedSeat != selectedSeat ||
      old.previousSelected != previousSelected ||
      old.shift != shift ||
      old.crackingSeat != crackingSeat ||
      old.crackProgress != crackProgress ||
      old.spark != spark ||
      old.spotlightOpen != spotlightOpen ||
      old.revealProgress != revealProgress ||
      old.portraitIn != portraitIn ||
      !mapEquals(old.glyphs, glyphs) ||
      !mapEquals(old.joinProgress, joinProgress) ||
      old.youLabel != youLabel ||
      old.leftLabel != leftLabel ||
      old.idle != idle ||
      old.cracked != cracked ||
      old.empty != empty ||
      old.mote != mote ||
      old.spotlightArt != spotlightArt ||
      old.breath != breath ||
      old.ringColor != ringColor ||
      old.textColor != textColor;
}
