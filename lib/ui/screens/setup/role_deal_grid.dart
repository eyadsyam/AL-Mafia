import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../../engine/models/enums.dart' as engine show Alignment;
import '../../../engine/models/enums.dart' show Role, RoleX;
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';
import 'role_rows.dart' show StoreDoor;

/// The deal as cards (owner, 2026-10-29): «لازم يبقا بال assets». Every role is
/// its card's art with its count on it and − / + under it; a bought role is
/// ringed in gold with «بتاعك»; a role not owned is dimmed and its pill opens
/// the store. A tap on the art opens the card big ([showRoleSheet]).
///
/// One widget for both tables: the offline roles screen and the online host's
/// deal both build their split from these, so the two can never drift.
/// A public setup surface: it shows the split, never who holds what (Doc 05).
class RoleDealSpec {
  final Role role;
  final String name;
  final int count;

  /// The short rule under the card («واحد بس», «من ٧», «الباقي»), or null.
  final String? rule;

  /// A bought role this player owns.
  final bool owned;

  /// A bought role this player does not own: dimmed, with the lock pill.
  final bool locked;

  final VoidCallback? onPlus;
  final VoidCallback? onMinus;

  /// Why a bought role cannot join this table, when it cannot.
  final String? blocked;

  /// The smallest table that takes this role, and the most a match deals.
  final int minPlayers;
  final int? max;

  const RoleDealSpec({
    required this.role,
    required this.name,
    required this.count,
    this.rule,
    this.owned = false,
    this.locked = false,
    this.onPlus,
    this.onMinus,
    this.blocked,
    this.minPlayers = 5,
    this.max,
  });
}

/// The card face for [role].
String roleFace(Role role) => switch (role) {
  Role.mafia => AppImages.cardFaceMafia,
  Role.silencer => AppImages.cardFaceSilencer,
  Role.detective => AppImages.cardFaceDetective,
  Role.doctor => AppImages.cardFaceDoctor,
  Role.elder => AppImages.cardFaceElder,
  Role.sniper => AppImages.cardFaceSniper,
  Role.citizen => AppImages.cardFaceCitizen,
};

class RoleDealGrid extends StatelessWidget {
  final List<RoleDealSpec> cards;

  /// A short phone: the art is shorter so the whole deal fits.
  final bool compact;

  const RoleDealGrid({super.key, required this.cards, this.compact = false});

  static Key card(Role role) => ValueKey('deal_card_${role.name}');
  static Key plus(Role role) => ValueKey('deal_plus_${role.name}');
  static Key minus(Role role) => ValueKey('deal_minus_${role.name}');
  static Key count(Role role) => ValueKey('deal_count_${role.name}');
  static Key lock(Role role) => ValueKey('deal_lock_${role.name}');

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = RolesTokens.dealGap;
      final width =
          (box.maxWidth - gap * (RolesTokens.dealColumns - 1)) /
          RolesTokens.dealColumns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final c in cards)
            SizedBox(
              width: width,
              child: RoleDealCard(spec: c, compact: compact),
            ),
        ],
      );
    },
  );
}

class RoleDealCard extends StatelessWidget {
  final RoleDealSpec spec;
  final bool compact;

