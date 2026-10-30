import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/models/enums.dart';
import '../../../engine/models/match_settings.dart';
import '../../economy/my_cosmetics.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';
import '../setup/optional_roles.dart';
import '../setup/role_deal_grid.dart';
import 'lobby_deal.dart';

/// The online host's deal, as the same cards the one-phone table uses
/// ([RoleDealGrid]). The host owns the split: Mafia, Detective and Doctor by
/// − / +, the bought roles on and off (a room setting the server checks), and
/// the citizens follow the seats.
///
/// [base] is null until the host first edits: the recommended split.
class OnlineDealCards {
  static List<RoleDealSpec> specs(
    BuildContext context, {
    required int players,
    required MatchSettings settings,
    required LobbyBase? base,
    required Set<String> owned,
    required void Function(LobbyBase base) onBase,
    required void Function(OptionalRole role, bool on) onRole,
    int capacity = 0,
  }) {
    final l = context.l10n;
    final deal = lobbyDeal(players, settings, base: base, capacity: capacity);
    final counts = deal.counts;
    final seats = lobbyDealSeats(players, capacity: capacity);
    // What is really being dealt, so a − / + moves from what the host sees.
    final now = (
      mafia: (counts[Role.mafia] ?? 0) + (counts[Role.silencer] ?? 0),
      detective: counts[Role.detective] ?? 0,
      doctor: counts[Role.doctor] ?? 0,
    );
    final on = {
      if (deal.settings.silencerEnabled) OptionalRole.silencer,
      if (deal.settings.elderEnabled) OptionalRole.elder,
      if (deal.settings.sniperEnabled) OptionalRole.sniper,
    };
    final citizens = counts[Role.citizen] ?? 0;
    final canGrow = citizens > 1;

    // Why a role the host switched on is not in the deal yet. It waits rather
    // than refuses: a room fills up after its host has set it.
    String? waiting(OptionalRole r) {
      if (!deal.skipped.contains(r)) return null;
      if (seats < r.minPlayers) return l.rolesWaitSeats(r.minPlayers);
      return r == OptionalRole.silencer
          ? l.balanceSilencerNeedsTwoMafia
          : l.rolesNoCitizenLeft;
    }

    RoleDealSpec sold(OptionalRole r, String rule) {
      final has = owned.contains(r.code);
      final isOn = on.contains(r);
      final wanted = isOn || deal.skipped.contains(r);
      return RoleDealSpec(
        role: r.role,
        name: EngineCopy.roleName(l, r.role),
        count: isOn ? 1 : 0,
        rule: rule,
        owned: has,
        locked: !has && !wanted,
        blocked: waiting(r),
        minPlayers: r.minPlayers,
        max: 1,
        onPlus: has && !wanted ? () => onRole(r, true) : null,
        onMinus: wanted ? () => onRole(r, false) : null,
      );
    }

    void edit({int? mafia, int? detective, int? doctor}) => onBase((
      mafia: mafia ?? now.mafia,
      detective: detective ?? now.detective,
      doctor: doctor ?? now.doctor,
    ));

    return [
      RoleDealSpec(
        role: Role.mafia,
        name: l.roleGroupMafia,
        count: counts[Role.mafia] ?? 0,
        onPlus: canGrow && (now.mafia + 1) * 2 < seats
            ? () => edit(mafia: now.mafia + 1)
            : null,
        onMinus: now.mafia > (on.contains(OptionalRole.silencer) ? 2 : 1)
            ? () => edit(mafia: now.mafia - 1)
            : null,
      ),
      sold(OptionalRole.silencer, l.rolesRuleOne),
      RoleDealSpec(
        role: Role.detective,
        name: l.roleGroupDetective,
        count: now.detective,
        rule: l.rolesRuleOne,
        max: 1,
        onPlus: now.detective < 1 && canGrow
            ? () => edit(detective: now.detective + 1)
            : null,
        onMinus: now.detective > 0
            ? () => edit(detective: now.detective - 1)
            : null,
      ),
      RoleDealSpec(
        role: Role.doctor,
        name: l.roleGroupDoctor,
        count: now.doctor,
        onPlus: canGrow ? () => edit(doctor: now.doctor + 1) : null,
        onMinus: now.doctor > 0 ? () => edit(doctor: now.doctor - 1) : null,
      ),
      sold(OptionalRole.elder, l.rolesRuleFrom(OptionalRole.elder.minPlayers)),
      sold(
        OptionalRole.sniper,
        l.rolesRuleFrom(OptionalRole.sniper.minPlayers),
      ),
      RoleDealSpec(
        role: Role.citizen,
        name: l.roleGroupCitizen,
        count: citizens,
        rule: l.rolesRuleRest,
      ),
    ];
  }
}

