import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/asset_constants.dart';
import '../../platform/asset_warmup.dart';
import '../../platform/reduce_motion.dart';
import '../economy/economy_capabilities.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart' show SupabaseConfig;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'feathered_art.dart';

/// Whether launch preparation runs at all. Off in debug and in tests, where it
/// would read the whole bundle and sign in on every pump.
final warmupEnabledProvider = Provider<bool>(
  (ref) => kReleaseMode || kProfileMode,
);

/// «بنجهّز الترابيزة»: the first launch (and the first launch after an update
/// that changed the art) reads every asset once and warms the server, behind
/// a quiet preparation screen with a real progress line. Every later launch
/// warms the first screens' paintings and the server in the background and
/// shows nothing.
///
/// Never a gate that can trap anyone: it gives up after
/// [WarmupTokens.maxWait] and lets the table through, and any failure simply
/// ends preparation early.
class WarmupGate extends ConsumerStatefulWidget {
  final Widget child;
  const WarmupGate({super.key, required this.child});

  static const Key overlayKey = ValueKey('warmup_overlay');

  @override
  ConsumerState<WarmupGate> createState() => _WarmupGateState();
}

class _WarmupGateState extends ConsumerState<WarmupGate> {
  /// Null: nothing to show. Otherwise the share of the bundle read so far.
  double? _progress;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    if (!ref.read(warmupEnabledProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final warmup = AssetWarmup(bundle: rootBundle);
    try {
      final assets = await warmup.assets();
      final signature = AssetWarmup.signature(assets);
      final firstTime = !await AssetWarmup.prepared(signature);
      unawaited(_warmServer());
      if (!mounted) return;
      if (!firstTime) {
        await _decodeFirstScreens();
        return;
      }
      setState(() => _progress = 0);
      await Future.wait([
        warmup.read(
          assets,
          onProgress: (done, total) {
            if (mounted) setState(() => _progress = done / total);
          },
        ),
        _decodeFirstScreens(),
      ]).timeout(WarmupTokens.maxWait);
      await AssetWarmup.markPrepared(signature);
    } catch (_) {
      // Timed out or failed: the table opens anyway, and the next launch
      // tries again because nothing was marked prepared.
    }
    _leave();
  }

  /// Decodes the paintings the first screens draw, so Home and setup appear
  /// complete rather than filling in.
  Future<void> _decodeFirstScreens() async {
    if (!mounted) return;
    final paths = [...AppImages.values, ...AppGallery.values];
    for (var i = 0; i < paths.length; i += WarmupTokens.decodeBatch) {
      if (!mounted) return;
      final slice = paths.skip(i).take(WarmupTokens.decodeBatch);
      await Future.wait(
        slice.map(
          (path) => precacheImage(
            ResizeImage(
              AssetImage(path),
              width: WarmupTokens.decodeWidth,
              policy: ResizeImagePolicy.fit,
            ),
            context,
          ).catchError((Object _) {}),
        ),
      );
    }
  }

  /// Signs in and reads the capabilities once, so the vault, the council and
  /// the online door answer on the first tap instead of after a cold start.
  Future<void> _warmServer() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await ref
          .read(economyCapabilitiesProvider.future)
          .timeout(WarmupTokens.serverWait);
    } catch (_) {
      /* The read is retried by whoever needs it next. */
    }
  }

  void _leave() {
    if (!mounted || _progress == null) return;
    setState(() => _leaving = true);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (progress == null) return widget.child;
    final reduce = ReduceMotion.of(context);
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          ignoring: _leaving,
          child: AnimatedOpacity(
            opacity: _leaving ? 0 : 1,
            duration: reduce ? Duration.zero : context.motion.dramatic,
            onEnd: () {
              if (_leaving && mounted) setState(() => _progress = null);
            },
            child: _Preparation(key: WarmupGate.overlayKey, progress: progress),
          ),
        ),
      ],
    );
  }
}

class _Preparation extends StatelessWidget {
  final double progress;
  const _Preparation({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l = context.l10n;
    // Above the navigator, so it brings its own Material (text style, ink).
    return Material(
      color: colors.surfaceBase,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: WarmupTokens.backdropOpacity,
            child: FeatheredArt(
              feather: Feather.hero,
              halo: false,
              child: Image.asset(
                AppImages.bgNight,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AppImages.splashMask,
                    width: WarmupTokens.mask,
                    height: WarmupTokens.mask,
                    excludeFromSemantics: true,
                  ),
                  SizedBox(height: spacing.lg),
                  Text(
                    l.warmupTitle,
                    style: type.title.copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: spacing.md),
                  SizedBox(
                    width: WarmupTokens.barWidth,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        WarmupTokens.barHeight,
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: WarmupTokens.barHeight,
                        backgroundColor: colors.borderSubtle,
                        color: colors.accentGold,
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    l.warmupOnce,
                    style: type.caption.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
