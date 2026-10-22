import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../economy/mafia_coin.dart';
import '../../economy/waiting_banner.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../back_action.dart';
import '../mafia_public.dart';
import 'deck_buttons.dart';

export 'deck_rise.dart';

export 'deck_buttons.dart';

/// The deck's public pieces (docs/design/DECK-SYSTEM.md): cards with a
/// character in an arched window, rows, sheets, pills, the value button and
/// the scaffold every new public screen stands on.
///
/// **Public only.** Nothing here may be imported by a pass-the-phone, reveal,
/// night or day surface; the hand-off purity test enforces it.

/// The value button: struck gold, always with the coin and the amount in its
/// label. Only where coins are spent or earned.
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool inRow;

  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.inRow = false,
  });

  @override
  Widget build(BuildContext context) {
    final type = context.typography;
    final radius = BorderRadius.circular(context.radii.button);
    final button = SizedBox(
      height: inRow ? DeckTokens.goldInRow : DeckTokens.primaryHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              DeckTokens.goldLight,
              DeckTokens.gold,
              DeckTokens.goldDeep,
            ],
            stops: DeckTokens.goldStops,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MafiaCoin(size: DeckTokens.coinGlyph),
                  SizedBox(width: context.spacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DeckTokens.body(type).copyWith(
                        color: DeckTokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return onPressed == null
        ? Opacity(opacity: DeckTokens.disabledAlpha, child: button)
        : button;
  }
}

/// A character (or a scene) in the card's arched window: a silver hairline,
/// a round top, the bottom feathered into the panel behind it.
class ArtWindow extends StatelessWidget {
  final String asset;
  final Size size;
  final Alignment focus;
  final double zoom;
  final bool dimmed;

  const ArtWindow({
    super.key,
    required this.asset,
    this.size = DeckTokens.windowList,
    this.focus = Alignment.center,
    this.zoom = 1,
    this.dimmed = false,
  });

  /// The asset decoded to fit a square a little larger than the window
  /// needs at this zoom, whichever way the source is oriented: a fraction of
  /// the source's pixels, so the texture is small and the first frame quick.
  ImageProvider _decoded(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final side = (size.longestSide * zoom * dpr * DeckTokens.artDecodeHeadroom)
        .round();
    return ResizeImage(
      AssetImage(asset),
      width: side,
      height: side,
      policy: ResizeImagePolicy.fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final arch = BorderRadius.vertical(
      top: Radius.circular(size.width / 2),
      bottom: Radius.circular(context.radii.button / 2),
    );
    final panel = context.colors.surfaceRaised;
    return SizedBox.fromSize(
      size: size,
      child: Opacity(
        opacity: dimmed ? DeckTokens.lockedArtAlpha : 1,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: arch,
            border: Border.all(color: DeckTokens.silver),
          ),
          child: ClipRRect(
            borderRadius: arch,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(
                  scale: zoom,
                  alignment: focus,
                  child: Image(
                    image: _decoded(context),
                    fit: BoxFit.cover,
                    alignment: focus,
                    gaplessPlayback: true,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [panel.withValues(alpha: 0), panel],
                      stops: const [1 - DeckTokens.featherFraction, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Something to pick or collect. `list`: the arched window at the start, the
/// words beside it. `hero`: wide art on top (a story's scene), the body under.
class ArtCard extends StatelessWidget {
  final String? title;
  final String? meta;
  final ArtWindow? art;
  final VoidCallback? onTap;
  final bool selected;
  final String? lockedReason;

  /// A shorter card — smaller window, one line of meta — for short phones.
  final bool compact;

  /// Key on the locked line, for tests that read it.
  final Key? lockedKey;
  final String? heroArt;
  final Widget? heroTitle;
  final Widget? body;
  final List<Widget> pills;
  final Widget? action;

  const ArtCard.list({
    super.key,
    required String this.title,
    this.meta,
    required ArtWindow this.art,
    this.onTap,
    this.selected = false,
    this.lockedReason,
    this.lockedKey,
    this.compact = false,
  }) : heroArt = null,
       heroTitle = null,
       body = null,
       pills = const [],
       action = null;

  const ArtCard.hero({
    super.key,
    required String art,
    required Widget title,
    this.body,
    this.pills = const [],
    this.action,
    this.onTap,
  }) : heroArt = art,
       heroTitle = title,
       title = null,
       meta = null,
       art = null,
       selected = false,
       lockedReason = null,
       lockedKey = null,
       compact = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(context.radii.card);
    final border = selected
        ? Border.all(color: DeckTokens.bone, width: DeckTokens.selectedRim)
        : Border.all(
            color: DeckTokens.bone.withValues(alpha: DeckTokens.hairlineAlpha),
          );
    return DeckPress(
      enabled: onTap != null && lockedReason == null,
      child: Material(
        color: colors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          highlightColor: colors.surfaceOverlay,
          splashColor: IdentityTokens.transparent,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(borderRadius: radius, border: border),
            child: heroArt == null ? _list(context) : _hero(context),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final reason = lockedReason;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: compact ? DeckTokens.artMinCompact : DeckTokens.artMin,
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? s.sm : s.md),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ArtWindow(
                  asset: art!.asset,
                  size: compact ? DeckTokens.windowCompact : art!.size,
                  focus: art!.focus,
                  zoom: art!.zoom,
                  dimmed: reason != null,
                ),
                if (selected)
                  PositionedDirectional(
                    top: -s.xs,
                    end: -s.xs,
                    child: Container(
                      width: DeckTokens.check,
                      height: DeckTokens.check,
                      decoration: const BoxDecoration(
                        color: DeckTokens.bone,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: DeckTokens.lock,
                        color: colors.surfaceBase,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: s.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title!,
                    style: DeckTokens.card(type).copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (meta != null)
                    Text(
                      meta!,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: DeckTokens.meta(
                        type,
                      ).copyWith(color: colors.textSecondary),
                    ),
                  if (reason != null)
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: DeckTokens.lock,
                          color: colors.textMuted,
                        ),
                        SizedBox(width: s.xs),
                        Flexible(
                          child: Text(
                            reason,
                            key: lockedKey,
                            style: DeckTokens.meta(
                              type,
                            ).copyWith(color: colors.textMuted),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (onTap != null && reason == null)
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                size: DeckTokens.chevron,
                color: DeckTokens.silverLight,
              ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final s = context.spacing;
    final panel = context.colors.surfaceRaised;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: DeckTokens.heroAspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(heroArt!, fit: BoxFit.cover),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: DeckTokens.heroFeather,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [panel.withValues(alpha: 0), panel],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(s.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              heroTitle!,
              if (body != null) ...[SizedBox(height: s.xs), body!],
              if (pills.isNotEmpty) ...[
                SizedBox(height: s.sm),
                Wrap(spacing: s.sm, runSpacing: s.sm, children: pills),
              ],
              if (action != null) ...[SizedBox(height: s.md), action!],
            ],
          ),
        ),
      ],
    );
  }
}

/// Everything that is not a card: a line with an optional icon, a value or a
/// chevron at the end, and a divider inset past the icon.
class DeckRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? meta;
  final Widget? trailing;
  final VoidCallback? onTap;

  const DeckRow({
    super.key,
    this.icon,
    required this.title,
    this.meta,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    return InkWell(
      onTap: onTap,
      highlightColor: colors.surfaceOverlay,
      splashColor: IdentityTokens.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: meta == null ? DeckTokens.rowOne : DeckTokens.rowTwo,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.md),
          child: Row(
            children: [
              if (icon != null)
                SizedBox(
                  width: DeckTokens.rowIconSlot,
                  child: Icon(
                    icon,
                    size: DeckTokens.icon,
                    color: DeckTokens.silverLight,
                  ),
                ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DeckTokens.body(
                        type,
                      ).copyWith(color: colors.textPrimary),
                    ),
                    if (meta != null)
                      Text(
                        meta!,
                        style: DeckTokens.meta(
                          type,
                        ).copyWith(color: colors.textMuted),
                      ),
                  ],
                ),
              ),
              ?trailing,
              if (trailing == null && onTap != null)
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left
                      : Icons.chevron_right,
                  size: DeckTokens.chevron,
                  color: DeckTokens.silver,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dealt card from the bottom: the handle, the title with «اقفل» at its
/// end, the body, and the primary pinned under it. Swipe or a tap outside
/// also closes it. No banner inside.
Future<T?> showDeckSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder body,
  Widget? primary,
}) => showMafiaSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: DeckTokens.panel,
  builder: (sheetContext) => Builder(
    builder: (context) {
      final s = context.spacing;
      final type = context.typography;
      final heading = DeckTokens.title(type).copyWith(fontSize: 22);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * DeckTokens.sheetMax,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(s.md, s.sm, s.md, s.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: DeckTokens.sheetHandle.width,
                    height: DeckTokens.sheetHandle.height,
                    decoration: BoxDecoration(
                      color: DeckTokens.silver,
                      borderRadius: BorderRadius.circular(
                        DeckTokens.sheetHandle.height,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: heading.copyWith(
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      key: DeckSheet.closeKey,
                      tooltip: context.l10n.sheetClose,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close, size: DeckTokens.icon),
                      color: DeckTokens.silverLight,
                    ),
                  ],
                ),
                Flexible(child: SingleChildScrollView(child: body(context))),
                if (primary != null) ...[SizedBox(height: s.md), primary],
              ],
            ),
          ),
        ),
      );
    },
  ),
);

/// Keys for the deck sheet.
abstract final class DeckSheet {
  static const closeKey = ValueKey('deck_sheet_close');
}

/// A small tag: difficulty, minutes, «إعلان».
class DeckPill extends StatelessWidget {
  final String label;
  final bool ad;
  const DeckPill(this.label, {super.key, this.ad = false});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Container(
      height: DeckTokens.pill,
      padding: EdgeInsets.symmetric(horizontal: s.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DeckTokens.pill / 2),
        border: Border.all(color: DeckTokens.silver),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: DeckTokens.meta(
            context.typography,
          ).copyWith(color: ad ? DeckTokens.muted : DeckTokens.text2),
        ),
      ),
    );
  }
}

