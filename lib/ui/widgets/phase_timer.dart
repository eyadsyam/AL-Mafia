import 'package:flutter/material.dart';

import '../theme/mafia_theme.dart';
import '../theme/design_tokens.dart';

/// A reusable countdown timer widget showing mm:ss with a progress indicator.
///
/// Displays remaining time in tabular monospace format (no jitter) and a
/// circular progress ring or linear bar below. The parent owns the ticking;
/// this widget is purely presentational — it takes `remaining` and `total`
/// durations and renders them.
///
/// Reference: spec FR-016, T034
class PhaseTimer extends StatelessWidget {
  /// Time remaining in this phase.
  final Duration remaining;

  /// Total time for this phase (used to compute progress).
  final Duration total;

  /// Enlarges only the public, on-table clock. Callers in private phases keep
  /// the standard presentation.
  final bool tabletop;

  const PhaseTimer({
    super.key,
    required this.remaining,
    required this.total,
    this.tabletop = false,
  });

  /// Formats [duration] as "mm:ss" with leading zeros.
  static String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    // Clamp progress between 0 and 1
    final progress = total.inMilliseconds > 0
        ? (total.inMilliseconds - remaining.inMilliseconds) /
              total.inMilliseconds
        : 1.0;
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Time text in tabular monospace
        Text(
          _formatTime(remaining),
          key: const ValueKey('phase_timer_text'),
          style: type.timer.copyWith(
            color: colors.textPrimary,
            fontSize: tabletop ? TabletopTokens.timerFontSize : null,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: spacing.lg),

        // Progress indicator: a circular ring
        SizedBox(
          width: spacing.xl * 2,
          height: spacing.xl * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: clampedProgress,
                  strokeWidth: spacing.xs * 1.5,
                  backgroundColor: colors.surfaceOverlay,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accentGold),
                ),
              ),
              // Center dot for visual balance
              Container(
                width: spacing.xs * 2,
                height: spacing.xs * 2,
                decoration: BoxDecoration(
                  color: colors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
