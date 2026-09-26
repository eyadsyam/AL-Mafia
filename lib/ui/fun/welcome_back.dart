import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'loaded_capabilities.dart';
import '../l10n_ext.dart';
import '../screens/setup/coin_store.dart' show CoinStore;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../economy/council_art.dart' show RasterOr;
import 'fun_art.dart';

/// Phase 109: «وحشتنا». When a player comes back after 20 hours or more, a
/// gentle card on Home points at the daily coffer. Navigation only: it opens
/// the vault (Rewards is its first tab when daily rewards are on) and grants
/// nothing itself.
const welcomeBackLastSeenKey = 'mafia.fun.lastSeen';

/// Overridable clock.
final welcomeBackClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Whether this Home visit is a return after [FunTokens.welcomeBackAfter].
/// Read once per app run, and records "now" as the last visit, so the card
/// greets a return once and not on every trip back to Home.
final welcomeBackDueProvider = FutureProvider<bool>((ref) async {
  final now = ref.read(welcomeBackClockProvider)();
  try {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(welcomeBackLastSeenKey);
    await prefs.setInt(welcomeBackLastSeenKey, now.millisecondsSinceEpoch);
    if (last == null) return false;
    final away = now.difference(DateTime.fromMillisecondsSinceEpoch(last));
    return away >= FunTokens.welcomeBackAfter;
  } catch (_) {
    return false;
  }
});

/// Keeps the last-seen stamp current while the app is used, so "away" means
/// away and not "since Home was last opened".
Future<void> noteWelcomeBackSeen(DateTime now) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(welcomeBackLastSeenKey, now.millisecondsSinceEpoch);
  } catch (_) {}
}

class WelcomeBackCard extends ConsumerStatefulWidget {
  const WelcomeBackCard({super.key});

  static const Key cardKey = ValueKey('welcome_back_card');
  static const Key openKey = ValueKey('welcome_back_open');
  static const Key dismissKey = ValueKey('welcome_back_dismiss');

  @override
  ConsumerState<WelcomeBackCard> createState() => _WelcomeBackCardState();
}

class _WelcomeBackCardState extends ConsumerState<WelcomeBackCard>
    with WidgetsBindingObserver {
  bool _dismissed = false;
  final _vault = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      unawaited(noteWelcomeBackSeen(ref.read(welcomeBackClockProvider)()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final due = ref.watch(welcomeBackDueProvider).valueOrNull ?? false;
    if (!due) return const SizedBox.shrink();
    // Never starts a capabilities read from Home; uses one already made.
    final caps = loadedCapabilities(ref);
    if (caps == null) recheckCapabilitiesAfterFrame(this);
    final daily = caps?.daily ?? false;
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return OverlayPortal(
      controller: _vault,
      overlayChildBuilder: (_) => Positioned.fill(
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _vault.hide();
          },
          child: CoinStore(onClose: _vault.hide),
        ),
      ),
      // The portal outlives the card: "open" dismisses the card and the
      // vault it opened stays up until it is closed.
      child: _dismissed
          ? const SizedBox.shrink()
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: reduce ? 1 : 0, end: 1),
              duration: reduce ? Duration.zero : context.motion.standard,
              builder: (context, t, child) => Padding(
                padding: EdgeInsets.only(bottom: s.sm),
                child: Opacity(opacity: t, child: child),
              ),
              child: Container(
                key: WelcomeBackCard.cardKey,
                padding: EdgeInsets.all(s.sm),
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(context.radii.card),
                  border: Border.all(color: colors.accentGold),
                ),
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: FunTokens.welcomeArt,
                      child: RasterOrWelcome(size: FunTokens.welcomeArt),
                    ),
                    SizedBox(width: s.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l.welcomeBackTitle,
                            style: type.title.copyWith(
                              color: colors.accentGold,
                            ),
                          ),
                          Text(
                            daily ? l.welcomeBackBody : l.welcomeBackBodyPlain,
                            style: type.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          Wrap(
                            spacing: s.xs,
                            children: [
                              if (daily)
                                TextButton(
                                  key: WelcomeBackCard.openKey,
                                  onPressed: () {
                                    setState(() => _dismissed = true);
                                    _vault.show();
                                  },
                                  child: Text(l.welcomeBackOpen),
                                ),
                              TextButton(
                                key: WelcomeBackCard.dismissKey,
                                onPressed: () =>
                                    setState(() => _dismissed = true),
                                child: Text(
                                  l.welcomeBackDismiss,
                                  style: TextStyle(color: colors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The envelope-and-candle art, or a painted envelope until it arrives.
class RasterOrWelcome extends StatelessWidget {
  final double size;
  const RasterOrWelcome({super.key, required this.size});

  @override
  Widget build(BuildContext context) => RasterOr(
    path: FunRaster.welcomeBack,
    width: size,
    height: size,
    fallback: Icon(
      Icons.mark_email_unread_rounded,
      size: size * 0.7,
      color: context.colors.accentGold,
    ),
  );
}
