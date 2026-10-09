import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../../platform/monetization/ad_formats.dart' show BannerPlacement;
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';
import '../../widgets/experience_surface.dart';

/// «هتلعب إيه؟», the one screen behind Home's «ابدأ اللعبة».
///
/// Two playing cards, fanned like Home's: the Mafia and the stories. The
/// stories card opens its hub. The Mafia card lifts to the top, turns over,
/// and deals the ways to play out of itself as three small cards — with
/// friends on one phone, online on everyone's own phone, alone against the
/// computer — each saying how many can play. Back (the header arrow, the
/// rim button, or the turned card itself) runs it all in reverse.
///
/// Motion is transform and opacity only, over repaint boundaries, so the
/// cards are painted once and the compositor moves them. With animations
/// switched off every state is simply there. Online without a server stays
/// on its card, explained, rather than vanishing.
class ModeScreen extends StatefulWidget {
  /// One phone, passed around. The existing setup flow.
  final VoidCallback onPlayOffline;

  /// Everybody on their own phone. Null only when this build has no project,
  /// which draws the card explained rather than absent.
  final VoidCallback? onPlayOnline;

  /// Alone, the other seats played by the computer.
  final VoidCallback? onPlayBots;

  /// «قصص وتحقيقات»: a case to crack. Null hides the card.
  final VoidCallback? onPlayStories;

  /// Back to Home.
  final VoidCallback onBack;

  const ModeScreen({
    super.key,
    required this.onPlayOffline,
    required this.onPlayOnline,
    this.onPlayBots,
    this.onPlayStories,
    required this.onBack,
  });

  static const Key mafiaCard = ValueKey('mode_mafia');
  static const Key offlineCard = ValueKey('mode_offline');
  static const Key onlineCard = ValueKey('mode_online');
  static const Key botsCard = ValueKey('mode_bots');
  static const Key storiesCard = ValueKey('mode_stories');
  static const Key unavailableText = ValueKey('mode_unavailable');
  static const Key closeButton = ValueKey('mode_close');

  /// A story's scene rather than a face: the case, not a character.
  static const String storiesArt = 'assets/images/stories/covers/cover_01.webp';

  @override
  State<ModeScreen> createState() => _ModeScreenState();
}

