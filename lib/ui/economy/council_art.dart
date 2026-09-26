import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import 'mafia_coin.dart';

/// Council Life artwork, drawn in code: crisp at every size from a 22 dp seat
/// badge to the celebration, and nothing to download. Public identity only —
/// a rank is earned from matches that are over, and says nothing about a role.

/// Raster art a later art pass may add (see the README in each folder). A
/// file is used only once it is listed in [delivered]; until then, and
/// whenever it fails to decode, the painting stands in, so a missing file
/// never shows a blank or a broken image. council_raster_test keeps the list
/// and the folders on disk in step.
abstract final class CouncilRaster {
  static const council = 'assets/images/council';
  static const storeV3 = 'assets/images/store_v3';

  static String rankTier(int tier) =>
      '$council/rank_tier_${tier.clamp(1, 10).toString().padLeft(2, '0')}.webp';
  static const levelUpRays = '$council/rank_levelup_rays.webp';
  static const leaderboardHeader = '$council/leaderboard_header.webp';
  static String podium(int position) =>
      '$council/leaderboard_podium_$position.webp';
  static const inviteIllustration = '$council/invite_illustration.webp';
  static const inviteRewardBadge = '$council/invite_reward_badge.webp';

  /// The six contract kinds, the weekly contract and the claimed mark.
  static const contractKinds = {
    'finish',
    'town',
    'mafia',
    'win',
    'host',
    'reunion',
    'weekly',
    'bonus_all3',
    'claimed_check',
  };
  static String? contract(String kind) =>
      contractKinds.contains(kind) ? '$council/contract_$kind.webp' : null;

  static const councilSeal = '$storeV3/frame_council_seal.webp';
  static const starterBundle = '$storeV3/starter_bundle_cover.webp';
  static const quietPass = '$storeV3/quiet_pass_cover.webp';
  static const vaultHero = '$storeV3/vault_hero_v3.webp';

  /// Coin pack covers by size: the smallest, middle and largest pack.
  static String coinPack(int index) =>
      '$storeV3/coins_pack_${const ['small', 'medium', 'large'][index.clamp(0, 2)]}.webp';

  /// The files the art pass has delivered, by path. Empty until it lands.
  static const delivered = <String>{};

  static Set<String>? _override;

  /// Whether this build bundles [path].
  static bool has(String path) => (_override ?? delivered).contains(path);

  /// Which files count as bundled, for tests.
  @visibleForTesting
  static set bundledForTest(Set<String>? paths) => _override = paths;
}

/// [path] when the build bundles it, else [fallback] (also on a decode
/// failure). Decorative: never read by a screen reader.
class RasterOr extends StatelessWidget {
  final String? path;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  const RasterOr({
    super.key,
    required this.path,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final asset = path;
    if (asset == null || !CouncilRaster.has(asset)) return fallback;
    final w = width;
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: w == null ? StoreTokens.decodeWidth : (w * ratio).ceil(),
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// The tier a level belongs to: five levels each, 1–10.
int rankTier(int level) => ((level.clamp(1, 50) - 1) ~/ 5) + 1;

/// The title of [tier], in the player's language.
String rankTitle(AppLocalizations l, int tier) => switch (tier) {
  1 => l.rankTier1,
  2 => l.rankTier2,
  3 => l.rankTier3,
  4 => l.rankTier4,
  5 => l.rankTier5,
  6 => l.rankTier6,
  7 => l.rankTier7,
  8 => l.rankTier8,
  9 => l.rankTier9,
  _ => l.rankTier10,
};

/// A rank emblem for [level]. [shimmer] passes one light across it (a newly
/// earned rank); still under reduced motion.
class RankEmblem extends StatefulWidget {
  final int level;
  final double size;
  final bool shimmer;
  const RankEmblem({
    super.key,
    required this.level,
    this.size = CouncilLifeTokens.emblemCard,
    this.shimmer = false,
  });

  @override
  State<RankEmblem> createState() => _RankEmblemState();
}

class _RankEmblemState extends State<RankEmblem>
    with SingleTickerProviderStateMixin {
  AnimationController? _light;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = widget.shimmer && !MediaQuery.disableAnimationsOf(context);
    if (animate && _light == null) {
      _light = AnimationController(
        vsync: this,
        duration: CouncilLifeTokens.shimmer,
      )..forward();
    } else if (!animate && _light != null) {
      _light!.dispose();
      _light = null;
    }
  }

  @override
  void dispose() {
    _light?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tier = rankTier(widget.level);
    final light = _light;
    Widget paint(double sweep) => CustomPaint(
      size: Size.square(widget.size),
      painter: RankEmblemPainter(tier: tier, sweep: sweep),
    );
    return Semantics(
      label: l.rankSemantics(rankTitle(l, tier), widget.level),
      image: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: light == null
              ? RasterOr(
                  path: CouncilRaster.rankTier(tier),
                  width: widget.size,
                  height: widget.size,
                  fallback: paint(-1),
                )
              : AnimatedBuilder(
                  animation: light,
                  builder: (context, _) => paint(light.value),
                ),
        ),
      ),
    );
  }
}

