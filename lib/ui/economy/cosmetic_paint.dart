import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/asset_constants.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'cosmetics.dart';
import 'council_art.dart';
import 'cosmetic_art_cache.dart';
import 'store_art.dart';

/// Draws a purchased frame around a seat of [diameter] centred on [centre].
/// Shared by the council painter and the store preview, so what is sold is
/// exactly what the table shows.
void paintCosmeticFrame(
  Canvas canvas,
  Offset centre,
  double diameter,
  FrameStyle style, {
  double opacity = 1,
  double? maxSide,
}) {
  final art = CosmeticArtCache.images[style.artCode];
  if (art != null) {
    // The art's empty centre sits just inside the seat's rim, so the frame
    // replaces the rim instead of covering the face.
    final side = math.min(
      diameter * CosmeticTokens.frameApertureCover / style.aperture,
      maxSide ?? double.infinity,
    );
    paintImage(
      canvas: canvas,
      rect: Rect.fromCenter(center: centre, width: side, height: side),
      image: art,
      fit: BoxFit.contain,
      opacity: opacity,
      filterQuality: FilterQuality.medium,
    );
    return;
  }
  final width = diameter * CosmeticTokens.frameWidthRatio;
  final gap = diameter * CosmeticTokens.frameGapRatio;
  final radius = diameter / 2 + gap + width / 2;
  if (style.artCode == 'frame_council_seal') {
    // Vector by design: kept inside the same box the drawn frames respect.
    final studs = councilSealStudRadius(radius, width);
    final reach = math.max(width / 2, studs);
    final fitted = maxSide == null
        ? radius
        : math.min(radius, maxSide / 2 - reach - StoreTokens.hairlineOverlap);
    paintCouncilSeal(canvas, centre, fitted, width, opacity: opacity);
    return;
  }
  final fittedRadius = maxSide == null
      ? radius
      : math.min(radius, maxSide / 2 - width / 2 - StoreTokens.hairlineOverlap);
  canvas.drawCircle(
    centre,
    fittedRadius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = style.outer.withValues(alpha: style.outer.a * opacity),
  );
  canvas.drawCircle(
    centre,
    fittedRadius - width / 2,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width / 3
      ..color = style.inner.withValues(alpha: style.inner.a * opacity),
  );
}

/// The colour a name is written in on [style]: light on the drawn plate's
/// charcoal field, the vector plate's own colour if the art is missing.
Color plateTextColor(PlateStyle style) =>
    CosmeticArtCache.images.containsKey(style.artCode)
    ? style.onArt
    : style.text;

/// Paints the plate behind a name label of [size] whose top-left is [origin].
void paintCosmeticPlate(
  Canvas canvas,
  Offset origin,
  Size size,
  PlateStyle style, {
  double opacity = 1,
}) {
  final art = CosmeticArtCache.images[style.artCode];
  if (art != null) {
    _paintPlateArt(canvas, origin & size, art, style, opacity);
    return;
  }
  const pad = CosmeticTokens.platePadding;
  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(
      origin.dx - pad * 2,
      origin.dy - pad / 2,
      size.width + pad * 4,
      size.height + pad,
    ),
    const Radius.circular(CosmeticTokens.plateRadius),
  );
  canvas.drawRRect(
    rect,
    Paint()..color = style.fill.withValues(alpha: style.fill.a * opacity),
  );
  canvas.drawRRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = CosmeticTokens.plateBorderWidth
      ..color = style.border.withValues(alpha: style.border.a * opacity),
  );
}

