import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/motion_preference.dart';
import '../../../data/repository_provider.dart';
import '../../../engine/models/match_settings.dart';
import '../../account/account_sheet.dart' show showAccountSheet;
import '../../account/onboarding_account_step.dart'
    show accountsAvailableProvider;
import '../../l10n_ext.dart';
import '../../social/push_toggle.dart';
import '../onboarding/permissions_step.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/legal_documents.dart';
import '../../widgets/settings_kit.dart';
import '../online/rewarded_reward_button.dart';
import '../online/safety_center.dart';
import 'help_center.dart';
import 'setup_draft.dart';

/// Keys for the settings sheet.
abstract final class SettingsSheetKeys {
  static const sheet = ValueKey('settings_sheet');
  static const saved = ValueKey('settings_saved');
  static ValueKey<String> row(String name) => ValueKey('settings_row_$name');
  static const minutesLess = ValueKey('settings_minutes_less');
  static const minutesMore = ValueKey('settings_minutes_more');
}

/// Settings as a deck sheet over Home: sound, the rules every new match
/// starts from, general, and the links. There is no save button; every change
/// is stored the moment it is made and «اتحفظ» says so.
Future<void> showSettingsSheet(BuildContext context) => showDeckSheet<void>(
  context: context,
  title: context.l10n.settingsTitle,
  ruqaa: true,
  body: (_) => const SettingsSheetBody(key: SettingsSheetKeys.sheet),
);

class SettingsSheetBody extends ConsumerStatefulWidget {
  const SettingsSheetBody({super.key});

  @override
  ConsumerState<SettingsSheetBody> createState() => _SettingsSheetBodyState();
}

class _SettingsSheetBodyState extends ConsumerState<SettingsSheetBody> {
  MatchSettings? _s;
  bool _toast = false;
  Timer? _toastTimer;

  // 120 is the Hard preset length; it must be a stop on the stepper.
  static const _discussion = [120, 180, 300, 420];

  /// The stop nearest to [seconds], so a value that is not a stop (an old
  /// save, a preset) still steps both ways from where it is.
  static int _nearestStop(int seconds) {
    var best = 0;
    for (var i = 1; i < _discussion.length; i++) {
      if ((_discussion[i] - seconds).abs() <
          (_discussion[best] - seconds).abs()) {
        best = i;
      }
    }
    return best;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    MatchSettings loaded;
    try {
      loaded = await ref.read(matchRepositoryProvider).loadDefaultSettings();
    } catch (_) {
      loaded = ref.read(setupDraftProvider).settings;
    }
    if (mounted) setState(() => _s = loaded);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _saved() {
    setState(() => _toast = true);
    _toastTimer?.cancel();
    _toastTimer = Timer(SettingsSheetTokens.toast, () {
      if (mounted) setState(() => _toast = false);
    });
  }

  /// One edit: applied to the running app (the draft carries the audio flags
  /// to the director), stored as the new defaults, and acknowledged.
  void _edit(MatchSettings Function(MatchSettings) f) {
    final next = f(_s!);
    setState(() => _s = next);
    ref.read(setupDraftProvider.notifier).setSettings(next);
    unawaited(ref.read(matchRepositoryProvider).saveDefaultSettings(next));
    _saved();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = context.l10n;
    final cur = _s;
    if (cur == null) {
      return const SizedBox(height: IdentityTokens.headerHeight * 2);
    }
    final reduceMotion = ref.watch(reduceMotionPreferenceProvider);
    final index = _nearestStop(cur.discussionSeconds);
    final minutes = cur.discussionSeconds ~/ 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: SettingsSheetTokens.linkMin / 2,
          child: Center(
            child: _SavedToast(shown: _toast, still: _still),
          ),
        ),
        _Group(
          title: l.settingsSectionAudio,
          children: [
            SettingsSwitchRow(
              switchKey: SettingsSheetKeys.row('muteAll'),
              label: l.muteAllAudio,
              hint: l.settingMuteAllHint,
              value: cur.muteAllAudio,
              onChanged: (v) => _edit((x) => x.copyWith(muteAllAudio: v)),
            ),
            SettingsSwitchRow(
              switchKey: SettingsSheetKeys.row('narration'),
              label: l.settingsNarratorOn,
              hint: l.settingsNarratorOnHint,
              value: cur.narrationEnabled && !cur.muteAllAudio,
              onChanged: cur.muteAllAudio
                  ? null
                  : (v) => _edit((x) => x.copyWith(narrationEnabled: v)),
            ),
            SettingsSwitchRow(
              switchKey: SettingsSheetKeys.row('score'),
              label: l.scoreEnabledLabel,
              value: cur.scoreEnabled && !cur.muteAllAudio,
              onChanged: cur.muteAllAudio
                  ? null
                  : (v) => _edit((x) => x.copyWith(scoreEnabled: v)),
            ),
          ],
        ),
        _Group(
          title: l.settingsGroupRules,
          subtitle: l.settingsGroupRulesHint,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.settingsDiscussion,
                    style: DeckTokens.body(
                      context.typography,
                    ).copyWith(color: context.colors.textPrimary),
                  ),
                ),
                _Stepper(
                  lessKey: SettingsSheetKeys.minutesLess,
                  moreKey: SettingsSheetKeys.minutesMore,
                  label: l.minutesSuffix(minutes),
                  onLess: index > 0
                      ? () => _edit(
                          (x) => x.copyWith(
                            discussionSeconds: _discussion[index - 1],
                          ),
                        )
                      : null,
                  onMore: index < _discussion.length - 1
                      ? () => _edit(
                          (x) => x.copyWith(
                            discussionSeconds: _discussion[index + 1],
                          ),
                        )
                      : null,
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: s.sm),
              child: SettingsSegments<bool>(
                label: l.settingsVoteLabel,
                pill: l.settingsOnlineOnly,
                value: cur.openVoting,
                options: [
                  (true, l.settingsVoteOpen, SettingsSheetKeys.row('voteOpen')),
                  (
                    false,
                    l.settingsVoteSecret,
                    SettingsSheetKeys.row('voteSecret'),
                  ),
                ],
                onChanged: (v) => _edit((x) => x.copyWith(openVoting: v)),
              ),
            ),
            SettingsSwitchRow(
              switchKey: SettingsSheetKeys.row('revealDeath'),
              label: l.settingsRevealDeath,
              value: cur.revealNightVictimRole,
              onChanged: (v) =>
                  _edit((x) => x.copyWith(revealNightVictimRole: v)),
            ),
          ],
        ),
        _Group(
          title: l.settingsSectionGeneral,
          children: [
            const LanguagePicker(),
            SettingsSwitchRow(
              switchKey: SettingsSheetKeys.row('reduceMotion'),
              label: l.prefReduceMotion,
              value: reduceMotion,
              onChanged: (v) async {
                final ok = await ref
                    .read(reduceMotionPreferenceProvider.notifier)
                    .set(v);
                if (ok && mounted) _saved();
              },
            ),
          ],
        ),
        _Group(
          title: l.permissionsTitle,
          children: const [PushSettingsRow(), MicrophoneSettingsRow()],
        ),
        _Group(
          children: [
            if (ref.watch(accountsAvailableProvider))
              SettingsLinkRow(
                key: SettingsSheetKeys.row('account'),
                icon: Icons.person_outline,
                label: l.settingsAccountLink,
                onTap: () => showAccountSheet(context),
              ),
            const HelpButton(tile: true),
            const SafetyButton(privacy: true),
            const AdPrivacyButton(),
            const LegalDocuments(),
          ],
        ),
      ],
    );
  }
}

