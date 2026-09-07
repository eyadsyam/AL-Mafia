import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/asset_constants.dart';
import '../../engine/models/enums.dart' as engine;
import '../../platform/reduce_motion.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../l10n_ext.dart';

/// Reveals the outcome through media before result copy or standings appear.
class VictoryReveal extends StatefulWidget {
  final engine.Alignment winner;
  final VoidCallback onComplete;
  final VoidCallback? onStart;

  const VictoryReveal({
    super.key,
    required this.winner,
    required this.onComplete,
    this.onStart,
  });

  @override
  State<VictoryReveal> createState() => _VictoryRevealState();
}

class _VictoryRevealState extends State<VictoryReveal>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _started = false;
  final Stopwatch _visibleTime = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _resumeTimer() {
    _visibleTime.start();
    final remaining = MafiaTiming.victoryReveal - _visibleTime.elapsed;
    _timer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      widget.onComplete,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    _timer?.cancel();
    _visibleTime.stop();
    if (state == AppLifecycleState.resumed) _resumeTimer();
  }

  void _start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onStart?.call();
      _resumeTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mafia = widget.winner == engine.Alignment.mafia;
    final still = mafia ? AppImages.outcomeMafiaWin : AppImages.outcomeTownWin;
    final media = ReduceMotion.of(context)
        ? still
        : mafia
        ? AppVideo.outcomeMafiaWinLoop
        : AppVideo.outcomeTownWinLoop;
    return ColoredBox(
      color: context.colors.surfaceBase,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            media,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            excludeFromSemantics: true,
            frameBuilder: (context, child, frame, synchronous) {
              if (frame != null || synchronous) _start();
              return child;
            },
            errorBuilder: (context, error, stack) {
              _start();
              return Image.asset(still, fit: BoxFit.cover);
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(context.spacing.xl),
                child: Text(
                  mafia ? context.l10n.mafiaWins : context.l10n.townWins,
                  textAlign: TextAlign.center,
                  style: context.typography.display.copyWith(
                    color: context.colors.textPrimary,
                    backgroundColor: context.colors.surfaceOverlay,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