  const RoleDealCard({super.key, required this.spec, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final l = context.l10n;
    final c = spec;
    final off = c.locked
        ? RolesTokens.dealLockedAlpha
        : (c.owned && c.count == 0 ? RolesTokens.dealOffAlpha : 1.0);
    final ring = c.owned || c.locked
        ? Border.all(
            color: VaultTokens.gold.withValues(
              alpha: c.locked ? RolesTokens.dealLockedAlpha : 1,
            ),
            width: RolesTokens.dealOwnedRing,
          )
        : Border.all(
            color: DeckTokens.bone.withValues(alpha: DeckTokens.hairlineAlpha),
          );
    final art = Semantics(
      button: true,
      label: l.rolesOpenCard(c.name),
      child: GestureDetector(
        onTap: () => showRoleSheet(context, c),
        child: Container(
          height: compact ? RolesTokens.dealArtShort : RolesTokens.dealArt,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
            border: ring,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                roleFace(c.role),
                fit: BoxFit.cover,
                alignment: RolesTokens.dealFocus,
                excludeFromSemantics: true,
              ),
              if (c.owned)
                PositionedDirectional(
                  top: RolesTokens.dealBadgeInset,
                  start: RolesTokens.dealBadgeInset,
                  child: _Seal(text: l.rolesOwnedSeal),
                ),
              PositionedDirectional(
                bottom: RolesTokens.dealBadgeInset,
                end: RolesTokens.dealBadgeInset,
                child: Container(
                  key: RoleDealGrid.count(c.role),
                  constraints: const BoxConstraints(
                    minWidth: RolesTokens.dealBadge,
                    minHeight: RolesTokens.dealBadge,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DeckTokens.ground,
                    shape: BoxShape.circle,
                    border: Border.all(color: DeckTokens.bone),
                  ),
                  child: Text(
                    '${c.count}',
                    style: DeckTokens.card(type).copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget step(IconData icon, String tip, VoidCallback? onTap, Key key) =>
        SizedBox(
          width: RolesTokens.dealStep,
          height: RolesTokens.dealStepHeight,
          child: IconButton(
            key: key,
            tooltip: '$tip ${c.name}',
            padding: EdgeInsets.zero,
            onPressed: onTap,
            icon: Icon(icon, size: DeckTokens.icon),
            color: colors.textPrimary,
            disabledColor: colors.textMuted.withValues(
              alpha: DeckTokens.disabledAlpha,
            ),
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
                side: const BorderSide(color: DeckTokens.silver),
              ),
            ),
          ),
        );

    final controls = c.locked
        ? StoreDoor(
            builder: (context, open) => Semantics(
              button: true,
              child: InkWell(
                key: RoleDealGrid.lock(c.role),
                customBorder: const StadiumBorder(),
                onTap: open,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DeckPill(l.roleLockedPill),
                  ),
                ),
              ),
            ),
          )
        : Row(
            children: [
              step(
                Icons.add,
                l.increaseRole,
                c.onPlus,
                RoleDealGrid.plus(c.role),
              ),
              Expanded(
                child: Text(
                  c.blocked ?? c.rule ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DeckTokens.meta(
                    type,
                  ).copyWith(color: colors.textSecondary),
                ),
              ),
              step(
                Icons.remove,
                l.decreaseRole,
                c.onMinus,
                RoleDealGrid.minus(c.role),
              ),
            ],
          );

    return KeyedSubtree(
      key: RoleDealGrid.card(c.role),
      child: Opacity(
        opacity: off,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            art,
            SizedBox(height: context.spacing.xs),
            Text(
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DeckTokens.card(type).copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: context.spacing.xs),
            controls,
          ],
        ),
      ),
    );
  }
}

