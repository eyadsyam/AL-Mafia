import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/intro_gate.dart';
import '../../../data/motion_preference.dart';
import '../../../data/player_profile.dart';
import '../../../data/repository_provider.dart';
import '../../../data/terms_consent.dart';
import '../../../engine/models/player.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/legal_documents.dart';
import '../../widgets/profile_identity.dart';
import '../../widgets/settings_kit.dart';
import '../../widgets/experience_surface.dart';
import '../setup/setup_draft.dart';

/// Holds every route that needs a finished setup: a saved profile and an
/// acceptance of the current terms.
///
/// Inline rather than a redirect, so a deep link (`/join/CODE`) keeps its
/// destination: once setup completes, the same route shows its real screen.
/// An install that already has a profile but predates the terms gets the
/// compact form (terms only), once. A later app build with unchanged terms
/// never asks again.
class SetupRequired extends ConsumerWidget {
  final Widget child;
  const SetupRequired({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (IntroGate.pendingOf(context)) return const _Waiting();
    final profile = ref.watch(playerProfileProvider);
    final terms = ref.watch(termsAcceptanceProvider);
    if (profile.isLoading || terms.isLoading) return const _Waiting();
    if (profile.valueOrNull == null) {
      return const FirstRunScreen(key: FirstRunScreen.screenKey);
    }
    if (terms.valueOrNull?.current != true) {
      return const FirstRunScreen(
        key: FirstRunScreen.screenKey,
        termsOnly: true,
      );
    }
    return child;
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Language → name and avatar → preferences → 18+ and terms → continue.
///
/// Four short chapters with one decision at a time. Nothing asks for a birth date, phone or email, and the
/// microphone is asked for only when voice is first used.
class FirstRunScreen extends ConsumerStatefulWidget {
  /// Existing installs that have a profile: only the terms and 18+ rows.
  final bool termsOnly;
  const FirstRunScreen({super.key, this.termsOnly = false});

  static const screenKey = ValueKey('first_run');
  static const nameKey = ValueKey('first_run_name');
  static const adultKey = ValueKey('first_run_adult');
  static const termsKey = ValueKey('first_run_terms');
  static const termsLinkKey = ValueKey('first_run_terms_link');
  static const privacyLinkKey = ValueKey('first_run_privacy_link');
  static const soundKey = ValueKey('first_run_sound');
  static const musicKey = ValueKey('first_run_music');
  static const motionKey = ValueKey('first_run_motion');
  static const continueKey = ValueKey('first_run_continue');
  static const nextKey = ValueKey('first_run_next');
  static const backKey = ValueKey('first_run_back');
  static const failedKey = ValueKey('first_run_failed');

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends ConsumerState<FirstRunScreen> {
  late final TextEditingController _name;
  PlayerGender _gender = PlayerGender.unspecified;
  late bool _sound;
  late bool _music;
  late bool _reduceMotion;
  bool _adult = false;
  bool _terms = false;
  bool _saving = false;
  bool _failed = false;
  int _step = 0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerProfileProvider).valueOrNull;
    _name = TextEditingController(text: profile?.name ?? '');
    _gender = profile?.gender ?? PlayerGender.unspecified;
    final settings = ref.read(setupDraftProvider).settings;
    _sound = !settings.muteAllAudio;
    _music = settings.scoreEnabled;
    _reduceMotion = ref.read(reduceMotionPreferenceProvider);
    // A previous acceptance of an older version leaves the 18+ answer; the
    // terms box is always unticked.
    _adult = ref.read(termsAcceptanceProvider).valueOrNull?.adult ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _profileReady =>
      widget.termsOnly ||
      (_name.text.trim().isNotEmpty && _gender != PlayerGender.unspecified);

  bool get _ready => _profileReady && _adult && _terms && !_saving;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      if (!widget.termsOnly) {
        await _savePreferences();
        await ref
            .read(playerProfileProvider.notifier)
            .save(PlayerProfile(name: _name.text.trim(), gender: _gender));
      }
      // Last, and required: the gate opens when this lands.
      await ref.read(termsAcceptanceProvider.notifier).accept(adult: _adult);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Best effort: a preference that fails to save is still editable in
  /// Settings, and must not hold a new player at the door.
  Future<void> _savePreferences() async {
    try {
      final draft = ref.read(setupDraftProvider.notifier);
      final settings = ref
          .read(setupDraftProvider)
          .settings
          .copyWith(muteAllAudio: !_sound, scoreEnabled: _music);
      draft.setSettings(settings);
      await ref.read(matchRepositoryProvider).saveDefaultSettings(settings);
    } catch (_) {}
    await ref.read(reduceMotionPreferenceProvider.notifier).set(_reduceMotion);
  }

  void _move(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = context.l10n;
    final step = widget.termsOnly ? 3 : _step;
    final titles = [
      l.setupWelcomeTitle,
      l.arrivalIdentityTitle,
      l.setupPreferencesTitle,
      l.arrivalPactTitle,
    ];
    final hints = [
      l.arrivalWelcomeHint,
      l.arrivalIdentityHint,
      l.setupPreferencesHint,
      l.setupAdultHint,
    ];
    final art = [
      ExperienceArt.invitation,
      ExperienceArt.invitation,
      ExperienceArt.council,
      ExperienceArt.pact,
    ];
    return PopScope(
      canPop: widget.termsOnly || _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving && _step > 0) _move(_step - 1);
      },
      child: Scaffold(
        body: ExperienceSurface(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: s.maxContentWidth),
                child: Column(
                  children: [
                    if (!widget.termsOnly)
                      Padding(
                        padding: EdgeInsets.all(s.md),
                        child: Row(
                          children: [
                            if (_step > 0)
                              IconButton(
                                key: FirstRunScreen.backKey,
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                                onPressed: _saving
                                    ? null
                                    : () => _move(_step - 1),
                                icon: const BackButtonIcon(),
                              ),
                            Expanded(
                              child: Semantics(
                                label: l.arrivalStep(_step + 1, 4),
                                child: Row(
                                  children: List.generate(
                                    4,
                                    (i) => Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: s.xs,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: i <= _step ? 1 : 0,
                                          color: context.colors.accentGold,
                                          backgroundColor:
                                              context.colors.borderSubtle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: EdgeInsets.all(s.screenMargin),
                        child: Material(
                          type: MaterialType.transparency,
                          child: AnimatedSwitcher(
                            duration:
                                _reduceMotion ||
                                    MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : context.motion.standard,
                            child: Column(
                              key: ValueKey(step),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!widget.termsOnly &&
                                    MediaQuery.viewInsetsOf(context).bottom ==
                                        0) ...[
                                  ExperienceHero(
                                    asset: art[step],
                                    compact: step != 0,
                                  ),
                                  SizedBox(height: s.lg),
                                ],
                                Semantics(
                                  header: true,
                                  child: Text(
                                    widget.termsOnly
                                        ? l.termsUpdatedTitle
                                        : titles[step],
                                    style: context.typography.headline,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(height: s.sm),
                                Text(
                                  widget.termsOnly
                                      ? l.termsUpdatedHint
                                      : hints[step],
                                  style: context.typography.body,
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: s.lg),
                                if (step == 0) const LanguagePicker(),
                                if (step == 1)
                                  ProfileIdentityFields(
                                    name: _name,
                                    nameKey: FirstRunScreen.nameKey,
                                    gender: _gender,
                                    avatarDiameter: s.xl * 2,
                                    onGender: (v) =>
                                        setState(() => _gender = v),
                                    onNameChanged: (_) => setState(() {}),
                                    onSubmitted: (_) {
                                      if (_profileReady) _move(2);
                                    },
                                  ),
                                // The same rows the settings screen uses, so
                                // the first settings a player meets look like
                                // the ones they will find again later.
                                if (step == 2)
                                  _PreferencesPanel(
                                    children: [
                                      SettingsSwitchRow(
                                        switchKey: FirstRunScreen.soundKey,
                                        label: l.prefSound,
                                        value: _sound,
                                        onChanged: (v) =>
                                            setState(() => _sound = v),
                                      ),
                                      SettingsSwitchRow(
                                        switchKey: FirstRunScreen.musicKey,
                                        label: l.prefMusic,
                                        value: _music,
                                        onChanged: _sound
                                            ? (v) => setState(() => _music = v)
                                            : null,
                                      ),
                                      SettingsSwitchRow(
                                        switchKey: FirstRunScreen.motionKey,
                                        label: l.prefReduceMotion,
                                        value: _reduceMotion,
                                        onChanged: (v) =>
                                            setState(() => _reduceMotion = v),
                                      ),
                                    ],
                                  ),
                                if (step == 3) ...[
                                  CheckboxListTile(
                                    key: FirstRunScreen.adultKey,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    value: _adult,
                                    onChanged: _saving
                                        ? null
                                        : (v) => setState(
                                            () => _adult = v ?? false,
                                          ),
                                    title: Text(l.setupAdultConfirm),
                                  ),
                                  _TermsRow(
                                    value: _terms,
                                    onChanged: (v) {
                                      if (!_saving) setState(() => _terms = v);
                                    },
                                  ),
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: TextButton(
                                      key: FirstRunScreen.privacyLinkKey,
                                      onPressed: () =>
                                          showPrivacyDocument(context),
                                      child: Text(l.privacyLinkLabel),
                                    ),
                                  ),
                                  if (_failed)
                                    Text(
                                      key: FirstRunScreen.failedKey,
                                      l.profileSaveFailed,
                                      style: context.typography.body.copyWith(
                                        color: context.colors.accentCrimson,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(s.screenMargin),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: step == 3
                              ? FirstRunScreen.continueKey
                              : FirstRunScreen.nextKey,
                          onPressed: step == 3
                              ? (_ready ? _submit : null)
                              : (step != 1 || _profileReady)
                              ? () => _move(step + 1)
                              : null,
                          child: Text(
                            _saving ? l.arrivalSaving : l.continueAction,
                          ),
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
}

/// A raised panel of rows, the settings kit's surface without its heading
/// (the page title already names it).
class _PreferencesPanel extends StatelessWidget {
  final List<Widget> children;
  const _PreferencesPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(context.radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(color: colors.borderSubtle, height: spacing.sm + 1),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// «قرأت الشروط والأحكام وأوافق عليها» with an unticked box. The underlined
/// words open the document; the box is the only thing that accepts.
class _TermsRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _TermsRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final link = context.typography.body.copyWith(
      color: context.colors.accentGold,
      decoration: TextDecoration.underline,
      decorationColor: context.colors.accentGold,
    );
    return Row(
      children: [
        Checkbox(
          key: FirstRunScreen.termsKey,
          value: value,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l.termsAcceptPrefix, style: context.typography.body),
              Semantics(
                link: true,
                child: InkWell(
                  key: FirstRunScreen.termsLinkKey,
                  onTap: () => showTermsDocument(context),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
                    child: Text(l.termsAcceptLink, style: link),
                  ),
                ),
              ),
              Text(l.termsAcceptSuffix, style: context.typography.body),
            ],
          ),
        ),
      ],
    );
  }
}
