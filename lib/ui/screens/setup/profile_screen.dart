import '../../widgets/mafia_kit.dart';
import '../../widgets/case_file.dart';
import '../../widgets/deck/seat_card.dart';
import '../../widgets/deck/deck_buttons.dart';
import '../../widgets/player_avatar.dart';
import '../../economy/cosmetic_paint.dart' show CosmeticFrameRing;
import '../../fun/founder_badge.dart';
import '../../fun/character_dossiers.dart';
import '../../fun/loaded_capabilities.dart';
import '../../widgets/setup_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player_profile.dart';
import '../../../engine/models/player.dart';
import '../../economy/council_hub.dart' show LeaderboardVisibilitySwitch;
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/experience_surface.dart';
import '../../widgets/profile_identity.dart';
import '../../economy/waiting_banner.dart';
import '../../account/profile_panels.dart';
import '../../economy/my_cosmetics.dart';
import '../../social/titles_partner.dart';
import '../../social/directory_settings.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;

  /// Where back goes. Null only where there is nowhere to go back to (the
  /// online door asking for a profile it does not have yet).
  final VoidCallback? onBack;

  /// Opens the Four Dossiers from the portrait strip.
  final VoidCallback? onCharacters;

  /// Opens the full match log from the «السجل» tab.
  final VoidCallback? onHistory;
  const ProfileScreen({
    super.key,
    this.onSaved,
    this.onBack,
    this.onCharacters,
    this.onHistory,
  });

  static const Key nameKey = ValueKey('profile_name');
  static const Key saveKey = ValueKey('profile_save');
  static const Key fileKey = ValueKey('profile_file');
  static const Key stampKey = ValueKey('profile_stamp');
  static const Key historyKey = ValueKey('profile_history');
  static Key tabKey(String id) => ValueKey('profile_tab_$id');

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  PlayerGender _gender = PlayerGender.unspecified;
  bool _saving = false;
  bool _failed = false;

  /// Whether the player has touched the form. A saved profile that arrives
  /// after the first frame fills it only while it is untouched.
  bool _edited = false;

  /// The open tab of the file: characters, titles or history.
  String? _tab;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _adopt(ref.read(playerProfileProvider).valueOrNull);
  }

  void _adopt(PlayerProfile? profile) {
    if (profile == null || _edited) return;
    _name.text = profile.name;
    _gender = profile.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref
          .read(playerProfileProvider.notifier)
          .save(PlayerProfile(name: _name.text.trim(), gender: _gender));
      if (mounted) widget.onSaved?.call();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Editing sits on the case file's dark desk; the first-run question keeps
  /// the experience backdrop.
  Widget _surface({required Widget child}) => widget.onBack != null
      ? ColoredBox(color: CaseFileTokens.desk, child: child)
      : ExperienceSurface(child: child);

  void _setGender(PlayerGender v) => setState(() {
    _edited = true;
    _gender = v;
  });

  /// The player's file: the photo (the avatar on a Mafia seat card), a stamp
  /// over it, and the identity fields on the paper.
  Widget _folder(BuildContext context, MyCosmetics mine) {
    final s = context.spacing;
    final l = context.l10n;
    return CaseFilePaper(
      key: ProfileScreen.fileKey,
      padding: EdgeInsets.all(s.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Transform.rotate(
                angle: ProfileTokens.photoTilt,
                child: SizedBox.fromSize(
                  size: ProfileTokens.photo,
                  child: SeatCardFrame(
                    child: Center(
                      child: CosmeticFrameRing(
                        frame: mine.frame,
                        diameter: ProfileTokens.photoAvatar,
                        child: PlayerAvatar(
                          name: _name.text,
                          gender: _gender,
                          diameter: ProfileTokens.photoAvatar,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: ProfileTokens.stampTop,
                end: 0,
                child: CaseStamp(
                  l.fileStampSuspect,
                  key: ProfileScreen.stampKey,
                  angle: CaseFileTokens.stampTilt,
                ),
              ),
            ],
          ),
          SizedBox(height: s.md),
          ProfileIdentityFields(
            name: _name,
            nameKey: ProfileScreen.nameKey,
            gender: _gender,
            avatarDiameter: ProfileTokens.photoAvatar,
            showAvatar: false,
            frame: mine.frame,
            plate: mine.plate,
            onGender: _saving ? null : _setGender,
            onNameChanged: (_) => setState(() => _edited = true),
            onSubmitted: (_) {
              if (_name.text.trim().isNotEmpty &&
                  _gender != PlayerGender.unspecified &&
                  !_saving) {
                _save();
              }
            },
          ),
        ],
      ),
    );
  }

  /// «شخصياتي · ألقابي · السجل»: paper tabs, each over the content the
  /// profile already had, now under its own divider.
  Widget _tabs(BuildContext context, bool bondsEnabled) {
    final l = context.l10n;
    final ids = [if (bondsEnabled) 'characters', 'titles', 'history'];
    final open = ids.contains(_tab) ? _tab! : ids.first;
    final labels = {
      'characters': l.fileTabCharacters,
      'titles': l.fileTabTitles,
      'history': l.fileTabHistory,
    };
    final s = context.spacing;
    final Widget content = switch (open) {
      'characters' => CharacterDossiers(onOpen: widget.onCharacters),
      'titles' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EquippedTitleLine(),
          const TitleEquipList(),
          SizedBox(height: s.sm),
          const PartnerPicker(),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ProfileStats(),
          if (widget.onHistory != null) ...[
            SizedBox(height: s.sm),
            RimButton(
              key: ProfileScreen.historyKey,
              label: l.history,
              onPressed: widget.onHistory,
            ),
          ],
        ],
      ),
    };
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CaseFileTabs(
          labels: [for (final id in ids) labels[id]!],
          selected: ids.indexOf(open),
          tabKey: (i) => ProfileScreen.tabKey(ids[i]),
          onSelect: (i) => setState(() => _tab = ids[i]),
        ),
        CaseFileSheet(
          child: AnimatedSwitcher(
            duration: still ? Duration.zero : DeckTokens.slide,
            child: KeyedSubtree(key: ValueKey(open), child: content),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerProfileProvider, (_, next) {
      setState(() => _adopt(next.valueOrNull));
    });
    final s = context.spacing;
    final l = context.l10n;
    final existing = ref.watch(playerProfileProvider).valueOrNull != null;
    final bondsEnabled = loadedCapabilities(ref)?.fun.characterBonds == true;
    // Store truth: what this player equipped, on their own avatar and name.
    final mine = ref.watch(myCosmeticsProvider);
    final ready =
        !_saving &&
        _name.text.trim().isNotEmpty &&
        _gender != PlayerGender.unspecified;
    return MafiaScaffold(
      backgroundColor: widget.onBack != null ? CaseFileTokens.desk : null,
      body: _surface(
        child: SetupEntrance(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: s.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.onBack != null)
                      Padding(
                        padding: EdgeInsets.all(s.sm),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: BackAction(onPressed: widget.onBack!),
                        ),
                      ),
                    // Phase 108: only when editing (never the first-run
                    // profile), at the top, far from the Save button.
                    if (widget.onBack != null)
                      const WaitingBanner(placement: BannerPlacement.profile),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(s.screenMargin),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.onBack == null &&
                                MediaQuery.viewInsetsOf(context).bottom ==
                                    0) ...[
                              // The first-run identity page's art: this is
                              // the same question, asked again later.
                              const ExperienceHero(
                                asset: ExperienceArt.invitation,
                                compact: true,
                              ),
                              SizedBox(height: s.lg),
                            ],
                            Semantics(
                              header: true,
                              child: Text(
                                l.profileTitle,
                                style: widget.onBack != null
                                    ? StoryTokens.ruqaa(
                                        context.typography.headline,
                                      )
                                    : context.typography.headline,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: s.sm),
                            Text(
                              l.profileHint,
                              style: context.typography.body,
                              textAlign: TextAlign.center,
                            ),
                            // Phase 109: the permanent Founder badge, once
                            // earned. Editing only, like the banner above.
                            if (widget.onBack != null)
                              Padding(
                                padding: EdgeInsets.only(top: s.sm),
                                child: const Center(child: FounderBadge()),
                              ),
                            SizedBox(height: s.lg),
                            if (widget.onBack == null) ...[
                              ProfileIdentityFields(
                                name: _name,
                                nameKey: ProfileScreen.nameKey,
                                gender: _gender,
                                avatarDiameter: s.xl * 2,
                                frame: mine.frame,
                                plate: mine.plate,
                                onGender: _saving ? null : _setGender,
                                onNameChanged: (_) =>
                                    setState(() => _edited = true),
                                onSubmitted: (_) {
                                  if (ready) _save();
                                },
                              ),
                              // Phase 107: the player's leaderboard choice,
                              // shown only while the board exists.
                              const LeaderboardVisibilitySwitch(),
                            ] else ...[
                              _folder(context, mine),
                              SizedBox(height: s.md),
                              _tabs(context, bondsEnabled),
                              SizedBox(height: s.lg),
                              const AccountCard(),
                              const LeaderboardVisibilitySwitch(),
                              // Invites: the handle others search for, and
                              // the two directory switches.
                              const DirectorySettings(),
                            ],
                            if (_failed)
                              Text(
                                l.profileSaveFailed,
                                style: context.typography.body.copyWith(
                                  color: context.colors.accentCrimson,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(s.screenMargin),
                      child: FilledButton(
                        key: ProfileScreen.saveKey,
                        onPressed: ready ? _save : null,
                        // An edit is saved; a first profile moves on.
                        child: Text(existing ? l.save : l.continueAction),
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
