import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'mafia_coin.dart';

/// One card system for every 1.0.1 surface — the vault's tabs, the Council,
/// rewards, offers, the result screen's strips — so they read as one
/// engraved object family rather than a dozen flat boxes.
///
/// ## The pieces
///
/// * [VaultCard] — a raised panel lit from above: a gold lamp-wash along the
///   top, an engraved hairline inside the edge and four gold corner marks.
///   `lit` rims it in gold with a soft glow (something waits there); `tag`
///   rides a ribbon on its top edge (best value, one time only).
/// * [VaultHeading] — art, title and a line under it, one rhythm everywhere.
/// * [RewardChip] — the coin and the amount in a gold-rimmed enamel pill:
///   every reward reads the same at a glance.
/// * [VaultBar] — an inset track with a metal fill that eases to its value.
/// * [vaultGoldStyle] / [vaultOutlineStyle] — the reward buttons: struck
///   gold for a claim or a purchase, a gold rim for an optional ad.
/// * [VaultPress] — the small give under a finger.
/// * [VaultGlint] — one light across a card, once, never a loop.
/// * [ClaimedMark], [VaultSkeleton], [VaultRetry] — the finished, loading and
///   failed states, drawn the same on every tab.
///
/// Every animation here is finite and stands still under reduced motion.

/// The raised, engraved panel.
class VaultCard extends StatelessWidget {
  final List<Widget> children;
  final bool lit;
  final String? tag;

  /// Oxblood for a tag that should outrank gold (the best offer).
  final bool tagOxblood;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;

  const VaultCard({
    super.key,
    required this.children,
    this.lit = false,
    this.tag,
    this.tagOxblood = false,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(context.radii.card);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              VaultTokens.gold.withValues(
                alpha: lit ? VaultTokens.lampWash * 1.6 : VaultTokens.lampWash,
              ),
              colors.surfaceRaised,
            ),
            colors.surfaceRaised,
            Color.lerp(colors.surfaceRaised, colors.surfaceBase, 0.45)!,
          ],
          stops: const [0, 0.42, 1],
        ),
        border: Border.all(
          color: lit ? VaultTokens.gold : colors.borderSubtle,
          width: lit ? VaultTokens.litBorder : 1,
        ),
        boxShadow: [
          ...context.elevation.level1,
          if (lit)
            BoxShadow(
              color: VaultTokens.gold.withValues(
                alpha: VaultTokens.litGlowAlpha,
              ),
              blurRadius: VaultTokens.litGlowBlur,
            ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _EngravingPainter(
          radius: context.radii.card,
          lit: lit,
        ),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.fromLTRB(
                context.spacing.md,
                tag == null
                    ? context.spacing.md
                    : context.spacing.md + VaultTokens.tagLift / 2,
                context.spacing.md,
                context.spacing.md,
              ),
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      ),
    );
    final label = tag;
    if (label == null) return card;
    return Padding(
      padding: const EdgeInsets.only(top: VaultTokens.tagLift),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          PositionedDirectional(
            top: -VaultTokens.tagLift,
            start: context.spacing.md,
            child: VaultTag(label, oxblood: tagOxblood),
          ),
        ],
      ),
    );
  }
}

/// A small ribbon label: «الأفضل قيمة», «مرة واحدة بس».
class VaultTag extends StatelessWidget {
  final String text;
  final bool oxblood;
  const VaultTag(this.text, {super.key, this.oxblood = false});

  @override
  Widget build(BuildContext context) => Container(
    height: VaultTokens.tagHeight,
    padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(VaultTokens.tagHeight / 2),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: oxblood
            ? const [VaultTokens.oxbloodLight, VaultTokens.oxblood]
            : const [VaultTokens.goldLight, VaultTokens.gold],
      ),
      border: Border.all(
        color: oxblood ? VaultTokens.gold : VaultTokens.goldLight,
        width: VaultTokens.chipRim,
      ),
      boxShadow: context.elevation.level1,
    ),
    // As wide as its words, wherever it sits.
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          maxLines: 1,
          style: context.typography.caption.emphasised.copyWith(
            color: oxblood ? VaultTokens.goldLight : VaultTokens.goldInk,
            height: 1.2,
          ),
        ),
      ],
    ),
  );
}