/// The crest: a shield of the tier's metal around a dark field with the
/// council's mask. Bronze tiers carry chevrons, gold tiers a laurel, obsidian
/// tiers a gold trim and a gem, and the tenth a crown.
class RankEmblemPainter extends CustomPainter {
  final int tier;

  /// 0..1 while the shimmer crosses; negative when still.
  final double sweep;
  const RankEmblemPainter({required this.tier, this.sweep = -1});

  static Path shield(Rect r) {
    final w = r.width, h = r.height;
    return Path()
      ..moveTo(r.left + w * 0.5, r.top)
      ..lineTo(r.left + w * 0.92, r.top + h * 0.14)
      ..lineTo(r.left + w * 0.92, r.top + h * 0.5)
      ..quadraticBezierTo(
        r.left + w * 0.9,
        r.top + h * 0.82,
        r.left + w * 0.5,
        r.bottom,
      )
      ..quadraticBezierTo(
        r.left + w * 0.1,
        r.top + h * 0.82,
        r.left + w * 0.08,
        r.top + h * 0.5,
      )
      ..lineTo(r.left + w * 0.08, r.top + h * 0.14)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = tier.clamp(1, 10);
    final metal = CouncilLifeTokens.tierMetal[t - 1];
    final obsidian = t >= 7;
    final trim = t == 10
        ? CouncilLifeTokens.godfatherTrim
        : obsidian
        ? CouncilLifeTokens.obsidianTrim
        : metal[0];
    final s = size.shortestSide;
    final crown = t == 10;
    final top = crown ? s * 0.16 : s * 0.04;
    final outer = Rect.fromLTWH(s * 0.1, top, s * 0.8, s * 0.94 - top);
    final body = shield(outer);

    // Laurel behind the shield for the gold tiers.
    if (t >= 4 && t <= 6) _laurel(canvas, s, metal[1], t - 3);

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [metal[0], metal[1], metal[2]],
        ).createShader(outer),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.035)
        ..color = trim,
    );
    final inner = outer.deflate(s * 0.1);
    final field = shield(inner);
    canvas.drawPath(field, Paint()..color = CouncilLifeTokens.field);
    canvas.drawPath(
      field,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, s * 0.015)
        ..color = trim.withValues(alpha: 0.7),
    );

    // The mask: an almond band with two eyes.
    final mw = inner.width * 0.7;
    final mh = inner.height * 0.2;
    final mc = Offset(inner.center.dx, inner.top + inner.height * 0.36);
    final mask = Path()
      ..moveTo(mc.dx - mw / 2, mc.dy)
      ..quadraticBezierTo(mc.dx - mw / 4, mc.dy - mh, mc.dx, mc.dy - mh * 0.35)
      ..quadraticBezierTo(mc.dx + mw / 4, mc.dy - mh, mc.dx + mw / 2, mc.dy)
      ..quadraticBezierTo(mc.dx + mw / 4, mc.dy + mh, mc.dx, mc.dy + mh * 0.3)
      ..quadraticBezierTo(mc.dx - mw / 4, mc.dy + mh, mc.dx - mw / 2, mc.dy)
      ..close();
    canvas.drawPath(mask, Paint()..color = trim);
    final eye = Paint()..color = CouncilLifeTokens.field;
    for (final dx in [-mw * 0.2, mw * 0.2]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: mc + Offset(dx, 0),
          width: mw * 0.2,
          height: mh * 0.5,
        ),
        eye,
      );
    }

    // Marks under the mask: chevrons count the step within the metal.
    final step = ((t - 1) % 3) + 1;
    if (t <= 9) {
      final chevron = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1, s * 0.04)
        ..color = trim;
      for (var i = 0; i < step; i++) {
        final y = inner.top + inner.height * (0.6 + i * 0.12);
        final half = inner.width * 0.22;
        canvas.drawPath(
          Path()
            ..moveTo(inner.center.dx - half, y)
            ..lineTo(inner.center.dx, y + half * 0.45)
            ..lineTo(inner.center.dx + half, y),
          chevron,
        );
      }
    } else {
      // The Godfather's star.
      _star(
        canvas,
        Offset(inner.center.dx, inner.top + inner.height * 0.7),
        inner.width * 0.18,
        trim,
      );
    }

    if (obsidian) {
      final g = Offset(outer.center.dx, outer.top + s * 0.02);
      final r = s * 0.06;
      final diamond = Path()
        ..moveTo(g.dx, g.dy - r)
        ..lineTo(g.dx + r, g.dy)
        ..lineTo(g.dx, g.dy + r)
        ..lineTo(g.dx - r, g.dy)
        ..close();
      canvas.drawPath(
        diamond,
        Paint()
          ..shader = const RadialGradient(
            colors: [CouncilLifeTokens.gemLight, CouncilLifeTokens.gem],
          ).createShader(Rect.fromCircle(center: g, radius: r)),
      );
      canvas.drawPath(
        diamond,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, s * 0.012)
          ..color = trim,
      );
    }
    if (crown) _crown(canvas, s, trim);

    if (sweep >= 0) {
      canvas.save();
      canvas.clipPath(body);
      final x = outer.left - outer.width + sweep * outer.width * 3;
      canvas.drawRect(
        outer,
        Paint()
          ..shader =
              const LinearGradient(
                colors: [
                  Colors.transparent,
                  CouncilLifeTokens.highlight,
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromLTWH(x, outer.top, outer.width, outer.height),
              ),
      );
      canvas.restore();
    }
  }

  void _laurel(Canvas canvas, double s, Color color, int leaves) {
    final paint = Paint()..color = color;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 2 + leaves; i++) {
        final a = math.pi / 2 + side * (0.5 + i * 0.32);
        final c =
            Offset(s / 2, s * 0.52) +
            Offset(math.cos(a), math.sin(a)) * s * 0.44;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(a + math.pi / 2);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: s * 0.07,
            height: s * 0.15,
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  void _crown(Canvas canvas, double s, Color color) {
    final base = s * 0.2;
    final path = Path()
      ..moveTo(s * 0.3, base)
      ..lineTo(s * 0.28, s * 0.05)
      ..lineTo(s * 0.4, s * 0.12)
      ..lineTo(s * 0.5, s * 0.01)
      ..lineTo(s * 0.6, s * 0.12)
      ..lineTo(s * 0.72, s * 0.05)
      ..lineTo(s * 0.7, base)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(RankEmblemPainter old) =>
      old.tier != tier || old.sweep != sweep;
}

/// Paints a small seat badge for [level] at [centre] (the council table).
void paintSeatRank(Canvas canvas, Offset centre, double side, int level) {
  canvas.save();
  canvas.translate(centre.dx - side / 2, centre.dy - side / 2);
  RankEmblemPainter(tier: rankTier(level)).paint(canvas, Size.square(side));
  canvas.restore();
}

/// The six contract kinds the server names (`metric`).
class ContractIcon extends StatelessWidget {
  final String metric;
  final double size;
  final bool done;
  const ContractIcon({
    super.key,
    required this.metric,
    this.size = CouncilLifeTokens.contractIcon,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RasterOr(
      path: CouncilRaster.contract(metric),
      width: size,
      height: size,
      fallback: CustomPaint(
        size: Size.square(size),
        painter: ContractIconPainter(
          metric: metric,
          ink: done
              ? CouncilLifeTokens.tierMetal[5][0]
              : CouncilLifeTokens.tierMetal[3][1],
          ground: CouncilLifeTokens.field,
        ),
      ),
    ),
  );
}

class ContractIconPainter extends CustomPainter {
  final String metric;
  final Color ink;
  final Color ground;
  const ContractIconPainter({
    required this.metric,
    required this.ink,
    required this.ground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(s / 2, s / 2);
    canvas.drawCircle(c, s / 2, Paint()..color = ground);
    canvas.drawCircle(
      c,
      s / 2 - s * 0.03,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.04
        ..color = ink.withValues(alpha: 0.8),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * CouncilLifeTokens.iconStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    final fill = Paint()..color = ink;
    double u(double v) => v * s;
    switch (metric) {
      case 'finish':
        // An hourglass run out.
        canvas.drawPath(
          Path()
            ..moveTo(u(0.34), u(0.28))
            ..lineTo(u(0.66), u(0.28))
            ..lineTo(u(0.34), u(0.72))
            ..lineTo(u(0.66), u(0.72))
            ..close(),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(u(0.4), u(0.7))
            ..lineTo(u(0.6), u(0.7))
            ..lineTo(u(0.5), u(0.58))
            ..close(),
          fill,
        );
      case 'town':
        // A house under a lantern's light.
        canvas.drawPath(
          Path()
            ..moveTo(u(0.3), u(0.5))
            ..lineTo(u(0.5), u(0.3))
            ..lineTo(u(0.7), u(0.5))
            ..moveTo(u(0.36), u(0.46))
            ..lineTo(u(0.36), u(0.7))
            ..lineTo(u(0.64), u(0.7))
            ..lineTo(u(0.64), u(0.46)),
          line,
        );
        canvas.drawRect(Rect.fromLTRB(u(0.46), u(0.56), u(0.54), u(0.7)), fill);
      case 'mafia':
        // A fedora.
        canvas.drawPath(
          Path()
            ..moveTo(u(0.38), u(0.56))
            ..quadraticBezierTo(u(0.38), u(0.32), u(0.5), u(0.36))
            ..quadraticBezierTo(u(0.62), u(0.32), u(0.62), u(0.56))
            ..close(),
          fill,
        );
        canvas.drawPath(
          Path()
            ..moveTo(u(0.26), u(0.58))
            ..quadraticBezierTo(u(0.5), u(0.68), u(0.74), u(0.58)),
          line,
        );
      case 'win':
        // A laurel wreath.
        for (final side in [-1.0, 1.0]) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: u(0.2)),
            math.pi / 2 + side * 0.3,
            side * 2.3,
            false,
            line,
          );
          for (var i = 0; i < 3; i++) {
            final a = math.pi / 2 + side * (0.7 + i * 0.6);
            final p = c + Offset(math.cos(a), math.sin(a)) * u(0.2);
            canvas.drawCircle(p, u(0.04), fill);
          }
        }
      case 'host':
        // A key.
        canvas.drawCircle(Offset(u(0.38), u(0.5)), u(0.1), line);
        canvas.drawPath(
          Path()
            ..moveTo(u(0.48), u(0.5))
            ..lineTo(u(0.72), u(0.5))
            ..moveTo(u(0.64), u(0.5))
            ..lineTo(u(0.64), u(0.6))
            ..moveTo(u(0.72), u(0.5))
            ..lineTo(u(0.72), u(0.6)),
          line,
        );
      default:
        // Reunion: two linked rings.
        canvas.drawCircle(Offset(u(0.42), u(0.5)), u(0.13), line);
        canvas.drawCircle(Offset(u(0.58), u(0.5)), u(0.13), line);
    }
  }

  @override
  bool shouldRepaint(ContractIconPainter old) =>
      old.metric != metric || old.ink != ink || old.ground != ground;
}

/// How large a seal's studs are for a ring of [radius] and [width].
double councilSealStudRadius(double radius, double width) =>
    math.max(width * 0.35, radius * CouncilLifeTokens.sealStudRatio);

/// The Council Seal frame when drawn as vectors: a wax-red ring, a gold
/// hairline and eight gold studs.
void paintCouncilSeal(
  Canvas canvas,
  Offset centre,
  double radius,
  double width, {
  double opacity = 1,
}) {
  Color a(Color c) => c.withValues(alpha: c.a * opacity);
  canvas.drawCircle(
    centre,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = a(CouncilLifeTokens.sealOuter),
  );
  canvas.drawCircle(
    centre,
    radius - width / 2,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width / 4
      ..color = a(CouncilLifeTokens.sealInner),
  );
  final stud = Paint()..color = a(CouncilLifeTokens.sealStud);
  final studRadius = councilSealStudRadius(radius, width);
  for (var i = 0; i < CouncilLifeTokens.sealStuds; i++) {
    final angle = -math.pi / 2 + i * 2 * math.pi / CouncilLifeTokens.sealStuds;
    canvas.drawCircle(
      centre + Offset(math.cos(angle), math.sin(angle)) * radius,
      studRadius,
      stud,
    );
  }
}

/// The Council Seal as a product picture (store, collection, bundle cover).
class CouncilSealArt extends StatelessWidget {
  final Widget? centre;
  const CouncilSealArt({super.key, this.centre});

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: CustomPaint(
      painter: _SealPainter(),
      child: Center(
        child: FractionallySizedBox(widthFactor: 0.5, child: centre),
      ),
    ),
  );

  /// The frame's product picture: the raster when bundled, else the seal.
  static Widget product() => const RasterOr(
    path: CouncilRaster.councilSeal,
    fallback: CouncilSealArt(),
  );
}

