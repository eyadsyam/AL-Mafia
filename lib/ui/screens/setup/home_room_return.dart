import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/online_session_store.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_buttons.dart';
import '../online/online_session.dart';

/// «عندك أوضة لسه شغالة»: on Home, the way back to an online seat the app was
/// closed on (or lost the network in), while the server still holds it.
///
/// Shown only when all three are true: this device kept a room pointer, it is
/// this player's own seat, and the server still says the room is open and
/// this player is in it. Anything less — a finished room, another account's
/// seat, no network — shows nothing: the card never promises a room that is
/// not there. The tap goes to the online door, which takes the seat again.
class HomeRoomReturn extends ConsumerStatefulWidget {
  final void Function(String code) onReturn;

  const HomeRoomReturn({super.key, required this.onReturn});

  static const cardKey = ValueKey('home_room_return');
  static const actionKey = ValueKey('home_room_return_action');

  /// Statuses of a room a seat can still go back to.
  static const openStatuses = {'lobby', 'playing'};

  @override
  ConsumerState<HomeRoomReturn> createState() => _HomeRoomReturnState();
}

class _HomeRoomReturnState extends ConsumerState<HomeRoomReturn> {
  String? _code;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final resume = await OnlineSessionStore.load();
      if (resume == null || resume.userId == null) return;
      // Already seated in this app run: the table itself is the way back.
      if (ref.read(onlineSessionProvider).isInRoom) return;
      final backend = await ref.read(onlineBackendFactoryProvider)();
      if (!resume.belongsTo(backend.userId)) return;
      final rows = await backend.fetchRows(resume.roomId);
      if (rows.own == null) return;
      if (!HomeRoomReturn.openStatuses.contains(rows.state.status)) return;
      if (mounted) setState(() => _code = resume.code);
    } catch (_) {
      // No network, no session, a refused read: nothing worth offering.
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    if (code == null) return const SizedBox.shrink();
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    return Padding(
      padding: EdgeInsets.only(top: s.xs),
      child: DecoratedBox(
        key: HomeRoomReturn.cardKey,
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          border: Border.all(color: colors.accentGold),
          borderRadius: BorderRadius.circular(context.radii.card),
        ),
        child: Padding(
          padding: EdgeInsets.all(s.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.homeRoomReturnTitle,
                style: type.title.copyWith(color: colors.textPrimary),
              ),
              Text(
                '${l.onlineRoomCode} · $code',
                style: type.caption.copyWith(color: colors.textSecondary),
              ),
              SizedBox(height: s.xs),
              BoneButton(
                key: HomeRoomReturn.actionKey,
                label: l.homeRoomReturnAction,
                onPressed: () => widget.onReturn(code),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
