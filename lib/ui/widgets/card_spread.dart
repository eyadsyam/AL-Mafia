import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/asset_constants.dart';
import '../../engine/models/enums.dart' show Role;
import '../../platform/reduce_motion.dart';
import '../../platform/tilt_source.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import 'ambient_motion.dart';

/// The four role cards, dealt across the home screen.
///
/// This is the home screen's background *and* its explanation of the roles:
/// tapping a card lifts it clear of the others and turns it over to show what
/// that role does. There is no separate roles reference because there does not
/// need to be one — the deck is on the table.
///
/// ## Why this is safe to show
///
/// Every leakage rule in this app is about what one player can learn about
/// *another* player. Nothing here is about anybody: the whole deck is face up,
/// before a single card has been dealt, on a screen the entire table is looking
/// at together. Showing all four is the opposite of a tell — it is the thing
/// that makes the four backs downstream mean nothing.
///
/// It uses the **gallery** copies of the paintings rather than the in-match
/// faces. Those are the same four pictures without the ±2% luminance matching
/// the night screens need, so they keep their original contrast. The matching
/// exists to stop one card lighting its holder's face more than another; here
/// there is no holder and no secret, and side by side in a lit room the gained
/// mafia card reads as washed out next to the others.
///
/// ## Motion
///
/// Four independent things, in layers:
///
/// * **the deal** — a bounded entrance, once, skippable by touching the screen;
/// * **the float** — each card rises and falls on its own slow period, with the
///   periods deliberately chosen not to divide into each other so the four
///   never fall into step;
/// * **the parallax** — the whole spread leans with the phone, each card by an
///   amount set by its depth, so the stack has a front and a back;
/// * **the flip** — one card at a time, on tap.
///
/// The float and the parallax are *ambient*: they never end, so they are gated
/// on [AmbientMotion] as well as on the OS Reduce Motion setting. The deal and
/// the flip are bounded and only respect Reduce Motion.
class CardSpread extends StatefulWidget {
  /// Where tilt comes from. Defaults to no sensor at all.
  final TiltSource tiltSource;

  /// Fired once when the entrance deal begins, for the dealing sound.
  final VoidCallback? onDealStarted;

  /// Fired every time a card turns over, in either direction.
  ///
  /// A callback rather than a direct read of the audio provider, for the same
  /// reason [onDealStarted] is one: this widget is pumped by four test entry
  /// points and none of them should have to stand up an audio stack to draw a
  /// card.
  final VoidCallback? onFlip;

  const CardSpread({
    super.key,
    this.tiltSource = const LevelTiltSource(),
    this.onDealStarted,
    this.onFlip,
  });

  @override
  State<CardSpread> createState() => _CardSpreadState();
}

/// One card's place in the spread.
///
/// All positions are fractions of the stage, so the same numbers describe a
/// small phone and a tablet. Nothing here is in logical pixels.
@immutable
class _Slot {
  /// Which painting sits in this slot.
  final Role role;

  /// Centre, as a fraction of the stage: (0,0) is the middle.
  final Offset centre;

  /// Resting rotation, radians. The brief asks for −12°..+12°.
  final double angle;

  /// 0 = furthest back, 1 = nearest. Drives parallax throw and shadow depth.
  final double depth;

  /// Seconds for one rise-and-fall. Chosen so no two divide evenly into each
  /// other; four cards on 4.0/4.7/5.3/6.0 take over two minutes to come back
  /// into anything like alignment, which is longer than anyone looks at a menu.
  final double floatPeriod;

  /// Where in its own cycle the card starts.
  final double floatPhase;

  /// Which edge it flies in from during the deal, as a unit direction.
  final Offset from;

  const _Slot({
    required this.role,
    required this.centre,
    required this.angle,
    required this.depth,
    required this.floatPeriod,
    required this.floatPhase,
    required this.from,
  });
}

const double _deg = math.pi / 180;

