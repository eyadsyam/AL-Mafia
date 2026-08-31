import 'dart:async';

import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/mafia_theme.dart';
import 'falling_icons.dart';
import 'textured_surface.dart';

/// A full-screen phase announcement: one line of Egyptian Arabic, faded up over
/// a dark textured ground, held, and faded away.
///
/// ## Why every one of these is the same length
///
/// These are on-table moments — nobody is holding the phone, so none of them is
/// leakage-critical in the way a turn gate is. But the table learns rhythms
/// fast, and a night that took longer to arrive than a morning would become a
/// tell before anyone consciously noticed it was one. The fade, the hold and
/// the fade back are read from [MafiaTiming] and are identical for all six
/// announcements; the only thing that differs is the string.
///
/// That also holds under Reduce Motion. The text snaps in rather than fading,
/// but the *total* time on screen is the same — an accessibility setting must
/// not change how long the game takes, or turning it on becomes a signal too.
///
/// ## The narrator slot
///
/// [onStart] fires the moment the announcement appears. The match flow uses it
/// to ask [AudioDirector] for the matching cue, which plays an ambient bed, a
/// recorded narrator line, both, or nothing at all depending on what has been
/// recorded. The words on screen are the fallback and are always present, so the
/// game is complete before a single line has been voiced.
class CinematicText extends StatefulWidget {
  final String text;

  /// The announcement's backdrop, or null for the bare ground.
  ///
  /// Every announcement is on-table — the phone is flat and the whole room is
  /// reading the same words at the same time — which is the only reason there
  /// may be art behind them at all. The picture is chosen by the *moment*, in
  /// `MatchFlow._Moment`, and never by anybody's role.
  final String? image;

  /// The ambient loop for this announcement, played unless Reduce Motion is on.
  final String? loop;

  /// Fired once, as the announcement begins. The audio hook.
  final VoidCallback? onStart;

  /// Fired once, after the fade out has finished.
  final VoidCallback? onComplete;

  const CinematicText({
    super.key,
    required this.text,
    this.image,
    this.loop,
    this.onStart,
    this.onComplete,
  });

  @override
  State<CinematicText> createState() => _CinematicTextState();
}

class _CinematicTextState extends State<CinematicText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _fade;
  Timer? _sequence;
  bool _started = false;
  double _staticOpacity = 0.0;

  /// Bumped on every restart, so a sequence that was still in flight when the
  /// line changed cannot fire the new one's completion callback. Without it, an
  /// announcement replaced mid-fade would advance the match twice.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.linear);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fade.curve = context.motion.dramaticCurve;
    if (_started) return;
    _started = true;
    _run();
  }

  @override
  void didUpdateWidget(CinematicText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new line is a new announcement, even without a new key. The match flow
    // does key them, but a caller that simply swaps the string — a phase that
    // announces twice in a row — would otherwise get one announcement and then
    // silence, which looks exactly like a hang.
    if (widget.text != oldWidget.text) {
      _sequence?.cancel();
      _controller.reset();
      _staticOpacity = 0.0;
      _run();
    }
  }

  Future<void> _run() async {
    final generation = ++_generation;
    bool stale() => !mounted || _generation != generation;

    final fade = context.motion.dramatic;
    final hold = context.timing.phaseHold;

    widget.onStart?.call();

    if (ReduceMotion.of(context)) {
      // No fade, but the same wall-clock length. Timer rather than
      // `Future.delayed` so it can be cancelled on dispose — an announcement
      // whose completion callback fires after the match has moved on would
      // advance the game twice.
      setState(() => _staticOpacity = 1.0);
      _sequence = Timer(fade + hold + fade, () {
        if (stale()) return;
        setState(() => _staticOpacity = 0.0);
        widget.onComplete?.call();
      });
      return;
    }

    _controller.duration = fade;
    await _controller.forward();
    if (stale()) return;

    final done = Completer<void>();
    _sequence = Timer(hold, done.complete);
    await done.future;
    if (stale()) return;

    await _controller.reverse();
    if (stale()) return;
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _sequence?.cancel();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final spacing = context.spacing;

    final line = Text(
      widget.text,
      style: typography.display.copyWith(color: colors.textPrimary),
      textAlign: TextAlign.center,
    );

    return AppBackdrop(
      image: widget.image,
      loop: widget.loop,
      child: Stack(
        children: [
          // The corner icons drifting behind the words. Atmosphere only: all
          // four fall together in every announcement, so nothing here says
          // anything about anyone's role.
          const Positioned.fill(child: FallingIcons()),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.screenMargin),
              child: ReduceMotion.of(context)
                  ? Opacity(opacity: _staticOpacity, child: line)
                  : FadeTransition(opacity: _fade, child: line),
            ),
          ),
        ],
      ),
    );
  }
}
