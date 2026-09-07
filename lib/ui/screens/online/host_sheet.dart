import 'package:flutter/material.dart';

import '../../../transport/game_snapshot.dart';
import '../../../transport/online_transport.dart';
import '../../l10n_ext.dart';
import 'scene_sheet.dart';

/// The host's two moderation actions for one seat (task 6).
///
/// ## Why a sheet and not a menu on the seat
///
/// The council is one painter and fifteen invisible hit targets — there is
/// nowhere on a chair to hang a control that would not be drawn, and a drawn
/// control on every chair would be fifteen affordances for a thing that
/// happens twice a match. A sheet costs nothing until it is asked for.
///
/// ## Why it is a layer and not a route
///
/// Doc 12 §2.1: the table is one scene. This is a [SceneSheet] in the same
/// Stack, so it rebuilds from the same snapshot as the council underneath it —
/// a player who leaves while the host is looking at their seat takes their own
/// sheet away.
///
/// ## What it does not decide
///
/// Anything. Both actions are Edge Function calls that check the caller is the
/// room's host; this file is a pair of buttons, and a modified client that drew
/// them for a non-host would get `NOT_HOST` twice.
class HostSheet extends StatelessWidget {
  static const Key kickAction = ValueKey('host_sheet_kick');
  static const Key muteAction = ValueKey('host_sheet_mute');

  final GameSnapshot snapshot;
  final OnlineTransport? transport;

  /// The seat under inspection, or null when the sheet is closed.
  final int? seat;
  final VoidCallback onDismiss;

  const HostSheet({
    super.key,
    required this.snapshot,
    required this.transport,
    required this.seat,
    required this.onDismiss,
  });

  /// Whether [seat] may be inspected at all. Every call site can therefore pass
  /// a seat unconditionally and let this decide.
  bool get _open {
    final target = seat;
    if (target == null) return false;
    if (transport == null || !snapshot.canAdvance) return false;
    // A host does not moderate themselves. Kicking yourself would leave the
    // room with a host who is banned from it, and muting yourself is the
    // switch every player already has.
    if (target == snapshot.viewerSeat) return false;
    return _name != null && _name!.isNotEmpty;
  }

  String? get _name => snapshot.public.players
      .where((player) => player.seat == seat)
      .map((player) => player.name)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    if (!_open) return const SizedBox.shrink();
    final l10n = context.l10n;
    final target = seat!;
    final muted = snapshot.mutedSeats.contains(target);
    return SceneSheet(
      visible: true,
      title: _name,
      onDismiss: onDismiss,
      actions: [
        SceneAction(
          key: muteAction,
          icon: muted ? Icons.mic_off_outlined : Icons.mic_none_outlined,
          label: muted ? l10n.onlineUnmute : l10n.onlineMute,
          onTap: () {
            onDismiss();
            transport?.setPlayerMuted(target, !muted);
          },
        ),
        SceneAction(
          key: kickAction,
          icon: Icons.person_remove_outlined,
          label: l10n.onlineKick,
          onTap: () {
            onDismiss();
            transport?.kickPlayer(target);
          },
        ),
      ],
    );
  }
}
