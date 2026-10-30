import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n_ext.dart';

/// Set by a room that closed under this player (the host went). The table and
/// the lobby have no Scaffold to say it on and are about to go, so it is said
/// where they land.
final roomClosedNoticeProvider = StateProvider<bool>((_) => false);

/// Over Home: says once why this player was sent back from a room.
class RoomClosedNotice extends ConsumerStatefulWidget {
  final Widget child;
  const RoomClosedNotice({super.key, required this.child});

  @override
  ConsumerState<RoomClosedNotice> createState() => _RoomClosedNoticeState();
}

class _RoomClosedNoticeState extends ConsumerState<RoomClosedNotice> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(roomClosedNoticeProvider)) return;
      ref.read(roomClosedNoticeProvider.notifier).state = false;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.onlineRoomClosedByHost)),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
