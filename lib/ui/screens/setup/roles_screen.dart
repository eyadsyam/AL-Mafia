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
import '../../widgets/deck/card_fan.dart';
import '../../widgets/deck/deck_public.dart';
import 'optional_roles.dart';
import 'role_rows.dart';

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
        (counts[Role.mafia] ?? 0) + (on.contains(OptionalRole.silencer) ? 1 : 0);
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

  List<FanCard> _cards() {
    final counts = _counts;
    FanCard card(String face, String id, int k) => FanCard(
      id: '$id#$k',
      child: _FaceCard(asset: face),
    );
    return [
      for (var k = 0; k < (counts[Role.mafia] ?? 0); k++)
        card(AppImages.cardFaceMafia, 'mafia', k),
      if (_on.contains(OptionalRole.silencer))
        card(AppImages.cardFaceSilencer, 'silencer', 0),
      for (var k = 0; k < (counts[Role.detective] ?? 0); k++)
        card(AppImages.cardFaceDetective, 'detective', k),
      for (var k = 0; k < (counts[Role.doctor] ?? 0); k++)
        card(AppImages.cardFaceDoctor, 'doctor', k),
      if (_on.contains(OptionalRole.elder))
        card(AppImages.cardFaceElder, 'elder', 0),
      if (_on.contains(OptionalRole.sniper))
        card(AppImages.cardFaceSniper, 'sniper', 0),
      for (var k = 0; k < (counts[Role.citizen] ?? 0); k++)
        card(AppImages.cardFaceCitizen, 'citizen', k),
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
    final note =
        blocking ?? report.issues.firstOrNull; // blocking sorts first
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

    RoleStepper stepper(
      Role role,
      String label,
      int value, {
      required bool canMinus,
      required bool canPlus,
      required VoidCallback minus,
      required VoidCallback plus,
    }) => RoleStepper(
      key: RolesScreen.stepper(role),
      label: label,
      value: value,
      onMinus: canMinus ? minus : null,
      onPlus: canPlus ? plus : null,
    );

    final canGrow = _citizens > 1;
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
            KeyedSubtree(
              key: RolesScreen.fan,
              child: CardFan(
                cards: _cards(),
                cardSize: compact
                    ? RolesTokens.fanCardCompact
                    : RolesTokens.fanCard,
                step: compact ? RolesTokens.fanStepCompact : RolesTokens.fanStep,
                height: compact
                    ? RolesTokens.fanHeightCompact
                    : RolesTokens.fanHeight,
              ),
            ),
            SizedBox(height: s.sm),
            Column(
              key: RolesScreen.balance,
              children: [
                Text(
                  l.rolesBalanceLine(_mafia, _n - _mafia),
                  textAlign: TextAlign.center,
                  style: DeckTokens.body(type).copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  noteText,
                  textAlign: TextAlign.center,
                  style: DeckTokens.meta(type).copyWith(
                    color: blocking != null
                        ? colors.accentCrimson
                        : colors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: s.md),
            RoleRow(
              face: AppImages.cardFaceMafia,
              name: l.roleGroupMafia,
              power: l.rolePowerMafia,
              trailing: stepper(
                Role.mafia,
                l.roleGroupMafia,
                _mafia,
                canMinus: _mafia > (_on.contains(OptionalRole.silencer) ? 2 : 1),
                canPlus: canGrow && (_mafia + 1) * 2 < _n,
                minus: () => _edit(() => _mafia--),
                plus: () => _edit(() => _mafia++),
              ),
            ),
            const SizedBox(height: RolesTokens.rowGap),
            RoleRow(
              face: AppImages.cardFaceDetective,
              name: l.roleGroupDetective,
              power: l.rolePowerDetective,
              trailing: stepper(
                Role.detective,
                l.roleGroupDetective,
                _detective,
                canMinus: _detective > 0,
                // One Detective per match, never more (owner, 2026-10-01).
                canPlus: _detective < 1 && canGrow,
                minus: () => _edit(() => _detective--),
                plus: () => _edit(() => _detective++),
              ),
            ),
            const SizedBox(height: RolesTokens.rowGap),
            RoleRow(
              face: AppImages.cardFaceDoctor,
              name: l.roleGroupDoctor,
              power: l.rolePowerDoctor,
              trailing: stepper(
                Role.doctor,
                l.roleGroupDoctor,
                _doctor,
                canMinus: _doctor > 0,
                canPlus: canGrow,
                minus: () => _edit(() => _doctor--),
                plus: () => _edit(() => _doctor++),
              ),
            ),
            const SizedBox(height: RolesTokens.rowGap),
            RoleRow(
              face: AppImages.cardFaceCitizen,
              name: l.roleGroupCitizen,
              power: l.rolePowerCitizen,
              quiet: true,
              trailing: SizedBox(
                width: RolesTokens.stepperButton * 2 + RolesTokens.stepperCount,
                child: Text(
                  '${_counts[Role.citizen] ?? 0}',
                  key: const ValueKey('roles_citizen_count'),
                  textAlign: TextAlign.center,
                  style: DeckTokens.card(type).copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: s.lg),
            Text(
              l.rolesMore,
              style: DeckTokens.meta(type).copyWith(color: DeckTokens.muted),
            ),
            SizedBox(height: s.sm),
            OptionalRoleRows(
              players: _n,
              mafia: _mafia,
              citizens: _baseCitizens,
              selected: _on,
              onChanged: _toggle,
            ),
          ],
        ),
      ),
    );
  }
}

/// One card of the fan: the role's face on the Mafia card's frame.
class _FaceCard extends StatelessWidget {
  final String asset;
  const _FaceCard({required this.asset});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return LayoutBuilder(
      builder: (context, box) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FanTokens.radius),
          border: Border.all(color: SeatTokens.rim),
          boxShadow: [
            BoxShadow(
              color: DeckTokens.ground.withValues(alpha: FanTokens.shadowAlpha),
              blurRadius: FanTokens.shadowBlur,
              offset: const Offset(0, FanTokens.shadowDrop),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(FanTokens.radius),
          child: Image(
            image: ResizeImage(
              AssetImage(asset),
              width: (box.maxWidth * dpr * DeckTokens.artDecodeHeadroom)
                  .round(),
              policy: ResizeImagePolicy.fit,
            ),
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