class _EngravingPainter extends CustomPainter {
  final double radius;
  final bool lit;
  const _EngravingPainter({required this.radius, required this.lit});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = VaultTokens.engraveInset;
    final inner = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(inset),
      Radius.circular(math.max(0, radius - inset)),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = VaultTokens.engraveWidth
        ..color = VaultTokens.gold.withValues(
          alpha: lit
              ? VaultTokens.engraveAlpha * 1.8
              : VaultTokens.engraveAlpha,
        ),
    );
    // The top edge catches the lamp: a hairline that fades at both ends.
    final top = Rect.fromLTWH(radius, 0.5, size.width - radius * 2, 1);
    canvas.drawRect(
      top,
      Paint()
        ..shader = LinearGradient(
          colors: [
            VaultTokens.goldLight.withValues(alpha: 0),
            VaultTokens.goldLight.withValues(alpha: lit ? 0.55 : 0.28),
            VaultTokens.goldLight.withValues(alpha: 0),
          ],
        ).createShader(top),
    );
    // Four corner brackets, each with a stud, inside the hairline.
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = VaultTokens.gold.withValues(alpha: VaultTokens.cornerAlpha);
    final stud = Paint()
      ..color = VaultTokens.goldLight.withValues(
        alpha: VaultTokens.cornerAlpha,
      );
    const tick = VaultTokens.cornerTick;
    final o = inset + radius * 0.35;
    for (final (x, y, dx, dy) in [
      (o, o, 1.0, 1.0),
      (size.width - o, o, -1.0, 1.0),
      (o, size.height - o, 1.0, -1.0),
      (size.width - o, size.height - o, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * tick)
          ..lineTo(x, y)
          ..lineTo(x + dx * tick, y),
        mark,
      );
      canvas.drawCircle(
        Offset(x + dx * 3, y + dy * 3),
        VaultTokens.cornerStud,
        stud,
      );
    }
  }

  @override
  bool shouldRepaint(_EngravingPainter old) =>
      old.radius != radius || old.lit != lit;
}

/// Art, a title and a line under it.
class VaultHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Color? titleColor;

  /// A quieter title (a notice, not a section).
  final bool compact;
  const VaultHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.titleColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final colors = context.colors;
    return Row(
      children: [
        if (leading != null) ...[leading!, SizedBox(width: s.sm + s.xs)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style:
                      (compact
                              ? context.typography.body.emphasised
                              : context.typography.title)
                          .copyWith(color: titleColor ?? colors.textPrimary),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: context.typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[SizedBox(width: s.sm), trailing!],
      ],
    );
  }
}

/// «+25 🪙» in a gold-rimmed enamel pill. [muted] for a reward not yet
/// reachable, so the eye goes to the ones that are.
class RewardChip extends StatelessWidget {
  final int amount;
  final bool muted;