/// The plate art sized so the name's glyphs fill its flat field, in five
/// slices: both ornamented ends and the centre finial keep their aspect, and
/// only the plain field on either side of the finial stretches with the name.
void _paintPlateArt(
  Canvas canvas,
  Rect text,
  ui.Image art,
  PlateStyle style,
  double opacity,
) {
  final w = art.width.toDouble();
  final h = art.height.toDouble();
  final height = text.height * CosmeticTokens.plateGlyphShare / style.field;
  final scale = height / h;
  final capSrc = w * style.cap;
  final centreSrc = w * CosmeticTokens.plateCentre;
  final fillSrc = (w - centreSrc) / 2 - capSrc;
  final cap = capSrc * scale;
  final centre = centreSrc * scale;
  final pad = text.height * CosmeticTokens.plateGlyphShare / 2;
  final width = math.max(text.width + pad * 2 + cap * 2, cap * 2 + centre);
  final fill = (width - cap * 2 - centre) / 2;
  final left = text.center.dx - width / 2;
  final top = text.center.dy - height / 2;
  final paint = Paint()
    ..filterQuality = FilterQuality.medium
    ..color = Color.fromRGBO(0, 0, 0, opacity);
  // A hair of overlap so no seam shows between slices.
  const seam = StoreTokens.hairlineOverlap;
  var x = left;
  for (final (from, src, dst) in [
    (0.0, capSrc, cap),
    (capSrc, fillSrc, fill),
    (capSrc + fillSrc, centreSrc, centre),
    (capSrc + fillSrc + centreSrc, fillSrc, fill),
    (w - capSrc, capSrc, cap),
  ]) {
    if (dst > 0) {
      canvas.drawImageRect(
        art,
        Rect.fromLTWH(from, 0, src, h),
        Rect.fromLTWH(x, top, dst + seam, height),
        paint,
      );
    }
    x += dst;
  }
}

/// A seat as the table draws it, with a frame and a nameplate: the store's
/// preview of identity items.
class SeatPreview extends StatefulWidget {
  final String name;
  final String? frame;
  final String? plate;
  final String avatar;
  const SeatPreview({
    super.key,
    required this.name,
    this.frame,
    this.plate,
    this.avatar = AppCouncilArt.avatarMale,
  });

  @override
  State<SeatPreview> createState() => _SeatPreviewState();
}

class _SeatPreviewState extends State<SeatPreview> {
  @override
  void initState() {
    super.initState();
    // Painters repaint through [CosmeticArtCache.revision]; the name colour
    // is rebuilt here once the plate art has arrived.
    CosmeticArtCache.revision.addListener(_arrived);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    CosmeticArtCache.load(DefaultAssetBundle.of(context).load);
  }

