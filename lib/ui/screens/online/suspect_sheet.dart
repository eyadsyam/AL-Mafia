import 'package:flutter/material.dart';

import '../../../engine/models/enums.dart' show GamePhase, PlayerStatus;
import '../../../transport/game_snapshot.dart';
import '../../../transport/online_transport.dart';
import '../../l10n_ext.dart';
import 'scene_sheet.dart';

/// «أنا شاكك في» from a seat (owner, 2026-10-30): during the discussion a
/// living, unsilenced player names one living other out loud, or takes it
/// back. One pick a day, changeable until the vote opens; the server keeps
/// the rules and the table draws the result for everybody.
class SuspectSheet extends StatelessWidget {
  static const Key suspectAction = ValueKey('suspect_sheet_suspect');
  static const Key clearAction = ValueKey('suspect_sheet_clear');

  final GameSnapshot snapshot;
  final OnlineTransport? transport;
  final int? seat;
  final VoidCallback onDismiss;
  final VoidCallback? onFailed;

  const SuspectSheet({
    super.key,
    required this.snapshot,
    required this.transport,
    required this.seat,
    required this.onDismiss,
    this.onFailed,
  });

  /// Whether this viewer may name [seat] right now.
  static bool mayName(GameSnapshot snapshot, int seat) {
    final me = snapshot.viewerSeat;
    if (me == null || seat == me) return false;
    if (snapshot.phase != GamePhase.discussion || snapshot.viewerSilenced) {
      return false;
    }
    bool alive(int s) => snapshot.public.players.any(
      (p) => p.seat == s && p.status == PlayerStatus.alive,
    );
    return alive(me) && alive(seat);
  }

  String? get _name => snapshot.public.players
      .where((p) => p.seat == seat)
      .map((p) => p.name)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final target = seat;
    if (target == null || transport == null || !mayName(snapshot, target)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final mine = snapshot.publicSuspicions[snapshot.viewerSeat];
    final named = mine == target;
    Future<void> send(int? to) async {
      onDismiss();
      try {
        await transport!.setPublicSuspicion(to);
      } catch (_) {
        onFailed?.call();
      }
    }

    return SceneSheet(
      visible: true,
      title: _name,
      onDismiss: onDismiss,
      actions: [
        if (named)
          SceneAction(
            key: clearAction,
            icon: Icons.remove_circle_outline,
            label: l10n.suspectClear,
            onTap: () => send(null),
          )
        else
          SceneAction(
            key: suspectAction,
            icon: Icons.search,
            label: l10n.suspectAction,
            emphasised: true,
            onTap: () => send(target),
          ),
      ],
    );
  }
}
