import 'package:flutter/material.dart';
import '../../../app/asset_constants.dart';
import '../../../platform/reduce_motion.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';

/// A public doorway flourish, never shown on a private role surface.
class OnlineWelcomeArt extends StatelessWidget {
  const OnlineWelcomeArt({super.key});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).height <
        CouncilTokens.welcomeArtMinViewport) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: CouncilTokens.welcomeArtHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.radii.card),
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: ReduceMotion.of(context)
                    ? 1
                    : CouncilTokens.welcomeArtStartScale,
                end: 1,
              ),
              duration: ReduceMotion.of(context)
                  ? Duration.zero
                  : context.motion.phase,
              curve: Curves.easeOut,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: RepaintBoundary(
                child: Image.asset(
                  AppCouncilArt.onlineWelcome,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.expand(),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.colors.surfaceBase.withValues(alpha: 0),
                    context.colors.surfaceBase,
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(context.spacing.md),
                child: Text(
                  context.l10n.onlineWelcome,
                  textAlign: TextAlign.center,
                  style: context.typography.body.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