/// A rounded group of rows with a quiet title.
class _Group extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  const _Group({this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    return Padding(
      padding: EdgeInsets.only(bottom: s.sm + s.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DeckTokens.panel,
          borderRadius: BorderRadius.circular(SettingsSheetTokens.groupRadius),
          border: Border.all(color: DeckTokens.line),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  Padding(
                    padding: EdgeInsets.only(top: s.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title!,
                          style: DeckTokens.meta(
                            type,
                          ).copyWith(color: context.colors.textMuted),
                        ),
                        if (subtitle != null)
                          Flexible(
                            child: Text(
                              subtitle!,
                              style: type.caption.copyWith(
                                color: context.colors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(color: DeckTokens.line, height: 1),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final Key lessKey;
  final Key moreKey;
  final String label;
  final VoidCallback? onLess;
  final VoidCallback? onMore;
  const _Stepper({
    required this.lessKey,
    required this.moreKey,
    required this.label,
    required this.onLess,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    Widget button(Key key, IconData icon, VoidCallback? onTap) => IconButton(
      key: key,
      constraints: const BoxConstraints.tightFor(
        width: SettingsSheetTokens.stepperButton,
        height: SettingsSheetTokens.stepperButton,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: DeckTokens.icon),
      color: context.colors.textPrimary,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(lessKey, Icons.remove, onLess),
        SizedBox(
          width: SettingsSheetTokens.stepperValue,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.typography.title.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
        button(moreKey, Icons.add, onMore),
      ],
    );
  }
}

/// «اتحفظ»: fades and rises in beside the title, then leaves. Transform and
/// opacity only; with animations off it simply appears.
class _SavedToast extends StatelessWidget {
  final bool shown;
  final bool still;
  const _SavedToast({required this.shown, required this.still});

  @override
  Widget build(BuildContext context) {
    final duration = still ? Duration.zero : SettingsSheetTokens.toastMove;
    return IgnorePointer(
      child: AnimatedOpacity(
        key: SettingsSheetKeys.saved,
        opacity: shown ? 1 : 0,
        duration: duration,
        child: AnimatedSlide(
          offset: shown ? Offset.zero : const Offset(0, 0.4),
          duration: duration,
          child: Semantics(
            liveRegion: true,
            label: context.l10n.settingsSaved,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DeckTokens.bone,
                borderRadius: BorderRadius.circular(context.radii.button),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing.md,
                  vertical: context.spacing.xs,
                ),
                child: ExcludeSemantics(
                  child: Text(
                    context.l10n.settingsSaved,
                    style: context.typography.caption.copyWith(
                      color: DeckTokens.ground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
