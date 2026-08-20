import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/mafia_theme.dart';
import 'textured_surface.dart';

/// A deck of cards dealt one at a time.
///
/// The active card sits on a short pile; advancing sends it off the screen in
/// the reading direction and brings the next one up out of the pile. Going back
/// runs the same thing in reverse.
///
/// ## Controlled, not self-driving
///
/// The deck does not own [index]. The screen around it does, because the screen
/// also owns the pip row, the primary action and the "this is the last card"
/// decision — and two widgets holding the same integer is how a pip row ends up
/// one behind the card it describes. [onStep] reports a *request* to move; the
/// parent decides whether to honour it and passes a new [index] back down, at
/// which point the deck animates.
///
/// ## The cards behind are blank stock
///
/// Only the active card is built from [builder]. The two behind it are empty
/// [PaperPanel]s. That is both cheaper — the roles chapter builds four decoded
/// paintings, and it would build them again as a background nobody can read —
/// and more honest: a card you have not been dealt yet should not be legible
/// over the shoulder of the one you are reading.
///
/// ## Direction
///
/// Everything horizontal here is signed by [Directionality]. In the app's
/// Arabic default the deck advances rightwards-to-leftwards in the same sense
/// the text runs, so the dealt card leaves towards the right edge; under an
/// English locale it leaves towards the left. Nothing in the widget hardcodes a
/// side.
///
/// ## Motion budget
///
/// Every animation here is bounded and ends. Unlike the home spread, there is
/// no ambient float, so no [AmbientMotion] opt-out is needed and
/// `pumpAndSettle` terminates in tests. Reduce Motion collapses the duration to
/// zero, which leaves the deck fully usable and instantly stepped.
class OnboardingDeck extends StatefulWidget {
  /// The card on top.
  final int index;

  /// How many cards the deck holds.
  final int length;

  /// Builds the active card. Called for [index] only.
  final IndexedWidgetBuilder builder;

  /// A swipe asked to move by `delta` (+1 forward, -1 back). The parent decides
  /// whether that is allowed.
  final ValueChanged<int> onStep;

  const OnboardingDeck({
    super.key,
    required this.index,
    required this.length,
    required this.builder,
    required this.onStep,
  });

  /// How far a drag must travel, as a fraction of the deck's width, before
  /// release counts as a deal rather than a fidget.
  static const double _dragFraction = 0.22;

  /// A fling this fast counts regardless of distance, in logical pixels per
  /// second. Matches the threshold `role_card.dart` uses for its swipe, so the
  /// two card gestures in the app feel like the same gesture.
  static const double _flingVelocity = 300.0;

  @override
  State<OnboardingDeck> createState() => _OnboardingDeckState();
}

class _OnboardingDeckState extends State<OnboardingDeck>
    with SingleTickerProviderStateMixin {
  /// The level of the card in play. Levels count backwards into the pile.
  static const double _seated = 1;

  /// How much smaller each card is than the one in front of it.
  static const double _depthScale = 0.05;

  /// How far off the edge a dealt card travels, as a multiple of the deck's
  /// width. Slightly over one so the card is fully gone before it stops, rather
  /// than resting with its edge on the screen boundary.
  static const double _exitTravel = 1.2;

  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  /// The card being animated away, or null when the deck is at rest.
  int? _previous;

  /// +1 when the deck is moving forward, -1 when it is stepping back.
  int _direction = 1;

  /// Horizontal distance travelled by the current drag.
  double _drag = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deal.duration =
        ReduceMotion.of(context) ? Duration.zero : context.motion.standard;
  }

  @override
  void didUpdateWidget(OnboardingDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _previous = oldWidget.index;
    _direction = widget.index > oldWidget.index ? 1 : -1;
    _deal.forward(from: 0.0).whenComplete(() {
      // Guarded: the deck can be disposed mid-deal if the host skips out of
      // onboarding while a card is still travelling.
      if (mounted) setState(() => _previous = null);
    });
  }

  @override
  void dispose() {
    _deal.dispose();
    super.dispose();
  }

  /// Which way a dealt card leaves, in logical-pixel sign.
  ///
  /// Under RTL the deck reads right to left, so the card that has been finished
  /// with departs towards the trailing edge — which is the right of the screen.
  double get _exitSign =>
      Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;

  void _onDragEnd(DragEndDetails details, double width) {
    final velocity = details.primaryVelocity ?? 0.0;
    final travelled = _drag;
    _drag = 0;

    final farEnough = travelled.abs() > width * OnboardingDeck._dragFraction;
    final fastEnough = velocity.abs() > OnboardingDeck._flingVelocity;
    if (!farEnough && !fastEnough) return;

    // A drag towards the exit edge advances; the opposite direction steps back.
    final towardsExit = (fastEnough ? velocity : travelled) * _exitSign > 0;
    widget.onStep(towardsExit ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _drag = 0,
          onHorizontalDragUpdate: (details) => _drag += details.delta.dx,
          onHorizontalDragEnd: (details) => _onDragEnd(details, width),
          child: AnimatedBuilder(
            animation: _deal,
            builder: (context, _) {
              final t = context.motion.standardCurve.transform(_deal.value);
              final travel = _exitSign * width * _exitTravel;
              final leaving = _previous;

              if (leaving == null) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ..._pile(spacing.md),
                    _placed(
                      level: _seated,
                      step: spacing.md,
                      child: widget.builder(context, widget.index),
                    ),
                  ],
                );
              }

              // Forward: the finished card slides off the top of the deck while
              // the next one rises into its place from one level back. Back:
              // the same two motions with their roles exchanged. In both cases
              // the card that is *moving horizontally* has to paint above the
              // one that is not, or it appears to slide underneath it.
              final forward = _direction > 0;
              final departing = _placed(
                level: forward ? _seated : _seated + t,
                step: spacing.md,
                slide: forward ? travel * t : 0.0,
                child: widget.builder(context, leaving),
              );
              final arriving = _placed(
                level: forward ? _seated + (1 - t) : _seated,
                step: spacing.md,
                slide: forward ? 0.0 : travel * (1 - t),
                child: widget.builder(context, widget.index),
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  ..._pile(spacing.md),
                  if (forward) ...[arriving, departing] else ...[
                    departing,
                    arriving,
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// The undealt remainder, as blank stock peeking above the active card.
  ///
  /// Two at most. A pile that grows with the chapter count would say "four
  /// left" precisely, and would also be four more panels to composite for a
  /// distinction nobody makes at a glance; the pip row is what carries the
  /// count exactly.
  List<Widget> _pile(double step) {
    final remaining = widget.length - widget.index - 1;
    return <Widget>[
      // Furthest back first, so the nearer card paints over it.
      for (var behind = remaining.clamp(0, 2); behind >= 1; behind--)
        _placed(
          level: _seated + behind,
          step: step,
          child: const PaperPanel(child: SizedBox.expand()),
        ),
    ];
  }

  /// Places one card in the pile.
  ///
  /// [level] is depth in cards: [_seated] is the card in play, one more is a
  /// card behind it. Fractional levels are what a card rising out of the pile
  /// passes through.
  Widget _placed({
    required double level,
    required double step,
    double slide = 0,
    required Widget child,
  }) {
    final behind = level - _seated;

    return Transform.translate(
      offset: Offset(slide, -step * behind),
      child: Transform.scale(
        // Five per cent a card: enough to read as depth, small enough that the
        // pile does not look like a fan.
        scale: 1 - _depthScale * behind,
        child: child,
      ),
    );
  }
}
