import 'package:flutter/material.dart';

import '../../../../platform/narration_controller.dart';
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';

/// The pieces of «الأباجورة», the Stories V2 look. Stories only.

/// A lamp-lit screen: warm dark ground with one pool of light at the top.
class LampScaffold extends StatelessWidget {
  const LampScaffold({
    super.key,
    required this.body,
    this.title,
    this.onBack,
    this.trailing,
    this.footer,
  });

  final Widget body;
  final String? title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    return Scaffold(
      backgroundColor: StoriesLampTokens.ground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.1,
            colors: [StoriesLampTokens.glow, StoriesLampTokens.ground],
            stops: [0, StoriesLampTokens.glowHeight],
          ),
        ),
        // A phone-wide column on a tablet or a desktop browser, so lines,
        // faces and the hold pad keep their phone proportions.
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: s.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onBack != null || title != null || trailing != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: s.sm),
                      child: Row(
                        children: [
                          if (onBack != null)
                            IconButton(
                              onPressed: onBack,
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).backButtonTooltip,
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: StoriesLampTokens.text2,
                            ),
                          Expanded(
                            child: Text(
                              title ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.caption.copyWith(
                                color: StoriesLampTokens.muted,
                              ),
                            ),
                          ),
                          ?trailing,
                        ],
                      ),
                    ),
                  Expanded(child: body),
                  if (footer case final footer?)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        s.screenMargin,
                        s.sm,
                        s.screenMargin,
                        s.md,
                      ),
                      child: footer,
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

/// A scrolling column with the screen margins.
class LampScroll extends StatelessWidget {
  const LampScroll({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return ListView(
      padding: EdgeInsets.fromLTRB(s.screenMargin, s.sm, s.screenMargin, s.lg),
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) SizedBox(height: s.sm),
          child,
        ],
      ],
    );
  }
}

/// Ruqaa for case titles and names, never under 22 dp (identity rule 7).
class LampTitle extends StatelessWidget {
  const LampTitle(
    this.text, {
    super.key,
    this.small = false,
    this.center = false,
  });

  final String text;
  final bool small;
  final bool center;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: center ? TextAlign.center : TextAlign.start,
    style: StoryTokens.ruqaa(context.typography.headline).copyWith(
      color: StoriesLampTokens.paper,
      fontSize: small
          ? StoriesLampTokens.titleSmall
          : StoriesLampTokens.titleSize,
    ),
  );
}

class LampMeta extends StatelessWidget {
  const LampMeta(this.text, {super.key, this.center = false, this.color});

  final String text;
  final bool center;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: center ? TextAlign.center : TextAlign.start,
    style: context.typography.bodySmall.copyWith(
      color: color ?? StoriesLampTokens.text2,
    ),
  );
}

/// Manila paper: the only light surface. Everything read aloud sits on it.
class LampPaper extends StatelessWidget {
  const LampPaper({
    super.key,
    required this.child,
    this.label,
    this.dimmed = false,
  });

