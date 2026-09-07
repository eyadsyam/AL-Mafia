import 'package:flutter/material.dart';
import '../../../app/l10n/app_localizations.dart';
import '../../../engine/models/enums.dart'
    show DiscussionMode, DayTieRule, Role;
import '../../../engine/models/match_settings.dart';
import '../../../engine/presets.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/textured_surface.dart';

/// Settings screen (S-04).
///
/// ## Doc 14 Part 5: five named groups, and the right control for each row
///
/// This used to be a flat wall of switches with a disclosure at the bottom
/// hiding another eighteen, and the honest summary of it is doc 14's: *"a
/// setting nobody understands is a setting nobody uses."* Two things changed.
///
/// **Every switch carries a line of description underneath it.** Not a tooltip
/// and not a help screen — the sentence is on the row, always, because a host
/// reads this screen once, standing up, with eight people waiting.
///
/// **Times are segmented controls and choices are radios.** A switch is for a
/// genuine on/off and nothing else. Turning "how long does somebody speak" into
/// three taps through a chip row is what made the old screen unreadable.
///
/// The rows doc 14 removed are gone from here entirely — the bullet master and
/// its four per-role switches, «فتح الملف», «الشهادة», the hint toggles, the
/// hint reset. What is left is what a host actually decides.
class SettingsScreen extends StatefulWidget {
  static const Key saveButton = ValueKey('settings_save');

  /// Initial settings (typically from previous match or defaults).
  final MatchSettings initial;

  /// Callback with final settings when "حفظ" is tapped.
  final void Function(MatchSettings) onSave;

  /// Preview audio immediately; leaving without saving restores the initial mix.
  final ValueChanged<MatchSettings>? onAudioPreview;

  /// Leaves without saving.
  final VoidCallback onBack;

  /// How many people are playing, when that is already known.
  ///
  /// Null from Home, where this screen edits the stored defaults and there is
  /// no table yet. A preset picked with no table still sets the rows of doc 13
  /// §5's table; it just has no role split to hand anywhere, because a third of
  /// an unknown number of players is not a number.
  final int? playerCount;

  /// The split chosen on the previous screen, so the lit chip can tell a
  /// preset from a preset whose Mafia count was then edited by hand.
  final Map<Role, int>? roleCounts;

  /// Called when a preset changes the split. Never called when [playerCount]
  /// is null.
  final void Function(Map<Role, int>)? onRoleCounts;

  const SettingsScreen({
    super.key,
    required this.initial,
    required this.onSave,
    required this.onBack,
    this.playerCount,
    this.roleCounts,
    this.onRoleCounts,
    this.onAudioPreview,
  });

  /// The chip for [preset]. Keyed rather than found by its text, because the
  /// three labels are translated and a test that reads them is a test about
  /// Arabic.
  static Key presetChip(MatchPreset preset) =>
      ValueKey('preset_${preset.code}');

  /// A switch, named for the field it writes.
  static Key toggle(String field) => ValueKey('setting_$field');

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// The whole settings object, edited in place.
  ///
  /// **One field, not one per control, and that is the fix for a real bug.**
  /// This screen used to keep a copy of each control's value and rebuild a
  /// fresh `MatchSettings(...)` on save out of exactly those eight — which
  /// silently reset every field it had no control for. A host who turned
  /// something off and then came back to change the speech clock got it back,
  /// and nothing said so.
  ///
  /// With one object there is no list to forget to extend: a control this
  /// screen does not draw is a value that passes through untouched, which is
  /// what a settings screen owes anything it does not know about.
  late MatchSettings _s;

  /// The role split, when there is a table. Only a preset changes it.
  Map<Role, int>? _counts;

  @override
  void initState() {
    super.initState();
    _s = widget.initial;
    _counts = widget.roleCounts;
  }

  void _edit(MatchSettings Function(MatchSettings) f) {
    setState(() => _s = f(_s));
    widget.onAudioPreview?.call(_s);
  }

