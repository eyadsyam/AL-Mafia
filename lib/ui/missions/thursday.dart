import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/online_backend.dart';
import '../economy/council_art.dart';
import '../economy/economy_capabilities.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

class ThursdayEvent {
  final bool enabled;
  final bool isThursday;
  final bool inWindow;
  final int progress;
  final bool stamp;
  final String event;

  const ThursdayEvent({
    this.enabled = false,
    this.isThursday = false,
    this.inWindow = false,
    this.progress = 0,
    this.stamp = false,
    this.event = '',
  });

  static const off = ThursdayEvent();

  factory ThursdayEvent.fromJson(Map<String, dynamic> json) => ThursdayEvent(
    enabled: json['enabled'] == true,
    isThursday: json['isThursday'] == true,
    inWindow: json['inWindow'] == true,
    progress: ((json['progress'] as num?)?.toInt() ?? 0).clamp(0, 2),
    stamp: json['stamp'] == true,
    event: json['event'] is String ? json['event'] as String : '',
  );
}

bool thursdayBannerVisible({
  required bool capability,
  required ThursdayEvent event,
}) => capability && event.isThursday;

final thursdayEventProvider = FutureProvider<ThursdayEvent>((ref) async {
  final capabilities = await ref.watch(economyCapabilitiesProvider.future);
  if (!capabilities.thursday) return ThursdayEvent.off;
  try {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return ThursdayEvent.fromJson(
      await backend.call('economy', {'action': 'thursdayEvent'}),
    );
  } on BackendException {
    return ThursdayEvent.off;
  } catch (_) {
    return ThursdayEvent.off;
  }
});

class ThursdayBanner extends ConsumerWidget {
  static const keyValue = ValueKey('thursday_banner');
  static const art = 'assets/images/launch/thursday_banner.webp';

  const ThursdayBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability =
        ref.watch(economyCapabilitiesProvider).valueOrNull?.thursday ?? false;
    final event = ref.watch(thursdayEventProvider).valueOrNull;
    if (event == null ||
        !thursdayBannerVisible(capability: capability, event: event)) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    final colors = context.colors;
    final radius = BorderRadius.circular(context.radii.card);
    final fallback = ColoredBox(color: colors.surfaceRaised);
    return Semantics(
      container: true,
      label:
          '${context.l10n.thursdayNight}. '
          '${context.l10n.thursdayProgress(event.progress)}',
      child: Container(
        key: keyValue,
        height: ThursdayTokens.bannerHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: radius,
          border: Border.all(
            color: colors.accentGold,
            width: ThursdayTokens.borderWidth,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: ThursdayTokens.artOpacity,
              child: RasterOr(path: art, fit: BoxFit.cover, fallback: fallback),
            ),
            Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.thursdayNight,
                    style: context.typography.title.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    context.l10n.thursdayProgress(event.progress),
                    style: context.typography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