  final Widget child;
  final String? label;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final paper = DecoratedBox(
      decoration: BoxDecoration(
        color: StoriesLampTokens.paper,
        borderRadius: BorderRadius.circular(StoriesLampTokens.radiusPaper),
        boxShadow: const [
          BoxShadow(
            color: StoriesLampTokens.paperLine,
            offset: Offset(0, StoriesLampTokens.paperLift),
          ),
          BoxShadow(
            color: StoriesLampTokens.shadow,
            blurRadius: StoriesLampTokens.paperBlur,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
        child: DefaultTextStyle.merge(
          style: context.typography.body.copyWith(
            color: StoriesLampTokens.paperInk,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: context.typography.caption.copyWith(
                    color: StoriesLampTokens.amberDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    );
    return dimmed
        ? Opacity(opacity: StoriesLampTokens.dimmed, child: paper)
        : paper;
  }
}

enum LampButtonKind { action, ghost, verdict }

class LampButton extends StatelessWidget {
  const LampButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = LampButtonKind.action,
  });

  final String label;
  final VoidCallback? onPressed;
  final LampButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = switch (kind) {
      LampButtonKind.action => (
        StoriesLampTokens.amber,
        StoriesLampTokens.onAmber,
        null,
      ),
      LampButtonKind.verdict => (
        StoriesLampTokens.velvet,
        StoriesLampTokens.text,
        null,
      ),
      LampButtonKind.ghost => (
        StoriesLampTokens.ground,
        StoriesLampTokens.paper,
        const BorderSide(color: StoriesLampTokens.line),
      ),
    };
    return SizedBox(
      height: StoriesLampTokens.buttonHeight,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: StoriesLampTokens.raised,
          disabledForegroundColor: StoriesLampTokens.muted,
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StoriesLampTokens.radiusButton),
          ),
          textStyle: context.typography.body.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

/// A character's photo, framed like evidence.
class LampFace extends StatelessWidget {
  const LampFace(
    this.image, {
    super.key,
    this.width = StoriesLampTokens.faceWidth,
    this.height = StoriesLampTokens.faceHeight,
    this.picked = false,
  });

  final String image;
  final double width;
  final double height;
  final bool picked;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(StoriesLampTokens.radiusPaper),
      border: Border.all(
        color: picked ? StoriesLampTokens.amberHi : StoriesLampTokens.paper,
        width: picked
            ? StoriesLampTokens.pickedBorder
            : StoriesLampTokens.faceBorder,
      ),
      color: StoriesLampTokens.raised,
    ),
    clipBehavior: Clip.antiAlias,
    child: Image(
      image: lampFaceImage(context, image),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}

/// A face as every page draws it: one decode per face at the largest size a
/// page shows it, shared by every page (a browser decodes off the frame, so
/// a face decoded per size came in blank for a moment on each new page).
ImageProvider lampFaceImage(BuildContext context, String path) => ResizeImage(
  AssetImage(path),
  width:
      (StoriesLampTokens.revealFaceWidth *
              MediaQuery.devicePixelRatioOf(context))
          .ceil(),
);

/// Decodes every face of [paths] ahead, so the cast, the cards and the
/// decision open complete. Failures are quiet: a face just loads later.
void precacheLampFaces(BuildContext context, Iterable<String> paths) {
  for (final path in paths) {
    precacheImage(lampFaceImage(context, path), context, onError: (_, _) {});
  }
}

/// Press and hold to open a private line. The same pad, timing and light for
/// every seat, whatever is behind it (Doc 05).
class LampHoldPad extends StatefulWidget {
  const LampHoldPad({
    super.key,
    required this.label,
    required this.hint,
    required this.onHeld,
  });

  final String label;
  final String hint;
  final VoidCallback onHeld;

  @override
  State<LampHoldPad> createState() => _LampHoldPadState();
}

class _LampHoldPadState extends State<LampHoldPad>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: StoriesLampTokens.hold)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _hold.reset();
            widget.onHeld();
          }
        });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = context.typography;
    return Semantics(
      button: true,
      label: widget.label,
      onLongPress: widget.onHeld,
      child: GestureDetector(
        onTapDown: (_) => _hold.forward(),
        onTapUp: (_) => _hold.reverse(),
        onTapCancel: _hold.reverse,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => Container(
            height: StoriesLampTokens.holdPad,
            decoration: BoxDecoration(
              color: StoriesLampTokens.paper,
              borderRadius: BorderRadius.circular(
                StoriesLampTokens.radiusButton,
              ),
              border: Border.all(
                color: Color.lerp(
                  StoriesLampTokens.paperLine,
                  StoriesLampTokens.amber,
                  _hold.value,
                )!,
                width: StoriesLampTokens.holdStroke,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: type.body.copyWith(
                    color: StoriesLampTokens.paperInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.hint,
                  style: type.caption.copyWith(
                    color: StoriesLampTokens.paperInk2,
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

/// The narrator: play/pause, a bar you tap or drag anywhere, ±5 s, restart.
/// State comes from the controller, never from a local flag.
class StoryNarratorPlayer extends StatelessWidget {
  const StoryNarratorPlayer({
    super.key,
    required this.controller,
    required this.asset,
    required this.title,
  });

  static const playKey = ValueKey('sv2_narrator_play');
  static const barKey = ValueKey('sv2_narrator_bar');

  final NarrationController controller;
  final String asset;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final type = context.typography;
    final s = context.spacing;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final mine = controller.asset == asset;
        final state = mine ? controller.state : NarrationState.idle;
        final total = mine ? controller.duration : Duration.zero;
        final at = mine ? controller.position : Duration.zero;
        final fraction = total.inMilliseconds == 0
            ? 0.0
            : (at.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        final playing = state == NarrationState.playing;
        final ended = state == NarrationState.ended;
        return Container(
          padding: EdgeInsets.all(s.sm),
          decoration: BoxDecoration(
            color: StoriesLampTokens.panel,
            borderRadius: BorderRadius.circular(StoriesLampTokens.radiusButton),
            border: Border.all(color: StoriesLampTokens.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: type.caption.copyWith(color: StoriesLampTokens.text2),
              ),
              LayoutBuilder(
                builder: (context, box) {
                  void seekTo(double dx) {
                    if (total == Duration.zero) return;
                    final rtl = Directionality.of(context) == TextDirection.rtl;
                    final f = (dx / box.maxWidth).clamp(0.0, 1.0);
                    controller.seek(total * (rtl ? 1 - f : f));
                  }

                  return GestureDetector(
                    key: barKey,
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => seekTo(d.localPosition.dx),
                    onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
                    child: SizedBox(
                      height: StoriesLampTokens.barTouch,
                      child: Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [
                          Container(
                            height: StoriesLampTokens.barHeight,
                            decoration: BoxDecoration(
                              color: StoriesLampTokens.raised,
                              borderRadius: BorderRadius.circular(
                                StoriesLampTokens.barHeight,
                              ),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: fraction,
                            child: Container(
                              height: StoriesLampTokens.barHeight,
                              decoration: BoxDecoration(
                                color: StoriesLampTokens.amber,
                                borderRadius: BorderRadius.circular(
                                  StoriesLampTokens.barHeight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _clock(at),
                      style: type.caption.copyWith(
                        color: StoriesLampTokens.muted,
                      ),
                    ),
                    Text(
                      _clock(total),
                      style: type.caption.copyWith(
                        color: StoriesLampTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _control(
                    context,
                    Icons.replay_rounded,
                    l.sv2NarrRestart,
                    controller.restart,
                  ),
                  _labelControl(
                    context,
                    l.sv2NarrBackLabel,
                    l.sv2NarrBack,
                    () => controller.skip(-NarrationController.skipStep),
                  ),
                  SizedBox(
                    width: StoriesLampTokens.controlMain,
                    height: StoriesLampTokens.controlMain,
                    child: IconButton.filled(
                      key: playKey,
                      tooltip: ended
                          ? l.sv2NarrAgain
                          : playing
                          ? l.sv2NarrPause
                          : l.sv2NarrPlay,
                      style: IconButton.styleFrom(
                        backgroundColor: StoriesLampTokens.amber,
                        foregroundColor: StoriesLampTokens.onAmber,
                      ),
                      onPressed: () => controller.toggle(asset),
                      icon: Icon(
                        ended
                            ? Icons.replay_rounded
                            : playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ),
                  _labelControl(
                    context,
                    l.sv2NarrForwardLabel,
                    l.sv2NarrForward,
                    () => controller.skip(NarrationController.skipStep),
                  ),
                ],
              ),
              if (ended)
                Text(
                  l.sv2NarrAgain,
                  textAlign: TextAlign.center,
                  style: type.caption.copyWith(
                    color: StoriesLampTokens.amberHi,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _control(
    BuildContext context,
    IconData icon,
    String tip,
    VoidCallback onTap,
  ) => SizedBox(
    width: StoriesLampTokens.control,
    height: StoriesLampTokens.control,
    child: IconButton(
      tooltip: tip,
      onPressed: onTap,
      color: StoriesLampTokens.paper,
      icon: Icon(icon),
    ),
  );

  Widget _labelControl(
    BuildContext context,
    String label,
    String tip,
    VoidCallback onTap,
  ) => SizedBox(
    width: StoriesLampTokens.control,
    height: StoriesLampTokens.control,
    child: Tooltip(
      message: tip,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: StoriesLampTokens.paper,
          shape: const CircleBorder(
            side: BorderSide(color: StoriesLampTokens.line),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: context.typography.caption.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// A bottom sheet in the lamp look.
Future<T?> showLampSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: StoriesLampTokens.panel,
      constraints: BoxConstraints(maxWidth: context.spacing.maxContentWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(StoriesLampTokens.radiusSheet),
        ),
      ),
      builder: builder,
    );