  /// Doc 13 §5. Sets the rows of the table and nothing else.
  void _applyPreset(MatchPreset preset) {
    final n = widget.playerCount;
    final counts = n == null ? null : preset.roleCounts(n);
    setState(() {
      _s = preset.applyTo(_s);
      if (counts != null) _counts = counts;
    });
    if (counts != null) widget.onRoleCounts?.call(counts);
  }

  bool _saved = false;

  void _onSave() {
    _saved = true;
    widget.onSave(_s);
  }

  @override
  void dispose() {
    if (!_saved) widget.onAudioPreview?.call(widget.initial);
    super.dispose();
  }

  /// Doc 13 §5's preset row.
  ///
  /// The lit chip is *derived*, never stored: [MatchPreset.identify] asks the
  /// settings themselves which preset they are. So there is no state to get out
  /// of step with the controls, and turning one switch after tapping a chip
  /// puts the chip out for free, because the settings genuinely are not that
  /// preset any more.
  Widget _presetSection(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;

    final current = MatchPreset.identify(
      _s,
      counts: _counts,
      players: widget.playerCount,
    );
    final offered = [
      for (final preset in MatchPreset.values)
        if (widget.playerCount == null ||
            preset.availableFor(widget.playerCount!))
          preset,
    ];

    return _Group(
      title: l10n.presetLabel,
      children: [
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            for (final preset in offered)
              ChoiceChip(
                key: SettingsScreen.presetChip(preset),
                label: Text(EngineCopy.presetName(l10n, preset)),
                selected: current == preset,
                onSelected: (_) => _applyPreset(preset),
                backgroundColor: colors.surfaceRaised,
                selectedColor: colors.accentGold,
                labelStyle: type.body.copyWith(
                  color: current == preset
                      ? colors.surfaceBase
                      : colors.textPrimary,
                ),
                side: BorderSide(
                  color: current == preset
                      ? colors.accentGold
                      : colors.borderSubtle,
                ),
              ),
          ],
        ),
        SizedBox(height: spacing.sm),
        // One line, and it is always there. A description that appears only
        // when a chip is lit would make the row change height under a thumb,
        // and custom is a real answer rather than the absence of one.
        Text(
          current == null
              ? l10n.presetCustom
              : EngineCopy.presetHint(l10n, current),
          style: type.caption.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  /// A segmented control. Doc 14 Part 5: times are never switches.
  Widget _segmented({
    required String label,
    required String description,
    required List<int> values,
    required int current,
    required String Function(int) format,
    required void Function(int) onPick,
  }) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return _Row(
      label: label,
      description: description,
      control: Wrap(
        spacing: spacing.sm,
        runSpacing: spacing.xs,
        children: [
          for (final value in values)
            ChoiceChip(
              key: ValueKey('$label-$value'),
              label: Text(format(value)),
              selected: current == value,
              onSelected: (_) => onPick(value),
              backgroundColor: colors.surfaceRaised,
              selectedColor: colors.accentGold,
              labelStyle: type.body.copyWith(
                color: current == value
                    ? colors.surfaceBase
                    : colors.textPrimary,
              ),
              side: BorderSide(
                color: current == value
                    ? colors.accentGold
                    : colors.borderSubtle,
              ),
            ),
        ],
      ),
      controlBelow: true,
    );
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
                    ScreenHeader(
                      title: l10n.settingsTitle,
                      onBack: widget.onBack,
                    ),
                    SizedBox(height: spacing.lg),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _presetSection(context),
                            SizedBox(height: spacing.lg),
                            _pace(l10n),
                            SizedBox(height: spacing.lg),
                            _information(l10n),
                            SizedBox(height: spacing.lg),
                            _reveal(l10n),
                            SizedBox(height: spacing.lg),
                            _voting(l10n),
                            SizedBox(height: spacing.lg),
                            _audio(l10n),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.lg),
                    FilledButton(
                      key: SettingsScreen.saveButton,
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

  // ── the five groups ───────────────────────────────────────────────────────

  Widget _pace(AppLocalizations l10n) => _Group(
    title: l10n.settingsSectionPace,
    children: [
      _segmented(
        label: l10n.speechSecondsLabel,
        description: l10n.settingSpeechSecondsHint,
        values: const [30, 45, 60, 90],
        current: _s.speechSeconds,
        format: l10n.secondsSuffix,
        onPick: (v) => _edit((s) => s.copyWith(speechSeconds: v)),
      ),
      _segmented(
        label: l10n.settingDiscussionSeconds,
        description: l10n.settingDiscussionSecondsHint,
        values: const [180, 300, 420],
        current: _s.discussionSeconds,
        format: (v) => l10n.minutesSuffix(v ~/ 60),
        onPick: (v) => _edit((s) => s.copyWith(discussionSeconds: v)),
      ),
      _Row(
        label: l10n.discussionModeLabel,
        description: l10n.settingDiscussionModeHint,
        controlBelow: true,
        control: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RadioOption(
              label: l10n.discussionStructured,
              value: DiscussionMode.structured,
              groupValue: _s.discussionMode,
              onChanged: (m) => _edit((s) => s.copyWith(discussionMode: m)),
            ),
            SizedBox(height: context.spacing.sm),
            _RadioOption(
              label: l10n.discussionFree,
              value: DiscussionMode.free,
              groupValue: _s.discussionMode,
              onChanged: (m) => _edit((s) => s.copyWith(discussionMode: m)),
            ),
          ],
        ),
      ),
      _switch(
        field: 'pressureCurve',
        label: l10n.settingPressureCurve,
        description: l10n.settingPressureCurveHint,
        value: _s.pressureCurveEnabled,
        onChanged: (v) => _edit((s) => s.copyWith(pressureCurveEnabled: v)),
      ),
    ],
  );