  /// A word after the amount («XP»), or nothing for coins.
  final String? unit;
  const RewardChip(this.amount, {super.key, this.muted = false, this.unit});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Container(
      height: VaultTokens.chipHeight,
      padding: EdgeInsetsDirectional.only(start: s.xs, end: s.sm),
      decoration: BoxDecoration(
        color: VaultTokens.enamel,
        borderRadius: BorderRadius.circular(VaultTokens.chipHeight / 2),
        border: Border.all(
          color: muted
              ? context.colors.borderSubtle
              : VaultTokens.gold.withValues(alpha: 0.8),
          width: VaultTokens.chipRim,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unit == null)
            Opacity(
              opacity: muted ? 0.55 : 1,
              child: const MafiaCoin(size: VaultTokens.chipCoin),
            ),
          SizedBox(width: s.xs),
          // Numbers are an identifier-like run: always left to right.
          Text(
            unit == null ? '+$amount' : '+$amount $unit',
            textDirection: TextDirection.ltr,
            style: context.typography.bodySmall.emphasised.copyWith(
              color: muted ? context.colors.textMuted : VaultTokens.goldLight,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// «اتستلم ✓»: a finished reward, in gold, with a struck check.
class ClaimedMark extends StatelessWidget {
  final String text;
  const ClaimedMark(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: VaultTokens.chipCoin + 4,
        height: VaultTokens.chipCoin + 4,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [VaultTokens.goldLight, VaultTokens.goldDeep],
          ),
        ),
        child: const Icon(
          Icons.check_rounded,
          size: VaultTokens.chipCoin,
          color: VaultTokens.goldInk,
        ),
      ),
      SizedBox(width: context.spacing.xs),
      Text(
        text,
        style: context.typography.bodySmall.emphasised.copyWith(
          color: VaultTokens.gold,
        ),
      ),
    ],
  );
}

/// An inset track with a struck-metal fill. Eases to a new value; still
/// under reduced motion.
class VaultBar extends StatelessWidget {
  final double value;
  final double height;
  const VaultBar({
    super.key,
    required this.value,
    this.height = VaultTokens.barHeight,
  });

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final colors = context.colors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      value: '${(target * 100).round()}%',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: target),
          duration: reduce ? Duration.zero : VaultTokens.barFill,
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => CustomPaint(
            painter: _BarPainter(
              value: v,
              rtl: rtl,
              track: colors.surfaceBase,
              edge: colors.borderSubtle,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double value;
  final bool rtl;
  final Color track;
  final Color edge;
  const _BarPainter({
    required this.value,
    required this.rtl,
    required this.track,
    required this.edge,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final whole = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas.drawRRect(whole, Paint()..color = track);
    // The groove's shadow along its top edge.
    canvas.save();
    canvas.clipRRect(whole);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.35),
      Paint()..color = VaultTokens.goldInk.withValues(alpha: 0.6),
    );
    canvas.restore();
    canvas.drawRRect(
      whole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = edge,
    );
    if (value <= 0) return;
    final w = math.max(size.height, size.width * value);
    final fillRect = rtl
        ? Rect.fromLTWH(size.width - w, 0, w, size.height)
        : Rect.fromLTWH(0, 0, w, size.height);
    final fill = RRect.fromRectAndRadius(fillRect.deflate(1), r);
    canvas.drawRRect(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: value >= 1
              ? const [
                  VaultTokens.goldLight,
                  VaultTokens.gold,
                  VaultTokens.goldDeep,
                ]
              : const [
                  VaultTokens.goldPressedLight,
                  VaultTokens.goldPressed,
                  VaultTokens.goldDeep,
                ],
        ).createShader(fillRect),
    );
    // A struck highlight along the fill's top.
    final shine = Rect.fromLTWH(
      fillRect.left + size.height / 2,
      fillRect.top + 1.5,
      math.max(0, fillRect.width - size.height),
      1,
    );
    canvas.drawRect(
      shine,
      Paint()
        ..color = VaultTokens.goldLight.withValues(alpha: VaultTokens.barShine),
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value ||
      old.rtl != rtl ||
      old.track != track ||
      old.edge != edge;
}

/// Struck gold: a claim, a spin, a purchase. Disabled reads as an empty
/// slot, never as a faded gold that might still be tapped.
ButtonStyle vaultGoldStyle(BuildContext context, {Size? minimumSize}) {
  final colors = context.colors;
  final radius = BorderRadius.circular(context.radii.button);
  return ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? colors.textMuted
          : VaultTokens.goldInk,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? colors.textMuted
          : VaultTokens.goldInk,
    ),
    overlayColor: WidgetStatePropertyAll(
      VaultTokens.goldLight.withValues(alpha: 0.16),
    ),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    minimumSize: minimumSize == null
        ? null
        : WidgetStatePropertyAll(minimumSize),
    textStyle: WidgetStatePropertyAll(context.typography.body.emphasised),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radius)),
    backgroundBuilder: (context, states, child) {
      final disabled = states.contains(WidgetState.disabled);
      final pressed = states.contains(WidgetState.pressed);
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: disabled ? colors.surfaceOverlay : null,
          gradient: disabled
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: pressed
                      ? const [
                          VaultTokens.goldPressedLight,
                          VaultTokens.goldPressed,
                          VaultTokens.goldDeep,
                        ]
                      : const [
                          VaultTokens.goldLight,
                          VaultTokens.gold,
                          VaultTokens.goldPressed,
                        ],
                  stops: const [0, 0.55, 1],
                ),
          border: Border.all(
            color: disabled
                ? colors.borderSubtle
                : VaultTokens.goldLight.withValues(alpha: 0.7),
          ),
          boxShadow: disabled || pressed
              ? null
              : [
                  BoxShadow(
                    color: VaultTokens.gold.withValues(
                      alpha: VaultTokens.buttonGlowAlpha,
                    ),
                    blurRadius: VaultTokens.buttonGlowBlur,
                    offset: const Offset(0, VaultTokens.buttonGlowDrop),
                  ),
                ],
        ),
        child: child,
      );
    },
  );
}

/// A gold rim on enamel: the optional things (an ad, a copy, a board).
ButtonStyle vaultOutlineStyle(BuildContext context) {
  final colors = context.colors;
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? Colors.transparent
          : states.contains(WidgetState.pressed)
          ? VaultTokens.gold.withValues(alpha: 0.12)
          : VaultTokens.enamel,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? colors.textMuted
          : VaultTokens.goldLight,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? colors.textMuted
          : VaultTokens.gold,
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? colors.borderSubtle
            : VaultTokens.gold.withValues(alpha: 0.7),
      ),
    ),
    overlayColor: WidgetStatePropertyAll(
      VaultTokens.gold.withValues(alpha: 0.12),
    ),
  );
}