class _ModeScreenState extends State<ModeScreen> with TickerProviderStateMixin {
  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: ModeTokens.deal,
  );
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: ModeTokens.open,
  );
  bool _isOpen = false;
  bool _started = false;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _still ? _deal.value = 1 : _deal.forward();
  }

  @override
  void dispose() {
    _deal.dispose();
    _open.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    if (_isOpen == open) return;
    setState(() => _isOpen = open);
    if (_still) {
      _open.value = open ? 1 : 0;
    } else if (open) {
      _open.forward();
    } else {
      _open.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DeckScaffold(
      title: _isOpen ? l10n.modeMafiaTitle : l10n.modeTitle,
      onBack: _isOpen ? () => _setOpen(false) : widget.onBack,
      banner: BannerPlacement.home,
      body: LayoutBuilder(
        builder: (context, box) => _stage(context, box.biggest),
      ),
    );
  }

  Widget _stage(BuildContext context, Size size) {
    final l10n = context.l10n;
    final s = context.spacing;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // The Mafia card sits on the reading side's start, as on Home's fan.
    final dir = rtl ? 1.0 : -1.0;
    final w = size.width;
    final h = size.height;

    final cw = math.min(
      w * ModeTokens.cardWidth,
      h * ModeTokens.cardMaxHeight / ModeTokens.cardAspect,
    );
    final ch = cw * ModeTokens.cardAspect;
    final closedTop = math.max(0.0, (h - ch) / 2 - s.lg);
    final mafiaX = w / 2 + dir * ModeTokens.fanSpread * cw;
    final storiesX = w / 2 - dir * ModeTokens.fanSpread * cw;
    final openCenterY = ch * ModeTokens.openScale / 2;

    final ways = <_Way>[
      _Way(
        key: ModeScreen.offlineCard,
        art: ExperienceArt.council,
        face: false,
        title: l10n.modeOnePhoneTitle,
        body: l10n.modeOnePhoneBody,
        onTap: widget.onPlayOffline,
      ),
      _Way(
        key: ModeScreen.onlineCard,
        art: AppImages.cardFaceDoctor,
        face: true,
        title: l10n.modeOnlineTitle,
        body: l10n.modeOnlineBody,
        onTap: widget.onPlayOnline,
        lockedReason: widget.onPlayOnline == null ? l10n.modeNoServer : null,
      ),
      if (widget.onPlayBots != null)
        _Way(
          key: ModeScreen.botsCard,
          art: AppImages.cardFaceCitizen,
          face: true,
          title: l10n.modeBotsCardTitle,
          body: l10n.modeBotsBody,
          onTap: widget.onPlayBots,
        ),
    ];
    final mw = math.min(
      ModeTokens.wayMaxWidth,
      (w - ModeTokens.wayGap * (ways.length - 1)) / 3,
    );
    final waysTop = ch * ModeTokens.openScale + s.lg;
    // As tall as the room under the turned card allows, down to the line
    // that names them and the way back.
    final mh = math.min(
      mw * ModeTokens.wayAspect,
      h - waysTop - s.md - ModeTokens.pickLine - DeckTokens.rim - s.md * 2,
    );
    final step = mw + ModeTokens.wayGap;
    final firstX = w / 2 + dir * step * (ways.length - 1) / 2;

    final dealt = CurvedAnimation(parent: _deal, curve: Curves.easeOutCubic);
    final lift = CurvedAnimation(
      parent: _open,
      curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
    );
    final flip = CurvedAnimation(
      parent: _open,
      curve: const Interval(0.16, 0.8, curve: Curves.easeInOutCubic),
    );
    final last = CurvedAnimation(
      parent: _open,
      curve: const Interval(0.8, 1, curve: Curves.easeOut),
    );

    final mafiaFront = RepaintBoundary(
      child: _PlayCard(
        art: AppImages.cardFaceMafia,
        width: cw,
        title: l10n.modeMafiaTitle,
        body: l10n.modeMafiaBody,
      ),
    );
    final mafiaBack = RepaintBoundary(
      child: _PlayCard(
        art: AppImages.cardBack,
        width: cw,
        title: l10n.modeMafiaTitle,
      ),
    );
    final stories = RepaintBoundary(
      child: _PlayCard(
        art: ModeScreen.storiesArt,
        width: cw,
        title: l10n.modeStoriesCardTitle,
        body: l10n.modeStoriesCardBody,
        ruqaa: true,
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // «دوس على كارت» while nothing is chosen.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: ReverseAnimation(lift),
            child: Text(
              l10n.modeHint,
              textAlign: TextAlign.center,
              style: DeckTokens.meta(
                context.typography,
              ).copyWith(color: context.colors.textMuted),
            ),
          ),
        ),
        if (widget.onPlayStories != null)
          AnimatedBuilder(
            animation: Listenable.merge([_deal, _open]),
            child: IgnorePointer(
              ignoring: _isOpen,
              child: DeckPress(
                child: GestureDetector(
                  key: ModeScreen.storiesCard,
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onPlayStories,
                  child: stories,
                ),
              ),
            ),
            builder: (context, child) {
              final d = 1 - dealt.value;
              final t = lift.value;
              return Positioned(
                left: storiesX - cw / 2,
                top: closedTop,
                width: cw,
                height: ch,
                child: Opacity(
                  opacity: (dealt.value * (1 - t)).clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(
                      -dir * (ModeTokens.exitSpread * cw * t) +
                          dir * ModeTokens.dealSpread * d,
                      ModeTokens.fanDrop +
                          ModeTokens.exitDrop * t +
                          ModeTokens.dealRise * d,
                    ),
                    child: Transform.rotate(
                      angle:
                          -dir * ModeTokens.fanTilt -
                          dir * (ModeTokens.exitTilt - ModeTokens.fanTilt) * t +
                          dir * ModeTokens.dealTilt * d,
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
        AnimatedBuilder(
          animation: Listenable.merge([_deal, _open]),
          builder: (context, _) {
            final d = 1 - Interval(
              0.12,
              1,
              curve: Curves.easeOutCubic,
            ).transform(_deal.value);
            final t = lift.value;
            final angle = math.pi * flip.value;
            final showBack = angle > math.pi / 2;
            final cy = closedTop + ch / 2;
            final x = mafiaX + (w / 2 - mafiaX) * t - dir * ModeTokens.dealSpread * d;
            final y = cy + (openCenterY - cy) * t + ModeTokens.dealRise * d;
            final scale = 1 - (1 - ModeTokens.openScale) * t;
            return Positioned(
              left: x - cw / 2,
              top: y - ch / 2,
              width: cw,
              height: ch,
              child: Opacity(
                opacity: (1 - d).clamp(0, 1),
                child: Transform.rotate(
                  angle: dir * ModeTokens.fanTilt * (1 - t) -
                      dir * ModeTokens.dealTilt * d,
                  child: Transform.scale(
                    scale: scale,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, ModeTokens.perspective)
                        ..rotateY(showBack ? angle - math.pi : angle),
                      child: DeckPress(
                        child: GestureDetector(
                          key: ModeScreen.mafiaCard,
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _setOpen(!_isOpen),
                          child: showBack ? mafiaBack : mafiaFront,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        for (final (i, way) in ways.indexed)
          _dealtWay(
            way: way,
            index: i,
            width: mw,
            height: mh,
            centerX: firstX - dir * step * i,
            top: waysTop - (i == 1 && ways.length == 3 ? ModeTokens.wayLift : 0),
            fromX: w / 2,
            fromY: openCenterY,
            tilt: ways.length == 3 ? dir * ModeTokens.fanTilt * (1 - i) : 0,
          ),
        // What the small cards are, then the way back.
        Positioned(
          top: waysTop + mh + s.md,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: last,
            child: Text(
              l10n.modeMafiaPick,
              textAlign: TextAlign.center,
              style: DeckTokens.body(
                context.typography,
              ).copyWith(color: context.colors.textSecondary),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: s.md,
          child: IgnorePointer(
            ignoring: !_isOpen,
            child: FadeTransition(
              opacity: last,
              child: RimButton(
                key: ModeScreen.closeButton,
                label: l10n.back,
                onPressed: () => _setOpen(false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One way to play, dealt out of the turned Mafia card: it starts small
  /// at the card's centre and lands in its place, a beat after the last.
  Widget _dealtWay({
    required _Way way,
    required int index,
    required double width,
    required double height,
    required double centerX,
    required double top,
    required double fromX,
    required double fromY,
    required double tilt,
  }) {
    final start = 0.5 + 0.07 * index;
    final t = CurvedAnimation(
      parent: _open,
      curve: Interval(start, math.min(1, start + 0.45), curve: Curves.easeOutCubic),
    );
    final appear = CurvedAnimation(
      parent: _open,
      curve: Interval(start, math.min(1, start + 0.15)),
    );
    final card = RepaintBoundary(
      child: _WayCard(way: way, width: width, height: height),
    );
    return Positioned(
      left: centerX - width / 2,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        ignoring: !_isOpen,
        child: AnimatedBuilder(
          animation: _open,
          child: card,
          builder: (context, child) {
            final v = t.value;
            return Opacity(
              opacity: appear.value,
              child: Transform.translate(
                offset: Offset(
                  (fromX - centerX) * (1 - v),
                  (fromY - top - height / 2) * (1 - v),
                ),
                child: Transform.rotate(
                  angle: tilt * v,
                  child: Transform.scale(
                    scale: ModeTokens.wayStartScale +
                        (1 - ModeTokens.wayStartScale) * v,
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Way {
  final Key key;
  final String art;
  final bool face;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final String? lockedReason;

  const _Way({
    required this.key,
    required this.art,
    required this.face,
    required this.title,
    required this.body,
    required this.onTap,
    this.lockedReason,
  });
}

/// A big playing card: the art full bleed, Home's inner frame, the name on
/// the card's foot over a fade into the ground.
class _PlayCard extends StatelessWidget {
  final String art;
  final double width;
  final String title;
  final String? body;
  final bool ruqaa;

  const _PlayCard({
    required this.art,
    required this.width,
    required this.title,
    this.body,
    this.ruqaa = false,
  });

  @override
  Widget build(BuildContext context) {
    final type = context.typography;
    final colors = context.colors;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final radius = BorderRadius.circular(context.radii.card);
    final heading = DeckTokens.card(
      type,
    ).copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: ModeTokens.shadow,
            blurRadius: ModeTokens.shadowBlur,
            offset: ModeTokens.shadowOffset,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: ResizeImage(
                AssetImage(art),
                width: (width * dpr).round(),
              ),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(ModeTokens.frameInset),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ModeTokens.frameRadius),
                    border: Border.all(
                      color: DeckTokens.bone.withValues(
                        alpha: DeckTokens.hairlineAlpha,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      DeckTokens.ground.withValues(alpha: 0),
                      DeckTokens.ground,
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.spacing.sm,
                    context.spacing.xl,
                    context.spacing.sm,
                    context.spacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: ruqaa ? StoryTokens.ruqaa(heading) : heading,
                      ),
                      if (body != null)
                        Text(
                          body!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DeckTokens.meta(
                            type,
                          ).copyWith(color: colors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the three small cards: the way's face or scene on top, feathered
/// into the panel, its name and who it is for underneath.
class _WayCard extends StatelessWidget {
  final _Way way;
  final double width;
  final double height;

  const _WayCard({required this.way, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final locked = way.lockedReason != null;
    final radius = BorderRadius.circular(context.radii.button);
    final artHeight = height * ModeTokens.wayArt;
    Widget art = Image(
      image: ResizeImage(
        AssetImage(way.art),
        width: (width * dpr * (way.face ? ModeTokens.faceZoom : 1)).round(),
      ),
      fit: BoxFit.cover,
      alignment: way.face ? ModeTokens.faceFocus : Alignment.center,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
    if (way.face) {
      art = Transform.scale(
        scale: ModeTokens.faceZoom * 0.8,
        alignment: ModeTokens.faceFocus,
        child: art,
      );
    }
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: radius,
        border: Border.all(
          color: DeckTokens.bone.withValues(alpha: DeckTokens.hairlineAlpha),
        ),
        boxShadow: const [
          BoxShadow(
            color: ModeTokens.shadow,
            blurRadius: ModeTokens.wayShadowBlur,
            offset: ModeTokens.wayShadowOffset,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: artHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: locked ? DeckTokens.lockedArtAlpha : 1,
                    child: ClipRect(child: art),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.surfaceRaised.withValues(alpha: 0),
                          colors.surfaceRaised,
                        ],
                        stops: const [1 - DeckTokens.featherFraction, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: s.xs),
                // As many lines of the meta as the card has room for: a short
                // phone keeps the name and loses the second line, never the
                // other way round.
                child: LayoutBuilder(
                  builder: (context, box) {
                    final titleStyle = DeckTokens.body(type).copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    );
                    final metaStyle = DeckTokens.meta(type).copyWith(
                      color: locked ? colors.textMuted : colors.textSecondary,
                    );
                    final titleHeight =
                        titleStyle.fontSize! * titleStyle.height!;
                    final lineHeight = metaStyle.fontSize! * metaStyle.height!;
                    final lines = ((box.maxHeight - titleHeight) / lineHeight)
                        .floor()
                        .clamp(0, locked ? 3 : 2);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          way.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        if (lines > 0)
                          Text(
                            locked ? way.lockedReason! : way.body,
                            key: locked ? ModeScreen.unavailableText : null,
                            textAlign: TextAlign.center,
                            maxLines: lines,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return DeckPress(
      enabled: !locked && way.onTap != null,
      child: GestureDetector(
        key: way.key,
        behavior: HitTestBehavior.opaque,
        onTap: locked ? null : way.onTap,
        child: card,
      ),
    );
  }
}
