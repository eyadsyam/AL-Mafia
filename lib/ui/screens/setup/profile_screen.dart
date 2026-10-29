import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player_profile.dart';
import '../../../engine/models/player.dart';
import '../../account/onboarding_account_step.dart'
    show accountsAvailableProvider;
import '../../account/profile_panels.dart';
import '../../account/profile_save.dart';
import '../../account/profile_sheets.dart';
import '../../economy/council_hub.dart' show LeaderboardVisibilitySwitch;
import '../../economy/my_cosmetics.dart';
import '../../economy/wallet.dart' show walletProvider;
import '../../economy/waiting_banner.dart';
import '../../fun/founder_badge.dart';
import '../../fun/loaded_capabilities.dart';
import '../../l10n_ext.dart';
import '../../social/friends.dart';
import '../../social/titles_partner.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/experience_surface.dart';
import '../../widgets/mafia_kit.dart';
import '../../widgets/profile_identity.dart';
import '../../widgets/setup_entrance.dart';
import '../online/online_session.dart' show SupabaseConfig;
import 'player_name.dart';

/// The player's page. First run (no [onBack]) is the one question: a name and
/// how to be addressed. After that it is who you are, three real numbers, and
/// four rows (friends, account, titles, history); each of the first three
/// opens a sheet from the bottom, history is the full match log.
class ProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;

  /// Where back goes. Null only where there is nowhere to go back to (the
  /// online door asking for a profile it does not have yet).
  final VoidCallback? onBack;

  /// Opens the Four Dossiers from the titles sheet.
  final VoidCallback? onCharacters;

  /// Opens the full match log from the «السجل» row.
  final VoidCallback? onHistory;

  /// Joins a room by its code (a friend's open lobby, an invite). Without it
  /// the friends row is not drawn: there would be nowhere to go.
  final ValueChanged<String>? onJoinRoom;
  const ProfileScreen({
    super.key,
    this.onSaved,
    this.onBack,
    this.onCharacters,
    this.onHistory,
    this.onJoinRoom,
  });

  static const Key nameKey = ValueKey('profile_name');
  static const Key saveKey = ValueKey('profile_save');
  static const Key historyKey = ValueKey('profile_history');
  static const Key friendsKey = ValueKey('profile_friends');
  static const Key titlesKey = ValueKey('profile_titles');

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  PlayerGender _gender = PlayerGender.unspecified;
  bool _saving = false;
  bool _failed = false;

  /// The server refused the name (it is not saved).
  bool _refused = false;

  /// Whether the player has touched the form. A saved profile that arrives
  /// after the first frame fills it only while it is untouched.
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _adopt(ref.read(playerProfileProvider).valueOrNull);
    // The coins on the page are the wallet's own number; ask for it once,
    // never blocking the page on it.
    if (widget.onBack != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            SupabaseConfig.isConfigured &&
            ref.read(walletProvider).valueOrNull == null) {
          unawaited(ref.read(walletProvider.notifier).refresh());
        }
      });
    }
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
      _refused = false;
    });
    final result = await saveProfileDraft(ref, _name.text, _gender);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _refused = result == ProfileSaveResult.refused;
      _failed = result == ProfileSaveResult.failed;
    });
    if (result == ProfileSaveResult.saved) widget.onSaved?.call();
  }

  /// Editing sits on Home's ground; the first-run question keeps the
  /// experience backdrop.
  Widget _surface({required Widget child}) => widget.onBack != null
      ? ColoredBox(color: DeckTokens.ground, child: child)
      : ExperienceSurface(child: child);

  void _setGender(PlayerGender v) => setState(() {
    _edited = true;
    _gender = v;
  });

  /// The rows under the numbers. A row is drawn only when what is behind it
  /// exists in this build and for this player.
  List<Widget> _rows(BuildContext context) {
    final l = context.l10n;
    final caps = loadedCapabilities(ref);
    final accounts = ref.watch(accountsAvailableProvider);
    final bondsEnabled = caps?.fun.characterBonds == true;
    final friendsState = ref.exists(friendsProvider)
        ? ref.watch(friendsProvider).valueOrNull
        : null;
    final hub = ref.exists(titleHubProvider)
        ? ref.watch(titleHubProvider).valueOrNull
        : null;
    final last = ref.watch(profileLastMatchProvider).valueOrNull;
    final now = ref.watch(profileClockProvider)();
    final onJoin = widget.onJoinRoom;
    return [
      if (onJoin != null && accounts && caps?.friends != false)
        ProfileRow(
          key: ProfileScreen.friendsKey,
          title: l.friendsSheetTitle,
          badge: friendsState?.incoming.length ?? 0,
          meta: friendsState == null
              ? null
              : l.profileFriendsCount(friendsState.friends.length),
          onTap: () => showFriendsSheet(context, onJoin: onJoin),
        ),
      const AccountCard(),
      if (bondsEnabled || (caps?.titles ?? false) || (caps?.partner ?? false))
        ProfileRow(
          key: ProfileScreen.titlesKey,
          title: l.fileTabTitles,
          meta: hub == null || !hub.enabled ? null : '${hub.owned.length}',
          onTap: () =>
              showTitlesSheet(context, onCharacters: widget.onCharacters),
        ),
      if (widget.onHistory != null)
        ProfileRow(
          key: ProfileScreen.historyKey,
          title: l.history,
          meta: lastMatchLine(context, last, now),
          onTap: widget.onHistory,
        ),
    ];
  }

  /// Whether the window is wide enough for two panes (a phone on its side).
  bool get _twoPane =>
      widget.onBack != null &&
      MediaQuery.sizeOf(context).width >= DeckTokens.twoColumnFrom;

  Widget _home(BuildContext context) {
    final s = context.spacing;
    final rows = _rows(context);
    final who = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileIdentityHeader(
          onEdit: () => showIdentitySheet(context, onSaved: widget.onSaved),
        ),
        // The permanent Founder badge, once earned.
        const Center(child: FounderBadge()),
        SizedBox(height: s.md),
        const ProfileStats(),
      ],
    );
    if (_twoPane) {
      // On its side: who you are on one side, the rows on the other, all in
      // view at once.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: who),
          SizedBox(width: s.lg),
          Expanded(
            child: rows.isEmpty
                ? const SizedBox.shrink()
                : ProfileRowList(rows: rows),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        who,
        SizedBox(height: s.md),
        if (rows.isNotEmpty) ProfileRowList(rows: rows),
      ],
    );
  }

  /// The first-run question: a name and how to be addressed.
  Widget _firstRun(BuildContext context, bool ready) {
    final s = context.spacing;
    final l = context.l10n;
    final mine = ref.watch(myCosmeticsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
          // The first-run identity page's art: this is the same question,
          // asked again later.
          const ExperienceHero(asset: ExperienceArt.invitation, compact: true),
          SizedBox(height: s.lg),
        ],
        Semantics(
          header: true,
          child: Text(
            l.profileTitle,
            style: context.typography.headline,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: s.sm),
        Text(
          l.profileHint,
          style: context.typography.body,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: s.lg),
        ProfileIdentityFields(
          name: _name,
          nameKey: ProfileScreen.nameKey,
          gender: _gender,
          avatarDiameter: s.xl * 2,
          frame: mine.frame,
          plate: mine.plate,
          onGender: _saving ? null : _setGender,
          onNameChanged: (_) => setState(() => _edited = true),
          onSubmitted: (_) {
            if (ready) _save();
          },
        ),
        // The player's leaderboard choice, shown only while the board exists.
        const LeaderboardVisibilitySwitch(),
        if (_failed || _refused)
          Text(
            _refused ? l.onlineNameNotAllowed : l.profileSaveFailed,
            style: context.typography.body.copyWith(
              color: context.colors.accentCrimson,
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
    final editing = widget.onBack != null;
    final ready =
        !_saving &&
        cleanPlayerName(_name.text).isNotEmpty &&
        _gender != PlayerGender.unspecified;
    return MafiaScaffold(
      backgroundColor: editing ? DeckTokens.ground : null,
      body: _surface(
        child: SetupEntrance(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _twoPane
                      ? DeckTokens.twoPaneMaxWidth
                      : s.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (editing) ...[
                      Padding(
                        padding: EdgeInsets.all(s.sm),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: BackAction(onPressed: widget.onBack!),
                        ),
                      ),
                      // Only when editing (never the first-run profile), at
                      // the top, far from any save button.
                      const WaitingBanner(placement: BannerPlacement.profile),
                    ],
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(s.screenMargin),
                        child: editing
                            ? _home(context)
                            : _firstRun(context, ready),
                      ),
                    ),
                    if (!editing)
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
