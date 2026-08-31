import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/asset_constants.dart';
import '../../engine/models/enums.dart' show Role;
import '../../platform/reduce_motion.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'hold_pad.dart';

/// The role card used during distribution — now a 3-step reveal:
///
/// 1. **Identity confirmation** — player name + hold button with ring.
/// 2. **Swipe to flip** — card back appears; a swipe in any direction turns
///    it, about Y for a sideways one and about X for an up-or-down one.
/// 3. **Auto-conceal** — card stays visible for 5s, auto-flips back,
///    re-reveal available, then pass button.
///
/// ## Why this is one widget and not four
///
/// The back face, the card's bounds and the pass control sit at identical
/// coordinates for every role, and the auto-conceal timer is the same for
/// everyone ([MafiaTiming.autoRevealDuration]). A player who draws Mafia
/// therefore takes exactly as long, and leaves exactly the same visual trace,
/// as a player who draws Citizen (L-04, L-08).
///
/// Role changes only two *textures*: the card face image and the text below
/// the card. It never changes the tree, the bounds, or a duration.
///
/// ## Card art is sacred
///
/// The four card images in `raw_assets/` are finished artwork. They are
/// displayed full-bleed with no cropping, no tinting, no overlay. The painted
/// border, corner letter (M/DR/D/C), and corner icon are part of the art.
/// The Arabic role name and description appear as Flutter text *below* the card,
/// not on top of it.
class RoleCard extends StatefulWidget {
  final String playerName;
  final Role role;

  /// Other Mafia members. Empty for every other role — but the slot that would
  /// hold them is laid out regardless, at the same height.
  final List<String> teammateNames;

  final VoidCallback onDismissed;

  /// Fired every time the card turns, in either direction — the swipe that
  /// opens it, the automatic conceal five seconds later, and every re-reveal
  /// after that.
  ///
  /// A callback rather than a read of the audio provider, and that is not only
  /// about testing. `audio_gate_test.dart` asserts that this file does not so
  /// much as *mention* the audio layer — an in-hand surface that cannot reach
  /// it cannot trip its gate — so the wiring lives in the screen above:
  /// `role_reveal_screen.dart` hands in `playCardTurn`, the one sound in the
  /// app allowed to happen while somebody is holding the phone. The argument
  /// for that exception is on the method itself, in
  /// `lib/platform/audio_director.dart`.
  ///
  /// It fires for all four roles at exactly the same three moments, which is
  /// what keeps it out of the leakage tests' way.
  final VoidCallback? onFlip;

  /// How long the identity pad must be held, from `MatchSettings`.
  ///
  /// Passed in rather than read from the theme because it is a *host* decision,
  /// not a design token: a table of fifteen cannot afford what a table of six
  /// can. Whatever it is set to, it is the same for every player in the match,
  /// which is what makes turn length say nothing about a role (L-08).
  ///
  /// Null falls back to the [MafiaTiming] token, which is what the golden tests
  /// and the widget catalogue use.
  final Duration? identityHold;

  const RoleCard({
    super.key,
    required this.playerName,
    required this.role,
    required this.teammateNames,
    required this.onDismissed,
    this.onFlip,
    this.identityHold,
  });

  static const Key holdPad = ValueKey('role_card_hold_pad');
  static const Key dismiss = ValueKey('role_card_dismiss');
  static const Key slotTeammates = ValueKey('role_card_teammates');
  static const Key slotCard = ValueKey('role_card_face');
  static const Key progressLine = ValueKey('role_card_progress');

  /// The strip under the card that holds the swipe hint or the pass button.
  ///
  /// Keyed because it is the one part of the tree whose *contents* change
  /// between phases. Its bounds must not, or the moment a player's card
  /// unlocked would be readable from across the table as a shift in the layout
  /// — so the golden suite measures this rather than the button inside it,
  /// which legitimately does not exist yet during the reveal.
  static const Key slotBottom = ValueKey('role_card_bottom');

  @override
  State<RoleCard> createState() => _RoleCardState();
}

