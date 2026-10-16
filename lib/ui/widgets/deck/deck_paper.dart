import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';

/// Mafia's own surfaces for the result, the match file, the profile and the
/// casebook: Home's raised grey with a silver hairline, a seal that sits
/// straight, and plain text tabs. They replace the stories' brown case-file
/// paper, rubber stamps and paper tabs on Mafia screens (owner, 2026-10-16).
///
/// Public surfaces only; never in a match.

/// A raised panel: Home's raised grey, a silver hairline, the panel radius.
class DeckPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final BorderRadiusGeometry? borderRadius;

  const DeckPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DeckTokens.panel,
        borderRadius:
            borderRadius ??
            BorderRadius.circular(radius ?? DeckTokens.panelRadius),
        border: Border.all(
          color: DeckTokens.silver.withValues(alpha: DeckTokens.hairlineAlpha),
        ),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// A short verdict word in a straight, outlined plate: bone by default,
/// [color] for the town's sage or the mafia's crimson. No tilt — the
/// rubber stamp belongs to «قصص وتحقيقات».
class DeckSeal extends StatelessWidget {
  final String text;
  final Color color;
  final TextStyle? style;

  const DeckSeal(
    this.text, {
    super.key,
    this.color = DeckTokens.bone,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final base = style ?? context.typography.bodySmall.emphasised;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DeckTokens.ground.withValues(alpha: DeckTokens.sealPlateAlpha),
        border: Border.all(color: color, width: DeckTokens.sealBorder),
        borderRadius: BorderRadius.circular(DeckTokens.pill / 2),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs / 2),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// [DeckSeal] arriving: it fades in and settles from a little larger. Under
/// reduced motion it is simply there.
class DeckSealDrop extends StatelessWidget {
  /// 0..1; the seal's own progress.
  final Animation<double> progress;
  final Widget child;

  const DeckSealDrop({super.key, required this.progress, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) {
          final p = progress.value.clamp(0.0, 1.0);
          final t = Curves.easeOutCubic.transform(p);
          return Opacity(
            opacity: p,
            child: Transform.scale(
              scale: DeckTokens.sealFrom - (DeckTokens.sealFrom - 1) * t,
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// Text tabs: the chosen one in the text colour over a bone underline, the
/// others muted, one hairline under them all.
class DeckTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final Key Function(int index)? tabKey;

  const DeckTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.tabKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DeckTokens.line)),
      ),
      child: Row(
        children: [
          for (final (i, label) in labels.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: InkWell(
                  key: tabKey?.call(i),
                  onTap: () => onSelect(i),
                  splashColor: IdentityTokens.transparent,
                  highlightColor: IdentityTokens.transparent,
                  child: AnimatedContainer(
                    duration: still ? Duration.zero : DeckTokens.slide,
                    curve: Curves.easeOutCubic,
                    constraints: const BoxConstraints(
                      minHeight: IdentityTokens.target,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: i == selected
                              ? DeckTokens.bone
                              : IdentityTokens.transparent,
                          width: DeckTokens.selectedRim,
                        ),
                      ),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodySmall.emphasised.copyWith(
                        color: i == selected
                            ? colors.textPrimary
                            : colors.textMuted,
                      ),
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

/// What sits under [DeckTabs]: the page, with the screen's own spacing.
class DeckTabPage extends StatelessWidget {
  final Widget child;
  const DeckTabPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: context.spacing.md),
    child: child,
  );
}
