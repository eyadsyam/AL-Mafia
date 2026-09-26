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
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(context.radii.button),
          border: Border.all(color: colors.accentGold),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RasterOr(
              path: FunRaster.founderBadge,
              width: FunTokens.founderBadge,
              height: FunTokens.founderBadge,
              fallback: Icon(
                Icons.verified_rounded,
                size: FunTokens.founderBadge,
                color: colors.accentGold,
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
                    style: context.typography.body.copyWith(
                      color: colors.accentGold,
                      fontWeight: FontWeight.w700,
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