  void _arrived() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CosmeticArtCache.revision.removeListener(_arrived);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const diameter = CosmeticTokens.previewAvatar;
    final plateStyle = widget.plate == null
        ? null
        : Cosmetics.plates[widget.plate];
    final text = context.typography.bodySmall.copyWith(
      color: plateStyle == null
          ? context.colors.textSecondary
          : plateTextColor(plateStyle),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: diameter * CosmeticTokens.previewFrameBox,
          child: CustomPaint(
            foregroundPainter: CosmeticFramePainter(
              widget.frame == null ? null : Cosmetics.frames[widget.frame],
              diameter,
            ),
            child: Center(
              child: ClipOval(
                child: Image.asset(
                  widget.avatar,
                  width: diameter,
                  height: diameter,
                  cacheWidth: StoreTokens.frameDecodeWidth,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: context.spacing.md),
        CustomPaint(
          painter: plateStyle == null ? null : CosmeticPlatePainter(plateStyle),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: CosmeticTokens.previewAvatar * 2,
            ),
            child: Text(
              widget.name,
              style: text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

/// The one frame painter: the store preview, the identity ring and the table
/// preview all draw through [paintCosmeticFrame] here.
class CosmeticFramePainter extends CustomPainter {
  final FrameStyle? style;
  final double diameter;
  CosmeticFramePainter(this.style, this.diameter)
    : super(repaint: CosmeticArtCache.revision);

  @override
  void paint(Canvas canvas, Size size) {
    final style = this.style;
    if (style == null) return;
    paintCosmeticFrame(canvas, size.center(Offset.zero), diameter, style);
  }

  @override
  bool shouldRepaint(CosmeticFramePainter old) =>
      old.style != style || old.diameter != diameter;
}

/// The one plate painter behind a name, shared by every identity placement.
class CosmeticPlatePainter extends CustomPainter {
  final PlateStyle style;
  CosmeticPlatePainter(this.style) : super(repaint: CosmeticArtCache.revision);
  @override
  void paint(Canvas canvas, Size size) =>
      paintCosmeticPlate(canvas, Offset.zero, size, style);
  @override
  bool shouldRepaint(CosmeticPlatePainter old) => old.style != style;
}

/// A public backdrop dressed by a presentation pack: its scene over the
/// graded [child], a veil and an overlay. [showArt] false keeps [child]'s own
/// picture (the result screen's outcome art) and only grades it.
///
/// Callers pass a pack only in public phases (`cosmeticsVisibleIn`), so a
/// purchased scene never reaches a night or reveal surface.
class PackBackdrop extends StatelessWidget {
  final PresentationPack? pack;
  final Widget child;
  final bool showArt;
  const PackBackdrop({
    super.key,
    required this.pack,
    required this.child,
    this.showArt = true,
  });

  static const Key artKey = ValueKey('pack_backdrop_art');

  @override
  Widget build(BuildContext context) {
    final pack = this.pack;
    if (pack == null) return child;
    final art = showArt ? StoreArt.forCode(pack.code) : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.matrix(pack.grade),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (art != null)
                Image.asset(
                  art,
                  key: artKey,
                  fit: BoxFit.cover,
                  cacheWidth: StoreTokens.decodeWidth,
                  opacity: const AlwaysStoppedAnimation(
                    CosmeticTokens.packArtOpacity,
                  ),
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
        ColoredBox(color: pack.veil),
        Opacity(
          opacity: CosmeticTokens.packOverlayOpacity,
          child: Image.asset(pack.overlay, fit: BoxFit.cover),
        ),
      ],
    );
  }
}

/// The pack's transition, played once each time [trigger] changes. Draws
/// over the table and takes no input; reduced motion shows nothing.
class PackTransitionOverlay extends StatefulWidget {
  final PresentationPack? pack;
  final Object? trigger;
  const PackTransitionOverlay({
    super.key,
    required this.pack,
    required this.trigger,
  });

  static const Key overlayKey = ValueKey('pack_transition');

  @override
  State<PackTransitionOverlay> createState() => _PackTransitionOverlayState();
}

class _PackTransitionOverlayState extends State<PackTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run;

  @override
  void initState() {
    super.initState();
    _run = AnimationController(
      vsync: this,
      duration: CosmeticTokens.transitionDuration,
    );
  }

  @override
  void didUpdateWidget(PackTransitionOverlay old) {
    super.didUpdateWidget(old);
    if (widget.pack == null || MediaQuery.disableAnimationsOf(context)) {
      _run.stop();
      return;
    }
    if (old.trigger != widget.trigger && widget.pack != null) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      _run.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    if (pack == null || MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _run,
        builder: (context, _) {
          if (!_run.isAnimating) return const SizedBox.shrink();
          return CustomPaint(
            key: PackTransitionOverlay.overlayKey,
            size: Size.infinite,
            painter: _TransitionPainter(pack.transition, _run.value),
          );
        },
      ),
    );
  }
}

class _TransitionPainter extends CustomPainter {
  final PackTransition kind;
  final double t;
  _TransitionPainter(this.kind, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Rises and falls once; never a flash.
    final strength = math.sin(t * math.pi);
    switch (kind) {
      case PackTransition.candle:
        const glow = CosmeticTokens.transitionCandle;
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              colors: [
                glow.withValues(alpha: glow.a * strength),
                glow.withValues(alpha: 0),
              ],
            ).createShader(rect),
        );
      case PackTransition.sweep:
        const beam = CosmeticTokens.transitionSweep;
        final x =
            size.width *
            (t * CosmeticTokens.sweepTravel - CosmeticTokens.sweepStart);
        final band = size.width * CosmeticTokens.sweepBand;
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              colors: [
                beam.withValues(alpha: 0),
                beam.withValues(alpha: beam.a * strength),
                beam.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromLTWH(x - band / 2, 0, band, size.height)),
        );
      case PackTransition.moonlight:
        // Cool light settling from above, then lifting.
        const moon = CosmeticTokens.transitionMoonlight;
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                moon.withValues(alpha: moon.a * strength),
                moon.withValues(alpha: 0),
              ],
            ).createShader(rect),
        );
    }
  }

  @override
  bool shouldRepaint(_TransitionPainter old) => old.t != t || old.kind != kind;
}

/// A short line on screen from the room's narrator or pack. The same text on
/// every device; nothing waits for it.
class NarrationCaption extends StatelessWidget {
  final String? text;

  /// The narrator pack whose look the line wears (store truth): its ground,
  /// rule, ink and marker. Null is the neutral caption (a presentation pack's
  /// own intro/outro line, or the night line).
  final NarratorPack? narrator;
  const NarrationCaption({super.key, required this.text, this.narrator});

  static const Key captionKey = ValueKey('narration_caption');
  static Key markerKey(String code) => ValueKey('narration_marker_$code');

