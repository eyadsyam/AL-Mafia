import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../../engine/models/enums.dart' show Role;
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/textured_surface.dart';

/// The rules, short enough to actually be read.
///
/// ## Shape
///
/// Six sections — goal, roles, day, night, winning, tips — each a heading and
/// one short panel. That is the shape a host needs while five people wait for
/// them to finish reading: skimmable, in the order the game happens, nothing
/// that requires navigating.
///
/// An earlier version was eight numbered sections of full paragraphs. It was
/// accurate and nobody would ever have read it. Everything it said that the
/// game does not teach on its own has survived into the tips.
///
/// ## No icons
///
/// No emoji and no Material glyphs anywhere on this screen. The only pictures
/// are the four role emblems from `assets/icons/`, which are the same marks
/// painted into the corners of the cards — so a player who has seen a card
/// recognises the row, and the rules and the deck look like they came from one
/// place. A stock magnifying-glass next to "المحقق" would be a second, worse
/// visual language competing with the one the app already has.
class HowToPlayScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onStartMatch;

  const HowToPlayScreen({
    super.key,
    required this.onBack,
    required this.onStartMatch,
  });

  static const Key startButton = ValueKey('how_to_play_start');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            // Prose has a readable measure regardless of window width. Without
            // this the lines run the full width of a tablet and become
            // unreadable in a way that looks like nobody checked.
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(title: l10n.howToPlayTitle, onBack: onBack),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        spacing.screenMargin,
                        0,
                        spacing.screenMargin,
                        spacing.xxl,
                      ),
                      children: [
                        PaperPanel(
                          child: Padding(
                            padding: EdgeInsets.all(spacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.onboardingStoryTitle,
                                  style: context.typography.title.emphasised
                                      .copyWith(color: colors.accentGold),
                                ),
                                SizedBox(height: spacing.sm),
                                Text(
                                  l10n.onboardingStoryBody,
                                  style: context.typography.body.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: spacing.xl),
                        _Section(
                          title: l10n.rulesGoalTitle,
                          body: l10n.rulesGoalBody,
                        ),
                        _RolesSection(title: l10n.rulesRolesTitle),
                        _Section(
                          title: l10n.rulesDayTitle,
                          body: l10n.rulesDayBody,
                        ),
                        _Section(
                          title: l10n.rulesNightTitle,
                          body: l10n.rulesNightBody,
                        ),
                        _Section(
                          title: l10n.rulesWinTitle,
                          body: l10n.rulesWinBody,
                        ),
                        // Task 11c — the four things doc 12 §9 says a
                        // first-time online player has to know, moved here off
                        // the deck that used to stand between them and the
                        // room. They are not a different game and they were
                        // never worth their own screen: a player who has just
                        // watched the film reads them in the same breath as
                        // the rules, and a player who joined by link is no
                        // longer made to read four cards while a friend waits.
                        const _OnlineSection(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      spacing.screenMargin,
                      spacing.sm,
                      spacing.screenMargin,
                      spacing.lg,
                    ),
                    child: FilledButton(
                      key: startButton,
                      onPressed: onStartMatch,
                      child: Text(l10n.homeAction),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The online half of the rules (task 11c).
///
/// Four items, and deliberately only four: they are the things that are **not**
/// guessable from the offline game, which is the only game any of these players
/// has seen. The phone is not passed; the night is simultaneous, so there is a
/// clock; a whisper's existence is public and its contents are not; and being
/// eliminated is not being ejected.
///
/// Everything else — what a role does, how a vote works — is on the sections
/// above this one, because it is the same in both games.
class _OnlineSection extends StatelessWidget {
  const _OnlineSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: l10n.onlineIntroPhoneTitle,
          body: l10n.onlineIntroPhoneBody,
        ),
        _Section(
          title: l10n.onlineIntroNightTitle,
          body: l10n.onlineIntroNightBody,
        ),
        _Section(
          title: l10n.onlineIntroWhisperTitle,
          body: l10n.onlineIntroWhisperBody,
        ),
        _Section(
          title: l10n.onlineIntroWitnessTitle,
          body: l10n.onlineIntroWitnessBody,
        ),
      ],
    );
  }
}

/// A heading with a rule under it, and one panel of text.
class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Heading(title: title),
          SizedBox(height: spacing.sm),
          PaperPanel(
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Text(
                body,
                // Leading comes from the token (1.6, pitched for Arabic), not
                // from here. A screen that sets its own line height is a second
                // type scale competing with the first.
                style: type.body.copyWith(color: colors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The four roles, each with its painted emblem, name and one line.
///
/// The copy comes from the same ARB keys the card backs use, so the rules and
/// the deck cannot drift apart.
class _RolesSection extends StatelessWidget {
  final String title;

  const _RolesSection({required this.title});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Heading(title: title),
          SizedBox(height: spacing.sm),
          PaperPanel(
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                children: [
                  for (final role in Role.values) ...[
                    if (role != Role.values.first) SizedBox(height: spacing.md),
                    _RoleRow(role: role),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  final Role role;

  const _RoleRow({required this.role});

  /// The bone-white emblems from `assets/icons/`, solved to identical ink
  /// coverage so no role's mark reads as louder than another's.
  String get _emblem => switch (role) {
    Role.mafia => AppIcons.roleMafia,
    Role.doctor => AppIcons.roleDoctor,
    Role.detective => AppIcons.roleDetective,
    Role.citizen => AppIcons.roleCitizen,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: spacing.xs),
          child: Image.asset(
            _emblem,
            width: spacing.lg,
            height: spacing.lg,
            // Decoded at the size it is drawn: the emblems ship at 1024² and
            // there are four of them on this screen.
            cacheWidth: 96,
            excludeFromSemantics: true,
          ),
        ),
        SizedBox(width: spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                EngineCopy.roleName(context.l10n, role),
                style: type.title.emphasised.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                EngineCopy.roleDescription(context.l10n, role),
                style: type.bodySmall.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section heading: the word, and a short gold rule under it.
///
/// The rule is the same device the home wordmark uses. It is what replaces the
/// emoji the reference app puts beside each heading — it separates the sections
/// just as clearly and it belongs to this app rather than to a keyboard.
class _Heading extends StatelessWidget {
  final String title;

  const _Heading({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: type.title.copyWith(color: colors.textPrimary)),
        SizedBox(height: spacing.xs),
        SizedBox(
          width: spacing.xl,
          child: Divider(color: colors.accentGold, height: 1, thickness: 1),
        ),
      ],
    );
  }
}
