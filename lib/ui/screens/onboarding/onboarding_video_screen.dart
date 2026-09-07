import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/asset_constants.dart';
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

  @override
  ConsumerState<OnboardingVideoScreen> createState() =>
      _OnboardingVideoScreenState();
}

class _OnboardingVideoScreenState extends ConsumerState<OnboardingVideoScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(AppVideo.onboarding)
      ..addListener(_watchPlayback);
    _initialise();
  }

  Future<void> _initialise() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      await _controller.setLooping(false);
      await _controller.setVolume(
        ref.read(setupDraftProvider).settings.muteAllAudio ? 0 : 1,
      );
      if (!mounted) return;
      setState(() => _ready = true);
      await _controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _watchPlayback() {
    if (!_ready || _finished || !_controller.value.isCompleted) return;
    _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_watchPlayback)
      ..dispose();
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

  @override
  Widget build(BuildContext context) {
    ref.listen(
      setupDraftProvider.select((draft) => draft.settings.muteAllAudio),
      (_, muted) {
        if (_ready) _controller.setVolume(muted ? 0 : 1);
      },
    );
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready)
            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(spacing.screenMargin),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: spacing.maxContentWidth,
                    ),
                    child: _frame(
                      Padding(
                        padding: EdgeInsets.all(spacing.sm),
                        child: AspectRatio(
                          key: OnboardingVideoScreen.player,
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            AppBackdrop(
              child: Center(
                child: _failed
                    ? Padding(
                        padding: EdgeInsets.all(spacing.screenMargin),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: spacing.maxContentWidth,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.howToPlayTitle,
                                style: type.display.copyWith(
                                  color: colors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: spacing.md),
                              Text(
                                l10n.onboardingStoryBody,
                                style: type.body.copyWith(
                                  color: colors.textSecondary,
                                ),
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
                      )
                    : CircularProgressIndicator(color: colors.accentGold),
              ),
            ),
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
                  child: Text(l10n.skip),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