class _Seal extends StatelessWidget {
  final String text;
  const _Seal({required this.text});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: VaultTokens.gold,
      borderRadius: BorderRadius.all(Radius.circular(DeckTokens.pill)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      child: Text(
        text,
        style: context.typography.caption.copyWith(
          color: VaultTokens.goldInk,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// Town against Mafia, as a bar under its two numbers.
class RoleBalanceBar extends StatelessWidget {
  final int mafia;
  final int town;
  const RoleBalanceBar({super.key, required this.mafia, required this.town});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                context.l10n.rolesTownCount(town),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DeckTokens.body(type).copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Flexible(
              child: Text(
                context.l10n.rolesMafiaCount(mafia),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DeckTokens.body(
                  type,
                ).copyWith(color: colors.roleMafia, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        SizedBox(height: context.spacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(RolesTokens.balanceBar),
          child: SizedBox(
            height: RolesTokens.balanceBar,
            child: Row(
              children: [
                Expanded(
                  flex: town < 1 ? 1 : town,
                  child: const ColoredBox(color: DeckTokens.bone),
                ),
                Expanded(
                  flex: mafia < 1 ? 1 : mafia,
                  child: ColoredBox(color: colors.roleMafia),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The card, big, over a sheet: its art, its side, what it does, its numbers,
/// and the same − / + as the grid, in words.
Future<void> showRoleSheet(BuildContext context, RoleDealSpec spec) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: RolesTokens.sheetScrim),
      builder: (context) => _RoleSheet(spec: spec),
    );

class _RoleSheet extends StatelessWidget {
  final RoleDealSpec spec;
  const _RoleSheet({required this.spec});

  static const Key addKey = ValueKey('role_sheet_add');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final c = spec;
    final sold = c.owned || c.locked;
    final mafiaSide = c.role.alignment == engine.Alignment.mafia;

    Widget stat(String big, String small) => Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceOverlay,
          borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
        ),
        child: Padding(
          padding: EdgeInsets.all(s.sm),
          child: Column(
            children: [
              Text(
                big,
                style: DeckTokens.card(type).copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                small,
                textAlign: TextAlign.center,
                style: DeckTokens.meta(
                  type,
                ).copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );

    void tap(VoidCallback? action) {
      if (action == null) return;
      action();
      Navigator.of(context).pop();
    }

    final primaryAction = c.locked
        ? null
        : (sold ? (c.count == 0 ? c.onPlus : c.onMinus) : c.onPlus);
    final primaryLabel = sold
        ? (c.count == 0 ? l.rolesSheetAdd : l.rolesSheetRemove)
        : l.rolesSheetMore;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: RolesTokens.sheetCard.width,
            height: RolesTokens.sheetCard.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.radii.card),
              border: sold
                  ? Border.all(
                      color: VaultTokens.gold,
                      width: RolesTokens.dealOwnedRing,
                    )
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              roleFace(c.role),
              fit: BoxFit.cover,
              semanticLabel: c.name,
            ),
          ),
          SizedBox(height: s.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(context.radii.dialog),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(s.lg, s.md, s.lg, s.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          c.name,
                          style: DeckTokens.title(
                            type,
                          ).copyWith(color: colors.textPrimary),
                        ),
                      ),
                      Text(
                        mafiaSide ? l.roleTeamMafia : l.roleTeamTown,
                        style: DeckTokens.meta(type).copyWith(
                          color: mafiaSide
                              ? colors.roleMafia
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: s.xs),
                  Text(
                    EngineCopy.roleDescription(l, c.role),
                    style: DeckTokens.body(
                      type,
                    ).copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: s.md),
                  Row(
                    children: [
                      stat('${c.minPlayers}+', l.rolesSheetMinPlayers),
                      SizedBox(width: s.sm),
                      stat(c.max == null ? '—' : '${c.max}', l.rolesSheetMax),
                      SizedBox(width: s.sm),
                      stat('${c.count}', l.rolesSheetNow),
                    ],
                  ),
                  if (c.blocked != null) ...[
                    SizedBox(height: s.sm),
                    Text(
                      c.blocked!,
                      style: DeckTokens.meta(
                        type,
                      ).copyWith(color: colors.accentCrimson),
                    ),
                  ],
                  SizedBox(height: s.md),
                  if (!c.locked && !sold && c.onMinus != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: s.sm),
                      child: OutlinedButton(
                        onPressed: () => tap(c.onMinus),
                        child: Text(l.rolesSheetLess),
                      ),
                    ),
                  if (c.locked)
                    StoreDoor(
                      builder: (context, open) =>
                          BoneButton(label: l.roleLockedPill, onPressed: open),
                    )
                  else
                    BoneButton(
                      key: addKey,
                      label: primaryLabel,
                      onPressed: primaryAction == null
                          ? null
                          : () => tap(primaryAction),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
