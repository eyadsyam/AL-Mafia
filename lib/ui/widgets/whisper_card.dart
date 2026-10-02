import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';

/// Doc 14 §3.4 — an arriving whisper, in the game's own styling.
///
/// ## What it is not
///
/// Not a system toast, not a dialog, and not a screen. A toast belongs to the
/// operating system and looks like it; a dialog stops the match; a screen takes
/// the table away from a player in the middle of the argument the whisper is
/// about. This is a card that slides down over the top of the table and leaves
/// everything under it live — the timer keeps running, the seats keep moving,
/// and the vote can still be watched while it is read.
///
/// ## Once, and then never again
///
/// The body is shown here and nowhere else. It is not written to the table, not
/// recalled from a list, and not persisted on screen — doc 14 §3.3: *"Private,
/// shown once, never persisted on screen."* Dismiss it or let it withdraw on
/// its own after [MafiaTiming.whisperCardDwell]; either way the words are gone
/// and only the public edge remains.
class WhisperCard extends StatefulWidget {
  /// Who sent it. Public already — the whole table can see the edge.
  final String senderName;

  /// The hundred and twenty characters. Never leaves this widget.
  final String body;

  /// Fired on dismissal, whether by the button or by the clock. The caller
  /// marks it delivered here.
  final VoidCallback onDismissed;

  const WhisperCard({
    super.key,
    required this.senderName,
    required this.body,
    required this.onDismissed,
  });

  static const Key card = ValueKey('whisper_card');
  static const Key dismiss = ValueKey('whisper_card_dismiss');

  @override
  State<WhisperCard> createState() => _WhisperCardState();
}

class _WhisperCardState extends State<WhisperCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(vsync: this);
  Timer? _withdraw;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_slide.duration != null) return;
    _slide
      ..duration = context.motion.travel
      ..forward();
    _withdraw = Timer(context.timing.whisperCardDwell, _dismiss);
  }

  @override
  void dispose() {
    _withdraw?.cancel();
    _slide.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_done) return;
    _done = true;
    _withdraw?.cancel();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: _slide,
                  curve: context.motion.travelCurve,
                ),
              ),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
              child: DecoratedBox(
                key: WhisperCard.card,
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(radii.card),
                  border: Border.all(color: colors.accentGold),
                ),
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.whisperFromTitle(widget.senderName),
                        style: type.caption.copyWith(color: colors.accentGold),
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        widget.body,
                        style: type.body.copyWith(color: colors.textPrimary),
                      ),
                      SizedBox(height: spacing.sm),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          key: WhisperCard.dismiss,
                          onPressed: _dismiss,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.textMuted,
                          ),
                          child: Text(
                            l10n.whisperDismiss,
                            style: type.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