/// «الكروت اللي هتتوزع»: the host's deal at a glance in the lobby, each role's
/// card with its count, and «عدّل» to open [OnlineDealPanel].
class LobbyDeckStrip extends StatelessWidget {
  final Map<Role, int> counts;
  final bool reset;
  final VoidCallback onEdit;

  const LobbyDeckStrip({
    super.key,
    required this.counts,
    required this.reset,
    required this.onEdit,
  });

  static const Key editKey = ValueKey('lobby_deck_edit');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final shown = [
      for (final r in Role.values)
        if ((counts[r] ?? 0) > 0) r,
    ];
    // One line: the lobby's foot already holds Ready, Start and the banner,
    // and Start must keep its clearance from the ad (M3).
    return Semantics(
      button: true,
      label: '${l.lobbyDeckTitle} · ${l.lobbyDeckEdit}',
      child: InkWell(
        key: editKey,
        onTap: onEdit,
        borderRadius: BorderRadius.circular(context.radii.card),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(context.radii.card),
            border: Border.all(
              color: reset
                  ? colors.accentCrimson
                  : DeckTokens.bone.withValues(alpha: DeckTokens.hairlineAlpha),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
            child: Row(
              children: [
                Expanded(
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        for (final r in shown)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: s.xs / 2,
                              ),
                              child: SizedBox(
                                height: LobbyDeckTokens.cardHeight,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        RolesTokens.dealRadius,
                                      ),
                                      child: Image.asset(
                                        roleFace(r),
                                        fit: BoxFit.cover,
                                        alignment: RolesTokens.dealFocus,
                                      ),
                                    ),
                                    PositionedDirectional(
                                      bottom: 0,
                                      end: 0,
                                      child: DecoratedBox(
                                        decoration: const BoxDecoration(
                                          color: DeckTokens.ground,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(s.xs / 2),
                                          child: Text(
                                            '${counts[r]}',
                                            style: type.caption.copyWith(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: s.sm),
                Text(
                  l.lobbyDeckEdit,
                  style: DeckTokens.body(type).copyWith(
                    color: colors.accentGold,
                    fontWeight: FontWeight.w800,
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

/// The deal editor over the lobby: a layer in the lobby's Stack (doc 12 §2.1),
/// so the room's pushes rebuild it as they arrive.
class OnlineDealPanel extends ConsumerWidget {
  final bool visible;
  final int players;

  /// The room's size: what the deal is planned for until five are here.
  final int capacity;
  final MatchSettings settings;
  final LobbyBase? base;
  final void Function(LobbyBase base) onBase;
  final void Function(OptionalRole role, bool on) onRole;
  final VoidCallback onClose;

  const OnlineDealPanel({
    super.key,
    required this.visible,
    required this.players,
    this.capacity = 0,
    required this.settings,
    required this.base,
    required this.onBase,
    required this.onRole,
    required this.onClose,
  });

  static const Key doneKey = ValueKey('online_deal_done');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible) return const SizedBox.shrink();
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final owned = ref.watch(hostOwnedRolesProvider);
    final seats = lobbyDealSeats(players, capacity: capacity);
    final deal = lobbyDeal(players, settings, base: base, capacity: capacity);
    final mafia =
        (deal.counts[Role.mafia] ?? 0) + (deal.counts[Role.silencer] ?? 0);
    final compact = MediaQuery.sizeOf(context).height < RolesTokens.fanShort;
    return Positioned.fill(
      child: Material(
        color: colors.surfaceBase,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(s.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.rolesDeckTitle,
                        style: DeckTokens.title(
                          type,
                        ).copyWith(color: colors.textPrimary),
                      ),
                    ),
                    DeckPill(l.playerCountShort(seats)),
                  ],
                ),
                SizedBox(height: s.md),
                RoleBalanceBar(mafia: mafia, town: seats - mafia),
                if (deal.reset) ...[
                  SizedBox(height: s.xs),
                  Text(
                    l.lobbyDeckReset,
                    style: DeckTokens.meta(
                      type,
                    ).copyWith(color: colors.accentCrimson),
                  ),
                ],
                SizedBox(height: s.md),
                Expanded(
                  child: SingleChildScrollView(
                    child: RoleDealGrid(
                      compact: compact,
                      cards: OnlineDealCards.specs(
                        context,
                        players: players,
                        capacity: capacity,
                        settings: settings,
                        base: base,
                        owned: owned,
                        onBase: onBase,
                        onRole: onRole,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: s.sm),
                Text(
                  l.lobbyDeckFollows,
                  style: DeckTokens.meta(
                    type,
                  ).copyWith(color: colors.textSecondary),
                ),
                SizedBox(height: s.sm),
                BoneButton(
                  key: doneKey,
                  label: l.lobbyDeckDone,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