  Widget _information(AppLocalizations l10n) => _Group(
    title: l10n.settingsSectionInformation,
    children: [
      _switch(
        field: 'trace',
        label: l10n.settingTrace,
        description: l10n.settingTraceHint,
        value: _s.traceEnabled,
        onChanged: (v) => _edit((s) => s.copyWith(traceEnabled: v)),
      ),
      _switch(
        field: 'confrontation',
        label: l10n.settingConfrontation,
        description: l10n.settingConfrontationHint,
        value: _s.confrontationEnabled,
        onChanged: (v) => _edit((s) => s.copyWith(confrontationEnabled: v)),
      ),
      // Doc 14 §4.2: default off, and opt-in with a description that says
      // what the ten seconds actually are.
      _switch(
        field: 'openingRound',
        label: l10n.settingOpeningRound,
        description: l10n.settingOpeningRoundHint,
        value: _s.openingRoundEnabled,
        onChanged: (v) => _edit((s) => s.copyWith(openingRoundEnabled: v)),
      ),
      // Online only, and said so rather than silently ignored offline.
      _switch(
        field: 'whisper',
        label: l10n.settingWhisper,
        description: l10n.settingWhisperHint,
        value: _s.whisperEnabled,
        onlineOnly: true,
        onChanged: (v) => _edit((s) => s.copyWith(whisperEnabled: v)),
      ),
    ],
  );

  Widget _reveal(AppLocalizations l10n) => _Group(
    title: l10n.settingsSectionReveal,
    children: [
      _switch(
        field: 'revealVictimRole',
        label: l10n.settingRevealVictimRole,
        description: l10n.settingRevealVictimRoleHint,
        value: _s.revealNightVictimRole,
        onChanged: (v) => _edit((s) => s.copyWith(revealNightVictimRole: v)),
      ),
      _switch(
        field: 'revealWhispers',
        label: l10n.settingRevealWhispers,
        description: l10n.settingRevealWhispersHint,
        value: _s.revealWhisperContent,
        onlineOnly: true,
        onChanged: (v) => _edit((s) => s.copyWith(revealWhisperContent: v)),
      ),
    ],
  );

