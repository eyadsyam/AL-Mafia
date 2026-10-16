import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';

/// A sheet of the dark case file: dark brown paper, a warm edge.
///
/// «قصص وتحقيقات» only; Mafia's surfaces use `DeckPanel`. Never in a match.
class CaseFilePaper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final BorderRadiusGeometry? borderRadius;

  const CaseFilePaper({
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: CaseFileTokens.paper,
        ),
        borderRadius:
            borderRadius ??
            BorderRadius.circular(radius ?? CaseFileTokens.radius),
        border: Border.all(
          color: CaseFileTokens.edge,
          width: CaseFileTokens.edgeWidth,
        ),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// A rubber stamp: a crimson (or [color]) outlined word, tilted.
class CaseStamp extends StatelessWidget {
  final String text;
  final Color color;
  final double angle;
  final TextStyle? style;

  const CaseStamp(
    this.text, {
    super.key,
    this.color = CaseFileTokens.stamp,
    this.angle = CaseFileTokens.stampTilt,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final base = style ?? context.typography.body.emphasised;
    return Transform.rotate(
      angle: angle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CaseFileTokens.stampPlate,
          border: Border.all(color: color, width: CaseFileTokens.stampBorder),
          borderRadius: BorderRadius.circular(CaseFileTokens.stampRadius),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs / 2),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: base.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// [CaseStamp] landing: it arrives large and turned, then settles. Under
/// reduced motion it is simply there.
class CaseStampDrop extends StatelessWidget {
  /// 0..1; the stamp's own progress.
  final Animation<double> progress;
  final Widget child;
  final double from;

  const CaseStampDrop({
    super.key,
    required this.progress,
    required this.child,
    this.from = ResultTokens.stampFrom,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) {
          final t = Curves.easeOutBack.transform(progress.value.clamp(0, 1));
          return Opacity(
            opacity: progress.value.clamp(0, 1),
            child: Transform.scale(
              scale: math.max(1, from - (from - 1) * t),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// Paper-tab dividers of a case file: the chosen tab is the sheet's own
/// colour and sits a little higher; the others are darker.
class CaseFileTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final Key Function(int index)? tabKey;

  const CaseFileTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.tabKey,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final radius = Radius.circular(context.radii.button);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, label) in labels.indexed) ...[
          if (i > 0) SizedBox(width: s.xs),
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              child: InkWell(
                key: tabKey?.call(i),
                borderRadius: BorderRadius.only(
                  topLeft: radius,
                  topRight: radius,
                ),
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: still ? Duration.zero : DeckTokens.slide,
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(
                    minHeight: IdentityTokens.target,
                  ),
                  transform: Matrix4.translationValues(
                    0,
                    i == selected ? -s.xs : 0,
                    0,
                  ),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: s.xs),
                  decoration: BoxDecoration(
                    color: i == selected
                        ? CaseFileTokens.paperTop
                        : CaseFileTokens.tabIdle,
                    borderRadius: BorderRadius.only(
                      topLeft: radius,
                      topRight: radius,
                    ),
                    border: Border(
                      top: BorderSide(
                        color: i == selected
                            ? CaseFileTokens.edge
                            : CaseFileTokens.tabLine,
                      ),
                      left: BorderSide(
                        color: i == selected
                            ? CaseFileTokens.edge
                            : CaseFileTokens.tabLine,
                      ),
                      right: BorderSide(
                        color: i == selected
                            ? CaseFileTokens.edge
                            : CaseFileTokens.tabLine,
                      ),
                    ),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.bodySmall.emphasised.copyWith(
                      color: i == selected
                          ? CaseFileTokens.ink
                          : CaseFileTokens.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The sheet under [CaseFileTabs]: paper with square top corners.
class CaseFileSheet extends StatelessWidget {
  final Widget child;
  const CaseFileSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    const radius = Radius.circular(CaseFileTokens.radius);
    return CaseFilePaper(
      borderRadius: const BorderRadius.only(
        bottomLeft: radius,
        bottomRight: radius,
      ),
      padding: EdgeInsets.all(s.md),
      child: child,
    );
  }
}
