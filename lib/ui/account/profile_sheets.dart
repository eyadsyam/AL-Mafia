import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player_profile.dart';
import '../../engine/models/player.dart' show PlayerGender;
import '../economy/council_hub.dart' show LeaderboardVisibilitySwitch;
import '../economy/my_cosmetics.dart';
import '../fun/character_dossiers.dart';
import '../fun/loaded_capabilities.dart';
import '../l10n_ext.dart';
import '../screens/setup/player_name.dart';
import '../screens/setup/profile_screen.dart';
import '../social/titles_partner.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/deck/deck_buttons.dart';
import '../widgets/deck/deck_form_sheet.dart';
import '../widgets/profile_identity.dart';
import 'profile_save.dart';

/// «غيّر الاسم أو الشخصية»: the name and the way the app addresses the player,
/// and who may see them on the board. Saving closes the sheet.
Future<void> showIdentitySheet(BuildContext context, {VoidCallback? onSaved}) =>
    showDeckFormSheet<void>(
      context: context,
      builder: (_) => IdentityEditSheet(onSaved: onSaved),
    );

class IdentityEditSheet extends ConsumerStatefulWidget {
  /// Called after the profile is saved and the sheet has closed.
  final VoidCallback? onSaved;
  const IdentityEditSheet({super.key, this.onSaved});

  @override
  ConsumerState<IdentityEditSheet> createState() => _IdentityEditSheetState();
}

class _IdentityEditSheetState extends ConsumerState<IdentityEditSheet> {
  final TextEditingController _name = TextEditingController();
  PlayerGender _gender = PlayerGender.unspecified;
  bool _saving = false;
  bool _failed = false;
  bool _refused = false;

  /// Whether the player has touched the form. A saved profile that arrives
  /// after the first frame fills it only while it is untouched.
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    _adopt(ref.read(playerProfileProvider).valueOrNull);
  }

  void _adopt(PlayerProfile? saved) {
    if (saved == null || _edited) return;
    _name.text = saved.name;
    _gender = saved.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready =>
      !_saving &&
      cleanPlayerName(_name.text).isNotEmpty &&
      _gender != PlayerGender.unspecified;

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
    if (result == ProfileSaveResult.saved) {
      Navigator.of(context).pop();
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerProfileProvider, (_, next) {
      setState(() => _adopt(next.valueOrNull));
    });
    final s = context.spacing;
    final l = context.l10n;
    final colors = context.colors;
    final mine = ref.watch(myCosmeticsProvider);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // On its side the title gives its room to the form: the name and the
    // address sit side by side above «حفظ».
    final sideBySide =
        MediaQuery.sizeOf(context).width >= DeckTokens.twoColumnFrom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!keyboardOpen && !sideBySide)
          Padding(
            padding: EdgeInsets.fromLTRB(s.md, s.sm, s.md, s.sm),
            child: Semantics(
              header: true,
              child: Text(
                l.profileTitle,
                style: context.typography.headline.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
        Flexible(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(s.md, s.sm, s.md, s.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileIdentityFields(
                  name: _name,
                  nameKey: ProfileScreen.nameKey,
                  gender: _gender,
                  avatarDiameter: ProfileTokens.identityAvatar,
                  showAvatar: false,
                  sideBySide: sideBySide,
                  frame: mine.frame,
                  plate: mine.plate,
                  onGender: _saving
                      ? null
                      : (v) => setState(() {
                          _edited = true;
                          _gender = v;
                        }),
                  onNameChanged: (_) => setState(() => _edited = true),
                  onSubmitted: (_) {
                    if (_ready) _save();
                  },
                ),
                // The player's leaderboard choice, shown only while the board
                // exists.
                const LeaderboardVisibilitySwitch(),
                if (_failed || _refused)
                  Padding(
                    padding: EdgeInsets.only(top: s.sm),
                    child: Text(
                      _refused ? l.onlineNameNotAllowed : l.profileSaveFailed,
                      style: context.typography.body.copyWith(
                        color: colors.accentCrimson,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(s.md, s.xs, s.md, s.md),
          child: BoneButton(
            key: ProfileScreen.saveKey,
            label: l.save,
            onPressed: _ready ? _save : null,
          ),
        ),
      ],
    );
  }
}

/// «ألقابي»: the titles to wear, the Partner to bond with, and the way into
/// the four characters' files.
Future<void> showTitlesSheet(
  BuildContext context, {
  VoidCallback? onCharacters,
}) => showDeckFormSheet<void>(
  context: context,
  builder: (_) => TitlesSheet(onCharacters: onCharacters),
);

class TitlesSheet extends ConsumerWidget {
  final VoidCallback? onCharacters;
  const TitlesSheet({super.key, this.onCharacters});

  static const sheetKey = ValueKey('titles_sheet');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spacing;
    final l = context.l10n;
    final colors = context.colors;
    final caps = loadedCapabilities(ref);
    final bondsEnabled = caps?.fun.characterBonds == true;
    final hasTitles = caps?.titles ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: sheetKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(s.md, s.sm, s.md, s.sm),
          child: Semantics(
            header: true,
            child: Text(
              l.fileTabTitles,
              style: context.typography.headline.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(s.md, 0, s.md, s.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasTitles) ...[
                  const EquippedTitleLine(),
                  const TitleEquipList(),
                  SizedBox(height: s.sm),
                ],
                const PartnerPicker(),
                if (bondsEnabled)
                  CharacterDossiers(
                    onOpen: onCharacters == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onCharacters!();
                          },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
