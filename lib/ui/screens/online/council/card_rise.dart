import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/asset_constants.dart';
// `Alignment` here is the engine's win side, not Flutter's layout anchor, and
// this file centres a card — so the layout one keeps the name.
import '../../../../engine/models/enums.dart' hide Alignment;
import '../../../../platform/reduce_motion.dart';
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';

/// The card art for a role, at the one size doc 15 lets a card be drawn.
///
/// This is the same file [RoleCard] uses, and deliberately so: there is exactly
/// one painted face per role in this app, it is luminance-matched against the
/// other three, and a second set would be a second thing to keep matched.
String faceFor(Role role) => switch (role) {
  Role.mafia => AppImages.cardFaceMafia,
  Role.doctor => AppImages.cardFaceDoctor,
  Role.detective => AppImages.cardFaceDetective,
  Role.citizen => AppImages.cardFaceCitizen,
};

/// Doc 15 §S-O12: the eliminated player's card rises, holds, and flips.
///
/// ## Why the card comes back at all
///
/// Doc 15 §1.3 stopped drawing the card at seat size — *"the ornate engraving
/// is beautiful at 300dp and mud at 60dp"* — and the council is rings and
/// initials because of it. This is the other half of that decision: the art
/// still exists, and the two moments it is legible are the two moments it is
/// the whole point. A card at 280dp in the middle of the screen is the reason
/// the seats do not need to be cards.
///
/// ## The beats, and what Reduce Motion keeps
///
///     Beat 2  rise to 280dp                m-rise, easeOutBack
///     Beat 3  0.8s hold                    (pacing)
///     Beat 4  flip, role revealed          m-card
///     Beat 5  shrink back                  m-rise
///
/// Under Reduce Motion the card cross-fades in already face-up and the holds
/// are kept at full length. Doc 15 §3: *"Dramatic holds remain — they are
/// pacing, not motion."* A reveal that is over before the room has looked up
/// is not an accessibility win.
class CardRise extends StatefulWidget {
  /// The role the card turns over to show.
  final Role role;

  /// Whose card it is. Drawn under the art, so the room is never left matching
  /// a face to a seat from memory.
  final String name;

  /// Called once the whole sequence has played.
  final VoidCallback? onFinished;

  /// Whether the card shrinks away at the end (an elimination) or stays up (a
  /// result, where the match is over and there is nothing to go back to).
  final bool shrinkBack;

  const CardRise({
    super.key,
    required this.role,
    required this.name,
    this.onFinished,
    this.shrinkBack = true,
  });

  static const Key card = ValueKey('council_card_rise');

  /// Doc 15 §5: *"card art never renders below 200dp."*
  static const double minimumArt = 200;

  @override
  State<CardRise> createState() => _CardRiseState();
}

class _CardRiseState extends State<CardRise> with SingleTickerProviderStateMixin {
  late final AnimationController _beats = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  /// Where each beat starts and ends inside the run, as fractions.
  late double _riseEnd;
  late double _flipStart;
  late double _flipEnd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_beats.duration != Duration.zero) return;

    final motion = context.motion;
    final rise = motion.rise;
    final hold = motion.phase;
    final flip = motion.card;
    final shrink = widget.shrinkBack ? motion.rise : Duration.zero;
    final total = rise + hold + flip + shrink;

    double at(Duration d) => d.inMicroseconds / total.inMicroseconds;
    _riseEnd = at(rise);
    _flipStart = at(rise + hold);
    _flipEnd = at(rise + hold + flip);

    _beats.duration = total;
    _beats.forward().whenComplete(() {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _beats.dispose();
    super.dispose();
  }

  double _phase(double from, double to) {
    if (_beats.value <= from) return 0;
    if (_beats.value >= to) return 1;
    return (_beats.value - from) / (to - from);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final motion = context.motion;
    final still = ReduceMotion.of(context);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _beats,
        builder: (context, _) {
          final rising = motion.riseCurve.transform(_phase(0, _riseEnd));
          final flipping = motion.standardCurve.transform(
            _phase(_flipStart, _flipEnd),
          );
          final leaving = widget.shrinkBack
              ? motion.standardCurve.transform(_phase(_flipEnd, 1))
              : 0.0;

          // Cross-fade rather than transform, and face-up from the first
          // frame — there is no rotation to read and no scale to track.
          final scale = still ? 1.0 : (0.2 + 0.8 * rising) * (1 - 0.8 * leaving);
          final faceUp = still ? true : flipping >= 0.5;
          final turn = still ? 0.0 : flipping * math.pi;
          final opacity = still
              ? math.min(rising, 1 - leaving)
              : (1 - leaving);

          return ColoredBox(
            color: colors.surfaceBase.withValues(alpha: 0.86 * (1 - leaving)),
            child: Center(
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, motion.perspective)
                    ..rotateY(turn)
                    ..scaleByDouble(scale, scale, 1, 1),
                  child: _Face(
                    role: widget.role,
                    name: widget.name,
                    faceUp: faceUp,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One side of the card, at [CouncilTokens.cardRiseSize].
class _Face extends StatelessWidget {
  final Role role;
  final String name;
  final bool faceUp;

  const _Face({required this.role, required this.name, required this.faceUp});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;

    return Transform(
      // The face is drawn during the *second* half of the turn, by which point
      // the parent has rotated past 90° and everything inside it is mirrored.
      // Countering by another half-turn is what makes the art come up the
      // right way round rather than as its own reflection.
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(faceUp ? math.pi : 0),
      child: Column(
        key: CardRise.card,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(radii.card),
            child: Image.asset(
              faceUp ? faceFor(role) : AppImages.cardBack,
              width: CouncilTokens.cardRiseSize,
              height: CouncilTokens.cardRiseSize,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            name,
            textAlign: TextAlign.center,
            style: type.title.copyWith(color: colors.textPrimary),
          ),
          if (faceUp) ...[
            SizedBox(height: spacing.xs),
            Text(
              EngineCopy.roleName(context.l10n, role),
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.accentGold),
            ),
          ],
        ],
      ),
    );
  }
}
