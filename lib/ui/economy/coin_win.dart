import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'mafia_coin.dart';

/// The win, drawn over the prize that paid it (the wheel's hub, the coffer):
/// «+N» pops in and counts up from zero while coins fly out of it and rise
/// toward the balance, then it fades and [onDone] lets the next offer in.
///
/// Reduce motion: the final number at once, held for [WinTokens.hold].
class CoinWinReveal extends StatefulWidget {
  final int amount;
  final VoidCallback onDone;
  const CoinWinReveal({super.key, required this.amount, required this.onDone});

  static const valueKey = ValueKey('coin_win_value');

  @override
  State<CoinWinReveal> createState() => _CoinWinRevealState();
}

class _CoinWinRevealState extends State<CoinWinReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: WinTokens.reveal,
  )..addStatusListener(_finished);
  Timer? _hold;
  bool _started = false;
  bool _done = false;

  void _finished(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finish();
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _run.value = WinTokens.countShare;
      _hold = Timer(WinTokens.hold, _finish);
    } else {
      _run.forward();
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _run.dispose();
    super.dispose();
  }

  static double _share(double t, double from, double length) =>
      ((t - from) / length).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final style = context.typography.headline.copyWith(
      color: VaultTokens.goldLight,
      fontWeight: FontWeight.w700,
      shadows: [
        Shadow(
          color: VaultTokens.gold.withValues(alpha: WinTokens.glowAlpha),
          blurRadius: WinTokens.glowBlur,
        ),
      ],
    );
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: context.l10n.dailyCofferGranted(widget.amount),
        excludeSemantics: true,
        child: AnimatedBuilder(
          animation: _run,
          builder: (context, _) {
            final t = _run.value;
            final counted = Curves.easeOutCubic.transform(
              _share(t, 0, WinTokens.countShare),
            );
            final pop = _share(t, 0, WinTokens.popShare);
            final scale = pop < 0.5
                ? WinTokens.popFrom +
                      (WinTokens.popPeak - WinTokens.popFrom) *
                          Curves.easeOut.transform(pop * 2)
                : WinTokens.popPeak -
                      (WinTokens.popPeak - 1) *
                          Curves.easeInOut.transform((pop - 0.5) * 2);
            final fade =
                1 - _share(t, 1 - WinTokens.fadeShare, WinTokens.fadeShare);
            return Opacity(
              opacity: fade,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < WinTokens.coins; i++)
                    _coin(i, _share(t, i * WinTokens.stagger,
                        WinTokens.flightShare)),
                  Transform.scale(
                    scale: scale,
                    child: Text(
                      '+${(widget.amount * counted).round()}',
                      key: CoinWinReveal.valueKey,
                      textDirection: TextDirection.ltr,
                      style: style,
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

  /// Coin [i] at [flight] (0..1): out of the prize on its own bearing, then
  /// up toward the balance, fading as it goes.
  Widget _coin(int i, double flight) {
    if (flight <= 0 || flight >= 1) return const SizedBox.shrink();
    final bearing = (i / WinTokens.coins) * 2 * math.pi;
    final out = Curves.easeOutCubic.transform(flight);
    final up = Curves.easeInCubic.transform(flight);
    final offset = Offset(
      math.cos(bearing) * WinTokens.spread * out,
      math.sin(bearing) * WinTokens.spread * out * 0.5 - WinTokens.rise * up,
    );
    return Transform.translate(
      offset: offset,
      child: Opacity(
        opacity: 1 - flight,
        child: const MafiaCoin(size: WinTokens.coin),
      ),
    );
  }
}
