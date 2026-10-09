import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../economy/mafia_coin.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// A sheet of the dark case file: dark brown paper, a warm edge.
///
/// Public surfaces only (result, profile, casebook); never in a match.
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
                  constraints: BoxConstraints(minHeight: IdentityTokens.target),
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
    final radius = Radius.circular(CaseFileTokens.radius);
    return CaseFilePaper(
      borderRadius: BorderRadius.only(bottomLeft: radius, bottomRight: radius),
      padding: EdgeInsets.all(s.md),
      child: child,
    );
  }
}

/// Wraps a screen so coins can fly across it: [CoinFlightLayerState.fly]
/// takes the centres of two widgets (by key) and sends a handful of coins from
/// the first to the second. Transform and opacity only; under reduced motion
/// nothing flies and the call answers at once.
class CoinFlightLayer extends StatefulWidget {
  final Widget child;
  const CoinFlightLayer({super.key, required this.child});

  @override
  State<CoinFlightLayer> createState() => CoinFlightLayerState();
}

class CoinFlightLayerState extends State<CoinFlightLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: ResultTokens.flight,
  );
  Offset? _from;
  Offset? _to;
  VoidCallback? _landed;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      final landed = _landed;
      _landed = null;
      if (mounted) setState(() => _from = _to = null);
      landed?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Sends the coins from the widget keyed [from] to the one keyed [to];
  /// [onLanded] runs when the last one arrives (or at once when nothing flies).
  void fly(GlobalKey from, GlobalKey to, {VoidCallback? onLanded}) {
    final stack = context.findRenderObject();
    Offset? centre(GlobalKey key) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || stack is! RenderBox) {
        return null;
      }
      return stack.globalToLocal(
        box.localToGlobal(box.size.center(Offset.zero)),
      );
    }

    final a = centre(from);
    final b = centre(to);
    if ((MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        a == null ||
        b == null) {
      onLanded?.call();
      return;
    }
    setState(() {
      _from = a;
      _to = b;
      _landed = onLanded;
    });
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    final to = _to;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (from != null && to != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    const n = ResultTokens.flightCoins;
                    const window = 1 - (n - 1) * ResultTokens.flightStagger;
                    return Stack(
                      children: [
                        for (var i = 0; i < n; i++)
                          () {
                            final p = Curves.easeIn.transform(
                              ((_c.value - i * ResultTokens.flightStagger) /
                                      window)
                                  .clamp(0.0, 1.0),
                            );
                            final at = Offset.lerp(from, to, p)!;
                            return Positioned(
                              left: at.dx - ResultTokens.flightCoinSize / 2,
                              top: at.dy - ResultTokens.flightCoinSize / 2,
                              child: Opacity(
                                opacity: p == 0 ? 0 : 1 - 0.8 * p,
                                child: const MafiaCoin(
                                  size: ResultTokens.flightCoinSize,
                                ),
                              ),
                            );
                          }(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