/// The balance, in gold, as the store's own control.
class CoinPill extends StatelessWidget {
  final int balance;
  final VoidCallback? onTap;
  const CoinPill({super.key, required this.balance, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return SizedBox(
      height: IdentityTokens.target,
      child: Center(
        child: Material(
          color: DeckTokens.gold,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MafiaCoin(size: DeckTokens.coinGlyphSmall),
                  SizedBox(width: s.xs),
                  Text(
                    '$balance',
                    style: DeckTokens.meta(context.typography).copyWith(
                      color: DeckTokens.ink,
                      fontWeight: FontWeight.w700,
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

/// A choice in a group (player count, level): 48 dp, a bone rim and a check
/// when chosen.
class DeckChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  const DeckChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = context.spacing;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.surfaceOverlay : IdentityTokens.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? DeckTokens.bone : DeckTokens.silver,
            width: selected ? DeckTokens.rimBorder : 1,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onSelected(!selected),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: DeckTokens.chip,
              minWidth: DeckTokens.chip,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: s.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check,
                      size: DeckTokens.lock,
                      color: DeckTokens.bone,
                    ),
                    SizedBox(width: s.xs),
                  ],
                  Text(
                    label,
                    style: DeckTokens.body(
                      context.typography,
                    ).copyWith(color: colors.textPrimary),
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

/// The narrator in his arched window, one line, one way forward. For empty,
/// loading-failed and nothing-yet states on public screens.
class NarratorEmpty extends StatelessWidget {
  final String line;
  final String actionLabel;
  final VoidCallback onAction;
  final bool primary;

  const NarratorEmpty({
    super.key,
    required this.line,
    required this.actionLabel,
    required this.onAction,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return LayoutBuilder(
      builder: (context, box) {
        final small = box.maxHeight < DeckTokens.narratorCompactBelow;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: DeckTokens.narratorLineWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ArtWindow(
                    asset: AppImages.cardFaceCitizen,
                    size: small
                        ? DeckTokens.narratorSmall
                        : DeckTokens.narrator,
                    focus: DeckTokens.narratorFocus,
                    zoom: DeckTokens.narratorZoom,
                  ),
                ),
                SizedBox(height: s.md),
                Text(
                  line,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: DeckTokens.body(
                    context.typography,
                  ).copyWith(color: context.colors.textPrimary),
                ),
                SizedBox(height: s.lg),
                primary
                    ? BoneButton(label: actionLabel, onPressed: onAction)
                    : RimButton(label: actionLabel, onPressed: onAction),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A public screen's header: back at the start, the title at 28, an optional
/// line under it and an optional control (the coin pill) at the end.
class DeckHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  const DeckHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final heading = DeckTokens.title(
      type,
    ).copyWith(fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (onBack != null) BackAction(onPressed: onBack!),
            const Spacer(),
            ?trailing,
          ],
        ),
        SizedBox(height: s.sm),
        // A screen that changes what it is asking (the mode screen opening
        // the Mafia card) cross-fades its heading rather than snapping.
        AnimatedSwitcher(
          duration: DeckTokens.slide,
          layoutBuilder: (current, previous) => Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [...previous, if (current != null) current],
          ),
          child: Text(
            title,
            key: ValueKey(title),
            style: heading.copyWith(color: colors.textPrimary),
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: DeckTokens.meta(type).copyWith(color: colors.textSecondary),
          ),
      ],
    );
  }
}

/// Every new public screen: Home's ground, the header, the body, and the
/// footer — primary on top, a ruled gap, then the banner. The banner is never
/// between the content and the primary.
class DeckScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget body;
  final Widget? primary;
  final BannerPlacement? banner;
  final bool desktopFullWidth;
  final bool hideHeader;

  /// A full-bleed ground behind the body, dimmed (public screens only).
  final String? backdrop;

  const DeckScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    required this.body,
    this.primary,
    this.banner,
    this.desktopFullWidth = false,
    this.hideHeader = false,
    this.backdrop,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final s = context.spacing;
        final placement = banner;
        final footer = primary == null && placement == null
            ? null
            : SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (primary != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          s.screenMargin,
                          s.sm,
                          s.screenMargin,
                          0,
                        ),
                        child: primary,
                      ),
                    if (placement != null) ...[
                      if (primary != null) ...[
                        const SizedBox(height: DeckTokens.footerGap / 2),
                        const Divider(
                          height: DeckTokens.footerGap / 2,
                          thickness: 1,
                          color: DeckTokens.line,
                        ),
                      ],
                      WaitingBanner(placement: placement),
                    ] else
                      SizedBox(height: s.sm),
                  ],
                ),
              );
        return MafiaScaffold(
          backgroundColor: DeckTokens.ground,
          bottomNavigationBar: footer,
          body: _Backdrop(
            asset: backdrop,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: desktopFullWidth
                        ? double.infinity
                        : s.maxContentWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      s.screenMargin,
                      s.sm,
                      s.screenMargin,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!hideHeader) ...[
                          DeckHeader(
                            title: title,
                            subtitle: subtitle,
                            onBack: onBack,
                            trailing: trailing,
                          ),
                          SizedBox(height: s.md),
                        ],
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A dimmed full-bleed picture behind a public screen's body, decoded at
/// the screen's size. Nothing when [asset] is null.
class _Backdrop extends StatelessWidget {
  final String? asset;
  final Widget child;

  const _Backdrop({required this.asset, required this.child});

  @override
  Widget build(BuildContext context) {
    final path = asset;
    if (path == null) return child;
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Opacity(
            opacity: DeckTokens.backdropAlpha,
            child: Image(
              image: ResizeImage(
                AssetImage(path),
                width: (size.width * dpr).round(),
                policy: ResizeImagePolicy.fit,
              ),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              gaplessPlayback: true,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
