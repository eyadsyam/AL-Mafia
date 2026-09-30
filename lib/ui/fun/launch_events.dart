import 'package:flutter/material.dart';

import '../../transport/online_backend.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// Row 12: the launch-event stamps a finished online room earned, for the
/// public result only (`eventResult{roomId}`). The server answers empty for a
/// room that is still being played, so no live surface can draw one.
Future<List<String>> fetchLaunchEventStamps(
  OnlineBackend backend,
  String roomId,
) async {
  try {
    final answer = await backend.call('economy', {
      'action': 'eventResult',
      'roomId': roomId,
    });
    final events = answer['events'];
    if (answer['enabled'] != true || events is! List) return const [];
    return [for (final code in events) if (code is String) code];
  } catch (_) {
    // Never load-bearing for the result screen.
    return const [];
  }
}

/// The event name drawn over the rubber-stamp impression, from its code
/// (`launch_night` → "launch night"). No catalog is fetched: the stamp is
/// decorative and never load-bearing, so a plain readable label is enough.
String launchEventLabel(String code) => code.replaceAll('_', ' ');

/// One earned event as its stamp, the name drawn in-app over the ring.
class LaunchEventStamp extends StatelessWidget {
  final String code;
  const LaunchEventStamp({super.key, required this.code});

  static Key stampKey(String code) => ValueKey('launch_event_stamp_$code');

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: stampKey(code),
    child: SizedBox(
      width: LaunchEventTokens.stampSize,
      height: LaunchEventTokens.stampSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/launch/event_stamp.webp',
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          Padding(
            padding: EdgeInsets.all(context.spacing.sm),
            child: Text(
              launchEventLabel(code),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.typography.caption.copyWith(
                color: VaultTokens.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Fetches and shows this online room's earned stamps, or nothing while
/// there are none (still playing, disabled, or a refusal).
class LaunchEventStamps extends StatelessWidget {
  final OnlineBackend backend;
  final String roomId;
  const LaunchEventStamps({
    super.key,
    required this.backend,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: fetchLaunchEventStamps(backend, roomId),
    builder: (context, snapshot) {
      final codes = snapshot.data;
      if (codes == null || codes.isEmpty) return const SizedBox.shrink();
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: context.spacing.sm,
        runSpacing: context.spacing.sm,
        children: [for (final code in codes) LaunchEventStamp(code: code)],
      );
    },
  );
}

abstract final class LaunchEventTokens {
  static const double stampSize = 96.0;
}
