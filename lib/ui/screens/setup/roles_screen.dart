import 'package:flutter/material.dart';
import '../../../engine/balance_guard.dart';
import '../../../engine/models/enums.dart' show Role;
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/textured_surface.dart';

/// Roles screen (S-03) — configure role distribution.
///
/// Reference: spec US4, FR-003, FR-004 (balance validation)
/// UI patterns: see turn_shell.dart for styling reference
class RolesScreen extends StatefulWidget {
  /// Number of players (from AddPlayersScreen).
  final int playerCount;

  /// Callback with final role distribution when "التالي" is tapped.
  final void Function(Map<Role, int>) onNext;

  /// Back to the roster. Changing who is playing is the usual reason to leave
  /// this screen, and there was no way to do it.
  final VoidCallback onBack;

  const RolesScreen({
    super.key,
    required this.playerCount,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  late int _mafia;
  late int _detective;
  late int _doctor;

  @override
  void initState() {
    super.initState();
    // Initialize from recommended distribution
    final recommended = BalanceGuard.recommended(widget.playerCount);
    _mafia = recommended[Role.mafia] ?? 1;
    _detective = recommended[Role.detective] ?? 1;
    _doctor = recommended[Role.doctor] ?? 1;
  }

  int get _citizen => widget.playerCount - _mafia - _detective - _doctor;

  Map<Role, int> get _roleCounts => {
    Role.mafia: _mafia,
    Role.detective: _detective,
    Role.doctor: _doctor,
    Role.citizen: _citizen.clamp(0, widget.playerCount),
  };

  BalanceReport get _report => BalanceGuard.evaluate(
    playerCount: widget.playerCount,
    roleCounts: _roleCounts,
  );

  void _incrementMafia() {
    if (_mafia < widget.playerCount) {
      setState(() => _mafia++);
    }
  }

  void _decrementMafia() {
    if (_mafia > 0) {
      setState(() => _mafia--);
    }
  }

  void _incrementDetective() {
    if (_detective < widget.playerCount) {
      setState(() => _detective++);
    }
  }

  void _decrementDetective() {
    if (_detective > 0) {
      setState(() => _detective--);
    }
  }

  void _incrementDoctor() {
    if (_doctor < widget.playerCount) {
      setState(() => _doctor++);
    }
  }

  void _decrementDoctor() {
    if (_doctor > 0) {
      setState(() => _doctor--);
    }
  }

  void _onNext() {
    widget.onNext(_roleCounts);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;
    final report = _report;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: AppBackdrop(
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
                    // Header
                    ScreenHeader(
                      title: l10n.rolesTitle,
                      onBack: widget.onBack,
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      l10n.playerCountShort(widget.playerCount),
                      style: type.body.copyWith(color: colors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.lg),

                    // Steppers
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _RoleStepper(
                              label: l10n.roleGroupMafia,
                              value: _mafia,
                              onIncrement: _incrementMafia,
                              onDecrement: _decrementMafia,
                            ),
                            SizedBox(height: spacing.lg),
                            _RoleStepper(
                              label: l10n.roleGroupDetective,
                              value: _detective,
                              onIncrement: _incrementDetective,
                              onDecrement: _decrementDetective,
                            ),
                            SizedBox(height: spacing.lg),
                            _RoleStepper(
                              label: l10n.roleGroupDoctor,
                              value: _doctor,
                              onIncrement: _incrementDoctor,
                              onDecrement: _decrementDoctor,
                            ),
                            SizedBox(height: spacing.lg),

                            // Citizens (read-only)
                            Container(
                              height: spacing.xxl + spacing.md,
                              padding: EdgeInsets.symmetric(
                                horizontal: spacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceRaised,
                                borderRadius: BorderRadius.circular(radii.card),
                                border: Border.all(color: colors.borderSubtle),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.roleGroupCitizen,
                                    style: type.body.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    _citizen.toString(),
                                    style: type.title.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.lg),

                    // Status line (blocking issues in crimson, advisories in gold)
                    if (report.issues.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.md,
                          vertical: spacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceRaised,
                          borderRadius: BorderRadius.circular(radii.card),
                          border: Border.all(
                            color: report.issues.any((i) => i.blocking)
                                ? colors.accentCrimson
                                : colors.accentGold,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: report.issues
                              .map(
                                (issue) => Padding(
                                  padding: EdgeInsets.only(bottom: spacing.xs),
                                  child: Text(
                                    EngineCopy.balanceIssue(
                                      context.l10n,
                                      issue,
                                    ),
                                    style: type.bodySmall.copyWith(
                                      color: issue.blocking
                                          ? colors.accentCrimson
                                          : colors.accentGold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    if (report.issues.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: spacing.md),
                        child: Text(
                          l10n.balanceValid,
                          style: type.body.copyWith(color: colors.accentSage),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(height: spacing.lg),

                    // Next button (disabled while blocking issues exist)
                    FilledButton(
                      onPressed: report.valid ? _onNext : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accentGold,
                        foregroundColor: colors.surfaceBase,
                        disabledBackgroundColor: colors.surfaceOverlay,
                        disabledForegroundColor: colors.textMuted,
                        padding: EdgeInsets.symmetric(vertical: spacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radii.button),
                        ),
                      ),
                      child: Text(l10n.next, style: type.title),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A stepper control for a single role.
class _RoleStepper extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _RoleStepper({
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    return Container(
      height: spacing.xxl + spacing.md,
      padding: EdgeInsets.symmetric(horizontal: spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // The stepper controls are fixed-width and must never be pushed off
          // screen, so the label is the part that yields under a long
          // translation or a large Dynamic Type setting.
          Expanded(
            child: Text(
              label,
              style: type.body.copyWith(color: colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.remove, color: colors.accentGold),
                onPressed: onDecrement,
              ),
              SizedBox(
                width: spacing.xl,
                child: Text(
                  value.toString(),
                  style: type.title.copyWith(color: colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, color: colors.accentGold),
                onPressed: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