/// The four faces, stepping across and down in a shallow arc, each clearing
/// enough of the one behind it to show its corner letter — the letter is how a
/// player finds the card they want to tap.
///
/// **There is no fifth card here.** An earlier version dealt the card back
/// above the fan, on the argument that it is the picture the table stares at
/// for a whole match and belongs in the deck. It read as an extra card rather
/// than as the deck's lid: five objects on a screen whose whole subject is
/// that there are *four* roles, and the one nobody may tap sat highest and
/// took the eye first. The back has its own screen — every night turn opens on
/// it — and does not need a second one. The four then move up into the space
/// it left, which is the point: this screen is the four roles and nothing
/// else.
const List<_Slot> _slots = [
  _Slot(
    role: Role.mafia,
    centre: Offset(-0.40, -0.23),
    angle: -12 * _deg,
    depth: 0.35,
    floatPeriod: 5.3,
    floatPhase: 0.55,
    from: Offset(-1.8, -0.4),
  ),
  _Slot(
    role: Role.doctor,
    centre: Offset(-0.14, -0.13),
    angle: -5 * _deg,
    depth: 0.55,
    floatPeriod: 4.7,
    floatPhase: 0.85,
    from: Offset(-1.4, 1.2),
  ),
  _Slot(
    role: Role.detective,
    centre: Offset(0.14, -0.13),
    angle: 5 * _deg,
    depth: 0.75,
    floatPeriod: 4.0,
    floatPhase: 0.30,
    from: Offset(1.6, -0.8),
  ),
  _Slot(
    role: Role.citizen,
    centre: Offset(0.40, -0.23),
    angle: 12 * _deg,
    depth: 1.0,
    floatPeriod: 5.7,
    floatPhase: 0.70,
    from: Offset(1.8, 0.9),
  ),
];