class _SealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    paintCouncilSeal(canvas, size.center(Offset.zero), s * 0.38, s * 0.1);
  }

  @override
  bool shouldRepaint(_SealPainter old) => false;
}

/// The Starter Bundle's cover: the seal around a coin.
class StarterBundleArt extends StatelessWidget {
  final double size;
  const StarterBundleArt({super.key, this.size = CouncilLifeTokens.bundleArt});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: RasterOr(
      path: CouncilRaster.starterBundle,
      width: size,
      height: size,
      fallback: CouncilSealArt(centre: MafiaCoin(size: size / 2)),
    ),
  );
}

/// Coins bursting outward once from the middle of [child] each time
/// [trigger] changes. Nothing under reduced motion.
class CoinBurst extends StatefulWidget {
  final Object? trigger;
  final Widget child;
  const CoinBurst({super.key, required this.trigger, required this.child});

  static const Key burstKey = ValueKey('council_coin_burst');

  @override
  State<CoinBurst> createState() => _CoinBurstState();
}

class _CoinBurstState extends State<CoinBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: CouncilLifeTokens.burst,
  );

  @override
  void didUpdateWidget(CoinBurst old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger &&
        widget.trigger != null &&
        !MediaQuery.disableAnimationsOf(context)) {
      _run.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    // The child keeps the width its parent gives it (a full-width claim).
    fit: StackFit.passthrough,
    children: [
      widget.child,
      IgnorePointer(
        child: AnimatedBuilder(
          animation: _run,
          builder: (context, _) {
            if (!_run.isAnimating) return const SizedBox.shrink();
            final t = Curves.easeOutCubic.transform(_run.value);
            // Centred on the child whatever width the child was given.
            return Center(
              child: SizedBox.square(
                key: CoinBurst.burstKey,
                dimension: 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < CouncilLifeTokens.burstCoins; i++)
                      Transform.translate(
                        offset:
                            Offset(
                                  math.cos(
                                    i *
                                        2 *
                                        math.pi /
                                        CouncilLifeTokens.burstCoins,
                                  ),
                                  math.sin(
                                    i *
                                        2 *
                                        math.pi /
                                        CouncilLifeTokens.burstCoins,
                                  ),
                                ) *
                                CouncilLifeTokens.burstReach *
                                t -
                            const Offset(
                              CouncilLifeTokens.burstCoin / 2,
                              CouncilLifeTokens.burstCoin / 2,
                            ),
                        child: Opacity(
                          opacity: 1 - _run.value,
                          child: const MafiaCoin(
                            size: CouncilLifeTokens.burstCoin,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
