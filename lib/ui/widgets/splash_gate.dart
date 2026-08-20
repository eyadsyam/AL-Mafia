import 'package:flutter/material.dart';

import '../../app/asset_constants.dart';
import '../../platform/reduce_motion.dart';
import '../theme/mafia_theme.dart';

/// The Flutter half of the launch handover.
///
/// ## What problem this solves
///
/// Android shows `launch_background.xml` — the mask, centred, on the app's
/// ground colour — from the moment the icon is tapped until the engine draws
/// its first frame. Then it tears that window down. Without this widget, that
/// hand-off is a hard cut: the mask is on screen, and then it is not, and the
/// home screen appears mid-blink. It reads as a stutter even when nothing is
/// actually slow.
///
/// So Flutter's first frame is *the same picture*: the same mask, the same
/// size, on the same colour. Nothing appears to happen at the handover, because
/// nothing does. Then the mask dissolves and the app is underneath it.
///
/// The bitmap, the ground colour and the size are all generated or read from
/// one place — `tool/generate_icons.py` writes the mask at 640px and both the
/// native layer-list and this widget draw it at [_maskSize] on
/// `MafiaColors.surfaceBase`, which `values/ic_launcher_background.xml` also
/// carries. If any of those three drift, the seam becomes visible.
///
/// ## Why it is not a "splash screen" in the usual sense
///
/// It adds no waiting. The dissolve begins on the first frame and runs for one
/// `motion.dramatic`; there is no hold, no logo animation, no version string.
/// The app is fully built and interactive underneath the whole time — this is a
/// veil coming off, not a gate.
///
/// Under Reduce Motion it is skipped entirely, which is the correct degradation:
/// the point of the veil is the motion, and without motion there is nothing left
/// to show.
class SplashGate extends StatefulWidget {
  final Widget child;

  const SplashGate({super.key, required this.child});

  /// Drawn at the same size the native launch window centres its bitmap at.
  static const double maskSize = 160;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _veil;
  late final CurvedAnimation _fade;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _veil = AnimationController(vsync: this, value: 1.0);
    _fade = CurvedAnimation(parent: _veil, curve: Curves.linear);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (ReduceMotion.of(context)) {
      _veil.value = 0.0;
      return;
    }
    _veil.duration = context.motion.dramatic;
    _veil.reverse();
  }

  @override
  void dispose() {
    _fade.dispose();
    _veil.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Stack(
      children: [
        widget.child,
        // `IgnorePointer` rather than removing it from the tree: the app
        // underneath is live from frame one, so a tap during the dissolve
        // should land on what the user can see themselves aiming at.
        IgnorePointer(
          child: FadeTransition(
            opacity: _fade,
            child: ColoredBox(
              color: colors.surfaceBase,
              child: Center(
                child: Image.asset(
                  AppImages.splashMask,
                  width: SplashGate.maskSize,
                  height: SplashGate.maskSize,
                  // The bitmap is the mask on its own near-black ground, which
                  // is the same near-black as `surfaceBase`, so it needs no
                  // blending to sit invisibly on it.
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
