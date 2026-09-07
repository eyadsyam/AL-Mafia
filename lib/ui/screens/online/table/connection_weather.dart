import 'package:flutter/material.dart';

import '../../../../app/asset_constants.dart';

import '../../../../transport/game_snapshot.dart' show ConnectionQuality;
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';
import 'table_pulse.dart';

/// How bad the weather is (doc 12 §5).
///
/// Most apps treat network problems as errors. In a noir game they are
/// **weather** — which is not a decoration argument. A modal on a bad
/// connection at the wrong moment is how a match dies, and a red banner in a
/// game where red means *elimination* reads as a fatal crash. So the whole of
/// this file has three rules and no exceptions:
///
///   * no blocking modal, ever, during a match;
///   * no red;
///   * never a bare spinner — always a state with words.
enum TableWeather {
  /// Nothing to say. Offline, or online and in sync.
  clear,

  /// Reaching for the server. The table is legible; it is just cooler.
  connecting,

  /// Lost it and retrying. Play continues against the last snapshot.
  reconnecting,

  /// Given up for now. The table freezes and the actions go quiet.
  unreachable;

  /// The weather for a transport's connection state.
  ///
  /// [ConnectionQuality.local] is offline play, where the authority is this
  /// device and there is nothing that can be disconnected from — so it is
  /// always [clear], and this whole layer draws nothing.
  static TableWeather of(ConnectionQuality quality) => switch (quality) {
    ConnectionQuality.local || ConnectionQuality.connected => clear,
    ConnectionQuality.reconnecting => reconnecting,
    ConnectionQuality.offline => unreachable,
  };

  /// Whether the table below should stop accepting input.
  ///
  /// Only when there is nothing on the other end to accept it. Reconnecting
  /// deliberately stays live: a tap that lands during a two-second wobble is a
  /// tap the player meant, and the transport queues it.
  bool get freezesInput => this == unreachable;

  /// How much fog sits over the table.
  double get fog => switch (this) {
    clear => 0.0,
    connecting => 0.22,
    reconnecting => 0.38,
    unreachable => 0.62,
  };

  /// How much colour is drained out of the table.
  double get desaturation => switch (this) {
    clear => 0.0,
    connecting => 0.15,
    reconnecting => 0.55,
    unreachable => 0.85,
  };
}

/// Fog, desaturation and one line of copy over the table.
///
/// Everything below the fog stays visible in every state. Doc 12 §5: *"a
/// frozen, foggy table is far better than an error screen."*
class ConnectionWeather extends StatelessWidget {
  final TableWeather weather;

  /// Offered only when the weather is [TableWeather.unreachable] and the caller
  /// has somewhere to send them. Null hides the affordance rather than showing
  /// a dead one.
  final VoidCallback? onPlayOffline;

  final Widget child;

  const ConnectionWeather({
    super.key,
    required this.weather,
    required this.child,
    this.onPlayOffline,
  });

  static const Key fogKey = ValueKey('table_weather_fog');
  static const Key messageKey = ValueKey('table_weather_message');
  static const Key playOfflineKey = ValueKey('table_weather_play_offline');

  /// The saturation matrix for [amount] drained, 0 (untouched) to 1 (grey).
  ///
  /// Luminance weights are the sRGB ones, so a desaturated table keeps its
  /// relative brightness rather than turning flat.
  static List<double> saturationMatrix(double amount) {
    final s = 1.0 - amount.clamp(0.0, 1.0);
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    return <double>[
      lr + s * (1 - lr),
      lg * (1 - s),
      lb * (1 - s),
      0,
      0,
      lr * (1 - s),
      lg + s * (1 - lg),
      lb * (1 - s),
      0,
      0,
      lr * (1 - s),
      lg * (1 - s),
      lb + s * (1 - lb),
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final motion = context.motion;
    final l10n = context.l10n;

    if (weather == TableWeather.clear) return child;

    final message = switch (weather) {
      TableWeather.clear => '',
      TableWeather.connecting => l10n.onlineConnecting,
      TableWeather.reconnecting => l10n.onlineWeatherReconnecting,
      TableWeather.unreachable => l10n.onlineWeatherUnreachable,
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        // A colour matrix, not a BackdropFilter. Doc 12 §6 names the latter as
        // the most common cause of jank in Flutter, and this runs on every
        // frame of a match played on a bad train.
        ColorFiltered(
          colorFilter: ColorFilter.matrix(
            saturationMatrix(weather.desaturation),
          ),
          child: IgnorePointer(ignoring: weather.freezesInput, child: child),
        ),
        IgnorePointer(
          child: _Fog(key: fogKey, density: weather.fog),
        ),
        // The words. Positioned at the top so they never sit over the centre,
        // which is where the phase's own content lives.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedOpacity(
              duration: motion.phase,
              curve: motion.phaseCurve,
              opacity: 1,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.md,
                  vertical: spacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      key: messageKey,
                      message,
                      textAlign: TextAlign.center,
                      // Muted, not crimson. See the enum's doc comment.
                      style: type.caption.copyWith(color: colors.textSecondary),
                    ),
                    if (weather == TableWeather.unreachable &&
                        onPlayOffline != null) ...[
                      SizedBox(height: spacing.xs),
                      TextButton(
                        key: playOfflineKey,
                        onPressed: onPlayOffline,
                        child: Text(
                          l10n.onlinePlayOffline,
                          style: type.caption.copyWith(
                            color: colors.accentGold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Slow-drifting haze.
///
/// Two overlapping vertical gradients moved in opposite directions by the
/// table's shared breath. That is enough to read as weather and costs one
/// transform per frame — no particles, no blur, no second layer tree.
class _Fog extends StatelessWidget {
  final double density;

  const _Fog({super.key, required this.density});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final breath = TablePulse.of(context);

    return AnimatedBuilder(
      animation: breath,
      builder: (context, _) {
        final drift = (breath.value - 0.5) * 0.12;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1, -1 + drift),
                  end: Alignment(1, 1 - drift),
                  colors: [
                    colors.surfaceBase.withValues(alpha: density * 0.55),
                    colors.surfaceBase.withValues(alpha: density),
                    colors.surfaceBase.withValues(alpha: density * 0.70),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Doc 15 A14. The gradient alone reads as a dimmer; the overlay is
            // what makes it read as *weather*. Tinted to the ground rather than
            // drawn in its own colour, so a reconnecting table gets thicker
            // rather than bluer — and drifted by the same breath the gradient
            // uses, which is the one animation this widget owns.
            if (density > 0)
              Opacity(
                opacity: density,
                child: Transform.translate(
                  offset: Offset(0, drift * CouncilTokens.fogDrift),
                  child: Image.asset(
                    AppCouncilArt.fogOverlay,
                    fit: BoxFit.cover,
                    color: colors.surfaceBase,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
