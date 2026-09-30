import '../../widgets/language_picker.dart';
import '../../widgets/legal_documents.dart';
import '../../widgets/setup_entrance.dart';
import 'help_center.dart';
import 'coin_store.dart';
import 'scenario_store.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../online/safety_center.dart';
import '../online/rewarded_reward_button.dart';
import '../../../app/l10n/app_localizations.dart';
import '../../../engine/models/enums.dart'
    show DiscussionMode, DayTieRule, Role;
import '../../../engine/models/match_settings.dart';
import '../../../engine/presets.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/experience_surface.dart';
import '../../widgets/settings_kit.dart';
import '../../economy/web_ads.dart';

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
  /// The lit option is *derived*, never stored: [MatchPreset.identify] asks
  /// the settings themselves which preset they are. So there is no state to
  /// get out of step with the controls, and turning one switch after picking
  /// a preset puts it out for free, because the settings genuinely are not
  /// that preset any more.
  Widget _presetPanel(AppLocalizations l10n) {
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

    return SettingsPanel(
      icon: Icons.style_outlined,
      title: l10n.presetLabel,
      // One line, and it is always there. A description that appears only
      // when an option is lit would make the panel change height under a
      // thumb, and custom is a real answer rather than the absence of one.
      subtitle: current == null
          ? l10n.presetCustom
          : EngineCopy.presetHint(l10n, current),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
          child: SettingsSegments<MatchPreset?>(
            value: current,
            options: [
              for (final preset in offered)
                (
                  preset,
                  EngineCopy.presetName(l10n, preset),
                  SettingsScreen.presetChip(preset),
                ),
            ],
            onChanged: (preset) {
              if (preset != null) _applyPreset(preset);
            },
          ),
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
  }) => SettingsSegments<int>(
    label: label,
    hint: description,
    value: current,
    options: [
      for (final value in values)
        (value, format(value), ValueKey('$label-$value')),
    ],
    onChanged: onPick,
  );

  bool get _isDefaults => widget.playerCount == null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    // From Home this screen is the app's settings: language and sound first,
    // then the rules every new match starts from, then help and privacy.
    // Inside a match setup it is only the rules and the sound: the host is
    // standing up with the table waiting, and the language is not what they
    // came for.
    final rules = [
      _presetPanel(l10n),
      _pace(l10n),
      _information(l10n),
      _reveal(l10n),
      _voting(l10n),
    ];
    final panels = _isDefaults
        ? [
            SettingsPanel(
              icon: Icons.translate,
              title: l10n.settingsSectionGeneral,
              children: const [LanguagePicker()],
            ),
            _audio(l10n),
            SettingsHeading(
              title: l10n.settingsRulesTitle,
              subtitle: l10n.settingsRulesHint,
            ),
            ...rules,
            SettingsPanel(
              icon: Icons.support_agent_outlined,
              title: l10n.settingsSectionMore,
              divided: false,
              children: const [
                CoinStoreButton(tile: true),
                ScenarioStoreButton(tile: true),
                AdPrivacyButton(),
                HelpButton(tile: true),
                SafetyButton(privacy: true),
                LegalDocuments(),
              ],
            ),
          ]
        : [...rules, _audio(l10n)];

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      bottomNavigationBar: kIsWeb && widget.playerCount == null
          ? const WebAdBanner()
          : null,
      body: ExperienceSurface(
        child: SetupEntrance(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        spacing.screenMargin,
                        spacing.lg,
                        spacing.screenMargin,
                        spacing.md,
                      ),
                      child: ScreenHeader(
                        title: l10n.settingsTitle,
                        onBack: widget.onBack,
                      ),
                    ),
                    // A column, not a lazy list: nine panels is not a long
                    // list, and every switch should exist whether or not it
                    // has been scrolled to.
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          spacing.screenMargin,
                          0,
                          spacing.screenMargin,
                          spacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: panels,
                        ),
                      ),
                    ),
                    // The save bar sits on the ground under a hairline, so
                    // the last panel scrolls under something rather than
                    // being cut off mid-row by the button.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceBase,
                        border: Border(
                          top: BorderSide(color: colors.borderSubtle),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(spacing.md),
                        child: FilledButton(
                          key: SettingsScreen.saveButton,
                          onPressed: _onSave,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.accentGold,
                            foregroundColor: colors.surfaceBase,
                            padding: EdgeInsets.symmetric(vertical: spacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radii.button),
                            ),
                          ),
                          child: Text(l10n.save, style: type.title),
                        ),
                      ),
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

  // ── the groups ────────────────────────────────────────────────────────────

  Widget _pace(AppLocalizations l10n) => SettingsPanel(
    icon: Icons.timer_outlined,
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
      SettingsSegments<DiscussionMode>(
        label: l10n.discussionModeLabel,
        hint: l10n.settingDiscussionModeHint,
        value: _s.discussionMode,
        options: [
          (DiscussionMode.structured, l10n.discussionStructured, null),
          (DiscussionMode.free, l10n.discussionFree, null),
        ],
        onChanged: (m) => _edit((s) => s.copyWith(discussionMode: m)),
      ),
      _switch(
        field: 'pressureCurve',
        label: l10n.settingPressureCurve,
        description: l10n.settingPressureCurveHint,
        value: _s.pressureCurveEnabled,
        onChanged: (v) => _edit((s) => s.copyWith(pressureCurveEnabled: v)),
      ),
      _switch(
        field: 'tabletopPresentation',
        label: l10n.settingTabletopPresentation,
        description: l10n.settingTabletopPresentationHint,
        value: _s.tabletopPresentation,
        onChanged: (v) => _edit((s) => s.copyWith(tabletopPresentation: v)),
      ),
    ],
  );

  Widget _information(AppLocalizations l10n) => SettingsPanel(
    icon: Icons.manage_search_outlined,
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

  Widget _reveal(AppLocalizations l10n) => SettingsPanel(
    icon: Icons.visibility_outlined,
    title: l10n.settingsSectionReveal,
    children: [
      _switch(
        field: 'revealVictimRole',
        label: l10n.settingRevealVictimRole,
        description: l10n.settingRevealVictimRoleHint,
        value: _s.revealNightVictimRole,
        onChanged: (v) => _edit((s) => s.copyWith(revealNightVictimRole: v)),
      ),
      // «اكشف محتوى الهمسات بعد المباراة» was here, online-only and read by
      // nothing. It lives in the room settings now (RoomSettingsPanel), where
      // the server honours it (Doc 09 §7, launch audit A4).
    ],
  );

  Widget _voting(AppLocalizations l10n) => SettingsPanel(
    icon: Icons.how_to_vote_outlined,
    title: l10n.settingsSectionVoting,
    children: [
      SettingsSegments<DayTieRule>(
        label: l10n.dayTieRuleLabel,
        value: _s.dayTieRule,
        options: [
          (DayTieRule.revote, l10n.tieRevote, null),
          (DayTieRule.noElimination, l10n.tieNoElimination, null),
        ],
        onChanged: (r) => _edit((s) => s.copyWith(dayTieRule: r)),
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

  Widget _audio(AppLocalizations l10n) => SettingsPanel(
    icon: Icons.volume_up_outlined,
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

  /// Online-only rows are named, not hidden (doc 14 Part 5): a host who
  /// cannot find the whisper switch concludes the app lost it. The note is a
  /// pill beside the name, so the sentence under it stays a sentence.
  Widget _switch({
    required String field,
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool onlineOnly = false,
  }) => SettingsSwitchRow(
    switchKey: SettingsScreen.toggle(field),
    label: label,
    hint: description,
    pill: onlineOnly ? context.l10n.settingsOnlineOnly : null,
    value: value,
    onChanged: onChanged,
  );
}
