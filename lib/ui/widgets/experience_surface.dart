import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'feathered_art.dart';
import 'textured_surface.dart';

abstract final class ExperienceArt {
  static const invitation = 'assets/images/experience_v2/invitation.webp';
  static const council = 'assets/images/experience_v2/council.webp';
  static const pact = 'assets/images/experience_v2/pact.webp';
}

/// Quiet public surfaces. No wallpaper behind copy, no role-dependent art.
///
/// The same painted ground as every other screen — [AppBackdrop]'s ground and
/// weave — with a faint lamp-light at the top. It used to be a flat gradient
/// of its own, which is how the setup screens came to read as pure black next
/// to the textured ones (owner, 2026-09-24: one ground, everywhere).
class ExperienceSurface extends StatelessWidget {
  final Widget child;
  const ExperienceSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) => AppBackdrop(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.colors.accentGold.withValues(
              alpha: ExperienceTokens.backgroundGlow,
            ),
            context.colors.accentGold.withValues(alpha: 0),
          ],
        ),
      ),
      child: child,
    ),
  );
}

class ExperienceHero extends StatelessWidget {
  final String asset;
  final bool compact;
  const ExperienceHero({super.key, required this.asset, this.compact = false});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    // Feathered, not clipped: the painting dissolves into the room around it
    // instead of sitting in a rounded box on top of it.
    child: FeatheredArt(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: compact
              ? ExperienceTokens.compactHeroMaxHeight
              : ExperienceTokens.heroMaxHeight,
        ),
        child: AspectRatio(
          aspectRatio: compact
              ? ExperienceTokens.compactHeroAspect
              : ExperienceTokens.heroAspect,
          child: AnimatedSwitcher(
            duration: ReduceMotion.of(context)
                ? Duration.zero
                : context.motion.standard,
            child: Image.asset(
              asset,
              key: ValueKey(asset),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              // A missing/evicted decoration never blocks setup or room entry.
              errorBuilder: (_, _, _) => ColoredBox(
                color: context.colors.surfaceRaised,
                child: Center(
                  child: Icon(
                    Icons.theater_comedy_outlined,
                    size: context.spacing.xxl,
                    color: context.colors.accentGold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
