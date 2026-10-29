import 'package:flutter/material.dart';

import '../../platform/monetization/ad_formats.dart'
    show BannerSize, BannerSizing;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// The banner's frame, drawn the same whether or not an ad has arrived.
///
/// The owner's complaint was a screen that jumped up when the ad filled. The
/// slot is a fixed box from the first frame: [ad] goes inside it when there
/// is one, and until then, or when none ever comes, the box stays as a quiet
/// surface: no text, no pretend ad. Its height is [adHeight] plus
/// `AdTokens.bannerSlotChrome` either way, plus the [gap] above.
class BannerFrame extends StatelessWidget {
  final String label;
  final double gap;

  /// The width and the reserved height of the ad's box.
  final double adWidth;
  final double adHeight;

  /// The ad, or null while there is none. Sized to its own size; the frame
  /// centres it in the reserved box.
  final Widget? ad;

  const BannerFrame({
    super.key,
    required this.label,
    required this.gap,
    required this.adWidth,
    required this.adHeight,
    required this.ad,
  });

  static const adKey = ValueKey('banner_frame_ad');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = ad != null;
    return Padding(
      padding: EdgeInsets.only(top: gap),
      child: Semantics(
        container: true,
        label: filled ? label : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceBase,
            border: Border.all(
              color: colors.borderSubtle,
              width: AdTokens.bannerFrame,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AdTokens.bannerFrame),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AdTokens.bannerLabelGap),
                  child: SizedBox(
                    height: AdTokens.bannerLabelStrip,
                    child: Center(
                      child: filled
                          ? Text(
                              label,
                              maxLines: 1,
                              style: context.typography.caption.copyWith(
                                color: colors.textMuted,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                SizedBox(
                  key: adKey,
                  width: adWidth,
                  height: adHeight,
                  child: filled ? Center(child: ad) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether any banner has filled in this session.
///
/// Owner, 2026-10-29: no empty box when no ad comes. So a slot holds no place
/// until a banner has filled once; the first one opens over
/// `AdTokens.bannerReveal`, and from then on every slot reserves its place
/// from the first frame, so a later fill moves nothing (WP4).
abstract final class BannerFill {
  static final seen = ValueNotifier<bool>(false);

  static void markSeen() => seen.value = true;

  @visibleForTesting
  static void reset({bool seen = false}) => BannerFill.seen.value = seen;
}

/// Reserves a banner slot from the first frame and keeps it from changing,
/// once a banner has filled this session ([BannerFill]); before that it holds
/// nothing and opens when its own ad fills.
///
/// The large anchored adaptive size depends only on the width and the
/// orientation, so it is looked up in [sizing]'s cache synchronously; the
/// host resolves the current window's size at start-up, so a slot normally
/// knows its exact height on its first frame. Only a slot built before any
/// answer exists reserves `AdTokens.bannerAdaptiveFloor`, resolves, and keeps
/// whatever it reserved (growing once only if Google's answer is taller).
///
/// A change of width or orientation (a rotation) relayouts; an ad filling or
/// failing never does. [onSize] is told, after the frame, the size to request
/// for the current width and orientation.
class BannerReserve extends StatefulWidget {
  final String label;
  final double gap;
  final BannerSizing sizing;
  final Widget? ad;
  final void Function(BannerSize size)? onSize;

  const BannerReserve({
    super.key,
    required this.label,
    required this.gap,
    required this.sizing,
    required this.ad,
    this.onSize,
  });

  @override
  State<BannerReserve> createState() => _BannerReserveState();
}

class _BannerReserveState extends State<BannerReserve> {
  int? _width;
  Orientation? _orientation;
  double _height = AdTokens.bannerAdaptiveFloor;
  int _epoch = 0;

  /// The slot's ad width: the room it is given less its frame, floored (an
  /// ad wider than its box would be cropped, which AdMob forbids).
  int _widthFor(BoxConstraints constraints) {
    final available = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width;
    return (available - 2 * AdTokens.bannerFrame)
        .clamp(0.0, AdTokens.bannerMaxWidth)
        .floor();
  }

  void _rekey(int width, Orientation orientation) {
    _width = width;
    _orientation = orientation;
    final cached = widget.sizing.peek(width, orientation);
    _height = cached?.height.toDouble() ?? AdTokens.bannerAdaptiveFloor;
    final epoch = ++_epoch;
    // Never ask (or load) mid-layout: after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || epoch != _epoch) return;
      var size = cached;
      if (size == null) {
        try {
          size = await widget.sizing.resolve(width, orientation);
        } catch (_) {
          return;
        }
      }
      if (size == null || !mounted || epoch != _epoch) return;
      if (size.height > _height) {
        setState(() => _height = size!.height.toDouble());
      }
      widget.onSize?.call(size);
    });
  }

  @override
  void dispose() {
    _epoch++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ValueListenableBuilder<bool>(
      valueListenable: BannerFill.seen,
      builder: (context, seen, _) => LayoutBuilder(
        builder: (context, constraints) {
          final width = _widthFor(constraints);
          if (width != _width || orientation != _orientation) {
            _rekey(width, orientation);
          }
          final hold = seen || widget.ad != null;
          // No begin: a slot that holds on its first frame opens at once.
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: hold ? 1 : 0),
            duration: reduce ? Duration.zero : AdTokens.bannerReveal,
            curve: Curves.easeOut,
            child: BannerFrame(
              label: widget.label,
              gap: widget.gap,
              adWidth: width.toDouble(),
              adHeight: _height,
              ad: widget.ad,
            ),
            builder: (context, factor, child) => factor == 0
                ? const SizedBox.shrink()
                : ClipRect(
                    clipBehavior: factor == 1 ? Clip.none : Clip.hardEdge,
                    child: Align(
                      alignment: Alignment.topCenter,
                      widthFactor: 1,
                      heightFactor: factor,
                      child: child,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// The shell host's band: one hairline above the ad, a little air around it,
/// the bottom system inset kept inside (the host's body does not repeat it).
/// Same quiet surface when there is no ad. Its height is the ad's plus the
/// air, and the host only draws it once the size is known.
class ShellBandFrame extends StatelessWidget {
  final String label;
  final double adWidth;
  final double adHeight;
  final Widget? ad;

  const ShellBandFrame({
    super.key,
    required this.label,
    required this.adWidth,
    required this.adHeight,
    required this.ad,
  });

  static const adKey = ValueKey('shell_band_ad');

  /// The band's height above the system inset, for an ad [adHeight] tall.
  static double heightFor(double adHeight) =>
      adHeight + 2 * AdTokens.bannerBandPad;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceBase,
        border: Border(
          top: BorderSide(
            color: colors.borderSubtle,
            width: AdTokens.bannerBandRule,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          container: true,
          label: ad != null ? label : null,
          child: SizedBox(
            height: heightFor(adHeight),
            child: Center(
              child: SizedBox(
                key: adKey,
                width: adWidth,
                height: adHeight,
                child: ad,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
