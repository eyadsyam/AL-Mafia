import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../economy/council_art.dart' show RasterOr;
import '../economy/economy_capabilities.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart'
    show onlineBackendFactoryProvider;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'fun_art.dart';
import 'loaded_capabilities.dart';

/// Phase 109: the badges this account holds (today only `founder`). Asked
/// only of a server that announced the phase-109 surface; an older server,
/// or any failure, is "none".
final playerBadgesProvider = FutureProvider<Set<String>>((ref) async {
  try {
    final caps = await ref.watch(economyCapabilitiesProvider.future);
    if (!caps.fun.known) return const {};
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    final json = await backend.call('economy', {'action': 'fun_profile'});
    return {
      for (final b in (json['badges'] as List?) ?? const [])
        if (b is String) b,
    };
  } catch (_) {
    return const {};
  }
});

/// The permanent Founder badge, shown on the profile once earned.
class FounderBadge extends ConsumerStatefulWidget {
  const FounderBadge({super.key});

  static const Key badgeKey = ValueKey('founder_badge');

  @override
  ConsumerState<FounderBadge> createState() => _FounderBadgeState();
}

class _FounderBadgeState extends ConsumerState<FounderBadge> {
  @override
  Widget build(BuildContext context) {
    // The profile never starts a capabilities read of its own: only once
    // something else has asked (and the server knows phase 109) are the
    // badges fetched.
    final caps = loadedCapabilities(ref);
    if (caps == null) {
      recheckCapabilitiesAfterFrame(this);
      return const SizedBox.shrink();
    }
    if (!caps.fun.known) return const SizedBox.shrink();
    final badges = ref.watch(playerBadgesProvider).valueOrNull ?? const {};
    if (!badges.contains('founder')) return const SizedBox.shrink();
    final l = context.l10n;
    final colors = context.colors;
    final s = context.spacing;
    return Semantics(
      key: FounderBadge.badgeKey,
      label: '${l.founderBadge}. ${l.founderBadgeBody}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [
              Color.alphaBlend(
                VaultTokens.gold.withValues(alpha: VaultTokens.lampWash * 2),
                colors.surfaceRaised,
              ),
              colors.surfaceRaised,
            ],
          ),
          borderRadius: BorderRadius.circular(context.radii.button),
          border: Border.all(color: VaultTokens.gold),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RasterOr(
              path: FunRaster.founderBadge,
              width: FunTokens.founderBadge,
              height: FunTokens.founderBadge,
              fallback: const CustomPaint(
                size: Size.square(FunTokens.founderBadge),
                painter: FounderSealPainter(),
              ),
            ),
            SizedBox(width: s.xs),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.founderBadge,
                    style: context.typography.body.emphasised.copyWith(
                      color: VaultTokens.goldLight,
                    ),
                  ),
                  Text(
                    l.founderBadgeBody,
                    style: context.typography.caption.copyWith(
                      color: colors.textSecondary,
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

/// The Founder's mark until its art arrives: a gold rosette with a laurel
/// ring and a single star, struck like the rank crests.
class FounderSealPainter extends CustomPainter {
  const FounderSealPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final r = s / 2;
    // Scalloped rosette.
    final rosette = Path();
    const petals = 12;
    for (var i = 0; i <= petals * 6; i++) {
      final t = i / (petals * 6) * 2 * math.pi;
      final rr = r * (0.9 + 0.1 * math.cos(t * petals));
      final p = c + Offset(math.cos(t), math.sin(t)) * rr;
      i == 0 ? rosette.moveTo(p.dx, p.dy) : rosette.lineTo(p.dx, p.dy);
    }
    rosette.close();
    canvas.drawPath(
      rosette,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: [
            VaultTokens.goldLight,
            VaultTokens.gold,
            VaultTokens.goldDeep,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r * 0.62, Paint()..color = VaultTokens.enamel);
    canvas.drawCircle(
      c,
      r * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.04
        ..color = VaultTokens.goldLight,
    );
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r * 0.4 : r * 0.17;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = VaultTokens.gold);
  }

  @override
  bool shouldRepaint(FounderSealPainter old) => false;
}
