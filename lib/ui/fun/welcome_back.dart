import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'loaded_capabilities.dart';
import '../../platform/haptics.dart';
import '../l10n_ext.dart';
import '../screens/setup/coin_store.dart' show CoinStore;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../economy/council_art.dart' show RasterOr;
import '../economy/daily_rewards.dart';
import '../economy/mafia_coin.dart';
import '../economy/store_art.dart';
import '../economy/vault_kit.dart';
import '../widgets/motion_sprite.dart';
import 'fun_art.dart';

/// Home's daily strip. It exists only while today's coffer is waiting: one
/// slim line under the corner controls that claims the coffer where it is,
/// then offers the free wheel if it has not turned today. Dismissed, it stays
/// away until tomorrow. «وحشتنا» is only its greeting after a long absence.
const welcomeBackLastSeenKey = 'mafia.fun.lastSeen';

/// The server day the strip was dismissed on.
const cofferStripDismissedKey = 'mafia.fun.cofferStripDismissed';

/// Overridable clock.
final welcomeBackClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Whether this Home visit is a return after [FunTokens.welcomeBackAfter].
/// Read once per app run, and records "now" as the last visit. It only picks
/// the strip's greeting; it never makes the strip appear.
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

/// The server day the strip was last dismissed on, or null.
final cofferStripDismissedProvider = FutureProvider<String?>((ref) async {
  try {
    return (await SharedPreferences.getInstance()).getString(
      cofferStripDismissedKey,
    );
  } catch (_) {
    return null;
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
  static const Key claimKey = ValueKey('welcome_back_claim');
  static const Key spinKey = ValueKey('welcome_back_spin');
  static const Key dismissKey = ValueKey('welcome_back_dismiss');

  @override
  ConsumerState<WelcomeBackCard> createState() => _WelcomeBackCardState();
}

class _WelcomeBackCardState extends ConsumerState<WelcomeBackCard>
    with WidgetsBindingObserver {
  bool _dismissed = false;
  bool _asked = false;
  bool _busy = false;

  /// What the claim granted, once it has; the strip then says so.
  int? _got;
  Timer? _linger;
  final _vault = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _linger?.cancel();
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

  Future<void> _dismiss(String day) async {
    setState(() => _dismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cofferStripDismissedKey, day);
    } catch (_) {}
  }

  Future<void> _claim() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final grant = await ref.read(dailyProvider.notifier).claimCoffer();
      if (!mounted) return;
      Haptics.confirm();
      showRewardFlourish(context);
      setState(() => _got = grant.granted + grant.bonus);
      final spun = ref.read(dailyProvider).valueOrNull?.wheelSpun ?? true;
      // Nothing left to offer: the thanks lingers, then the strip goes.
      if (spun) {
        _linger = Timer(MafiaTiming.cofferStripLinger, () {
          if (mounted) setState(() => _dismissed = true);
        });
      }
    } on DailyActionFailed {
      // The strip stays; the refreshed status decides whether it still can.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Never starts a capabilities read from Home; uses one already made, so
    // an offline-only player is never signed in just for this strip.
    final caps = loadedCapabilities(ref);
    if (caps == null) recheckCapabilitiesAfterFrame(this);
    final on = caps?.daily ?? false;
    final daily = ref.watch(dailyProvider);
    if (on && !_asked && daily.valueOrNull == null && !daily.isLoading) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(ref.read(dailyProvider.notifier).refresh());
      });
    }
    final status = daily.valueOrNull;
    final dismissedOn = ref.watch(cofferStripDismissedProvider).valueOrNull;
    final show =
        on &&
        !_dismissed &&
        status != null &&
        status.enabled &&
        dismissedOn != status.day &&
        (!status.cofferClaimed || _got != null);

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
      // The portal outlives the strip: the vault the strip opened stays up
      // until it is closed.
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : context.motion.standard,
        curve: context.motion.standardCurve,
        alignment: Alignment.topCenter,
        child: show ? _strip(context, status) : const SizedBox.shrink(),
      ),
    );
  }

  Widget _strip(BuildContext context, DailyStatus status) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final got = _got;
    final greet = ref.watch(welcomeBackDueProvider).valueOrNull ?? false;
    final Widget action;
    if (got == null) {
      action = VaultPress(
        child: FilledButton(
          key: WelcomeBackCard.claimKey,
          style: vaultGoldStyle(context),
          onPressed: _busy ? null : _claim,
          child: Text(l.cofferStripClaim),
        ),
      );
    } else if (!status.wheelSpun) {
      action = VaultPress(
        child: FilledButton(
          key: WelcomeBackCard.spinKey,
          style: vaultGoldStyle(context),
          onPressed: () {
            setState(() => _dismissed = true);
            _vault.show();
          },
          child: Text(l.cofferStripSpin),
        ),
      );
    } else {
      action = const SizedBox.shrink();
    }
    return Padding(
      key: WelcomeBackCard.cardKey,
      padding: EdgeInsets.only(top: s.xs),
      child: VaultCard(
        lit: true,
        mainAxisSize: MainAxisSize.min,
        padding: EdgeInsetsDirectional.fromSTEB(s.sm, s.xs, s.xs, s.xs),
        children: [
          Row(
            children: [
              Image.asset(
                StoreArt.dailyCoffer,
                width: FunTokens.cofferStripArt,
                height: FunTokens.cofferStripArt,
                cacheWidth: StoreTokens.frameDecodeWidth,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) =>
                    const MafiaCoin(size: FunTokens.cofferStripArt / 2),
              ),
              SizedBox(width: s.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      got != null
                          ? l.cofferStripGot(got)
                          : greet
                          ? l.welcomeBackTitle
                          : l.cofferStripReady,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.body.copyWith(
                        color: VaultTokens.goldLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (got == null)
                      Text(
                        l.cofferStripBody,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (got == null && status.cofferAmount > 0) ...[
                RewardChip(status.cofferAmount),
                SizedBox(width: s.xs),
              ],
              action,
              IconButton(
                key: WelcomeBackCard.dismissKey,
                tooltip: l.cofferStripLater,
                visualDensity: VisualDensity.compact,
                onPressed: () => unawaited(_dismiss(status.day)),
                icon: Icon(Icons.close, color: colors.textMuted),
              ),
            ],
          ),
        ],
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
    fallback: CustomPaint(
      size: Size.square(size),
      painter: const EnvelopePainter(),
    ),
  );
}

/// A sealed letter: parchment-dark paper, a gold-edged flap and an oxblood
/// wax seal pressed with the council's mask.
class EnvelopePainter extends CustomPainter {
  const EnvelopePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final body = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: s * 0.86,
      height: s * 0.58,
    );
    final rrect = RRect.fromRectAndRadius(body, Radius.circular(s * 0.05));
    canvas.drawShadow(
      Path()..addRRect(rrect),
      VaultTokens.goldInk,
      s * 0.05,
      false,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [VaultTokens.goldPressedLight, VaultTokens.goldPressed],
        ).createShader(body),
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeJoin = StrokeJoin.round
      ..color = VaultTokens.goldDeep;
    // The lower folds meet in the middle.
    canvas.drawPath(
      Path()
        ..moveTo(body.left, body.bottom)
        ..lineTo(body.center.dx, body.center.dy + s * 0.04)
        ..lineTo(body.right, body.bottom),
      edge,
    );
    // The flap, closed over the top.
    final flap = Path()
      ..moveTo(body.left, body.top)
      ..lineTo(body.center.dx, body.center.dy + s * 0.06)
      ..lineTo(body.right, body.top)
      ..close();
    canvas.drawPath(
      flap,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [VaultTokens.goldLight, VaultTokens.gold],
        ).createShader(body),
    );
    canvas.drawPath(flap, edge);
    canvas.drawRRect(rrect, edge);
    // The wax seal, where the flap's point rests.
    final seal = Offset(body.center.dx, body.center.dy + s * 0.06);
    final r = s * 0.12;
    canvas.drawCircle(
      seal,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: [VaultTokens.oxbloodLight, VaultTokens.oxblood],
        ).createShader(Rect.fromCircle(center: seal, radius: r)),
    );
    canvas.drawCircle(
      seal,
      r * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = VaultTokens.goldLight.withValues(alpha: 0.6),
    );
    // Two eyes of the mask pressed into the wax.
    final eye = Paint()..color = VaultTokens.goldLight.withValues(alpha: 0.8);
    for (final dx in [-r * 0.3, r * 0.3]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: seal + Offset(dx, -r * 0.05),
          width: r * 0.34,
          height: r * 0.2,
        ),
        eye,
      );
    }
  }

  @override
  bool shouldRepaint(EnvelopePainter old) => false;
}
