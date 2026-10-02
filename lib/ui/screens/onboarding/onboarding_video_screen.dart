import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/asset_constants.dart';
import '../../../platform/media/video_download.dart';
import '../setup/setup_draft.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/textured_surface.dart';

/// A single cinematic introduction before the compact rules reference.
class OnboardingVideoScreen extends ConsumerStatefulWidget {
  final VoidCallback onFinished;

  const OnboardingVideoScreen({super.key, required this.onFinished});

  static const Key skipButton = ValueKey('onboarding_video_skip');
  static const Key continueButton = ValueKey('onboarding_video_continue');
  static const Key player = ValueKey('onboarding_video_player');
  static const Key playButton = ValueKey('onboarding_video_play');
  static const Key retryButton = ValueKey('onboarding_video_retry');

  @override
  ConsumerState<OnboardingVideoScreen> createState() =>
      _OnboardingVideoScreenState();
}

class _OnboardingVideoScreenState extends ConsumerState<OnboardingVideoScreen> {
  VideoPlayerController? _controller;

  /// Set on the web only, and only while the file is on its way. `null` means
  /// there is nothing to wait for — the film is already on the device.
  double? _progress;

  /// The blob this screen owns, if it made one. Revoked with the player.
  String? _localUrl;

  bool _ready = false;
  bool _failed = false;
  bool _finished = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    try {
      // Prefer the offline cached film when available. On a first visit, stream a
      // film directly so startup does not wait for the entire download. The
      // browser owns buffering and keeps the audio and video on one timeline.
      // On a
      // phone this returns null immediately and nothing below changes.
      if (kIsWeb) {
        setState(() => _progress = 0);
        _localUrl = await downloadVideoAsset(
          AppVideo.onboarding,
          onProgress: (value) {
            if (mounted && !_ready) setState(() => _progress = value);
          },
        );
        if (_disposed) {
          _releaseLocalUrl();
          return;
        }
      }

      final url = _localUrl;
      final controller = url == null
          ? VideoPlayerController.asset(AppVideo.onboarding)
          : VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller..addListener(_watchPlayback);

      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(false);
      await controller.setVolume(
        ref.read(setupDraftProvider).settings.muteAllAudio ? 0 : 1,
      );
      if (!mounted) return;
      setState(() {
        _ready = true;
        _progress = null;
      });
      // Mount the platform view before starting native playback. Browsers
      // start from an explicit gesture, so autoplay restrictions cannot leave
      // an audio-only intro behind a stale first frame.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && !kIsWeb) await _play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _watchPlayback() {
    final controller = _controller;
    if (!_ready || _finished || controller == null) return;
    if (controller.value.isCompleted) _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    // Nothing of this screen may outlive it. Disposal stops the element too,
    // but the pause is what guarantees no sound survives the frame in which
    // the next route is built.
    if (_ready) _controller?.pause().catchError((_) {});
    widget.onFinished();
  }