  @override
  Widget build(BuildContext context) {
    final line = text;
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : context.motion.standard,
      child: line == null ? const SizedBox.shrink() : _line(context, line),
    );
  }

  Widget _line(BuildContext context, String line) {
    final look = narrator?.look;
    final text = Text(
      line,
      key: captionKey,
      textAlign: TextAlign.center,
      style: context.typography.body.copyWith(
        color: look?.ink ?? context.colors.textPrimary,
        fontStyle: (look?.italic ?? true) ? FontStyle.italic : FontStyle.normal,
      ),
    );
    return Container(
      key: ValueKey(line),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: look?.ground ?? context.colors.surfaceOverlay,
        borderRadius: BorderRadius.circular(context.radii.card),
        border: look == null
            ? null
            : Border.all(
                color: look.rule,
                width: StoreTruthTokens.narratorBorderWidth,
              ),
      ),
      child: look == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KeyedSubtree(
                  key: markerKey(narrator!.code),
                  child: look.markerAsset == null
                      ? Icon(
                          look.marker,
                          size: StoreTruthTokens.narratorMarker,
                          color: look.rule,
                        )
                      : Image.asset(
                          look.markerAsset!,
                          width: StoreTruthTokens.narratorMarker,
                          height: StoreTruthTokens.narratorMarker,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => Icon(
                            look.marker,
                            size: StoreTruthTokens.narratorMarker,
                            color: look.rule,
                          ),
                        ),
                ),
                SizedBox(width: context.spacing.sm),
                Flexible(child: text),
              ],
            ),
    );
  }
}

/// A player's own avatar dressed with their equipped frame (store truth).
///
/// Reuses [CosmeticFramePainter], so the ring a buyer sees on Profile, Home,
/// friends, the lobby and the result is exactly the one the table draws.
/// [frame] null draws [child] alone. Callers pass a frame only where
/// `cosmeticsVisibleIn` allows it; nothing here reads a phase.
class CosmeticFrameRing extends StatefulWidget {
  final String? frame;
  final double diameter;
  final Widget child;
  const CosmeticFrameRing({
    super.key,
    required this.frame,
    required this.diameter,
    required this.child,
  });

  static const Key ringKey = ValueKey('cosmetic_frame_ring');

  @override
  State<CosmeticFrameRing> createState() => _CosmeticFrameRingState();
}

class _CosmeticFrameRingState extends State<CosmeticFrameRing> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    CosmeticArtCache.load(DefaultAssetBundle.of(context).load);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.frame == null ? null : Cosmetics.frames[widget.frame];
    if (style == null) return widget.child;
    final box = widget.diameter * CosmeticTokens.previewFrameBox;
    return SizedBox.square(
      key: CosmeticFrameRing.ringKey,
      dimension: box,
      child: CustomPaint(
        foregroundPainter: CosmeticFramePainter(style, widget.diameter),
        child: Center(
          child: SizedBox.square(
            dimension: widget.diameter,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A player's own name dressed with their equipped nameplate, drawn by
/// [CosmeticPlatePainter]. [plate] null is the plain [style] text.
class CosmeticNameplate extends StatefulWidget {
  final String name;
  final String? plate;
  final TextStyle style;
  final TextAlign? textAlign;
  const CosmeticNameplate({
    super.key,
    required this.name,
    required this.plate,
    required this.style,
    this.textAlign,
  });

  static const Key plateKey = ValueKey('cosmetic_nameplate');

  @override
  State<CosmeticNameplate> createState() => _CosmeticNameplateState();
}

class _CosmeticNameplateState extends State<CosmeticNameplate> {
  @override
  void initState() {
    super.initState();
    CosmeticArtCache.revision.addListener(_arrived);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    CosmeticArtCache.load(DefaultAssetBundle.of(context).load);
  }

  void _arrived() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CosmeticArtCache.revision.removeListener(_arrived);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.plate == null ? null : Cosmetics.plates[widget.plate];
    final text = Text(
      widget.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: widget.textAlign,
      style: style == null
          ? widget.style
          : widget.style.copyWith(color: plateTextColor(style)),
    );
    if (style == null) return text;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CosmeticTokens.platePadding * 2,
      ),
      child: CustomPaint(
        key: CosmeticNameplate.plateKey,
        painter: CosmeticPlatePainter(style),
        child: text,
      ),
    );
  }
}
