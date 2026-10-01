import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/game_snapshot.dart';
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

/// Thursday from midnight, and the first hour of Friday that still belongs
/// to Thursday night (the server's 20:00–01:00 window).
bool thursdayBannerVisible({
  required bool capability,
  required ThursdayEvent event,
}) => capability && (event.isThursday || event.inWindow);

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

/// «ليلة الخميس» as the first row of «أوض عامة»: what the night is in one
/// line, how far this player is, and one tap — into an open Thursday table
/// if there is one, otherwise a new one. Before 20:00 it says when it opens
/// and does nothing: a match started earlier would not count.
class ThursdayBanner extends ConsumerWidget {
  static const keyValue = ValueKey('thursday_banner');
  static const art = 'assets/images/launch/thursday_banner.webp';

  /// Open Thursday tables from the browse list (`PublicRoom.thursday`).
  final List<PublicRoom> rooms;
  final ValueChanged<String>? onJoin;
  final VoidCallback? onCreate;

  const ThursdayBanner({
    super.key,
    this.rooms = const [],
    this.onJoin,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability =
        ref.watch(economyCapabilitiesProvider).valueOrNull?.thursday ?? false;
    final event = ref.watch(thursdayEventProvider).valueOrNull;
    if (event == null ||
        !thursdayBannerVisible(capability: capability, event: event)) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final spacing = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final radius = BorderRadius.circular(context.radii.card);
    final fallback = ColoredBox(color: colors.surfaceRaised);
    final open = rooms.where((r) => !r.isFull).toList();
    final join = onJoin;
    final String action;
    final VoidCallback? onTap;
    if (!event.inWindow) {
      action = l.thursdayOpensLater;
      onTap = null;
    } else if (open.isNotEmpty) {
      action = l.thursdayJoinRoom;
      onTap = join == null ? null : () => join(open.first.code);
    } else {
      action = l.thursdayOpenRoom;
      onTap = onCreate;
    }
    final status = event.progress >= 2
        ? l.thursdayDone
        : '${l.thursdayProgress(event.progress)} · $action';
    return Padding(
      padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.xs),
      child: Semantics(
        container: true,
        button: onTap != null,
        label: '${l.thursdayNight}. ${l.thursdayLine} $status',
        child: Material(
          key: keyValue,
          color: colors.surfaceRaised,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: colors.accentGold,
              width: ThursdayTokens.borderWidth,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: ThursdayTokens.bannerHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: ThursdayTokens.artOpacity,
                    child: RasterOr(
                      path: art,
                      fit: BoxFit.cover,
                      fallback: fallback,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.md,
                      vertical: spacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l.thursdayNight,
                                style: type.title.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                l.thursdayLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.caption.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.caption.copyWith(
                                  color: colors.accentGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onTap != null)
                          Icon(Icons.chevron_right, color: colors.accentGold),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