  Widget _voting(AppLocalizations l10n) => _Group(
    title: l10n.settingsSectionVoting,
    children: [
      _Row(
        label: l10n.dayTieRuleLabel,
        description: '',
        controlBelow: true,
        control: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RadioOption(
              label: l10n.tieRevote,
              value: DayTieRule.revote,
              groupValue: _s.dayTieRule,
              onChanged: (r) => _edit((s) => s.copyWith(dayTieRule: r)),
            ),
            SizedBox(height: context.spacing.sm),
            _RadioOption(
              label: l10n.tieNoElimination,
              value: DayTieRule.noElimination,
              groupValue: _s.dayTieRule,
              onChanged: (r) => _edit((s) => s.copyWith(dayTieRule: r)),
            ),
          ],
        ),
      ),
      _switch(
        field: 'abstain',
        label: l10n.abstainAllowedLabel,
        description: l10n.settingAbstainHint,
        value: _s.abstainAllowed,
        onChanged: (v) => _edit((s) => s.copyWith(abstainAllowed: v)),
      ),
      _switch(
        field: 'openVoting',
        label: l10n.settingOpenVoting,
        description: l10n.settingOpenVotingHint,
        value: _s.openVoting,
        onlineOnly: true,
        onChanged: (v) => _edit((s) => s.copyWith(openVoting: v)),
      ),
    ],
  );

  Widget _audio(AppLocalizations l10n) => _Group(
    title: l10n.settingsSectionAudio,
    children: [
      _switch(
        field: 'muteAll',
        label: l10n.muteAllAudio,
        description: l10n.settingMuteAllHint,
        value: _s.muteAllAudio,
        onChanged: (v) => _edit((s) => s.copyWith(muteAllAudio: v)),
      ),
      // Narration cannot be heard through a master mute, so the switch that
      // would pretend otherwise is disabled rather than silently ignored.
      _switch(
        field: 'narration',
        label: l10n.narrationEnabledLabel,
        description: '',
        value: _s.narrationEnabled && !_s.muteAllAudio,
        onChanged: _s.muteAllAudio
            ? null
            : (v) => _edit((s) => s.copyWith(narrationEnabled: v)),
      ),
      _switch(
        field: 'score',
        label: l10n.scoreEnabledLabel,
        description: '',
        value: _s.scoreEnabled && !_s.muteAllAudio,
        onChanged: _s.muteAllAudio
            ? null
            : (v) => _edit((s) => s.copyWith(scoreEnabled: v)),
      ),
    ],
  );

  Widget _switch({
    required String field,
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool onlineOnly = false,
  }) {
    final l10n = context.l10n;
    return _Row(
      label: label,
      description: onlineOnly
          ? (description.isEmpty
                ? l10n.settingsOnlineOnly
                : '${l10n.settingsOnlineOnly} · $description')
          : description,
      control: Switch(
        key: SettingsScreen.toggle(field),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// One named group of rows, with a rule under its title.
class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: type.title.copyWith(color: colors.accentGold)),
        SizedBox(height: spacing.xs),
        Divider(color: colors.borderSubtle, height: spacing.md),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) ...[
            SizedBox(height: spacing.sm),
            Divider(color: colors.borderSubtle, height: spacing.md),
            SizedBox(height: spacing.sm),
          ],
          children[i],
        ],
      ],
    );
  }
}

/// One setting: a name, its control, and the sentence that explains it.
///
/// The description is not optional and not a tooltip. Doc 14 Part 5: *"a
/// setting nobody understands is a setting nobody uses."*
class _Row extends StatelessWidget {
  final String label;
  final String description;
  final Widget control;

  /// True when the control is wide (a segmented row, a radio group) and belongs
  /// under the label rather than beside it.
  final bool controlBelow;

  const _Row({
    required this.label,
    required this.description,
    required this.control,
    this.controlBelow = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    final title = Text(
      label,
      style: type.body.copyWith(color: colors.textPrimary),
    );
    final hint = description.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              description,
              style: type.caption.copyWith(color: colors.textMuted),
            ),
          );

    if (controlBelow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          hint,
          SizedBox(height: spacing.sm),
          control,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, hint],
          ),
        ),
        SizedBox(width: spacing.sm),
        control,
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
