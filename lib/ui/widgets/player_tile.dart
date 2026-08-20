import 'package:flutter/material.dart';

import '../theme/mafia_theme.dart';

/// The visual states a [PlayerTile] can be in. These are *game* states, never
/// role states: nothing here may be reachable only for one role.
enum PlayerTileState {
  normal,
  selected,

  /// Eliminated. Shown, but not selectable.
  dead,

  /// Alive but not a legal target right now (e.g. the actor themselves).
  disabled,
}

/// A single seat in a target list.
///
/// ## The reserved indicator slot (L-02)
///
/// Every tile lays out an indicator box of exactly the same size, in the same
/// place, for every role. Only the box's *contents* vary: for a Mafia actor it
/// shows how many teammates have already voted for this seat, and for everyone
/// else it is empty. Because the box is laid out unconditionally, a bystander
/// cannot infer anything from the tile's width, height or text position — and
/// the golden symmetry suite asserts exactly that.
class PlayerTile extends StatelessWidget {
  final int seat;
  final String name;
  final PlayerTileState state;

  /// Number of teammate votes already cast for this seat. Always zero unless
  /// the actor is Mafia — but the slot exists either way.
  final int indicatorCount;

  final VoidCallback? onTap;

  const PlayerTile({
    super.key,
    required this.seat,
    required this.name,
    this.state = PlayerTileState.normal,
    this.indicatorCount = 0,
    this.onTap,
  });

  bool get _selectable =>
      state == PlayerTileState.normal || state == PlayerTileState.selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    final Color background;
    final Color border;
    final Color text;
    switch (state) {
      case PlayerTileState.normal:
        background = colors.surfaceRaised;
        border = colors.borderSubtle;
        text = colors.textPrimary;
      case PlayerTileState.selected:
        background = colors.surfaceOverlay;
        border = colors.accentGold;
        text = colors.textPrimary;
      case PlayerTileState.dead:
        background = colors.surfaceBase;
        border = colors.borderSubtle;
        text = colors.textMuted;
      case PlayerTileState.disabled:
        background = colors.surfaceRaised;
        border = colors.borderSubtle;
        text = colors.textMuted;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _selectable ? onTap : null,
      child: Container(
        height: spacing.xxl + spacing.md,
        padding: EdgeInsets.symmetric(horizontal: spacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radii.card),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            _IndicatorSlot(count: indicatorCount),
            SizedBox(width: spacing.md),
            Expanded(
              child: Text(
                name,
                style: type.body.copyWith(
                  color: text,
                  decoration: state == PlayerTileState.dead
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: spacing.md),
            SizedBox(
              width: spacing.lg,
              child: Text(
                '${seat + 1}',
                style: type.caption.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reserved slot itself. Always the same size; empty when [count] is zero.
class _IndicatorSlot extends StatelessWidget {
  final int count;

  const _IndicatorSlot({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return SizedBox(
      width: spacing.lg,
      height: spacing.lg,
      child: count <= 0
          ? const SizedBox.expand()
          : Center(
              child: Container(
                width: spacing.md,
                height: spacing.md,
                decoration: BoxDecoration(
                  color: colors.textSecondary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  child: Text(
                    '$count',
                    style: context.typography.caption.copyWith(
                      color: colors.surfaceBase,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
