import 'package:flutter/material.dart';

import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/textured_surface.dart';
import '../../widgets/trace_line.dart';

/// The on-table morning announcement (screen S-10).
///
/// Three outcomes, and only three: someone died and is named; someone was
/// saved but is deliberately **not** named; or the night passed with nobody
/// targeted. Naming the saved player would hand the table the Doctor's aim and
/// the Mafia's target in one sentence, so the "saved" case stays anonymous
/// (FR-014/FR-015).
///
/// No role is ever shown here. The victim's role is revealed only at the day
/// vote reveal or at the end of the match.
class MorningScreen extends StatelessWidget {
  final int dayNumber;

  /// Name of the player who died, or null if nobody did.
  final String? victimName;

  /// True when the Mafia's target survived because they were protected.
  final bool someoneSavedUnnamed;

  /// This morning's trace, already rendered to a sentence, or null when the
  /// layer is switched off for this match.
  ///
  /// A *string*, not a `TraceResult`: which sentence a trace becomes is
  /// `InformationText`'s decision and this screen has no business making it,
  /// and passing the rendered line is what lets the golden suite drive every
  /// trace type through here without building an engine.
  final String? traceText;

  final VoidCallback onContinue;

  const MorningScreen({
    super.key,
    required this.dayNumber,
    required this.victimName,
    required this.someoneSavedUnnamed,
    this.traceText,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    final String headline;
    final String body;
    if (victimName != null) {
      headline = l10n.notEveryoneSurvived;
      body = l10n.lostPlayerLastNight(victimName!);
    } else if (someoneSavedUnnamed) {
      headline = l10n.quietNight;
      body = l10n.someoneSavedBody;
    } else {
      headline = l10n.quietNight;
      body = l10n.noLossesBody;
    }

    return AppBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.screenMargin,
                vertical: spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    l10n.morningOfDay(dayNumber),
                    style: type.caption.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    headline,
                    style: type.display.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    body,
                    style: type.body.copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (traceText != null) ...[
                    SizedBox(height: spacing.xl),
                    TraceLine(
                      // Keyed on the day so a second morning really replays the
                      // beat rather than inheriting the first one's finished
                      // fade.
                      key: ValueKey('trace-$dayNumber'),
                      label: l10n.traceLabel,
                      text: traceText!,
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    height: spacing.xxl + spacing.sm,
                    child: FilledButton(
                      onPressed: onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accentGold,
                        foregroundColor: colors.surfaceBase,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radii.button),
                        ),
                      ),
                      child: Text(l10n.startDiscussion, style: type.title),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
