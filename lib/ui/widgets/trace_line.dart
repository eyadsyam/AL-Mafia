import 'dart:async';

import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/mafia_theme.dart';

/// The morning's trace, arriving a beat after the death line (doc 09 §1.7).
///
/// ## The beat is the feature
///
/// *"Trace text appears 1.2s after the death line — never simultaneously. The
/// pause is the drama."* A trace that lands at the same instant as the name of
/// the person who died is read as part of the same sentence and lands as
/// nothing; a trace that arrives into a room that has just gone quiet is the
/// thing that starts the argument.
///
/// ## Same treatment for every type
///
/// No icon, no colour coding, no per-type layout — §1.7 again: *"colour-coding
/// traces would let players classify them before reading."* A table that has
/// learned that gold means «آخر شك للضحية» stops listening to the sentence and
/// starts reading the divider. So there is exactly one appearance, and the only
/// thing that varies between mornings is the words.
///
/// Under Reduce Motion the text is simply there. The delay is a fade, not a
/// gate: nothing is withheld, so honouring the setting costs nothing.
class TraceLine extends StatefulWidget {
  /// The caption above the rule — «الأثر».
  final String label;

  /// The observation itself.
  final String text;

  const TraceLine({super.key, required this.label, required this.text});

  @override
  State<TraceLine> createState() => _TraceLineState();
}

class _TraceLineState extends State<TraceLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Held rather than awaited, so it can be cancelled.
  ///
  /// A `Future.delayed` here is a timer the widget cannot reach, and a screen
  /// torn down inside the beat leaves it running — which in a widget test is a
  /// hard failure ("a Timer is still pending after the widget tree was
  /// disposed") and in the app is a stray callback on a dead State.
  Timer? _beat;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = context.motion.standard;
    if (_started) return;
    _started = true;
    _start();
  }

  void _start() {
    // Under Reduce Motion the text is simply there. Nothing is withheld by the
    // delay, so removing it costs the reader nothing.
    if (ReduceMotion.of(context)) {
      _controller.value = 1;
      return;
    }
    _beat = Timer(context.timing.traceBeat, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _beat?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return FadeTransition(
      opacity: _controller,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: colors.borderSubtle)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                child: Text(
                  widget.label,
                  style: type.caption.copyWith(color: colors.textMuted),
                ),
              ),
              Expanded(child: Divider(color: colors.borderSubtle)),
            ],
          ),
          SizedBox(height: spacing.md),
          Text(
            widget.text,
            style: type.title.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