  /// Starting playback is the only place a browser refuses us, so it is the
  /// only place [_failed] is raised once the film has loaded.
  Future<void> _play() async {
    try {
      await _controller?.play();
      if (mounted && _failed) setState(() => _failed = false);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _releaseLocalUrl() {
    final url = _localUrl;
    if (url == null) return;
    _localUrl = null;
    releaseVideoUrl(url);
  }

  /// What sits on top of the picture: the failure and its retry first, because
  /// a refused `play()` leaves a still first frame that otherwise reads as a
  /// video simply waiting to be started again.
  Widget _overlay(VideoPlayerValue value) {
    final colors = context.colors;
    final spacing = context.spacing;
    final l10n = context.l10n;
    if (_failed) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.videoFailed,
                style: context.typography.body.copyWith(
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.md),
              FilledButton.icon(
                key: OnboardingVideoScreen.retryButton,
                onPressed: _play,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.videoRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (value.isPlaying) {
      if (value.isBuffering) {
        return Center(
          child: CircularProgressIndicator(color: colors.accentGold),
        );
      }
      return Align(
        alignment: Alignment.bottomCenter,
        child: IconButton(
          tooltip: l10n.pause,
          onPressed: () => _controller?.pause(),
          icon: const Icon(Icons.pause_circle_outline),
        ),
      );
    }
    return Center(
      child: FilledButton.icon(
        key: OnboardingVideoScreen.playButton,
        onPressed: _play,
        icon: const Icon(Icons.play_arrow),
        label: Text(l10n.videoPlay),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _controller
      ?..removeListener(_watchPlayback)
      ..dispose();
    _releaseLocalUrl();
    super.dispose();
  }

  /// The panel around the film.
  ///
  /// ## Why the web gets a different one
  ///
  /// On the web `VideoPlayer` is a platform view — a real `<video>` element the
  /// browser composites, not pixels Flutter painted. [PaperPanel] wraps its
  /// child in a `ClipRRect` and stacks a texture behind it, and a platform view
  /// under a rounded clip is the case Flutter's web compositor gets wrong: the
  /// element ends up behind the canvas that clips it, so the sound plays and
  /// the picture never appears.
  ///
  /// The `FittedBox` this replaced was the other half of it — a scale transform
  /// on a platform view — which is why the frame changed *and* the sizing did.
  /// `AspectRatio` asks for the same shape without transforming anything.
  ///
  /// So the web draws the same surface, the same border and the same radius,
  /// and simply does not clip: the video is a rectangle inside a rectangle and
  /// there is nothing at the corners to cut.
  Widget _frame(Widget child) {
    final colors = context.colors;
    if (!kIsWeb) return PaperPanel(child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(context.radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: child,
    );
  }

  /// The film at the largest size the window allows, and the frame around
  /// exactly that.
  ///
  /// The frame used to be sized first — a panel as wide as a column of text,
  /// with the video centred inside it — which on a desktop window drew a tall
  /// empty box with a small portrait film floating in the middle of it and grey
  /// margins either side. `AspectRatio` under a `Center` takes the whole of
  /// whichever dimension runs out first and derives the other, so the border is
  /// always on the picture's edge, at every window size, with no breakpoints.
  Widget _film(VideoPlayerController controller) {
    return Center(
      child: AspectRatio(
        key: OnboardingVideoScreen.player,
        aspectRatio: controller.value.aspectRatio,
        child: _frame(
          Stack(
            fit: StackFit.expand,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: VideoPlayer(controller),
              ),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) => _overlay(value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Before the picture: the download, the failure, or neither.
  Widget _waiting() {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;

    if (_failed) {
      return Padding(
        padding: EdgeInsets.all(spacing.screenMargin),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.howToPlayTitle,
                style: type.display.copyWith(color: colors.textPrimary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.md),
              Text(
                l10n.onboardingStoryBody,
                style: type.body.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.xl),
              FilledButton(
                key: OnboardingVideoScreen.continueButton,
                onPressed: _finish,
                child: Text(l10n.howToPlay),
              ),
            ],
          ),
        ),
      );
    }

    final progress = _progress;
    // A determinate ring, because the wait has a known end and the number is
    // the difference between "downloading" and "stuck". Digits only: there is
    // nothing here to translate, and a percentage reads the same in both.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(
          color: colors.accentGold,
          value: progress == null || progress <= 0 ? null : progress,
        ),
        if (progress != null && progress > 0) ...[
          SizedBox(height: spacing.md),
          Text(
            '${(progress * 100).round()}%',
            style: type.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      setupDraftProvider.select((draft) => draft.settings.muteAllAudio),
      (_, muted) {
        if (_ready) _controller?.setVolume(muted ? 0 : 1);
      },
    );
    final colors = context.colors;
    final spacing = context.spacing;
    final controller = _controller;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready && controller != null)
            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(spacing.screenMargin),
                child: _film(controller),
              ),
            )
          else
            AppBackdrop(child: Center(child: _waiting())),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: EdgeInsets.all(spacing.sm),
                child: TextButton(
                  key: OnboardingVideoScreen.skipButton,
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    backgroundColor: colors.surfaceOverlay,
                    foregroundColor: colors.textPrimary,
                  ),
                  child: Text(context.l10n.skip),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