class _CardSpreadState extends State<CardSpread>
    with TickerProviderStateMixin {
  /// The four faces, shuffled into the four slots for this visit.
  ///
  /// A fresh deal every time the home screen is built. The positions, angles,
  /// float periods and depths all stay exactly where they are — what changes is
  /// which painting lands in which place, which is what makes it feel like a
  /// hand being dealt rather than a fixed illustration.
  late final List<_Slot> _dealt = _shuffleFaces();

  static List<_Slot> _shuffleFaces() {
    final roles = [for (final s in _slots) s.role]..shuffle();
    return [
      for (final s in _slots)
        _Slot(
          role: roles.removeLast(),
          centre: s.centre,
          angle: s.angle,
          depth: s.depth,
          floatPeriod: s.floatPeriod,
          floatPhase: s.floatPhase,
          from: s.from,
        ),
    ];
  }

  /// The deal. One controller for all four cards; each reads its own window out
  /// of it with an [Interval], so there is no pending `Timer` to leak and a
  /// `pumpAndSettle` settles the whole cascade.
  late final AnimationController _deal;

  /// The flip of whichever card is open, 0 = face down.
  late final AnimationController _flip;
  Role? _open;

  /// Drives the idle float. A raw [Ticker] rather than a repeating controller
  /// because the periods are not commensurate — there is no single loop length
  /// to repeat over.
  late final Ticker _idle;
  final ValueNotifier<double> _seconds = ValueNotifier(0);

  Tilt _tilt = Tilt.level;
  Object? _tiltSubscription;

  bool _dealtOnce = false;

  @override
  void initState() {
    super.initState();
    _deal = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _flip = AnimationController(vsync: this, duration: Duration.zero);
    _idle = createTicker((elapsed) {
      _seconds.value = elapsed.inMicroseconds / 1e6;
    });
    _listenToTilt();
  }

  void _listenToTilt() {
    _tiltSubscription = widget.tiltSource.tilt.listen(
      (t) {
        if (mounted) setState(() => _tilt = t);
      },
      // A device with no sensor produces an empty stream and this never fires,
      // which is the whole reason the parallax degrades silently.
      onError: (Object _) {},
      cancelOnError: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = ReduceMotion.of(context);
    _flip.duration = reduceMotion ? Duration.zero : context.motion.dramatic;

    // Ambient motion: the float only.
    final ambient = !reduceMotion && AmbientMotion.of(context);
    if (ambient && !_idle.isActive) {
      _idle.start();
    } else if (!ambient && _idle.isActive) {
      _idle.stop();
    }

    if (_dealtOnce) return;
    _dealtOnce = true;
    if (reduceMotion) {
      // Reduce Motion lands on the *finished* state, never the initial one —
      // otherwise the home screen would open with every card off-screen.
      _deal.value = 1.0;
    } else {
      widget.onDealStarted?.call();
      _deal.forward();
    }
  }

  @override
  void dispose() {
    (_tiltSubscription as dynamic)?.cancel();
    _idle.dispose();
    _seconds.dispose();
    _flip.dispose();
    _deal.dispose();
    super.dispose();
  }

  /// Cuts the entrance short. The brief asks for it to be skippable, and a
  /// menu that cannot be skipped past is a menu that wastes a second of every
  /// single launch forever.
  void _skipDeal() {
    if (_deal.isAnimating) _deal.value = 1.0;
  }

  void _toggle(Role role) {
    _skipDeal();
    // Both directions: closing a card is a card turning over too, and a turn
    // that is silent on the way back sounds like the sound failed.
    widget.onFlip?.call();
    setState(() {
      if (_open == role) {
        _open = null;
        _flip.reverse();
      } else {
        _open = role;
        _flip.forward(from: 0.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The stage is the space actually given, not the device — the app runs
        // in resizable windows and split screen, and a spread laid out against
        // the physical display would fall off the edge of both.
        final stage = Size(constraints.maxWidth, constraints.maxHeight);

        // Cards are sized off the shorter edge so the spread keeps its shape
        // when the window is wide, and capped so it does not become absurd on a
        // tablet. The fraction went up when the fifth card came out: four cards
        // in the room five used to share is the visible point of removing the
        // back, and a fan that kept its old size would have read as a screen
        // with a hole in the top of it.
        final cardWidth = math.min(stage.shortestSide * 0.50, 280.0);
        final cardHeight = cardWidth * 1.5;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _skipDeal,
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final slot in _ordered())
                _SpreadCard(
                  slot: slot,
                  stage: stage,
                  cardSize: Size(cardWidth, cardHeight),
                  deal: _deal,
                  dealIndex: _dealt.indexOf(slot),
                  idleSeconds: _seconds,
                  tilt: _tilt,
                  flip: slot.role == _open ? _flip : null,
                  onTap: () => _toggle(slot.role),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Painting order, with the open card last so it sits above the rest.
  List<_Slot> _ordered() {
    if (_open == null) return _dealt;
    return [
      for (final s in _dealt)
        if (s.role != _open) s,
      _dealt.firstWhere((s) => s.role == _open),
    ];
  }
}

class _SpreadCard extends StatelessWidget {
  final _Slot slot;
  final Size stage;
  final Size cardSize;
  final Animation<double> deal;
  final int dealIndex;
  final ValueListenable<double> idleSeconds;
  final Tilt tilt;

  /// Non-null only for the one card currently open.
  final Animation<double>? flip;
  final VoidCallback? onTap;

  const _SpreadCard({
    required this.slot,
    required this.stage,
    required this.cardSize,
    required this.deal,
    required this.dealIndex,
    required this.idleSeconds,
    required this.tilt,
    required this.flip,
    required this.onTap,
  });

  /// How far a card at depth 1 slides across the full tilt range, in pixels.
  static const double _parallaxThrow = 22.0;

  /// Peak vertical travel of the idle float, in pixels.
  static const double _floatAmplitude = 7.0;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;

    // The deal, staggered. Each card gets an equal, overlapping window, so the
    // five land one after another inside the controller's 1.5s.
    final entrance = CurvedAnimation(
      parent: deal,
      curve: Interval(
        dealIndex * 0.13,
        (dealIndex * 0.13 + 0.55).clamp(0.0, 1.0),
        curve: motion.dramaticCurve,
      ),
    );

    final resting = Offset(
      stage.width * 0.5 + slot.centre.dx * stage.width * 0.5,
      stage.height * 0.5 + slot.centre.dy * stage.height * 0.5,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([entrance, idleSeconds, flip]),
      builder: (context, _) {
        final t = entrance.value;

        // Off-stage start, easing to the resting slot.
        final flyIn = Offset(
          slot.from.dx * stage.width * 0.8,
          slot.from.dy * stage.height * 0.8,
        ) * (1 - t);

        final phase = (idleSeconds.value / slot.floatPeriod) + slot.floatPhase;
        final float = Offset(0, math.sin(phase * 2 * math.pi) * _floatAmplitude);

        final parallax = Offset(
          tilt.x * _parallaxThrow * slot.depth,
          tilt.y * _parallaxThrow * slot.depth,
        );

        // The open card lifts clear of the fan. Scale rather than a real
        // z-translation: the cards are laid out in a flat `Stack`, so the only
        // depth cue available is apparent size and shadow — and both of those
        // are what "picked up off the table" actually looks like anyway.
        final lift = flip?.value ?? 0.0;

        final centre = resting + flyIn + float + parallax;

        // Cards arrive turning, and settle to their resting angle. An open card
        // also straightens as it lifts, because a card someone is reading is a
        // card they have squared up.
        final angle = slot.angle * (1 - lift * 0.7) + (1 - t) * 0.6;

        return Positioned(
          left: centre.dx - cardSize.width / 2,
          top: centre.dy - cardSize.height / 2 - lift * 18,
          width: cardSize.width,
          height: cardSize.height,
          child: Opacity(
            // Fades in over the first part of its own window rather than the
            // whole of it, so the card is solid well before it stops moving.
            opacity: (t * 2.2).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scale: 1 + lift * 0.16,
                child: GestureDetector(
                  onTap: onTap,
                  child: _Face(
                    role: slot.role,
                    flip: flip,
                    depth: slot.depth + lift,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One card: the painting, and its Arabic name and description on the back of
/// the turn.
class _Face extends StatelessWidget {
  final Role role;
  final Animation<double>? flip;
  final double depth;

  /// See the note on `cacheWidth` below.
  static const int _decodeWidth = 512;

  const _Face({required this.role, required this.flip, required this.depth});

  String _asset(Role role) => switch (role) {
        Role.mafia => AppGallery.galleryMafia,
        Role.doctor => AppGallery.galleryDoctor,
        Role.detective => AppGallery.galleryDetective,
        Role.citizen => AppGallery.galleryCitizen,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radii = context.radii;
    final shape = BorderRadius.circular(radii.card);

    final painting = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: colors.borderSubtle),
        // The ladder, not a hand-rolled shadow: one light direction for the
        // whole app (see [MafiaElevation]). A nearer card sits a level higher,
        // which is the only thing depth is allowed to change.
        boxShadow: depth > 0.6
            ? context.elevation.level3
            : context.elevation.level2,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Image.asset(
          _asset(role),
          // Same rule as everywhere else the art appears: contain, never cover.
          // These are finished paintings and the frame is part of the picture.
          fit: BoxFit.contain,
          // Not optional. The source paintings are 1024×1536 and there are four
          // of them on this screen at once; decoded at full size that is about
          // 24 MB of bitmaps, and the decode blocked the UI thread long enough
          // to drop several hundred frames on launch — the splash could not
          // even fade out, because there were no frames for it to fade in.
          //
          // 512 is comfortably above what a card ever occupies: the widest a
          // card gets is 260 logical pixels, so this still has headroom at a
          // device pixel ratio of 3 wherever the art is scaled up by tilt or
          // by a large window.
          cacheWidth: _decodeWidth,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );

    final animation = flip;
    if (animation == null) return _tappable(context, painting);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final turn = animation.value;
        final angle = turn * math.pi;
        final showingBack = turn >= 0.5;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, context.motion.perspective)
            ..rotateY(angle),
          child: showingBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _explanation(context),
                )
              : painting,
        );
      },
    );
  }

  Widget _tappable(BuildContext context, Widget child) => Semantics(
        button: true,
        label: EngineCopy.roleName(context.l10n, role),
        child: child,
      );

  /// The reverse of a card: what the role does, in one line.
  ///
  /// Built to read as the *back of a card*, not as a dialog that happens to be
  /// card-shaped. The paintings have an aged-paper border and a woven ground,
  /// so this has the same: a parchment rule inside the edge, the canvas texture
  /// underneath the type, and the role name set in the display face rather than
  /// a body style. Without them it was a black rectangle with two lines in it,
  /// which is what a placeholder looks like.
  Widget _explanation(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final shape = BorderRadius.circular(radii.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: shape,
        border: Border.all(color: colors.accentGold.withValues(alpha: 0.55)),
        boxShadow: context.elevation.level3,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              AppImages.canvasTexture,
              repeat: ImageRepeat.repeat,
              // The weave is a tile; `opacity` on the image itself rather than
              // an `Opacity` widget, so it costs no offscreen layer.
              opacity: const AlwaysStoppedAnimation<double>(0.20),
              excludeFromSemantics: true,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.lg,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    EngineCopy.roleName(context.l10n, role),
                    style:
                        type.headline.emphasised.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.sm),
                  // The same hairline rule the home wordmark uses, so the card
                  // back and the title are visibly from one press.
                  SizedBox(
                    width: spacing.xxl,
                    child: Divider(
                      color: colors.accentGold.withValues(alpha: 0.7),
                      height: spacing.sm,
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Flexible(
                    child: Text(
                      EngineCopy.roleDescription(context.l10n, role),
                      style: type.body.copyWith(color: colors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
