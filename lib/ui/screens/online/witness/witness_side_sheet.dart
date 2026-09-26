import 'package:flutter/material.dart';

import '../../../../platform/reduce_motion.dart';
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';

/// Where the witness panel lives: a sheet that slides in from the side, full
/// height, instead of a strip squeezed under the table.
///
/// The owner found the strip unreadable — three tabs and a transcript in a
/// third of the hand band. Closed, the table has the whole screen and a small
/// tab sits on the edge; open, the panel has the height it needs and the table
/// stays visible, dimmed, beside it. A tap on the table closes it.
class WitnessSideSheet extends StatelessWidget {
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final Widget child;

  const WitnessSideSheet({
    super.key,
    required this.open,
    required this.onOpenChanged,
    required this.child,
  });

  static const Key handle = ValueKey('witness_sheet_handle');
  static const Key scrim = ValueKey('witness_sheet_scrim');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final motion = context.motion;
    final duration = ReduceMotion.of(context) ? Duration.zero : motion.band;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // The sheet comes from the end edge: left in Arabic, right in English.
    final away = Offset(rtl ? -1 : 1, 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth * WitnessSheetTokens.widthFraction)
            .clamp(0.0, WitnessSheetTokens.maxWidth);
        return Stack(
          children: [
            IgnorePointer(
              ignoring: !open,
              child: AnimatedOpacity(
                opacity: open ? 1 : 0,
                duration: duration,
                curve: motion.standardCurve,
                child: GestureDetector(
                  key: scrim,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onOpenChanged(false),
                  child: ColoredBox(
                    color: colors.surfaceBase.withValues(
                      alpha: WitnessSheetTokens.scrimAlpha,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            // The tab on the edge. Always there while closed, so the panel is
            // one tap away and never in the way.
            PositionedDirectional(
              end: 0,
              top: constraints.maxHeight * WitnessSheetTokens.handleTop,
              child: AnimatedOpacity(
                opacity: open ? 0 : 1,
                duration: duration,
                child: IgnorePointer(
                  ignoring: open,
                  child: Material(
                    color: colors.surfaceRaised,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusDirectional.horizontal(
                        start: Radius.circular(radii.dialog),
                      ).resolve(Directionality.of(context)),
                      side: BorderSide(color: colors.borderSubtle),
                    ),
                    child: InkWell(
                      key: handle,
                      onTap: () => onOpenChanged(true),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.sm,
                          vertical: spacing.md,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              color: colors.accentGold,
                            ),
                            SizedBox(height: spacing.xs),
                            RotatedBox(
                              quarterTurns: rtl ? 1 : 3,
                              child: Text(
                                context.l10n.witnessTabTable,
                                style: context.typography.caption.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              width: width,
              child: IgnorePointer(
                ignoring: !open,
                child: AnimatedSlide(
                  offset: open ? Offset.zero : away,
                  duration: duration,
                  curve: motion.standardCurve,
                  child: SafeArea(left: false, right: false, child: child),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
