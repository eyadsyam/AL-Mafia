import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// How far each edge of the art dissolves, as fractions of its size.
class Feather {
  final double top;
  final double bottom;
  final double side;
  const Feather({required this.top, required this.bottom, required this.side});

  static const hero = Feather(
    top: FeatherTokens.heroTop,
    bottom: FeatherTokens.heroBottom,
    side: FeatherTokens.heroSide,
  );
  static const banner = Feather(
    top: FeatherTokens.bannerTop,
    bottom: FeatherTokens.bannerBottom,
    side: FeatherTokens.bannerSide,
  );
  static const portrait = Feather(
    top: FeatherTokens.portraitTop,
    bottom: FeatherTokens.portraitBottom,
    side: FeatherTokens.portraitSide,
  );
}

/// Art that melts into whatever is behind it.
///
/// Two alpha masks (vertical, then horizontal) multiply into the child's own
/// alpha, so an opaque painting loses its rectangle and a transparent one
/// keeps its shape. Behind it, a faint warm halo — the art reads as lit from
/// the room, not pasted onto it. Purely a paint effect: layout, semantics and
/// hit testing are the child's.
///
/// Public surfaces only. In-hand screens (pass, role reveal, night action)
/// never use art at all, and this widget adds light, so it must not become a
/// way for them to.
class FeatheredArt extends StatelessWidget {
  final Widget child;
  final Feather feather;
  final bool halo;

  const FeatheredArt({
    super.key,
    required this.child,
    this.feather = Feather.hero,
    this.halo = true,
  });

  /// Mask stops: only alpha matters under [BlendMode.dstIn].
  static const _mask = [
    Colors.transparent,
    Colors.black,
    Colors.black,
    Colors.transparent,
  ];

  static Shader _vertical(Rect bounds, Feather f) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: _mask,
    stops: [0, f.top, 1 - f.bottom, 1],
  ).createShader(bounds);

  static Shader _horizontal(Rect bounds, Feather f) => LinearGradient(
    colors: _mask,
    stops: [0, f.side, 1 - f.side, 1],
  ).createShader(bounds);

  @override
  Widget build(BuildContext context) {
    final masked = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (b) => _vertical(b, feather),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (b) => _horizontal(b, feather),
        child: child,
      ),
    );
    if (!halo) return masked;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: FeatherTokens.haloRadius,
          colors: [
            context.colors.accentGold.withValues(
              alpha: FeatherTokens.haloOpacity,
            ),
            context.colors.accentGold.withValues(alpha: 0),
          ],
        ),
      ),
      child: masked,
    );
  }
}
