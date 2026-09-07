import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../platform/reduce_motion.dart';
import '../../../theme/design_tokens.dart';

/// Doc 16 V1/V2: the short sting that plays when the light changes.
///
/// ## Why it is over the council and not instead of it
///
/// Doc 15 §1.1 has one rule the whole redesign rests on: the match is one
/// place, and a phase change re-dresses it rather than replacing it. A sting
/// that took the screen would be the slideshow the four bands exist to end. So
/// it plays *over* the council at partial opacity, the seats stay where they
/// are underneath, and it is gone in a second.
///
/// ## Why it is muted, and why that is not a compromise
///
/// The sound of this game is [AudioDirector]'s: one cue per beat, chosen so it
/// cannot be heard as *whose* beat it was. A video with its own audio track is
/// a second sound system with no such rule in it, playing at a moment when the
/// room is listening hardest. Muted, the sting is what it should be — light —
/// and the cue that goes with it is the one the director already plays.
///
/// ## Why nothing waits on it
///
/// Same reason nothing waits on voice (doc 10 §1.2). A codec that is missing,
/// a decoder that is busy, a platform that does not do WebM at all: every one
/// of them ends here, with [onFinished] called and nothing drawn. The phase has
/// already changed — this is the flourish on top of it, and a flourish that can
/// stop a match is not a flourish.
class PhaseSting extends StatefulWidget {
  /// The clip. One of `AppVideo.stingNight` or `AppVideo.stingDawn`.
  final String asset;

  /// Called when the sting is over, or when it turned out there was not going
  /// to be one.
  final VoidCallback onFinished;

  const PhaseSting({
    super.key,
    required this.asset,
    required this.onFinished,
  });

  static const Key surface = ValueKey('council_phase_sting');

  @override
  State<PhaseSting> createState() => _PhaseStingState();
}

class _PhaseStingState extends State<PhaseSting> {
  VideoPlayerController? _player;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_player != null || _done) return;
    // A video *is* motion. There is no cross-fade of a sting that is worth
    // watching, so Reduce Motion gets the phase change on its own.
    if (ReduceMotion.of(context)) {
      _finish();
      return;
    }
    _start();
  }

  Future<void> _start() async {
    final player = VideoPlayerController.asset(widget.asset);
    _player = player;
    try {
      await player.initialize();
      await player.setVolume(0);
      await player.setLooping(false);
      player.addListener(_watch);
      await player.play();
      if (mounted) setState(() {});
    } catch (_) {
      _finish();
    }
  }

  void _watch() {
    final player = _player;
    if (player == null || _done) return;
    final value = player.value;
    if (value.hasError || (value.isInitialized && !value.isPlaying &&
        value.position >= value.duration)) {
      _finish();
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    // After the frame: this can be reached from a player callback during a
    // build, and the caller's `onFinished` sets state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _player?.removeListener(_watch);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null || !player.value.isInitialized || _done) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      key: PhaseSting.surface,
      child: Opacity(
        opacity: CouncilTokens.stingOpacity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: player.value.size.width,
            height: player.value.size.height,
            child: VideoPlayer(player),
          ),
        ),
      ),
    );
  }
}