/// The three phases of the reveal flow. Every player walks through them
/// identically — no phase is skipped or shortened for any role.
enum _RevealPhase {
  /// Player sees their name and holds to confirm identity.
  identityGate,

  /// Card back is shown. Player swipes in any direction to flip.
  cardBack,

  /// Card face is visible. Auto-conceals after the timer.
  cardRevealed,

  /// Card has auto-concealed back to the back face. Player may re-reveal
  /// or pass the phone.
  concealed,
}

class _RoleCardState extends State<RoleCard> with TickerProviderStateMixin {
  _RevealPhase _phase = _RevealPhase.identityGate;

  // -- Flip animation --
  late final AnimationController _flip;

  /// The flip's *eased* progress, 0 = face-down, 1 = face-up.
  ///
  /// Shared between the card and the text beneath it so the two cannot disagree
  /// about when the reveal happens. Built once and mutated, rather than
  /// constructed in `build`: a `CurvedAnimation` created per frame subscribes to
  /// its parent and is never disposed.
  late final CurvedAnimation _flipCurve;

  // -- Swipe tracking --
  //
  // The swipe is read in two dimensions and the card turns the way it was
  // pushed. [_drag] is the raw travel since the finger went down; [_axis] and
  // [_sign] are resolved from it at the end of the gesture and then held, so
  // the animated part of the flip continues in the direction the hand started
  // and the automatic conceal five seconds later reverses along the same line.
  Offset _drag = Offset.zero;
  Axis _axis = Axis.horizontal;
  double _sign = 1.0;
  bool _swiping = false;

  /// Which way the *live* drag is turning the card, before the gesture ends.
  ///
  /// Resolved on every update rather than latched at drag start: a finger that
  /// sets off sideways and commits upward should have the card follow it, and
  /// at the moment of touch-down there is no direction to latch yet.
  (Axis, double) get _liveDirection {
    final horizontal = _drag.dx.abs() >= _drag.dy.abs();
    final travel = horizontal ? _drag.dx : _drag.dy;
    return (
      horizontal ? Axis.horizontal : Axis.vertical,
      travel < 0 ? -1.0 : 1.0,
    );
  }

  // -- Auto-conceal timer --
  Timer? _concealTimer;
  late final AnimationController _concealProgress;

