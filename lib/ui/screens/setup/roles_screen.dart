import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/asset_constants.dart';
import '../../../engine/balance_guard.dart';
import '../../../engine/models/enums.dart' show Role;
import '../../../engine/presets.dart';
import '../../economy/my_cosmetics.dart' show ownedRolesProvider;
import '../../economy/wallet.dart' show walletProvider;
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';
import '../online/online_session.dart' show SupabaseConfig;
import 'optional_roles.dart';
import 'role_deal_grid.dart';

/// «الأدوار» (S-03): who is dealt what, before the cards are.
///
/// Presets, the whole table fanned out above, one line on the balance, a row
/// per role and the bought roles under «أدوار تانية». A public table screen:
/// it shows the *split*, never who holds which card, and nothing here reaches
/// a screen where a hand is held (Doc 05).
///
/// Reference: spec US4, FR-003, FR-004 (balance validation)
class RolesScreen extends ConsumerStatefulWidget {
  static const Key nextButton = ValueKey('roles_next');
  static Key stepper(Role role) => ValueKey('roles_${role.name}_stepper');
  static Key preset(String code) => ValueKey('roles_preset_$code');
  static const Key fan = ValueKey('roles_fan');
  static const Key balance = ValueKey('roles_balance');

  /// Number of players (from AddPlayersScreen).
  final int playerCount;

  /// Callback with the final role distribution when «وزّع الكروت» is tapped.
  final void Function(Map<Role, int>) onNext;

  /// The bought roles switched on, told just before [onNext] so the match's
  /// settings can carry their flags. Always called, with an empty set when
  /// none is on, so an earlier match's flags never leak into this one.
  final void Function(Set<OptionalRole>)? onOptionalRoles;

  /// Back to the roster. Changing who is playing is the usual reason to leave
  /// this screen, and there was no way to do it.
  final VoidCallback onBack;

  /// The split the host left here (the setup draft), bought roles included,
  /// so a Back from the settings step reopens what was chosen rather than the
  /// classic preset. Ignored when it does not add up to [playerCount].
  final Map<Role, int>? initialCounts;

  const RolesScreen({
    super.key,
    required this.playerCount,
    required this.onNext,
    required this.onBack,
    this.onOptionalRoles,
    this.initialCounts,
  });

