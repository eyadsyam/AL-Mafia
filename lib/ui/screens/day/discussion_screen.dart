import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../../engine/models/enums.dart';
import '../../../engine/models/player.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/phase_timer.dart';
import '../../widgets/textured_surface.dart';

/// Discussion Screen (S-11) — structured or free-form discussion phase.
///
/// Displays a countdown timer and manages speaker turns (structured mode) or
/// a single discussion countdown (free mode). Players can skip to the next
/// speaker (structured) or resume/pause the timer. When the final speaker
/// finishes or the free discussion timer expires, calls [onFinished].
///
/// Reference: spec FR-016, FR-017, T034
class DiscussionScreen extends StatefulWidget {
  /// Discussion mode: structured (taking turns) or free (open discussion).
  final DiscussionMode mode;

  /// List of alive players in seating order.
  final List<PublicPlayer> alivePlayers;

  /// Time allowed per speaker (structured) or total time (free).
  final Duration perSpeakerTime;

  /// Callback when discussion ends.
  final VoidCallback onFinished;

  /// Fired when the floor moves to the next speaker (structured mode only).
  /// The chime is an on-table cue; the screen does not play it itself, because
  /// only the caller knows whether the phone is on the table (L-11).
  final VoidCallback? onSpeakerChanged;

  /// Fired when a speaking slot runs out of time, as opposed to being skipped.
  final VoidCallback? onTimerEnded;

  const DiscussionScreen({
    super.key,
    required this.mode,
    required this.alivePlayers,
    required this.perSpeakerTime,
    required this.onFinished,
    this.onSpeakerChanged,
    this.onTimerEnded,
  });

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen>
    with TickerProviderStateMixin {
  late Timer _countdownTimer;
  late Duration _remaining;
  late int _currentSpeakerIndex;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _currentSpeakerIndex = 0;
    if (widget.mode == DiscussionMode.structured) {
      _remaining = widget.perSpeakerTime;
    } else {
      _remaining = widget.perSpeakerTime * widget.alivePlayers.length;
    }
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_isPaused) return;

      setState(() {
        if (_remaining.inSeconds > 0) {
          _remaining -= const Duration(seconds: 1);
        } else {
          _handlePhaseEnd();
        }
      });
    });
  }

  void _handlePhaseEnd() {
    _countdownTimer.cancel();
    // The slot expired rather than being skipped, which is the case the two
    // ascending tones exist to mark (design §8).
    widget.onTimerEnded?.call();

    if (widget.mode == DiscussionMode.structured) {
      // Move to next speaker
      if (_currentSpeakerIndex < widget.alivePlayers.length - 1) {
        _currentSpeakerIndex++;
        _remaining = widget.perSpeakerTime;
        widget.onSpeakerChanged?.call();
        _startCountdown();
      } else {
        // Last speaker finished
        widget.onFinished();
      }
    } else {
      // Free mode: discussion ends
      widget.onFinished();
    }
  }

  void _skipSpeaker() {
    _countdownTimer.cancel();
    if (widget.mode == DiscussionMode.structured) {
      if (_currentSpeakerIndex < widget.alivePlayers.length - 1) {
        _currentSpeakerIndex++;
        _remaining = widget.perSpeakerTime;
        setState(() {});
        widget.onSpeakerChanged?.call();
        _startCountdown();
      } else {
        widget.onFinished();
      }
    } else {
      // In free mode, skip acts like ending
      widget.onFinished();
    }
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  int get _speakersRemaining {
    if (widget.mode == DiscussionMode.structured) {
      return widget.alivePlayers.length - _currentSpeakerIndex;
    }
    return 0; // Not shown in free mode
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final radii = context.radii;
    final l10n = context.l10n;

    // The index is clamped rather than trusted: a player removed mid-discussion
    // shortens the roster under us, and a range error here would take down the
    // screen in front of the whole table.
    final speakerIndex = _currentSpeakerIndex.clamp(
      0,
      widget.alivePlayers.length - 1,
    );
    final currentSpeaker = widget.alivePlayers[speakerIndex];
    final totalTime = widget.mode == DiscussionMode.structured
        ? widget.perSpeakerTime
        : widget.perSpeakerTime * widget.alivePlayers.length;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: AppBackdrop(
        // The day is public by definition — nobody is holding anything — so
        // this is the one screen allowed to be brighter than the ground.
        image: AppImages.bgDay,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.screenMargin,
                  vertical: spacing.lg,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    Text(
                      widget.mode == DiscussionMode.structured
                          ? l10n.discussionTitle
                          : l10n.discussionFreeTitle,
                      style: type.display.copyWith(color: colors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.lg),

                    // Speaker info (structured mode only)
                    if (widget.mode == DiscussionMode.structured) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.md,
                          vertical: spacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceRaised,
                          borderRadius: BorderRadius.circular(radii.card),
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        child: Column(
                          children: [
                            Text(
                              l10n.currentSpeaker,
                              style: type.caption.copyWith(
                                color: colors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: spacing.sm),
                            Text(
                              currentSpeaker.name,
                              style: type.title.emphasised.copyWith(
                                color: colors.accentGold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: spacing.sm),
                            Text(
                              l10n.speakersRemaining(_speakersRemaining),
                              style: type.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spacing.lg),
                    ],

                    // Timer
                    Expanded(
                      child: Center(
                        child: PhaseTimer(
                          remaining: _remaining,
                          total: totalTime,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.lg),

                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Skip button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _skipSpeaker,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.textPrimary,
                              side: BorderSide(color: colors.borderSubtle),
                              padding: EdgeInsets.symmetric(
                                vertical: spacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  radii.button,
                                ),
                              ),
                            ),
                            child: Text(
                              // In free mode this control ends the discussion
                              // outright, so calling it "skip" would misdescribe
                              // what tapping it does.
                              widget.mode == DiscussionMode.structured
                                  ? l10n.skip
                                  : l10n.endDiscussion,
                              style: type.body.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: spacing.md),

                        // Pause/Resume button
                        Expanded(
                          child: FilledButton(
                            onPressed: _togglePause,
                            style: FilledButton.styleFrom(
                              backgroundColor: _isPaused
                                  ? colors.accentSage
                                  : colors.accentGold,
                              foregroundColor: colors.surfaceBase,
                              padding: EdgeInsets.symmetric(
                                vertical: spacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  radii.button,
                                ),
                              ),
                            ),
                            child: Text(
                              _isPaused ? l10n.resume : l10n.pause,
                              style: type.body,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
