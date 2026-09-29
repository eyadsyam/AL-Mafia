import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../../engine/models/enums.dart';
import '../../../engine/models/player.dart';
import '../../widgets/hint_slot.dart';
import '../../l10n_ext.dart';
import '../../economy/cosmetic_paint.dart';
import '../../economy/pass_table_dress.dart';
import '../../theme/mafia_theme.dart';
import '../../theme/design_tokens.dart';
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
  static const Key skipButton = ValueKey('discussion_skip');

  /// Discussion mode: structured (taking turns) or free (open discussion).
  final DiscussionMode mode;

  /// List of alive players in seating order.
  final List<PublicPlayer> alivePlayers;

  /// Time allowed per speaker in structured mode.
  final Duration perSpeakerTime;

  /// How long the whole free discussion runs.
  ///
  /// Free mode used to derive this as [perSpeakerTime] times the head count,
  /// which made "how long may we argue" a number nobody had ever chosen — and
  /// made it *grow* with the table exactly where doc 13 §3 wants it to shrink.
  /// It is now its own setting, and the pressure curve tightens it.
  ///
  /// Null falls back to the old derivation, which is what a caller that has
  /// not been told about the setting still gets.
  final Duration? totalTime;

  /// Callback when discussion ends.
  final VoidCallback onFinished;

  /// Fired when the floor moves to the next speaker (structured mode only).
  /// The chime is an on-table cue; the screen does not play it itself, because
  /// only the caller knows whether the phone is on the table (L-11).
  final VoidCallback? onSpeakerChanged;

  /// Fired when a speaking slot runs out of time, as opposed to being skipped.
  final VoidCallback? onTimerEnded;

  /// Reports how long a speaker actually held the floor, in seconds.
  ///
  /// The only source for `C6` («انت أقل واحد اتكلم»). Fired whether the slot
  /// expired or was skipped, because a player who waves the phone on after four
  /// seconds has spoken for four seconds, and that is exactly the observation
  /// the confrontation is about.
  final void Function(int seat, int seconds)? onSpoke;

  /// Opens the whisper composer. Null when the layer is off for this match.
  final VoidCallback? onWhisper;

  /// Today's whisper graph, as `(sender, recipient)` display names.
  ///
  /// Public by design (doc 09 §3.1) — *"The existence and the recipient are
  /// public. The content is private."* Nothing here carries a body.
  final List<(String, String)> whisperGraph;

  /// Whether doc 13 §4.2's one-line interface hints are printed at all.
  ///
  /// The slot's space is reserved either way; this only decides whether
  /// anything goes in it. See [HintSlot].
  final bool interfaceHintsEnabled;
  final bool tabletop;

  const DiscussionScreen({
    super.key,
    this.interfaceHintsEnabled = true,
    required this.mode,
    required this.alivePlayers,
    required this.perSpeakerTime,
    this.totalTime,
    required this.onFinished,
    this.onSpeakerChanged,
    this.onTimerEnded,
    this.onSpoke,
    this.onWhisper,
    this.whisperGraph = const [],
    this.tabletop = false,
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
      _remaining =
          widget.totalTime ??
          widget.perSpeakerTime * widget.alivePlayers.length;
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

  /// Reports the floor time of the speaker who is finishing.
  void _reportSpoke(Duration used) {
    final report = widget.onSpoke;
    if (report == null) return;
    if (widget.mode != DiscussionMode.structured) return;
    if (_currentSpeakerIndex >= widget.alivePlayers.length) return;
    report(widget.alivePlayers[_currentSpeakerIndex].seat, used.inSeconds);
  }

  void _handlePhaseEnd() {
    _countdownTimer.cancel();
    _reportSpoke(widget.perSpeakerTime);
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
    _reportSpoke(widget.perSpeakerTime - _remaining);
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
                      key: const ValueKey('discussion_headline'),
                      style: type.display.copyWith(
                        color: colors.textPrimary,
                        fontSize: widget.tabletop
                            ? TabletopTokens.headlineFontSize
                            : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.sm),
                    // Doc 14 Part 6: the row is reserved and empty. Nothing
                    // teaches during a live match, in either mode — but the
                    // reservation is what keeps the screen the same height as
                    // it was, so the timer under it does not jump.
                    SizedBox(height: HintSlot.reservedHeight(context)),
                    SizedBox(height: spacing.sm),

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
                            // Store truth: the host's own plate when the host
                            // holds the floor (public discussion only).
                            CosmeticNameplate(
                              name: currentSpeaker.name,
                              plate: HostIdentityScope.plateFor(
                                context,
                                currentSpeaker.name,
                              ),
                              style: type.title.emphasised.copyWith(
                                color: colors.accentGold,
                                fontSize: widget.tabletop
                                    ? TabletopTokens.factFontSize
                                    : null,
                              ),
                              textAlign: TextAlign.center,
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
                          tabletop: widget.tabletop,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.lg),

                    // The whisper graph, and the way into the composer. Both
                    // are on-table: who wrote to whom is meant to be argued
                    // about, and the composer gates itself behind a seat pick.
                    if (widget.onWhisper != null) ...[
                      _WhisperPanel(
                        graph: widget.whisperGraph,
                        onCompose: widget.onWhisper!,
                      ),
                      SizedBox(height: spacing.lg),
                    ],

                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Skip button
                        Expanded(
                          child: OutlinedButton(
                            key: DiscussionScreen.skipButton,
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

/// The public half of the whisper layer, on the discussion screen.
///
/// Shows the day's edges — «أحمد ← سارة» — and the control that opens the
/// composer. It never shows a body, and it has no way to reach one: the graph
/// arrives as display names and the store is not wired into this widget at all.
class _WhisperPanel extends StatelessWidget {
  final List<(String, String)> graph;
  final VoidCallback onCompose;

  const _WhisperPanel({required this.graph, required this.onCompose});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.whisperLabel,
            style: type.caption.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.sm),
          if (graph.isEmpty)
            Text(
              l10n.whisperGraphEmpty,
              style: type.bodySmall.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            )
          else
            for (final (from, to) in graph)
              Padding(
                padding: EdgeInsets.only(bottom: spacing.xs),
                child: Text(
                  '$from  ${l10n.whisperArrow}  $to',
                  style: type.body.copyWith(color: colors.textPrimary),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          SizedBox(height: spacing.sm),
          OutlinedButton(
            onPressed: onCompose,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textPrimary,
              side: BorderSide(color: colors.borderSubtle),
              padding: EdgeInsets.symmetric(vertical: spacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radii.button),
              ),
            ),
            child: Text(
              l10n.whisperCompose,
              style: type.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
