import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/asset_constants.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';

/// What the player the Mafia killed sees when the morning comes: the reaper,
/// lunging at them. Owner's request (2026-09-23) — a death at night should
/// *land*, on the one phone it belongs to, before the table's discussion.
///
/// ## Why only that phone, and why that is safe
///
/// Online, every player holds their own phone, and the morning report already
/// names the victim to the whole room. The scare adds nothing anybody else can
/// learn from; it plays only where the victim is looking, and it ends where the
/// witness's view begins.
///
/// ## Why nothing waits on it
///
/// Same rule as every flourish: a codec that is missing or a decoder that is
/// busy ends here with [onFinished] called and nothing drawn. The match has
/// already moved on under it.
class KillJumpscare extends StatefulWidget {
  /// Silence the scream when the player has switched sound off.
  final bool muted;

  /// False while the clip is only being loaded — the death is known before
  /// the morning is, and a decoder warmed in advance means the scare lands on
  /// the first frame of the morning instead of after a second of black.
  final bool armed;
  final VoidCallback onFinished;

  const KillJumpscare({
    super.key,
    required this.muted,
    required this.onFinished,
    this.armed = true,
  });

  static const Key surface = ValueKey('kill_jumpscare');

  @override
  State<KillJumpscare> createState() => _KillJumpscareState();
}

class _KillJumpscareState extends State<KillJumpscare> {
  VideoPlayerController? _player;
  bool _done = false;
  bool _leaving = false;

  /// The scare is drawn in the app's top overlay, not inside the table: the
  /// table sits above the call's control bar, and a reaper that stopped at
  /// that bar looked like a video in a box rather than the whole phone.
  final OverlayPortalController _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final player = VideoPlayerController.asset(AppVideo.killJumpscare);
    _player = player;
    try {
      await player.initialize();
      await player.setVolume(widget.muted ? 0 : 1);
      await player.setLooping(false);
      player.addListener(_watch);
      if (widget.armed) await player.play();
      if (mounted) setState(() {});
    } catch (_) {
      _finish();
    }
  }

  void _watch() {
    final player = _player;
    if (player == null || _done) return;
    final value = player.value;
    if (value.hasError) {
      _finish();
      return;
    }
    if (value.isInitialized &&
        !value.isPlaying &&
        value.position >= value.duration) {
      // Out through black rather than a cut back to the table.
      if (!_leaving && mounted) setState(() => _leaving = true);
      Future<void>.delayed(MafiaTiming.jumpscareFadeOut, _finish);
    }
  }

  @override
  void didUpdateWidget(KillJumpscare old) {
    super.didUpdateWidget(old);
    final player = _player;
    if (widget.armed && !old.armed && player != null) {
      if (player.value.isInitialized) unawaited(player.play());
      setState(() {});
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
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
    final ready = player != null && player.value.isInitialized;
    if (!widget.armed) {
      // Loading, invisible and out of the way of every touch.
      return IgnorePointer(
        child: Opacity(
          opacity: 0,
          child: ready ? VideoPlayer(player) : const SizedBox.shrink(),
        ),
      );
    }
    if (!_portal.isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_portal.isShowing) _portal.show();
      });
    }
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => _scare(context),
    );
  }

  Widget _scare(BuildContext context) {
    final colors = context.colors;
    final player = _player;
    final ready = player != null && player.value.isInitialized;
    return AnimatedOpacity(
      key: KillJumpscare.surface,
      opacity: _leaving ? 0 : 1,
      duration: MafiaTiming.jumpscareFadeOut,
      child: ColoredBox(
        // Black from the first frame: the scare starts in the dark, not on a
        // flash of the table while the decoder warms up.
        color: colors.surfaceBase,
        child: !ready
            ? const SizedBox.expand()
            : SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: player.value.size.width,
                    height: player.value.size.height,
                    child: VideoPlayer(player),
                  ),
                ),
              ),
      ),
    );
  }
}
