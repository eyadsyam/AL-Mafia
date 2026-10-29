import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/asset_constants.dart';
import '../../economy/my_cosmetics.dart' show ownedRolesProvider;
import '../../economy/wallet.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';
import '../online/online_session.dart' show SupabaseConfig;
import 'coin_store.dart';
import 'optional_roles.dart';

/// One role as a row of the roles list: the face in its arched window, the
/// name and its one-line power, and whatever controls it at the end.
class RoleRow extends StatelessWidget {
  final String face;
  final String name;
  final String power;
  final Widget trailing;
  final Color? nameColor;

  /// The citizens' row: computed, so drawn as a dashed-feeling quiet row.
  final bool quiet;
  final bool dimmed;
  final int maxPowerLines;

  const RoleRow({
    super.key,
    required this.face,
    required this.name,
    required this.power,
    required this.trailing,
    this.nameColor,
    this.quiet = false,
    this.dimmed = false,
    this.maxPowerLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = context.spacing;
    final type = context.typography;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: quiet ? DeckTokens.ground : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(context.radii.card),
        border: Border.all(
          color: DeckTokens.bone.withValues(alpha: DeckTokens.hairlineAlpha),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(RolesTokens.rowPad),
        child: Row(
          children: [
            ArtWindow(
              asset: face,
              size: DeckTokens.windowRole,
              focus: ModeTokens.faceFocus,
              zoom: ModeTokens.faceZoom,
              dimmed: dimmed,
            ),
            SizedBox(width: s.md),
            Expanded(
              child: Opacity(
                opacity: dimmed ? RolesTokens.lockedTextAlpha : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DeckTokens.card(
                        type,
                      ).copyWith(color: nameColor ?? colors.textPrimary),
                    ),
                    Text(
                      power,
                      maxLines: maxPowerLines,
                      overflow: TextOverflow.ellipsis,
                      style: DeckTokens.meta(
                        type,
                      ).copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: s.sm),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// − n + for a role's count. The count stays beside its buttons.
class RoleStepper extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final Key? minusButtonKey;
  final Key? plusButtonKey;

  const RoleStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.minusButtonKey,
    this.plusButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l = context.l10n;
    Widget button(
      IconData icon,
      String tooltip,
      VoidCallback? onTap,
      Key? key,
    ) => SizedBox.square(
      dimension: RolesTokens.stepperButton,
      child: IconButton(
        key: key,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: DeckTokens.icon),
        color: colors.textPrimary,
        disabledColor: colors.textMuted.withValues(
          alpha: DeckTokens.disabledAlpha,
        ),
        style: IconButton.styleFrom(
          shape: const CircleBorder(side: BorderSide(color: DeckTokens.silver)),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          Icons.remove,
          '${l.decreaseRole} $label',
          onMinus,
          minusButtonKey,
        ),
        SizedBox(
          width: RolesTokens.stepperCount,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: DeckTokens.card(
              context.typography,
            ).copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        button(Icons.add, '${l.increaseRole} $label', onPlus, plusButtonKey),
      ],
    );
  }
}

/// Opens «خزنة المجلس» over whatever stands under it, exactly as the store
/// button does, for a control that is not the store button (the lock pill).
class StoreDoor extends StatefulWidget {
  final Widget Function(BuildContext context, VoidCallback open) builder;
  const StoreDoor({super.key, required this.builder});

  @override
  State<StoreDoor> createState() => _StoreDoorState();
}

class _StoreDoorState extends State<StoreDoor> {
  final _overlay = OverlayPortalController();

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _overlay,
    overlayChildBuilder: (_) => Positioned.fill(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _overlay.hide();
        },
        child: CoinStore(onClose: _overlay.hide),
      ),
    ),
    child: widget.builder(context, _overlay.show),
  );
}

/// «أدوار تانية»: the bought roles. Owned ones are a switch; the rest are
/// dimmed with the lock pill, which opens the store. A table that cannot take
/// a role says why in the row, from the balance guard's own wording.
class OptionalRoleRows extends ConsumerStatefulWidget {
  final int players;

  /// Mafia-side seats in the base split (a silencer is one of them).
  final int mafia;

  /// Citizens in the base split, before any bought role takes a seat.
  final int citizens;
  final Set<OptionalRole> selected;
  final void Function(OptionalRole role, bool on) onChanged;

  const OptionalRoleRows({
    super.key,
    required this.players,
    required this.mafia,
    required this.citizens,
    required this.selected,
    required this.onChanged,
  });

  static Key rowKey(OptionalRole r) => ValueKey('optional_role_${r.name}');
  static Key switchKey(OptionalRole r) =>
      ValueKey('optional_role_${r.name}_switch');
  static Key lockKey(OptionalRole r) =>
      ValueKey('optional_role_${r.name}_lock');

  @override
  ConsumerState<OptionalRoleRows> createState() => _OptionalRoleRowsState();
}

class _OptionalRoleRowsState extends ConsumerState<OptionalRoleRows> {
  @override
  void initState() {
    super.initState();
    // Which roles this wallet owns is the server's answer; ask once, and
    // never block the screen on it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          SupabaseConfig.isConfigured &&
          ref.read(walletProvider).valueOrNull == null) {
        ref.read(walletProvider.notifier).refresh();
      }
    });
  }

  // The wallet when it has answered, the device's last copy until then.
  bool _owns(String code) {
    final wallet = ref.watch(walletProvider).valueOrNull;
    final kept = ref.watch(ownedRolesProvider);
    return wallet != null ? wallet.owned.contains(code) : kept.contains(code);
  }

  String _name(OptionalRole r) {
    final l = context.l10n;
    return switch (r) {
      OptionalRole.silencer => l.settingSilencer,
      OptionalRole.elder => l.settingElder,
      OptionalRole.sniper => l.settingSniper,
    };
  }

  String _hint(OptionalRole r) {
    final l = context.l10n;
    return switch (r) {
      OptionalRole.silencer => l.settingSilencerHint,
      OptionalRole.elder => l.settingElderHint,
      OptionalRole.sniper => l.settingSniperHint,
    };
  }

  String _face(OptionalRole r) => switch (r) {
    OptionalRole.silencer => AppImages.cardFaceSilencer,
    OptionalRole.elder => AppImages.cardFaceElder,
    OptionalRole.sniper => AppImages.cardFaceSniper,
  };

  String? _blocked(OptionalRole r) {
    final l = context.l10n;
    final others = widget.selected
        .where((o) => o != r && o != OptionalRole.silencer)
        .length;
    final code = r.blockedBy(
      players: widget.players,
      mafia: widget.mafia,
      citizens: widget.citizens - others,
    );
    return switch (code) {
      null => null,
      'silencer_needs_two_mafia' => l.balanceSilencerNeedsTwoMafia,
      'elder_min_players' => l.balanceElderMinPlayers,
      'sniper_min_players' => l.balanceSniperMinPlayers,
      _ => l.rolesNoCitizenLeft,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in OptionalRole.values) ...[
          Builder(
            builder: (context) {
              final owned = _owns(r.code);
              final on = widget.selected.contains(r);
              final blocked = on ? null : _blocked(r);
              return RoleRow(
                key: OptionalRoleRows.rowKey(r),
                face: _face(r),
                name: _name(r),
                power: !owned ? l.roleLockedHint : (blocked ?? _hint(r)),
                maxPowerLines: 2,
                dimmed: !owned,
                trailing: owned
                    ? Switch(
                        key: OptionalRoleRows.switchKey(r),
                        value: on,
                        onChanged: on || blocked == null
                            ? (v) => widget.onChanged(r, v)
                            : null,
                      )
                    : StoreDoor(
                        builder: (context, open) => Semantics(
                          button: true,
                          child: InkWell(
                            key: OptionalRoleRows.lockKey(r),
                            customBorder: const StadiumBorder(),
                            onTap: open,
                            child: DeckPill(l.roleLockedPill),
                          ),
                        ),
                      ),
              );
            },
          ),
          const SizedBox(height: RolesTokens.rowGap),
        ],
      ],
    );
  }
}
