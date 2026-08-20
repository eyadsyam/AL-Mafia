import 'package:flutter/material.dart';
import '../../../engine/models/enums.dart' show DiscussionMode, DayTieRule;
import '../../../engine/models/match_settings.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/textured_surface.dart';

/// Settings screen (S-04) — configure match behavior and timing.
///
/// Reference: spec US4, FR-005 (persist as defaults), data-model.md §4
/// UI patterns: see turn_shell.dart for styling reference
class SettingsScreen extends StatefulWidget {
  /// Initial settings (typically from previous match or defaults).
  final MatchSettings initial;

  /// Callback with final settings when "حفظ" is tapped.
  final void Function(MatchSettings) onSave;

  /// Leaves without saving.
  final VoidCallback onBack;

  const SettingsScreen({
    super.key,
    required this.initial,
    required this.onSave,
    required this.onBack,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _speechSeconds;
  late DiscussionMode _discussionMode;
  late DayTieRule _dayTieRule;
  late bool _narrationEnabled;
  late bool _abstainAllowed;
  late int _identityHoldSeconds;
  late bool _muteAllAudio;
  late bool _scoreEnabled;

  @override
  void initState() {
    super.initState();
    _speechSeconds = widget.initial.speechSeconds;
    _discussionMode = widget.initial.discussionMode;
    _dayTieRule = widget.initial.dayTieRule;
    _narrationEnabled = widget.initial.narrationEnabled;
    _abstainAllowed = widget.initial.abstainAllowed;
    _identityHoldSeconds = widget.initial.identityHoldSeconds;
    _muteAllAudio = widget.initial.muteAllAudio;
    _scoreEnabled = widget.initial.scoreEnabled;
  }

  void _setSpeechSeconds(int value) {
    setState(() => _speechSeconds = value);
  }

  void _setDiscussionMode(DiscussionMode mode) {
    setState(() => _discussionMode = mode);
  }

  void _setDayTieRule(DayTieRule rule) {
    setState(() => _dayTieRule = rule);
  }

  void _setNarrationEnabled(bool value) {
    setState(() => _narrationEnabled = value);
  }

  void _setAbstainAllowed(bool value) {
    setState(() => _abstainAllowed = value);
  }

  void _setIdentityHoldSeconds(int value) {
    setState(() => _identityHoldSeconds = value);
  }

  void _setMuteAllAudio(bool value) {
    setState(() => _muteAllAudio = value);
  }

  void _setScoreEnabled(bool value) {
    setState(() => _scoreEnabled = value);
  }

  void _onSave() {
    final settings = MatchSettings(
      speechSeconds: _speechSeconds,
      discussionMode: _discussionMode,
      dayTieRule: _dayTieRule,
      narrationEnabled: _narrationEnabled,
      abstainAllowed: _abstainAllowed,
      identityHoldSeconds: _identityHoldSeconds,
      muteAllAudio: _muteAllAudio,
      scoreEnabled: _scoreEnabled,
    );
    widget.onSave(settings);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

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
                      title: l10n.settingsTitle,
                      onBack: widget.onBack,
                    ),
                    SizedBox(height: spacing.lg),

                    // Settings
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Speech time
                            _SettingSection(
                              label: l10n.speechSecondsLabel,
                              child: Wrap(
                                spacing: spacing.sm,
                                children: [45, 60, 90].map((sec) {
                                  final selected = _speechSeconds == sec;
                                  return ChoiceChip(
                                    label: Text(l10n.secondsSuffix(sec)),
                                    selected: selected,
                                    onSelected: (_) => _setSpeechSeconds(sec),
                                    backgroundColor: colors.surfaceRaised,
                                    selectedColor: colors.accentGold,
                                    labelStyle: type.body.copyWith(
                                      color: selected
                                          ? colors.surfaceBase
                                          : colors.textPrimary,
                                    ),
                                    side: BorderSide(
                                      color: selected
                                          ? colors.accentGold
                                          : colors.borderSubtle,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            SizedBox(height: spacing.lg),

                            // Identity hold. The same for every player, which
                            // is the point — this is what makes one person's
                            // turn indistinguishable in length from another's.
                            _SettingSection(
                              label: l10n.identityHoldLabel,
                              child: Wrap(
                                spacing: spacing.sm,
                                children: [3, 5, 10, 20].map((sec) {
                                  final selected = _identityHoldSeconds == sec;
                                  return ChoiceChip(
                                    label: Text(l10n.identityHoldSuffix(sec)),
                                    selected: selected,
                                    onSelected: (_) =>
                                        _setIdentityHoldSeconds(sec),
                                    backgroundColor: colors.surfaceRaised,
                                    selectedColor: colors.accentGold,
                                    labelStyle: type.body.copyWith(
                                      color: selected
                                          ? colors.surfaceBase
                                          : colors.textPrimary,
                                    ),
                                    side: BorderSide(
                                      color: selected
                                          ? colors.accentGold
                                          : colors.borderSubtle,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            SizedBox(height: spacing.lg),

                            // Discussion mode
                            _SettingSection(
                              label: l10n.discussionModeLabel,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _RadioOption(
                                    label: l10n.discussionStructured,
                                    value: DiscussionMode.structured,
                                    groupValue: _discussionMode,
                                    onChanged: _setDiscussionMode,
                                  ),
                                  SizedBox(height: spacing.sm),
                                  _RadioOption(
                                    label: l10n.discussionFree,
                                    value: DiscussionMode.free,
                                    groupValue: _discussionMode,
                                    onChanged: _setDiscussionMode,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: spacing.lg),

                            // Day tie rule
                            _SettingSection(
                              label: l10n.dayTieRuleLabel,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _RadioOption(
                                    label: l10n.tieRevote,
                                    value: DayTieRule.revote,
                                    groupValue: _dayTieRule,
                                    onChanged: _setDayTieRule,
                                  ),
                                  SizedBox(height: spacing.sm),
                                  _RadioOption(
                                    label: l10n.tieNoElimination,
                                    value: DayTieRule.noElimination,
                                    groupValue: _dayTieRule,
                                    onChanged: _setDayTieRule,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: spacing.lg),

                            // Sound. Two independent switches, because they
                            // answer different questions: "I do not want the
                            // phone making noise at all" and "I want the chimes
                            // but not a voice". The game is fully playable with
                            // both off — every announcement carries its own
                            // words on screen.
                            _SettingSection(
                              label: l10n.audioSettingsLabel,
                              child: Column(
                                children: [
                                  _SwitchRow(
                                    label: l10n.muteAllAudio,
                                    value: _muteAllAudio,
                                    onChanged: _setMuteAllAudio,
                                  ),
                                  SizedBox(height: spacing.sm),
                                  _SwitchRow(
                                    label: l10n.narrationEnabledLabel,
                                    // Narration cannot be heard through a
                                    // master mute, so the switch that would
                                    // pretend otherwise is disabled rather than
                                    // silently ignored.
                                    value: _narrationEnabled && !_muteAllAudio,
                                    onChanged: _muteAllAudio
                                        ? null
                                        : _setNarrationEnabled,
                                  ),
                                  SizedBox(height: spacing.sm),
                                  _SwitchRow(
                                    label: l10n.scoreEnabledLabel,
                                    value: _scoreEnabled && !_muteAllAudio,
                                    onChanged: _muteAllAudio
                                        ? null
                                        : _setScoreEnabled,
                                  ),
                                  SizedBox(height: spacing.sm),
                                  Text(
                                    l10n.narratorPlaceholder,
                                    style: type.caption
                                        .copyWith(color: colors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: spacing.lg),

                            // Abstain allowed toggle
                            _SettingSection(
                              label: l10n.abstainAllowedLabel,
                              child: Switch(
                                value: _abstainAllowed,
                                onChanged: _setAbstainAllowed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.lg),

                    // Save button
                    FilledButton(
                      onPressed: _onSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accentGold,
                        foregroundColor: colors.surfaceBase,
                        padding: EdgeInsets.symmetric(vertical: spacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radii.button),
                        ),
                      ),
                      child: Text(l10n.save, style: type.title),
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

/// A setting section with label and child content.
class _SettingSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: type.body.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: spacing.sm),
        child,
      ],
    );
  }
}

/// A radio option for enum selection.
class _RadioOption<T> extends StatelessWidget {
  final String label;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;

  const _RadioOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final selected = value == groupValue;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        height: spacing.xl + spacing.sm,
        padding: EdgeInsets.symmetric(horizontal: spacing.md),
        decoration: BoxDecoration(
          color: selected ? colors.surfaceOverlay : colors.surfaceRaised,
          border: Border.all(
            color: selected ? colors.accentGold : colors.borderSubtle,
          ),
          borderRadius: BorderRadius.circular(radii.button),
        ),
        child: Row(
          children: [
            _CustomRadio(selected: selected, colors: colors),
            SizedBox(width: spacing.sm),
            // Flexible, not fixed: the longest option ("منظم (أدوار محددة)")
            // overruns a 390dp screen, and at 130% Dynamic Type every option
            // does. A settings row that overflows is unreadable, so the label
            // gives way rather than the layout.
            Expanded(
              child: Text(
                label,
                style: type.body.copyWith(color: colors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A custom radio button display (avoids deprecated Radio widget).
class _CustomRadio extends StatelessWidget {
  final bool selected;
  final MafiaColors colors;

  const _CustomRadio({required this.selected, required this.colors});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Container(
      width: spacing.lg,
      height: spacing.lg,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.accentGold : colors.borderSubtle,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: spacing.md,
                height: spacing.md,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accentGold,
                ),
              ),
            )
          : null,
    );
  }
}

/// A labelled switch on one row.
///
/// A null [onChanged] renders it disabled rather than hiding it: a control that
/// disappears when another one is toggled leaves the host wondering whether the
/// setting still exists, and the layout jumping under a thumb is its own small
/// insult.
class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final enabled = onChanged != null;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: type.body.copyWith(
              color: enabled ? colors.textPrimary : colors.textMuted,
            ),
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
