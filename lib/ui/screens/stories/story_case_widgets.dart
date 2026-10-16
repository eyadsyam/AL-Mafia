import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../stories/story_model.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import 'widgets/case_file.dart';

/// The dark case file of the stories (P12). These pieces belong to the
/// stories alone: story busts, covers and paper notes never enter a Mafia
/// screen, and no Mafia card art enters these.

bool _still(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// The ground every story screen stands on: the dark desk, a Ruqaa heading
/// with a way back, the body, and a footer that stays put.
class StoryDesk extends StatelessWidget {
  const StoryDesk({
    super.key,
    this.title,
    this.onBack,
    required this.body,
    this.footer,
    this.bottom,
  });

  final String? title;
  final VoidCallback? onBack;
  final Widget body;
  final Widget? footer;

  /// Below the footer: the waiting banner of the archive.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Scaffold(
      backgroundColor: CaseFileTokens.desk,
      body: SafeArea(
        bottom: bottom == null,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: s.maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null || onBack != null)
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      s.screenMargin,
                      s.sm,
                      s.screenMargin,
                      0,
                    ),
                    child: Row(
                      children: [
                        if (onBack != null) BackAction(onPressed: onBack!),
                        if (title != null)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(start: s.sm),
                              child: Text(
                                title!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StoryTokens.ruqaa(
                                  context.typography.headline,
                                ).copyWith(color: CaseFileTokens.ink),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(child: body),
                if (footer != null)
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      s.screenMargin,
                      s.sm,
                      s.screenMargin,
                      s.sm,
                    ),
                    child: footer,
                  ),
                ?bottom,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A scrolling body with the story gutters.
class StoryScroll extends StatelessWidget {
  const StoryScroll({super.key, this.scrollKey, required this.children});

  final Key? scrollKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return ListView(
      key: scrollKey,
      padding: EdgeInsets.fromLTRB(s.screenMargin, s.sm, s.screenMargin, s.md),
      children: children,
    );
  }
}

/// A photograph on a dark mat, turned a little, as pinned to a file.
class StoryPhoto extends StatelessWidget {
  const StoryPhoto({
    super.key,
    required this.image,
    required this.width,
    required this.height,
    this.turn = 0,
    this.bottomMat,
    this.dim = false,
    this.focusTop = false,
    this.clip = false,
  });

  final String image;
  final double width;
  final double height;
  final double turn;
  final double? bottomMat;
  final bool dim;
  final bool focusTop;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    const mat = StoryTokens.photoMat;
    final photo = DecoratedBox(
      decoration: const BoxDecoration(
        color: StoryTokens.photoShade,
        boxShadow: [
          BoxShadow(
            color: StoryTokens.noteShadow,
            blurRadius: CaseFileTokens.stampBorder * 4,
            offset: Offset(0, CaseFileTokens.stampBorder * 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(mat, mat, mat, bottomMat ?? mat),
        child: SizedBox(
          width: width - mat * 2,
          height: height - mat - (bottomMat ?? mat),
          child: Image.asset(
            image,
            fit: BoxFit.cover,
            alignment: focusTop ? const Alignment(0, -0.6) : Alignment.center,
            cacheWidth: (width * dpr).round(),
            color: dim
                ? CaseFileTokens.desk.withValues(
                    alpha: 1 - StoryTokens.lockedPhotoAlpha,
                  )
                : null,
            colorBlendMode: dim ? BlendMode.srcATop : null,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: StoryTokens.photoShade),
          ),
        ),
      ),
    );
    Widget result = SizedBox(width: width, height: height, child: photo);
    if (clip) {
      result = Stack(
        clipBehavior: Clip.none,
        children: [
          result,
          PositionedDirectional(
            top: -StoryTokens.clipHeight / 2,
            start: width * 0.4,
            child: Container(
              width: StoryTokens.clipWidth,
              height: StoryTokens.clipHeight,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: CaseFileTokens.inkMuted,
                    width: StoryTokens.clipStroke,
                  ),
                  left: BorderSide(
                    color: CaseFileTokens.inkMuted,
                    width: StoryTokens.clipStroke,
                  ),
                  right: BorderSide(
                    color: CaseFileTokens.inkMuted,
                    width: StoryTokens.clipStroke,
                  ),
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(StoryTokens.clipHeight / 2),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return turn == 0 ? result : Transform.rotate(angle: turn, child: result);
  }
}

/// One case in the archive: a folder with a numbered tab, its photo clipped
/// on, the title in Ruqaa and a stamp. A locked one carries a wax seal and
/// says how it opens; its title stays readable.
class StoryFolder extends StatelessWidget {
  const StoryFolder({
    super.key,
    required this.numberLabel,
    required this.title,
    required this.category,
    required this.synopsis,
    required this.facts,
    required this.image,
    required this.stampText,
    required this.stampColor,
    required this.sealed,
    this.unlockText,
    this.onTap,
  });

  final String numberLabel;
  final String title;
  final String category;
  final String synopsis;
  final List<String> facts;
  final String image;
  final String stampText;
  final Color stampColor;
  final bool sealed;
  final String? unlockText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    final paper = CaseFilePaper(
      padding: EdgeInsets.all(s.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              StoryPhoto(
                image: image,
                width: StoryTokens.folderPhotoWidth,
                height: StoryTokens.folderPhotoHeight,
                turn: StoryTokens.folderPhotoTilt,
                bottomMat: StoryTokens.photoMatBottom,
                dim: sealed,
                clip: true,
              ),
              if (sealed)
                const Positioned.fill(child: Center(child: _WaxSeal())),
            ],
          ),
          SizedBox(width: s.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: StoryTokens.ruqaa(
                    type.title,
                  ).copyWith(color: CaseFileTokens.ink),
                ),
                Text(
                  category,
                  style: type.caption.copyWith(color: CaseFileTokens.inkMuted),
                ),
                SizedBox(height: s.xs),
                Text(
                  synopsis,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall.copyWith(color: StoryDeckTokens.text2),
                ),
                SizedBox(height: s.sm),
                Wrap(
                  spacing: s.xs,
                  runSpacing: s.xs,
                  children: [for (final f in facts) _DashedFact(f)],
                ),
                SizedBox(height: s.sm),
                if (sealed && unlockText != null)
                  Text(
                    unlockText!,
                    style: type.caption.copyWith(color: CaseFileTokens.stamp),
                  )
                else
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: CaseStamp(
                      stampText,
                      color: stampColor,
                      angle: StoryTokens.stampFolderTilt,
                      style: type.caption.copyWith(
                        color: stampColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: StoryTokens.folderTabHeight),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(CaseFileTokens.radius),
              child: paper,
            ),
          ),
          PositionedDirectional(
            top: -StoryTokens.folderTabHeight,
            start: StoryTokens.folderTabInset,
            child: Container(
              height: StoryTokens.folderTabHeight,
              padding: EdgeInsets.symmetric(horizontal: s.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CaseFileTokens.paperTop,
                border: Border.all(color: CaseFileTokens.edge),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(CaseFileTokens.radius * 0.65),
                ),
              ),
              child: Text(
                numberLabel,
                style: type.caption.copyWith(color: StoryDeckTokens.text2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedFact extends StatelessWidget {
  const _DashedFact(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(CaseFileTokens.stampRadius),
      border: Border.all(color: StoryDeckTokens.silver),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xs * 2),
      child: Text(
        text,
        style: context.typography.caption.copyWith(
          color: StoryDeckTokens.text2,
        ),
      ),
    ),
  );
}

class _WaxSeal extends StatelessWidget {
  const _WaxSeal();

  @override
  Widget build(BuildContext context) => Container(
    width: StoryTokens.sealSize,
    height: StoryTokens.sealSize,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: Alignment(-0.2, -0.3),
        colors: [StoryTokens.sealTop, StoryTokens.sealBottom],
      ),
      boxShadow: [
        BoxShadow(
          color: StoryTokens.noteShadow,
          blurRadius: CaseFileTokens.stampBorder * 3,
          offset: Offset(0, CaseFileTokens.stampBorder),
        ),
      ],
    ),
    child: const Icon(
      Icons.lock_rounded,
      color: StoryTokens.sealGlyph,
      size: StoryTokens.sealSize / 2,
    ),
  );
}

/// A paper note, pinned: the Ruqaa heading and, under it, what it says.
class StoryNote extends StatelessWidget {
  const StoryNote({
    super.key,
    required this.title,
    this.body,
    this.width,
    this.turn = 0,
  });

  final String title;
  final String? body;
  final double? width;
  final double turn;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    return Transform.rotate(
      angle: turn,
      child: SizedBox(
        width: width,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: StoryTokens.note,
                boxShadow: [
                  BoxShadow(
                    color: StoryTokens.noteShadow,
                    blurRadius: CaseFileTokens.stampBorder * 4,
                    offset: Offset(0, CaseFileTokens.stampBorder * 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(s.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: StoryTokens.ruqaa(
                        type.bodySmall,
                      ).copyWith(color: StoryTokens.noteInk),
                    ),
                    if (body != null) ...[
                      SizedBox(height: s.xs),
                      Text(
                        body!,
                        style: type.caption.copyWith(
                          color: StoryTokens.noteInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: -StoryTokens.pinSize / 2,
              child: Container(
                width: StoryTokens.pinSize,
                height: StoryTokens.pinSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: CaseFileTokens.string,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A note landing on the board: it drops in from above, turned, and settles.
/// Under reduced motion it is simply there.
class StoryPinned extends StatefulWidget {
  const StoryPinned({super.key, required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<StoryPinned> createState() => _StoryPinnedState();
}

class _StoryPinnedState extends State<StoryPinned>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: StoryTokens.notePin + widget.delay,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_still(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = (StoryTokens.notePin + widget.delay).inMilliseconds;
    final begin = widget.delay.inMilliseconds / total;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(
            ((_c.value - begin) / (1 - begin)).clamp(0.0, 1.0),
          );
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, -StoryTokens.noteLift * (1 - t)),
              child: Transform.rotate(
                angle: -StoryTokens.noteTurn * (1 - t),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The moves left, as dots that dim as they are spent.
class StoryPips extends StatelessWidget {
  const StoryPips({super.key, required this.total, required this.left});

  final int total;
  final int left;

  @override
  Widget build(BuildContext context) {
    final still = _still(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: StoryTokens.pipsMaxWidth),
      child: Wrap(
        spacing: context.spacing.xs,
        runSpacing: context.spacing.xs,
        alignment: WrapAlignment.end,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedScale(
              scale: i < left ? 1 : StoryTokens.pipSpent,
              duration: still ? Duration.zero : StoryTokens.pipFade,
              child: AnimatedContainer(
                duration: still ? Duration.zero : StoryTokens.pipFade,
                width: StoryTokens.pip,
                height: StoryTokens.pip,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < left
                      ? StoryDeckTokens.bone
                      : StoryTokens.ringTrack,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One move on the search: its title, what it looks into, and its cost in a
/// ring. Spent ones show a tick; those dearer than what is left dim.
class StoryMoveCard extends StatelessWidget {
  const StoryMoveCard({
    super.key,
    required this.title,
    required this.description,
    required this.cost,
    required this.unit,
    required this.enabled,
    required this.done,
    required this.onPressed,
  });

  final String title;
  final String description;
  final int? cost;
  final String unit;
  final bool enabled;
  final bool done;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    final accent = done ? CaseFileTokens.sage : StoryDeckTokens.silverLight;
    return Opacity(
      opacity: done
          ? StoryTokens.doneOpacity
          : (enabled ? 1 : StoryTokens.poorOpacity),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled && !done ? onPressed : null,
          borderRadius: BorderRadius.circular(CaseFileTokens.radius),
          child: CaseFilePaper(
            padding: EdgeInsets.symmetric(
              horizontal: s.md,
              vertical: s.sm + s.xs / 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: type.body.copyWith(
                          color: CaseFileTokens.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        description,
                        style: type.caption.copyWith(
                          color: CaseFileTokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: s.sm),
                Container(
                  width: StoryTokens.costDot,
                  height: StoryTokens.costDot,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent,
                      width: StoryTokens.costStroke,
                    ),
                  ),
                  child: done
                      ? Icon(Icons.check_rounded, color: accent)
                      : (cost == null
                            ? Icon(Icons.search_rounded, color: accent)
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$cost',
                                    style: type.body.copyWith(
                                      color: CaseFileTokens.ink,
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                    ),
                                  ),
                                  Text(
                                    unit,
                                    style: type.caption.copyWith(
                                      color: CaseFileTokens.inkMuted,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «اسمع القضية»: play or stop, a waveform that moves while the narrator
/// speaks. The audio layer reports no length and no end, so the bar shows
/// the state it started, never a progress it cannot know.
class StoryNarratorBar extends StatefulWidget {
  const StoryNarratorBar({
    super.key,
    required this.title,
    required this.playingText,
    required this.idleText,
    required this.stopTooltip,
    required this.playTooltip,
    required this.onPlay,
    required this.onStop,
    this.startsPlaying = false,
  });

  final String title;
  final String playingText;
  final String idleText;
  final String stopTooltip;
  final String playTooltip;
  final VoidCallback onPlay;
  final VoidCallback? onStop;
  final bool startsPlaying;

  static const playKey = ValueKey('story_narrator_play');

  @override
  State<StoryNarratorBar> createState() => _StoryNarratorBarState();
}

class _StoryNarratorBarState extends State<StoryNarratorBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: StoryTokens.waveTick * StoryTokens.waveBars,
  );
  late bool _playing = widget.startsPlaying;
  bool _synced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced) return;
    _synced = true;
    _sync();
  }

  void _sync() {
    if (_playing && !_still(context)) {
      _wave.repeat();
    } else {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_playing) {
      widget.onStop?.call();
    } else {
      widget.onPlay();
    }
    setState(() => _playing = !_playing);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    return Row(
      children: [
        Semantics(
          button: true,
          label: _playing ? widget.stopTooltip : widget.playTooltip,
          child: GestureDetector(
            key: StoryNarratorBar.playKey,
            onTap: _toggle,
            child: Container(
              width: StoryTokens.playButton,
              height: StoryTokens.playButton,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: StoryDeckTokens.bone,
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: StoryDeckTokens.ink,
              ),
            ),
          ),
        ),
        SizedBox(width: s.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: StoryTokens.ruqaa(
                  type.title,
                ).copyWith(color: CaseFileTokens.ink),
              ),
              SizedBox(
                height: StoryTokens.waveBarMax,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _wave,
                    builder: (context, _) => Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (var i = 0; i < StoryTokens.waveBars; i++) ...[
                          Container(
                            width: StoryTokens.waveBarWidth,
                            height: _playing
                                ? StoryTokens.waveBarMin +
                                      (StoryTokens.waveBarMax -
                                              StoryTokens.waveBarMin) *
                                          (math
                                              .sin(
                                                _wave.value * math.pi * 2 +
                                                    i * 0.7,
                                              )
                                              .abs())
                                : StoryTokens.waveBarMin,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                StoryTokens.waveBarWidth,
                              ),
                              color: _playing
                                  ? StoryDeckTokens.bone
                                  : StoryDeckTokens.silverLight,
                            ),
                          ),
                          const SizedBox(width: StoryTokens.waveBarWidth),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                _playing ? widget.playingText : widget.idleText,
                style: type.caption.copyWith(color: CaseFileTokens.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A suspect's photograph, standing in a row; the chosen one lifts and takes
/// a red frame.
class StorySuspect extends StatelessWidget {
  const StorySuspect({
    super.key,
    required this.character,
    required this.selected,
    required this.onTap,
    this.width = StoryTokens.suspectWidth,
    this.height = StoryTokens.suspectHeight,
  });

  final StoryCharacter character;
  final bool selected;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final still = _still(context);
    final type = context.typography;
    return Semantics(
      button: true,
      selected: selected,
      label: character.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSlide(
                duration: still ? Duration.zero : StoryTokens.suspectLiftTime,
                curve: Curves.easeOutCubic,
                offset: Offset(
                  0,
                  selected ? -StoryTokens.suspectLift / height : 0,
                ),
                child: AnimatedRotation(
                  duration: still ? Duration.zero : StoryTokens.suspectLiftTime,
                  turns: selected ? StoryTokens.suspectTurn / (math.pi * 2) : 0,
                  child: Container(
                    padding: const EdgeInsets.all(StoryTokens.suspectRingGap),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected
                            ? CaseFileTokens.stamp
                            : StoryTokens.transparentColor,
                        width: StoryTokens.suspectRing,
                      ),
                    ),
                    child: StoryPhoto(
                      image: character.image,
                      width: width - StoryTokens.suspectRing * 4,
                      height: height,
                      focusTop: true,
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                character.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: type.caption.copyWith(
                  color: selected ? CaseFileTokens.stamp : CaseFileTokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A choice of why or how: a paper row with a dot that fills when chosen.
class StoryOptionRow extends StatelessWidget {
  const StoryOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CaseFileTokens.radius),
            border: Border.all(
              color: selected
                  ? StoryDeckTokens.bone
                  : StoryTokens.transparentColor,
              width: StoryTokens.costStroke,
            ),
          ),
          child: CaseFilePaper(
            padding: EdgeInsets.symmetric(
              horizontal: s.md,
              vertical: s.sm + s.xs / 2,
            ),
            child: Row(
              children: [
                Container(
                  width: StoryTokens.optionDot,
                  height: StoryTokens.optionDot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? StoryDeckTokens.bone
                        : StoryTokens.transparentColor,
                    border: Border.all(
                      color: selected
                          ? StoryDeckTokens.bone
                          : StoryDeckTokens.silver,
                      width: StoryTokens.optionDotStroke,
                    ),
                  ),
                ),
                SizedBox(width: s.sm),
                Expanded(
                  child: Text(
                    label,
                    style: context.typography.bodySmall.copyWith(
                      color: selected
                          ? CaseFileTokens.ink
                          : StoryDeckTokens.text2,
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

/// The three Ruqaa questions: who, why, how. Shared by the solo accusation
/// and the secret ballot, so every seat answers the same page.
class StoryAccusationForm extends StatelessWidget {
  const StoryAccusationForm({
    super.key,
    required this.story,
    required this.culprit,
    required this.motive,
    required this.method,
    required this.questionWho,
    required this.questionWhy,
    required this.questionHow,
    required this.onCulprit,
    required this.onMotive,
    required this.onMethod,
  });

  final StoryDefinition story;
  final String? culprit;
  final String? motive;
  final String? method;
  final String questionWho;
  final String questionWhy;
  final String questionHow;
  final ValueChanged<String> onCulprit;
  final ValueChanged<String> onMotive;
  final ValueChanged<String> onMethod;

  static Key suspectKey(String id) => ValueKey('story_suspect_$id');
  static Key motiveKey(String id) => ValueKey('story_motive_$id');
  static Key methodKey(String id) => ValueKey('story_method_$id');

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final q = StoryTokens.ruqaa(
      context.typography.title,
    ).copyWith(color: CaseFileTokens.ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(questionWho, style: q),
        SizedBox(height: s.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(top: StoryTokens.suspectLift),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in story.characters) ...[
                StorySuspect(
                  key: suspectKey(c.id),
                  character: c,
                  selected: culprit == c.id,
                  onTap: () => onCulprit(c.id),
                ),
                SizedBox(width: s.sm),
              ],
            ],
          ),
        ),
        SizedBox(height: s.md),
        Text(questionWhy, style: q),
        SizedBox(height: s.sm),
        for (final o in story.motives) ...[
          StoryOptionRow(
            key: motiveKey(o.id),
            label: o.label,
            selected: motive == o.id,
            onTap: () => onMotive(o.id),
          ),
          SizedBox(height: s.sm),
        ],
        SizedBox(height: s.sm),
        Text(questionHow, style: q),
        SizedBox(height: s.sm),
        for (final o in story.methods) ...[
          StoryOptionRow(
            key: methodKey(o.id),
            label: o.label,
            selected: method == o.id,
            onTap: () => onMethod(o.id),
          ),
          SizedBox(height: s.sm),
        ],
      ],
    );
  }
}

/// A button that is held, not tapped: a fill runs across it for [duration];
/// letting go early empties it. Completion is a [Timer], the fill only
/// illustrates it.
class StoryHoldButton extends StatefulWidget {
  const StoryHoldButton({
    super.key,
    required this.label,
    required this.doneLabel,
    required this.duration,
    required this.enabled,
    required this.onConfirmed,
  });

  final String label;
  final String doneLabel;
  final Duration duration;
  final bool enabled;
  final VoidCallback onConfirmed;

  @override
  State<StoryHoldButton> createState() => _StoryHoldButtonState();
}

class _StoryHoldButtonState extends State<StoryHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _timer;
  bool _done = false;

  /// The pointer that owns the hold in flight (same rule as HoldPad): a
  /// second finger can neither start nor end it.
  int? _pointer;

  @override
  void didUpdateWidget(StoryHoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled && !_done) {
      _timer?.cancel();
      _timer = null;
      _pointer = null;
      _fill.value = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fill.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _done || _pointer != null) return;
    _pointer = event.pointer;
    _fill.forward(from: 0);
    _timer?.cancel();
    _timer = Timer(widget.duration, () {
      if (!mounted) return;
      setState(() => _done = true);
      widget.onConfirmed();
    });
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_done) return;
    _timer?.cancel();
    _fill.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(context.radii.button);
    return Opacity(
      opacity: widget.enabled ? 1 : StoryDeckTokens.disabledAlpha,
      child: Listener(
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: Semantics(
          button: true,
          enabled: widget.enabled,
          label: widget.label,
          child: ClipRRect(
            borderRadius: r,
            child: SizedBox(
              height: StoryDeckTokens.primaryHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: StoryDeckTokens.bone),
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _fill,
                      builder: (context, _) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FractionallySizedBox(
                          widthFactor: _done ? 1 : _fill.value,
                          heightFactor: 1,
                          child: const ColoredBox(
                            color: StoryDeckTokens.bonePressed,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      _done ? widget.doneLabel : widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.title.copyWith(
                        color: StoryDeckTokens.ink,
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
  }
}

/// A stamp landing, with the score under it: large and turned, then settled.
class StoryStampLanding extends StatefulWidget {
  const StoryStampLanding({
    super.key,
    required this.text,
    required this.detail,
    required this.color,
  });

  final String text;
  final String detail;
  final Color color;

  @override
  State<StoryStampLanding> createState() => _StoryStampLandingState();
}

class _StoryStampLandingState extends State<StoryStampLanding>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: StoryTokens.stampDrop,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_still(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = context.typography;
    return CaseStampDrop(
      progress: _c,
      child: CaseStamp(
        '${widget.text}\n${widget.detail}',
        color: widget.color,
        style: StoryTokens.ruqaa(
          type.display,
        ).copyWith(color: widget.color, fontSize: StoryTokens.stampBig),
      ),
    );
  }
}

/// A ring that empties over a discussion; decoration only.
class StoryTimerRing extends StatelessWidget {
  const StoryTimerRing({
    super.key,
    required this.fraction,
    required this.child,
  });

  final double fraction;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: StoryTokens.timerRing,
    height: StoryTokens.timerRing,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size.square(StoryTokens.timerRing),
          painter: _RingPainter(fraction.clamp(0.0, 1.0)),
        ),
        child,
      ],
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(StoryTokens.timerStroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = StoryTokens.timerStroke
      ..color = StoryTokens.ringTrack;
    canvas.drawArc(inset, 0, math.pi * 2, false, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = StoryTokens.timerStroke
      ..color = StoryDeckTokens.bone;
    canvas.drawArc(inset, -math.pi / 2, math.pi * 2 * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

/// The private file of a seat. **One layout for every seat**: the photo, who
/// you are, the thing you must do and a stack of clue notes, whoever holds
/// it, the one who did it included. Nothing on it says which seat that is.
class StoryDossier extends StatelessWidget {
  const StoryDossier({
    super.key,
    required this.character,
    required this.clues,
    required this.youAre,
    required this.mustDo,
  });

  final StoryCharacter character;

  /// One entry per round; null is an empty slot (same height for all seats).
  final List<StoryClue?> clues;
  final String youAre;
  final String mustDo;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    return CaseFilePaper(
      padding: EdgeInsets.all(s.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoryPhoto(
                image: character.image,
                width: StoryTokens.dossierPhotoWidth,
                height: StoryTokens.dossierPhotoHeight,
                turn: StoryTokens.folderPhotoTilt,
                bottomMat: StoryTokens.photoMatBottom,
                focusTop: true,
              ),
              SizedBox(width: s.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      youAre,
                      style: type.caption.copyWith(
                        color: CaseFileTokens.inkMuted,
                      ),
                    ),
                    Text(
                      character.name,
                      style: StoryTokens.ruqaa(
                        type.headline,
                      ).copyWith(color: CaseFileTokens.ink),
                    ),
                    Text(
                      character.background,
                      style: type.bodySmall.copyWith(
                        color: StoryDeckTokens.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: s.md),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CaseFileTokens.radius),
              border: Border.all(
                color: StoryDeckTokens.bone.withValues(
                  alpha: StoryTokens.dashAlpha,
                ),
                width: StoryTokens.dossierDash,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(s.sm + s.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mustDo,
                    style: type.bodySmall.copyWith(
                      color: StoryDeckTokens.bone,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    character.objective,
                    style: type.body.copyWith(color: CaseFileTokens.ink),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: s.md),
          for (final (i, clue) in clues.indexed) ...[
            if (clue == null)
              SizedBox(
                height: StoryTokens.emptyClueSlot,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(CaseFileTokens.radius),
                    border: Border.all(
                      color: StoryDeckTokens.bone.withValues(
                        alpha: StoryTokens.dashAlpha,
                      ),
                      width: StoryTokens.dossierDash,
                    ),
                  ),
                ),
              )
            else
              StoryNote(
                title: clue.title,
                body: clue.body,
                turn: i.isEven ? -0.02 : 0.02,
              ),
            SizedBox(height: s.sm + s.xs),
          ],
        ],
      ),
    );
  }
}