  @override
  ConsumerState<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends ConsumerState<RolesScreen> {
  /// The preset the split still is, or null once the host has edited it.
  MatchPreset? _preset = MatchPreset.classic;
  late int _mafia;
  late int _detective;
  late int _doctor;
  Set<OptionalRole> _on = const {};

  int get _n => widget.playerCount;

  @override
  void initState() {
    super.initState();
    if (!_restore(widget.initialCounts)) _apply(MatchPreset.classic);
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

  /// Reads [counts] back into the editor terms: the bought roles are the ones
  /// present, and the base Mafia count includes a silencer seat.
  bool _restore(Map<Role, int>? counts) {
    if (counts == null) return false;
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total != _n) return false;
    final on = {
      for (final r in OptionalRole.values)
        if ((counts[r.role] ?? 0) > 0) r,
    };
    final mafia =
        (counts[Role.mafia] ?? 0) +
        (on.contains(OptionalRole.silencer) ? 1 : 0);
    if (mafia < 1) return false;
    _mafia = mafia;
    _detective = counts[Role.detective] ?? 0;
    _doctor = counts[Role.doctor] ?? 0;
    _on = on;
    _preset = null;
    for (final preset in [MatchPreset.classic, MatchPreset.brutal]) {
      if (!preset.availableFor(_n)) continue;
      final p = preset.roleCounts(_n);
      if ((p[Role.mafia] ?? 0) == _mafia &&
          (p[Role.detective] ?? 0) == _detective &&
          (p[Role.doctor] ?? 0) == _doctor) {
        _preset = preset;
        break;
      }
    }
    return true;
  }

  void _apply(MatchPreset preset) {
    final counts = preset.roleCounts(_n);
    _preset = preset;
    _mafia = counts[Role.mafia] ?? 1;
    _detective = counts[Role.detective] ?? 0;
    _doctor = counts[Role.doctor] ?? 0;
    _on = OptionalRole.usable(
      _on,
      players: _n,
      mafia: _mafia,
      citizens: _baseCitizens,
    );
  }

  int get _baseCitizens => _n - _mafia - _detective - _doctor;
  int get _taken => _on.where((r) => r != OptionalRole.silencer).length;
  int get _citizens => _baseCitizens - _taken;

  Map<Role, int> get _counts => OptionalRole.apply({
    Role.mafia: _mafia,
    Role.detective: _detective,
    Role.doctor: _doctor,
    Role.citizen: _baseCitizens,
  }, _on);

  BalanceReport get _report =>
      BalanceGuard.evaluate(playerCount: _n, roleCounts: _counts);

  /// A hand edit: whatever the preset was, it is now the host's own.
  void _edit(VoidCallback change) => setState(() {
    change();
    _preset = null;
  });

  // A bought role is added on top of the split; it does not make the split
  // the host own, so the preset chip stays lit.
  void _toggle(OptionalRole role, bool on) => setState(() {
    _on = {..._on}..remove(role);
    if (on) _on = {..._on, role};
  });

  void _next() {
    // Only roles this player owns go into the match, whatever the switches
    // say: the wallet when it has answered, the device copy until then.
    final wallet = ref.read(walletProvider).valueOrNull;
    final kept = ref.read(ownedRolesProvider);
    final owned = {
      for (final r in OptionalRole.values)
        if (wallet != null
            ? wallet.owned.contains(r.code)
            : kept.contains(r.code))
          r,
    };
    if (!owned.containsAll(_on)) _on = _on.intersection(owned);
    widget.onOptionalRoles?.call(_on);
    widget.onNext(_counts);
  }

  // The wallet when it has answered, the device's last copy until then.
  bool _owns(OptionalRole r) {
    final wallet = ref.watch(walletProvider).valueOrNull;
    final kept = ref.watch(ownedRolesProvider);
    return wallet != null
        ? wallet.owned.contains(r.code)
        : kept.contains(r.code);
  }

  /// Why [r] cannot join this table now, in the balance guard's words.
  String? _blocked(OptionalRole r) {
    final l = context.l10n;
    final others = _on
        .where((o) => o != r && o != OptionalRole.silencer)
        .length;
    final code = r.blockedBy(
      players: _n,
      mafia: _mafia,
      citizens: _baseCitizens - others,
    );
    return switch (code) {
      null => null,
      'silencer_needs_two_mafia' => l.balanceSilencerNeedsTwoMafia,
      'elder_min_players' => l.balanceElderMinPlayers,
      'sniper_min_players' => l.balanceSniperMinPlayers,
      _ => l.rolesNoCitizenLeft,
    };
  }

  RoleDealSpec _sold(OptionalRole r, String rule) {
    final l = context.l10n;
    final owned = _owns(r);
    final on = _on.contains(r);
    final blocked = owned && !on ? _blocked(r) : null;
    return RoleDealSpec(
      role: r.role,
      name: EngineCopy.roleName(l, r.role),
      count: on ? 1 : 0,
      rule: rule,
      owned: owned,
      locked: !owned,
      blocked: blocked,
      minPlayers: r.minPlayers,
      max: 1,
      onPlus: owned && !on && blocked == null ? () => _toggle(r, true) : null,
      onMinus: on ? () => _toggle(r, false) : null,
    );
  }

  List<RoleDealSpec> _deal() {
    final l = context.l10n;
    final counts = _counts;
    final canGrow = _citizens > 1;
    return [
      RoleDealSpec(
        role: Role.mafia,
        name: l.roleGroupMafia,
        count: counts[Role.mafia] ?? 0,
        onPlus: canGrow && (_mafia + 1) * 2 < _n
            ? () => _edit(() => _mafia++)
            : null,
        onMinus: _mafia > (_on.contains(OptionalRole.silencer) ? 2 : 1)
            ? () => _edit(() => _mafia--)
            : null,
      ),
      _sold(OptionalRole.silencer, l.rolesRuleOne),
      RoleDealSpec(
        role: Role.detective,
        name: l.roleGroupDetective,
        count: _detective,
        rule: l.rolesRuleOne,
        max: 1,
        // One Detective per match, never more (owner, 2026-10-01).
        onPlus: _detective < 1 && canGrow
            ? () => _edit(() => _detective++)
            : null,
        onMinus: _detective > 0 ? () => _edit(() => _detective--) : null,
      ),
      RoleDealSpec(
        role: Role.doctor,
        name: l.roleGroupDoctor,
        count: _doctor,
        onPlus: canGrow ? () => _edit(() => _doctor++) : null,
        onMinus: _doctor > 0 ? () => _edit(() => _doctor--) : null,
      ),
      _sold(OptionalRole.elder, l.rolesRuleFrom(OptionalRole.elder.minPlayers)),
      _sold(
        OptionalRole.sniper,
        l.rolesRuleFrom(OptionalRole.sniper.minPlayers),
      ),
      RoleDealSpec(
        role: Role.citizen,
        name: l.roleGroupCitizen,
        count: counts[Role.citizen] ?? 0,
        rule: l.rolesRuleRest,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    final report = _report;
    final compact = MediaQuery.sizeOf(context).height < RolesTokens.fanShort;
    final blocking = report.issues.where((i) => i.blocking).firstOrNull;
    final note = blocking ?? report.issues.firstOrNull; // blocking sorts first
    final noteText = note == null
        ? l.balanceValid
        : EngineCopy.balanceIssue(l, note);

    Widget presetChip(String code, String label, MatchPreset? preset) {
      final offered = preset == null || preset.availableFor(_n);
      return Opacity(
        opacity: offered ? 1 : DeckTokens.disabledAlpha,
        child: IgnorePointer(
          ignoring: !offered,
          child: DeckChip(
            key: RolesScreen.preset(code),
            label: label,
            selected: _preset == preset,
            onSelected: (_) {
              if (preset == null) {
                setState(() => _preset = null);
              } else {
                setState(() => _apply(preset));
              }
            },
          ),
        ),
      );
    }

    return DeckScaffold(
      backdrop: AppOffline.bgRolesFan,
      title: l.rolesDeckTitle,
      onBack: widget.onBack,
      trailing: DeckPill(l.playerCountShort(_n)),
      primary: BoneButton(
        key: RolesScreen.nextButton,
        label: l.rolesDeal,
        onPressed: report.valid ? _next : null,
        disabledReason: report.valid ? null : noteText,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: RolesTokens.presetGap,
              runSpacing: RolesTokens.presetGap,
              children: [
                presetChip('normal', l.rolesPresetNormal, MatchPreset.classic),
                presetChip('hard', l.rolesPresetHard, MatchPreset.brutal),
                presetChip('custom', l.rolesPresetCustom, null),
              ],
            ),
            SizedBox(height: s.md),
            DecoratedBox(
              key: RolesScreen.balance,
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(context.radii.card),
                border: Border.all(
                  color: DeckTokens.bone.withValues(
                    alpha: DeckTokens.hairlineAlpha,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(s.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RoleBalanceBar(mafia: _mafia, town: _n - _mafia),
                    SizedBox(height: s.xs),
                    Text(
                      l.rolesBalanceLine(_mafia, _n - _mafia),
                      style: DeckTokens.meta(
                        type,
                      ).copyWith(color: colors.textSecondary),
                    ),
                    Text(
                      noteText,
                      style: DeckTokens.meta(type).copyWith(
                        color: blocking != null
                            ? colors.accentCrimson
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: s.md),
            KeyedSubtree(
              key: RolesScreen.fan,
              child: RoleDealGrid(cards: _deal(), compact: compact),
            ),
          ],
        ),
      ),
    );
  }
}
