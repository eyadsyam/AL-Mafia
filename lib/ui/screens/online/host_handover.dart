import 'dart:async';

import 'package:flutter/material.dart';

import '../../../transport/game_snapshot.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';

/// «{name} بقى الهوست» — one centred line, for three seconds (task 5).
///
/// ## Why it is announced at all
///
/// A host migration changes who may press the thing that moves the room on.
/// Before this, it happened silently: the old host's phone died, somebody
/// else's «كمل» quietly became live, and nobody in the room knew whose turn it
/// was to drive. Naming the new host once is the difference between a room
/// that waits and a room that carries on.
///
/// ## Why it is a notice and not a state
///
/// Because the match did not change. Doc 10 §8.1's rule is that a host
/// migration is *not* a state change in the game — the phase, the clock and
/// the ballot are exactly where they were — so this draws over the table for
/// three seconds and leaves nothing behind.
///
/// The very first host is not announced. Everybody watched them make the room.
class HostHandover extends StatefulWidget {
  final GameSnapshot snapshot;

  const HostHandover({super.key, required this.snapshot});

  static const Duration visible = MafiaTiming.hostHandover;

  @override
  State<HostHandover> createState() => _HostHandoverState();
}

class _HostHandoverState extends State<HostHandover> {
  int? _known;
  String? _announcing;
  Timer? _clear;

  @override
  void initState() {
    super.initState();
    _known = widget.snapshot.hostSeat;
  }

  @override
  void didUpdateWidget(HostHandover old) {
    super.didUpdateWidget(old);
    final host = widget.snapshot.hostSeat;
    if (host == null || host == _known) return;
    final first = _known == null;
    _known = host;
    if (first) return;
    final name = widget.snapshot.public.players
        .where((player) => player.seat == host)
        .map((player) => player.name)
        .firstOrNull;
    if (name == null || name.isEmpty) return;
    setState(() => _announcing = name);
    _clear?.cancel();
    _clear = Timer(HostHandover.visible, () {
      if (mounted) setState(() => _announcing = null);
    });
  }

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _announcing;
    if (name == null) return const SizedBox.shrink();
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceBase.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(context.radii.card),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.md,
            ),
            child: Text(
              context.l10n.onlineNewHost(name),
              textAlign: TextAlign.center,
              style: type.title.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
