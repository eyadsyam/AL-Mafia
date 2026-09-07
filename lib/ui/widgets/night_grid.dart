import 'package:flutter/material.dart';

import '../theme/mafia_theme.dart';

/// One cell of the night grid.
///
/// A seat, or the one special tile every role's grid ends with — doc 14 §1.3.
/// The two are the same class on purpose: the special option is *a choice among
/// the choices*, not a control bolted underneath them, and the surest way to
/// keep it that way is for the grid to be unable to tell them apart.
class NightChoice {
  /// The seat this tile picks, or [NightChoice.skipSeat] for "choose nobody".
  final int seat;

  /// What the tile reads. A player's name, or the special option's own words.
  final String label;

  /// Teammate votes already cast for this seat. Always zero unless the actor is
  /// Mafia — but the slot that holds it is laid out either way.
  final int indicatorCount;

  /// Whether it can be picked at all. A dead seat is drawn and not tappable.
  final bool selectable;

  /// The last tile. Drawn with a diamond in front of it so it reads as the
  /// odd one out rather than as a player nobody has heard of.
  final bool special;

  /// A once-per-match tile that has been used.
  ///
  /// Dimmed and inert, and **still there**. Doc 14 §1.3: *"It never disappears
  /// — a disappearing tile changes the grid shape, and grid shape is a tell."*
  final bool spent;

  const NightChoice({
    required this.seat,
    required this.label,
    this.indicatorCount = 0,
    this.selectable = true,
    this.special = false,
    this.spent = false,
  });

  /// The sentinel seat of a special tile that records no target.
  ///
  /// Negative so it can never collide with a real seat, and one value rather
  /// than a second nullable field so that "what did they pick" has exactly one
  /// shape everywhere downstream.
  static const int skipSeat = -1;

  bool get isSkip => seat == skipSeat;
}

/// Doc 14 §1.3's grid: every option on one screen, and it never scrolls.
///
/// ## Why a grid and not the list it replaces
///
/// The list scrolled at nine players and was unusable at fifteen, and a target
/// list you have to scroll is worse than slow — the seats below the fold are
/// seats a hurried player does not consider, so the shape of the viewport
/// starts deciding who dies. Everything is on screen or the screen is wrong.
///
/// ## How it always fits
///
/// The row count comes from the tile count, the row *height* comes from
/// whatever space the body has, and every row is [Expanded]. So the grid
/// cannot overflow by construction: it gives each row an equal share of what
/// there is, capped at [_maxTileHeight] so a table of five does not get tiles
/// the size of playing cards.
///
/// The last row is padded with empty cells rather than centred, so a tile in it
/// is exactly as wide as a tile anywhere else. Four roles, one geometry — which
/// is the only property doc 05 has ever asked of this screen.
class NightGrid extends StatelessWidget {
  final List<NightChoice> choices;

  /// The seat currently picked, or null.
  final int? selectedSeat;

  /// Null while the turn is not yet open for selection.
  final ValueChanged<int>? onPick;

  const NightGrid({
    super.key,
    required this.choices,
    required this.selectedSeat,
    required this.onPick,
  });

  /// Key of the tile for [seat]. Tests tap by seat, never by name.
  static Key tile(int seat) => ValueKey('night_tile_$seat');

  /// Doc 14 §1.3's column table, as the one function that owns it.
  static int columnsFor(int tiles) {
    if (tiles <= 6) return 2;
    if (tiles <= 12) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final gap = spacing.sm;
    final columns = columnsFor(choices.length);
    final rows = (choices.length + columns - 1) ~/ columns;

    // Doc 14's 64dp tile, in tokens. Rows shrink below it on a short screen and
    // never grow above it on a tall one.
    final maxTile = spacing.xxl + spacing.md;
    final maxHeight = rows * maxTile + (rows - 1) * gap;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) SizedBox(height: gap),
              Expanded(
                child: Row(
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) SizedBox(width: gap),
                      Expanded(child: _cell(row * columns + column)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(int index) {
    if (index >= choices.length) return const SizedBox.expand();
    final choice = choices[index];
    return NightGridTile(
      key: NightGrid.tile(choice.seat),
      choice: choice,
      selected: selectedSeat == choice.seat,
      onTap: onPick == null || !choice.selectable || choice.spent
          ? null
          : () => onPick!(choice.seat),
    );
  }
}

/// One tile. Fills whatever cell it is given.
class NightGridTile extends StatelessWidget {
  final NightChoice choice;
  final bool selected;
  final VoidCallback? onTap;

  const NightGridTile({
    super.key,
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    final live = choice.selectable && !choice.spent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        // Doc 14 §1.3's 40%.
        opacity: choice.spent ? 0.4 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.surfaceOverlay : colors.surfaceRaised,
            borderRadius: BorderRadius.circular(radii.card),
            border: Border.all(
              color: selected ? colors.accentGold : colors.borderSubtle,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.sm),
            child: Stack(
              children: [
                // The reserved indicator, in the corner rather than in the
                // flow: a tile is small now, and a slot that pushed the name
                // sideways would make a Mafia tile a different shape from
                // everybody else's.
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Padding(
                    padding: EdgeInsets.only(top: spacing.xs),
                    child: _Indicator(count: choice.indicatorCount),
                  ),
                ),
                Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(
                          child: Icon(
                            choice.spent
                                ? Icons.lock_outline
                                : Icons.diamond_outlined,
                            size: type.bodySmall.fontSize,
                            color: choice.special
                                ? (live ? colors.textPrimary : colors.textMuted)
                                : colors.surfaceRaised,
                          ),
                        ),
                        TextSpan(text: ' ${choice.label}'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: type.bodySmall.emphasised.copyWith(
                      color: live ? colors.textPrimary : colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Always the same size; empty when [count] is zero.
class _Indicator extends StatelessWidget {
  final int count;

  const _Indicator({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return SizedBox(
      width: spacing.md,
      height: spacing.md,
      child: count <= 0
          ? const SizedBox.expand()
          : DecoratedBox(
              decoration: BoxDecoration(
                color: colors.textSecondary,
                shape: BoxShape.circle,
              ),
              child: Center(
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