/// The small give under a finger. Nothing under reduced motion.
class VaultPress extends StatefulWidget {
  final Widget child;
  const VaultPress({super.key, required this.child});

  @override
  State<VaultPress> createState() => _VaultPressState();
}

class _VaultPressState extends State<VaultPress> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !reduce ? context.motion.pressScale : 1,
        duration: reduce ? Duration.zero : context.motion.tap,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// One slow light across [child], once, a beat after it appears: the best
/// offer, a fresh reward. Never loops; absent under reduced motion.
class VaultGlint extends StatefulWidget {
  final Widget child;
  final bool play;
  final BorderRadius? borderRadius;
  const VaultGlint({
    super.key,
    required this.child,
    this.play = true,
    this.borderRadius,
  });

  @override
  State<VaultGlint> createState() => _VaultGlintState();
}

class _VaultGlintState extends State<VaultGlint>
    with SingleTickerProviderStateMixin {
  AnimationController? _run;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = widget.play && !MediaQuery.disableAnimationsOf(context);
    if (animate && _run == null) {
      // The delay is part of the one run, not a timer: nothing outlives it.
      _run = AnimationController(
        vsync: this,
        duration: VaultTokens.glintDelay + VaultTokens.glint,
      )..forward();
    }
  }

  @override
  void dispose() {
    _run?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    if (run == null) return widget.child;
    final start =
        VaultTokens.glintDelay.inMilliseconds /
        (VaultTokens.glintDelay + VaultTokens.glint).inMilliseconds;
    final sweep = CurvedAnimation(
      parent: run,
      curve: Interval(start, 1, curve: Curves.easeInOut),
    );
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius:
                  widget.borderRadius ??
                  BorderRadius.circular(context.radii.card),
              child: AnimatedBuilder(
                animation: sweep,
                builder: (context, _) => run.isCompleted || sweep.value <= 0
                    ? const SizedBox.shrink()
                    : CustomPaint(painter: _GlintPainter(sweep.value)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlintPainter extends CustomPainter {
  final double t;
  const _GlintPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.shortestSide * 0.9;
    final x = -band + (size.width + band * 2) * t;
    final rect = Rect.fromLTWH(x - band, 0, band * 2, size.height);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1, -0.4),
          end: const Alignment(1, 0.4),
          colors: [
            VaultTokens.goldLight.withValues(alpha: 0),
            VaultTokens.goldLight.withValues(alpha: VaultTokens.glintAlpha),
            VaultTokens.goldLight.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlintPainter old) => old.t != t;
}

/// Engraved skeleton cards while a tab loads: the shape of what is coming,
/// still (a looping shimmer would never let a screen settle).
class VaultSkeleton extends StatelessWidget {
  final int cards;
  const VaultSkeleton({super.key, this.cards = 3});

  static const Key skeletonKey = ValueKey('vault_skeleton');

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final block = context.colors.textPrimary.withValues(
      alpha: VaultTokens.skeletonAlpha,
    );
    Widget line(double widthFactor) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: Container(
        height: VaultTokens.skeletonLine,
        decoration: BoxDecoration(
          color: block,
          borderRadius: BorderRadius.circular(VaultTokens.skeletonLine / 2),
        ),
      ),
    );
    return Semantics(
      key: skeletonKey,
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: ExcludeSemantics(
        child: ListView(
          padding: EdgeInsets.all(s.md),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < cards; i++) ...[
              VaultCard(
                children: [
                  Row(
                    children: [
                      Container(
                        width: CouncilLifeTokens.contractIcon,
                        height: CouncilLifeTokens.contractIcon,
                        decoration: BoxDecoration(
                          color: block,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: s.sm),
                      Expanded(
                        child: Column(
                          children: [
                            line(0.5),
                            SizedBox(height: s.sm),
                            line(0.8),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: s.md),
                  line(1),
                  SizedBox(height: s.md),
                  Container(
                    height: StoreTokens.touchTarget,
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: BorderRadius.circular(context.radii.button),
                    ),
                  ),
                ],
              ),
              SizedBox(height: s.md),
            ],
          ],
        ),
      ),
    );
  }
}

/// A failed read, said plainly, with the one thing to do about it.
class VaultRetry extends StatelessWidget {
  final String message;
  final String action;
  final VoidCallback onRetry;
  const VaultRetry({
    super.key,
    required this.message,
    required this.action,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(s.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: CouncilLifeTokens.contractIcon,
              color: context.colors.textMuted,
            ),
            SizedBox(height: s.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.typography.body.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            SizedBox(height: s.sm),
            OutlinedButton.icon(
              style: vaultOutlineStyle(context),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

/// A hairline between groups inside one card.
class VaultDivider extends StatelessWidget {
  const VaultDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
    child: Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.borderSubtle.withValues(alpha: 0),
            context.colors.borderSubtle.withValues(
              alpha: VaultTokens.dividerAlpha,
            ),
            context.colors.borderSubtle.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

/// A soft pool of lamp-light behind a crest, a medal or a coin. Painted past
/// the child's own bounds, so it never changes the layout.
class LampGlow extends StatelessWidget {
  final Widget child;
  final double spread;
  final double alpha;
  const LampGlow({
    super.key,
    required this.child,
    this.spread = VaultTokens.lampSpread,
    this.alpha = VaultTokens.lampAlpha,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LampPainter(spread: spread, alpha: alpha),
    child: child,
  );
}

class _LampPainter extends CustomPainter {
  final double spread;
  final double alpha;
  const _LampPainter({required this.spread, required this.alpha});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * spread;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            VaultTokens.gold.withValues(alpha: alpha),
            VaultTokens.gold.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_LampPainter old) =>
      old.spread != spread || old.alpha != alpha;
}

/// Rays of lamp-light fanning from the centre: behind a newly earned crest
/// until the art pass's rays arrive. [turn] rotates them a little as the
/// reveal plays.
class RaysPainter extends CustomPainter {
  final double turn;
  const RaysPainter({this.turn = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            VaultTokens.gold.withValues(alpha: VaultTokens.raysAlpha * 1.4),
            VaultTokens.gold.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    final ray = Paint()
      ..shader = RadialGradient(
        colors: [
          VaultTokens.goldLight.withValues(alpha: VaultTokens.raysAlpha),
          VaultTokens.goldLight.withValues(alpha: 0),
        ],
      ).createShader(rect);
    const n = VaultTokens.rays;
    for (var i = 0; i < n; i++) {
      final a = turn * 2 * math.pi + i * 2 * math.pi / n;
      final half = (i.isEven ? 0.07 : 0.035) * math.pi;
      final reach = i.isEven ? r : r * 0.78;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(
            c.dx + math.cos(a - half) * reach,
            c.dy + math.sin(a - half) * reach,
          )
          ..lineTo(
            c.dx + math.cos(a + half) * reach,
            c.dy + math.sin(a + half) * reach,
          )
          ..close(),
        ray,
      );
    }
  }

  @override
  bool shouldRepaint(RaysPainter old) => old.turn != turn;
}

/// A dashed gold edge around a ticket: the invite code.
class TicketPainter extends CustomPainter {
  final double radius;
  final Color ground;
  const TicketPainter({required this.radius, required this.ground});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            VaultTokens.gold.withValues(alpha: 0.14),
            VaultTokens.enamel,
          ],
        ).createShader(Offset.zero & size),
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = VaultTokens.gold.withValues(alpha: 0.8);
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, d + VaultTokens.ticketDash),
          dash,
        );
        d += VaultTokens.ticketDash + VaultTokens.ticketGap;
      }
    }
    // The two punched notches of a ticket, cut in the card's own ground.
    for (final x in [0.0, size.width]) {
      final at = Offset(x, size.height / 2);
      canvas.drawCircle(at, VaultTokens.ticketDash, Paint()..color = ground);
      canvas.drawCircle(at, VaultTokens.ticketDash, dash);
    }
  }

  @override
  bool shouldRepaint(TicketPainter old) =>
      old.radius != radius || old.ground != ground;
}

/// Fades the bottom edge of a scroll view while more lies below it, so a
/// hand that scrolls under a pinned action reads as "there is more", never
/// as something cut off. No fade once the end is reached.
class ScrollFadeEdge extends StatefulWidget {
  final Widget child;
  const ScrollFadeEdge({super.key, required this.child});

  @override
  State<ScrollFadeEdge> createState() => _ScrollFadeEdgeState();
}

class _ScrollFadeEdgeState extends State<ScrollFadeEdge> {
  bool _more = false;

  bool _update(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return false;
    final more = metrics.extentAfter > 0.5;
    if (more != _more) setState(() => _more = more);
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _update(n.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _update(n.metrics),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                VaultTokens.goldInk,
                VaultTokens.goldInk,
                _more
                    ? VaultTokens.goldInk.withValues(alpha: 0)
                    : VaultTokens.goldInk,
              ],
              stops: [
                0,
                rect.height <= 0
                    ? 1
                    : (1 - VaultTokens.pinnedFade / rect.height).clamp(
                        0.0,
                        1.0,
                      ),
                1,
              ],
            ).createShader(rect),
            child: widget.child,
          ),
        ),
      );
}
