import 'dart:async';

import 'package:flutter/material.dart';

import '../../../engine/models/enums.dart' show PlayerStatus;
import '../../../engine/models/player.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/player_tile.dart';
import '../../widgets/textured_surface.dart';

/// Day 1's «اسم واحد» round (doc 09 §2.2).
///
/// Every living player, in seating order, has ten seconds to name one suspect
/// out loud. No explaining, and no "I don't know".
///
/// ## Why this is a table screen and not a private turn
///
/// Nothing here is secret. The player says the name to the room; the phone only
/// records what everyone already heard. So the phone stays flat in the middle,
/// there is no identity pad, no dwell gate and no pass screen — none of doc
/// 05's private-turn machinery applies, because none of its threat model does.
/// That is also why the accusations are usable as `C1` evidence later and a
/// night suspicion never could be: one was spoken to the table, the other was
/// not.
///
/// ## Why the timer does not enforce anything
///
/// It runs down and then stops. It does not skip the player, because a forced
/// choice that the app can satisfy on your behalf is not a forced choice — and
/// because the ten seconds are there to stop people *explaining*, not to punish
/// someone who is still deciding. The number on screen does the work; a table
/// reads a stalled countdown perfectly well.
class OpeningRoundScreen extends StatefulWidget {
  final int dayNumber;

  /// The seat holding the floor.
  final int currentSeat;

  final List<PublicPlayer> players;

  /// Called with the seat that was named.
  final void Function(int targetSeat) onAccuse;

  const OpeningRoundScreen({
    super.key,
    required this.dayNumber,
    required this.currentSeat,
    required this.players,
    required this.onAccuse,
  });

  @override
  State<OpeningRoundScreen> createState() => _OpeningRoundScreenState();
}

class _OpeningRoundScreenState extends State<OpeningRoundScreen> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ticker == null) _restart();
  }

  @override
  void didUpdateWidget(OpeningRoundScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSeat != widget.currentSeat) _restart();
  }

  void _restart() {
    _ticker?.cancel();
    setState(() => _remaining = context.timing.openingRoundPerPlayer);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final next = _remaining - const Duration(seconds: 1);
        _remaining = next.isNegative ? Duration.zero : next;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;

    final speaker = widget.players[widget.currentSeat];
    final targets = [
      for (final p in widget.players)
        if (p.seat != widget.currentSeat && p.status == PlayerStatus.alive) p,
    ];

    return AppBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.screenMargin,
                vertical: spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.openingRoundTitle,
                    style: type.headline.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    l10n.openingRoundBody,
                    style: type.bodySmall.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.lg),
                  Text(
                    l10n.openingRoundPrompt(speaker.name),
                    style: type.title.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    '${_remaining.inSeconds}',
                    style: type.timer.copyWith(
                      color: _remaining == Duration.zero
                          ? colors.textMuted
                          : colors.accentGold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.md),
                  Expanded(
                    child: ListView.separated(
                      itemCount: targets.length,
                      separatorBuilder: (_, __) => SizedBox(height: spacing.xs),
                      itemBuilder: (context, index) {
                        final target = targets[index];
                        return PlayerTile(
                          name: target.name,
                          seat: target.seat,
                          onTap: () => widget.onAccuse(target.seat),
                        );
                      },
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
