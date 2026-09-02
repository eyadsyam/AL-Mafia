import 'package:flutter/material.dart';

import '../../transport/game_snapshot.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';

/// The connection banner — one of the two widgets doc 10 §7 permits to know
/// anything about the transport, and it knows exactly one thing.
///
/// ## What it reads, and what it deliberately does not
///
/// It reads [ConnectionQuality] off the snapshot. It does not ask whether the
/// transport is online, does not name a class, and cannot be told apart from
/// any other widget by its imports. Offline the quality is
/// [ConnectionQuality.local] and this renders nothing at all — there is no
/// connection to lose when the authority is the device in your hand.
///
/// ## Why it is a strip and not a dialog
///
/// A dropped connection does not stop the match: the last snapshot is still on
/// screen, the table is still arguing, and the client is retrying behind them
/// (doc 10 §8.1, O10). A modal would stop a game that has not stopped. So this
/// takes a line at the top, says which of the two states it is in, and gets out
/// of the way when the link comes back.
class ConnectionBanner extends StatelessWidget {
  final ConnectionQuality quality;

  const ConnectionBanner({super.key, required this.quality});

  static const Key bannerKey = ValueKey('connection_banner');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final l10n = context.l10n;

    final (label, tint) = switch (quality) {
      ConnectionQuality.local || ConnectionQuality.connected => (null, null),
      ConnectionQuality.reconnecting => (l10n.onlineConnecting, colors.accentGold),
      ConnectionQuality.offline => (l10n.onlineDisconnected, colors.accentCrimson),
    };
    if (label == null || tint == null) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      child: Container(
        key: bannerKey,
        width: double.infinity,
        color: colors.surfaceRaised,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: spacing.sm,
              height: spacing.sm,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
            SizedBox(width: spacing.sm),
            Text(label, style: type.caption.copyWith(color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