  // -- Turn-end state --
  //
  // Set when the card conceals itself for the first time. Not a clock: see
  // [_autoFlipBack].
  bool _passUnlocked = false;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(vsync: this, duration: Duration.zero);
    _flipCurve = CurvedAnimation(parent: _flip, curve: Curves.linear);
    _concealProgress = AnimationController(vsync: this, duration: Duration.zero);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = ReduceMotion.of(context);
    _flip.duration = reduceMotion ? Duration.zero : context.motion.dramatic;
    _flipCurve.curve = context.motion.dramaticCurve;
    _concealProgress.duration = context.timing.autoRevealDuration;
  }

  @override
  void dispose() {
    _concealTimer?.cancel();
    _flipCurve.dispose();
    _flip.dispose();
    _concealProgress.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Phase transitions
  // ---------------------------------------------------------------------------

  /// Identity confirmed — show the card back.
  void _onIdentityConfirmed() {
    setState(() => _phase = _RevealPhase.cardBack);
  }

  /// Swipe completed — flip the card and start the auto-conceal timer.
  void _doFlip() {
    if (_phase != _RevealPhase.cardBack && _phase != _RevealPhase.concealed) {
      return;
    }
    widget.onFlip?.call();
    setState(() {
      _phase = _RevealPhase.cardRevealed;
      _drag = Offset.zero;
      _swiping = false;
    });
    _flip.forward();
    _startConcealTimer();
  }

  /// Start the 5-second auto-conceal countdown.
  void _startConcealTimer() {
    _concealTimer?.cancel();
    _concealProgress.forward(from: 0.0);
    _concealTimer = Timer(context.timing.autoRevealDuration, () {
      if (!mounted) return;
      _autoFlipBack();
    });
  }

  /// Auto-conceal: flip back to the card back, and open the pass control.
  ///
  /// ## Why the pass unlocks here and not on a clock
  ///
  /// It used to unlock on `timing.turnFloor` (12s), measured from identity
  /// confirmation. That is the right rule for a *night* turn, where a player
  /// takes an action whose length would otherwise say something about which
  /// action it was. It is the wrong rule here, and it produced the worst bug in
  /// the flow: the card conceals itself after five seconds, so for the next
  /// seven the screen showed a face-down card, no pass button, and a hint
  /// reading "swipe to flip" — the only affordance on screen. Players did the
  /// only thing offered and saw their card a second time, then a third, until
  /// the clock happened to run out. It read as the app being stuck.
  ///
  /// Turn length is still role-independent, and now by construction rather than
  /// by a timer: identity hold (fixed) + the player's own swipe + one 5s window.
  /// None of those terms depends on what was drawn. A player who chooses to look
  /// again extends their own turn, which is a choice, not a tell.
  void _autoFlipBack() {
    _concealTimer?.cancel();
    _concealProgress.stop();
    widget.onFlip?.call();
    setState(() {
      _phase = _RevealPhase.concealed;
      _passUnlocked = true;
    });
    _flip.reverse();
  }

  // ---------------------------------------------------------------------------
  // Swipe gesture handling
  // ---------------------------------------------------------------------------

  /// The fraction of the card's own size along the swiped axis that must be
  /// travelled to trigger the flip.
  static const _swipeThresholdFraction = 0.3;

  /// Minimum velocity (logical pixels/s) that triggers the flip regardless of
  /// distance, so a fast flick also works.
  static const _swipeVelocityThreshold = 300.0;

  /// Any direction, and the card turns the way it was pushed.
  ///
  /// # Why this is a pan and not two drags
  ///
  /// It used to be `onHorizontalDrag*` with the offset clamped to positive:
  /// one gesture, rightwards, and the hint under the card said so. That is a
  /// rule to remember at the exact moment nobody wants to remember one — the
  /// phone has just been handed over, everyone is watching, and the natural
  /// motion is whatever the thumb happens to be resting on. A leftward swipe
  /// simply did nothing, which reads as the app being stuck rather than as the
  /// player having guessed wrong.
  ///
  /// So the gesture is a pan, both axes are live, and the *dominant* axis of
  /// the travel picks the rotation axis while its sign picks the direction. A
  /// swipe left turns the card left; a swipe up tips it away from you. The
  /// threshold is measured along whichever axis won, against that side of the
  /// card, so an upward swipe on a tall card is not held to the same number of
  /// pixels as a sideways one.
  ///
  /// # Why this is still leak-safe
  ///
  /// The direction is chosen by the player, and chosen *before* they have seen
  /// anything — the flip is what shows them the card. There is no branch on
  /// role anywhere in it: same thresholds, same durations, same geometry for
  /// all four. What a bystander could learn from watching the direction is
  /// which way somebody's thumb was pointing.
  void _onPanStart(DragStartDetails _) {
    if (_phase != _RevealPhase.cardBack && _phase != _RevealPhase.concealed) {
      return;
    }
    _swiping = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_swiping) return;
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_swiping) return;

    final (axis, sign) = _liveDirection;
    final bounds = context.findRenderObject()?.paintBounds;
    final extent = axis == Axis.horizontal
        ? (bounds?.width ?? 300)
        : (bounds?.height ?? 450);

    final travel = axis == Axis.horizontal ? _drag.dx : _drag.dy;
    final velocity = axis == Axis.horizontal
        ? details.velocity.pixelsPerSecond.dx
        : details.velocity.pixelsPerSecond.dy;

    // Both tests are on the magnitude: the sign has already been taken out and
    // put into `sign`, and a flick leftwards is exactly as much a flick as one
    // to the right.
    if (travel.abs() > extent * _swipeThresholdFraction ||
        velocity.abs() > _swipeVelocityThreshold) {
      _axis = axis;
      _sign = sign;
      _doFlip();
    } else {
      setState(() {
        _drag = Offset.zero;
        _swiping = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Data lookups
  // ---------------------------------------------------------------------------

  String _title(BuildContext context) =>
      EngineCopy.roleName(context.l10n, widget.role);

  String _description(BuildContext context) =>
      EngineCopy.roleDescription(context.l10n, widget.role);

  /// The role's own painted face.
  ///
  /// This is the one genuinely role-conditional *image* in the in-hand app.
  /// Nothing else here may branch on role: same frame, same border, same
  /// durations, same text position.
  String get _face {
    switch (widget.role) {
      case Role.mafia:
        return AppImages.cardFaceMafia;
      case Role.doctor:
        return AppImages.cardFaceDoctor;
      case Role.detective:
        return AppImages.cardFaceDetective;
      case Role.citizen:
        return AppImages.cardFaceCitizen;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return ColoredBox(
      color: colors.surfaceBase,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.screenMargin,
                vertical: spacing.lg,
              ),
              child: _phase == _RevealPhase.identityGate
                  ? _buildIdentityGate(context)
                  : _buildCardFlow(context),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Identity Gate
  // ---------------------------------------------------------------------------

  Widget _buildIdentityGate(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.playerName,
          style: type.display.emphasised.copyWith(color: colors.textPrimary),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: spacing.xxl),
        KeyedSubtree(
          key: RoleCard.holdPad,
          child: HoldPad(
            holdDuration: widget.identityHold ?? context.timing.holdToReveal,
            instruction: context.l10n.holdToConfirmIdentity,
            diameter: spacing.xxl * 3,
            onHoldComplete: _onIdentityConfirmed,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Steps 2 & 3: Card Back / Revealed / Concealed
  // ---------------------------------------------------------------------------

  Widget _buildCardFlow(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Player name header — same height always.
        SizedBox(
          height: spacing.xxl,
          child: Center(
            child: Text(
              widget.playerName,
              style: type.headline.emphasised.copyWith(color: colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(height: spacing.sm),

        // The card — full-bleed image, no overlay.
        Expanded(
          child: KeyedSubtree(
            key: RoleCard.slotCard,
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: _SwipeFlipCard(
                flipProgress: _flipCurve,
                // Mid-gesture the card follows the finger; once the gesture has
                // committed, the resolved axis and sign are what the animation
                // continues along.
                drag: _swiping ? _drag : Offset.zero,
                axis: _swiping ? _liveDirection.$1 : _axis,
                sign: _swiping ? _liveDirection.$2 : _sign,
                radius: radii.card,
                elevation: context.elevation,
                perspective: context.motion.perspective,
                back: _CardSurface(
                  image: AppImages.cardBack,
                  radius: radii.card,
                  border: colors.borderSubtle,
                ),
                front: _CardSurface(
                  image: _face,
                  radius: radii.card,
                  border: colors.borderSubtle,
                ),
              ),
            ),
          ),
        ),

        // Auto-conceal progress line (visible only when face-up).
        SizedBox(height: spacing.sm),
        KeyedSubtree(
          key: RoleCard.progressLine,
          child: SizedBox(
            height: 2,
            child: _phase == _RevealPhase.cardRevealed
                ? AnimatedBuilder(
                    animation: _concealProgress,
                    builder: (context, _) => LinearProgressIndicator(
                      value: _concealProgress.value,
                      backgroundColor: colors.surfaceOverlay,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.textSecondary,
                      ),
                      minHeight: 2,
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
        SizedBox(height: spacing.sm),

        // Everything the card *says*, as opposed to what it shows: the role
        // name, its one-line description, and the mafia teammate list.
        //
        // Gated on the flip's own geometry rather than on the phase. Phase
        // changes the instant the swipe completes, so an opacity driven by it
        // put the role name on screen in legible type while the card was still
        // turning — the leak the five-stage golden caught. Sharing
        // [_flipCurve] with the card means the words and the painting cross the
        // halfway point on the same frame, for every role, by construction.
        _RevealedText(
          flip: _flipCurve,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Role name — bone white, display font, centred. Identical
              // position, size, weight and colour for all four roles; only the
              // string differs, and it comes from the ARB.
              // Tall enough for one line of the display cut at its real
              // leading: 44 × 1.6 is 70.4, and this box was `xxl` (48), which
              // sliced the bottom off every role name — "دكتور" lost its
              // descender. Arabic needs the room; the box has to be told.
              SizedBox(
                height: spacing.xxl + spacing.lg,
                child: Center(
                  child: Text(
                    _title(context),
                    style: type.display.emphasised.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // The description, whole. Fixed height, so a wordier role cannot
              // make its card taller (L-02) — but three lines rather than one,
              // because at one line every role but the citizen was cut off
              // mid-sentence with an ellipsis. The longest of the four (the
              // detective's, 72 characters) wraps to two.
              //
              // Deliberately *not* a `FittedBox`: scaling the text down to fit
              // would give each role a different type size, and a glance at
              // someone's screen from across the table would tell you how long
              // their role's description is. Wrapping inside a box that is the
              // same height for everyone leaks nothing.
              SizedBox(
                height: spacing.xxl + spacing.lg,
                child: Center(
                  child: Text(
                    _description(context),
                    style: type.bodySmall.copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(height: spacing.sm),

              // Reserved teammates slot: same height for everyone (L-02).
              KeyedSubtree(
                key: RoleCard.slotTeammates,
                child: SizedBox(
                  height: spacing.xxl,
                  child: Center(
                    child: Text(
                      widget.teammateNames.isEmpty
                          ? ''
                          : context.l10n.teammatesLine(
                              widget.teammateNames
                                  .join(context.l10n.listSeparator),
                            ),
                      style: type.bodySmall.emphasised
                          .copyWith(color: colors.textPrimary),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom control: swipe hint, or pass button.
        KeyedSubtree(
          key: RoleCard.slotBottom,
          child: SizedBox(
            height: spacing.xxl + spacing.sm,
            child: _bottomControl(context),
          ),
        ),
      ],
    );
  }

  Widget _bottomControl(BuildContext context) {
    final colors = context.colors;
    final radii = context.radii;
    final type = context.typography;

    switch (_phase) {
      case _RevealPhase.identityGate:
        return const SizedBox.shrink();

      case _RevealPhase.cardBack:
        // Swipe hint.
        return Center(
          child: Text(
            context.l10n.swipeToReveal,
            style: type.bodySmall.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        );

      case _RevealPhase.cardRevealed:
        // While face is showing, show nothing — the progress line is visible.
        return const SizedBox.shrink();

      case _RevealPhase.concealed:
        // Pass button (or swipe-to-re-reveal hint if turn floor not met).
        if (_passUnlocked) {
          return FilledButton(
            key: RoleCard.dismiss,
            onPressed: widget.onDismissed,
            style: FilledButton.styleFrom(
              backgroundColor: colors.accentGold,
              foregroundColor: colors.surfaceBase,
              disabledBackgroundColor: colors.surfaceOverlay,
              disabledForegroundColor: colors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radii.button),
              ),
            ),
            child: Text(context.l10n.passThePhone, style: type.title),
          );
        }
        return Center(
          child: Text(
            context.l10n.swipeToReveal,
            style: type.bodySmall.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        );
    }
  }
}

/// Shows its child only once the card has turned past edge-on.
///
/// The threshold is the *same* half-turn the card itself uses to swap faces, so
/// the text under the card and the painting on it become visible on one frame
/// rather than two. There is no fade: a fade would put the role name on screen
/// at partial opacity while the card was still side-on to the table, which is
/// legible from a metre away and is precisely what this exists to prevent.
///
/// Laid out at full size in every state, so nothing moves when it appears.
class _RevealedText extends StatelessWidget {
  final Animation<double> flip;
  final Widget child;

  const _RevealedText({required this.flip, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flip,
      // `child` is built once and reused across every frame of the flip; only
      // the visibility wrapper rebuilds.
      child: child,
      builder: (context, child) => Visibility(
        visible: flip.value >= 0.5,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: child!,
      ),
    );
  }
}

/// One painted card face: artwork, border. No child overlay — the art is sacred.
class _CardSurface extends StatelessWidget {
  final String image;
  final double radius;
  final Color border;

  const _CardSurface({
    required this.image,
    required this.radius,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Image.asset(
          image,
          // BoxFit.contain ensures the entire card image is visible — painted
          // border, corner letter, corner icon. Nothing is cropped.
          fit: BoxFit.contain,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

/// The 3D flip with swipe-to-reveal physics.
///
/// Supports two modes of input:
/// - **Animated flip** via [flipProgress] (forward = reveal, reverse = conceal)
/// - **Live drag** via [drag] for the physical swipe-follow feel
///
/// [axis] and [sign] say which way the card is turning: about Y for a sideways
/// swipe, about X for an up-or-down one, in the direction the hand went. The
/// mirror applied to the front face turns about the same axis, because a face
/// mirrored across the wrong one arrives upside down.
///
/// Both faces are built for every role at every moment, and the swap happens at
/// the halfway point by geometry alone — no role-dependent branch anywhere.
class _SwipeFlipCard extends StatelessWidget {
  /// The eased flip progress, owned by the parent so the text beneath the card
  /// can share it. 0 = face-down, 1 = face-up.
  final Animation<double> flipProgress;

  /// Travel since the finger went down, or [Offset.zero] when nothing is being
  /// dragged.
  final Offset drag;

  /// The rotation axis: horizontal swipe turns about Y, vertical about X.
  final Axis axis;

  /// +1 or −1, following the direction of the swipe.
  final double sign;
  final Widget front;
  final Widget back;
  final double radius;
  /// The app's shadow ladder. Passed in rather than read from context so the
  /// builder below stays a pure function of its inputs.
  final MafiaElevation elevation;
  final double perspective;

  const _SwipeFlipCard({
    required this.flipProgress,
    required this.drag,
    required this.axis,
    required this.sign,
    required this.front,
    required this.back,
    required this.radius,
    required this.elevation,
    required this.perspective,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flipProgress,
      builder: (context, _) {
        // Combine the animated flip progress with the drag preview.
        // During a drag, the card tilts slightly to follow the finger.
        final animT = flipProgress.value;
        final travel = axis == Axis.horizontal ? drag.dx : drag.dy;
        final dragAngle =
            (travel.abs() / 300.0).clamp(0.0, 0.3) * math.pi;

        // Magnitude first, sign last: the half-turn test below is about how far
        // the card has turned, not about which way, and a signed angle would
        // make the front face appear on one side and not the other.
        final turn = animT * math.pi + dragAngle;
        final showingFront = turn >= math.pi * 0.5 && turn < math.pi * 1.5;
        final angle = turn * sign;

        final transform = Matrix4.identity()
          ..setEntry(3, 2, perspective);
        if (axis == Axis.horizontal) {
          transform.rotateY(angle);
        } else {
          transform.rotateX(angle);
        }

        final mirror = Matrix4.identity();
        if (axis == Axis.horizontal) {
          mirror.rotateY(math.pi);
        } else {
          mirror.rotateX(math.pi);
        }

        final face = showingFront
            ? Transform(
                alignment: Alignment.center,
                transform: mirror,
                child: front,
              )
            : back;

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              // The card lifts off the table as it turns and settles back.
              // Interpolated between two rungs of the shared ladder rather than
              // hand-rolled, so it grows in *size* only — the light direction
              // is the app's one lamp at every point of the flip. This used to
              // cast straight down while everything else cast down-right.
              boxShadow: BoxShadow.lerpList(
                elevation.level2,
                elevation.level3,
                math.sin(animT * math.pi),
              ),
            ),
            child: face,
          ),
        );
      },
    );
  }
}
