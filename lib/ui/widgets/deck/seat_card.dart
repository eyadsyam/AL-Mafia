import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../economy/cosmetics.dart';
import '../../economy/pass_table_dress.dart';
import '../../../engine/models/player.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';

/// The Mafia card's frame, drawn once and only here: a lit centre falling to
/// dark, a bone-grey rim and an inner hairline. When the game gets its own
/// player-card frame art, this is the one widget that changes.
///
/// Public screens only (the setup flow). It carries no role information.
class SeatCardFrame extends StatelessWidget {
  final Widget child;

  /// Lifted under a finger: a deeper shadow.
  final bool lifted;

  /// The host's equipped frame (bought in the store), worn as a coloured rim
  /// and glow on the host's own seat. Null for everyone else.
  final FrameStyle? dress;

  const SeatCardFrame({
    super.key,
    required this.child,
    this.lifted = false,
    this.dress,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeatTokens.radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: dress == null
            ? null
            : Border.all(color: dress!.outer, width: SeatTokens.dressRim),
        boxShadow: [
          if (dress != null)
            BoxShadow(
              color: dress!.inner.withValues(alpha: SeatTokens.dressGlowAlpha),
              blurRadius: SeatTokens.dressGlow,
            ),
          BoxShadow(
            color: DeckTokens.ground.withValues(alpha: SeatTokens.shadowAlpha),
            blurRadius: lifted
                ? SeatTokens.liftShadowBlur
                : SeatTokens.shadowBlur,
            offset: const Offset(0, SeatTokens.shadowDrop),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.1,
              colors: [SeatTokens.frameLit, SeatTokens.frameDark],
              stops: [0, 0.7],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// One player as a small Mafia card: the hooded portrait, the name on a plate,
/// the seat number, and a corner control (remove, or away for tonight).
class SeatCard extends StatelessWidget {
  final String name;

  /// 1-based seat.
  final int seat;
  final PlayerGender gender;

  /// Replaces the stock hooded portrait once a bigger art set exists.
  final String? avatarAsset;
  final bool lifted;

  /// The seat number in the corner; off where the card is a person, not a
  /// chair (first run).
  final bool showSeat;

  /// Away tonight: dimmed, still on the table.
  final bool away;
  final Key? cornerKey;
  final VoidCallback? onCorner;
  final String cornerLabel;
  final IconData cornerIcon;

  const SeatCard({
    super.key,
    required this.name,
    required this.seat,
    required this.gender,
    this.avatarAsset,
    this.lifted = false,
    this.showSeat = true,
    this.away = false,
    this.cornerKey,
    this.onCorner,
    this.cornerLabel = '',
    this.cornerIcon = Icons.close,
  });

  /// The portrait for a gender: the Mafia game's own hooded figures.
  static String defaultAvatar(PlayerGender gender) =>
      gender == PlayerGender.female
      ? AppCouncilArt.avatarFemale
      : AppCouncilArt.avatarMale;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final meta = DeckTokens.meta(type);
    return Semantics(
      label: showSeat ? '$name, $seat' : name,
      container: true,
      child: SeatCardFrame(
        lifted: lifted,
        dress: Cosmetics.frames[HostIdentityScope.frameFor(context, name)],
        child: LayoutBuilder(
          builder: (context, box) {
            final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
            final side = (box.maxHeight * SeatTokens.avatarHeight * dpr)
                .round();
            return Opacity(
              opacity: away ? SeatTokens.awayAlpha : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: box.maxHeight * SeatTokens.avatarBottom,
                    height: box.maxHeight * SeatTokens.avatarHeight,
                    child: Image(
                      image: ResizeImage(
                        AssetImage(avatarAsset ?? defaultAvatar(gender)),
                        height: side,
                        policy: ResizeImagePolicy.fit,
                      ),
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      gaplessPlayback: true,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Image(
                        image: ResizeImage(
                          const AssetImage(AppOffline.frameCard),
                          width: (box.maxWidth * dpr).round(),
                          policy: ResizeImagePolicy.fit,
                        ),
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                  if (showSeat)
                  PositionedDirectional(
                    start: SeatTokens.plateInset + SeatTokens.inset,
                    top: SeatTokens.plateInset + 1,
                    child: _Badge(
                      child: Text(
                        '$seat',
                        style: meta.copyWith(
                          color: DeckTokens.bone,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: SeatTokens.plateInset,
                    right: SeatTokens.plateInset,
                    bottom: SeatTokens.plateInset,
                    height: SeatTokens.plateHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: DeckTokens.ground.withValues(
                          alpha: SeatTokens.plateAlpha,
                        ),
                        borderRadius: BorderRadius.circular(
                          SeatTokens.insetRadius,
                        ),
                        border: Border.all(
                          color: DeckTokens.bone.withValues(
                            alpha: SeatTokens.hairlineAlpha,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.spacing.xs,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              name,
                              maxLines: 1,
                              style: meta.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (onCorner != null)
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: Semantics(
                        button: true,
                        label: cornerLabel,
                        child: GestureDetector(
                          key: cornerKey,
                          behavior: HitTestBehavior.opaque,
                          onTap: onCorner,
                          child: SizedBox(
                            width: SeatTokens.corner,
                            height: SeatTokens.corner,
                            child: Align(
                              alignment: AlignmentDirectional.topEnd,
                              child: Padding(
                                padding: EdgeInsets.all(
                                  context.spacing.sm + context.spacing.xs,
                                ),
                                child: _Badge(
                                  child: Icon(
                                    cornerIcon,
                                    size: SeatTokens.cornerGlyph,
                                    color: DeckTokens.bone,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The next seat, waiting: a dashed, dim card that says what is missing.
class EmptySeatCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const EmptySeatCard({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, box) {
            final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: SeatTokens.emptyArtAlpha,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(SeatTokens.radius),
                    child: Image(
                      image: ResizeImage(
                        const AssetImage(AppOffline.cardSeatEmpty),
                        width: (box.maxWidth * dpr).round(),
                        policy: ResizeImagePolicy.fit,
                      ),
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Positioned(
                  left: SeatTokens.plateInset,
                  right: SeatTokens.plateInset,
                  bottom: SeatTokens.plateInset,
                  height: SeatTokens.plateHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DeckTokens.ground.withValues(
                        alpha: SeatTokens.plateAlpha,
                      ),
                      borderRadius: BorderRadius.circular(
                        SeatTokens.insetRadius,
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.spacing.xs,
                          ),
                          child: Text(
                            label,
                            maxLines: 1,
                            style: DeckTokens.meta(
                              context.typography,
                            ).copyWith(color: DeckTokens.muted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A small dark disc that keeps the seat number and the corner control
/// readable over the card frame's bone border.
class _Badge extends StatelessWidget {
  final Widget child;

  const _Badge({required this.child});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: SeatTokens.badge,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: DeckTokens.ground.withValues(alpha: SeatTokens.badgeAlpha),
      ),
      child: Center(child: child),
    ),
  );
}
