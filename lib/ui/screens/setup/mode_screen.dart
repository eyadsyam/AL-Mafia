import 'package:flutter/material.dart';

import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/experience_surface.dart';

/// Public mode selection. Online leads the visual hierarchy; both modes
/// remain visible even when online is unavailable in the build.
class ModeScreen extends StatelessWidget {
  /// One phone, passed around. The existing setup flow.
  final VoidCallback onPlayOffline;

  /// Everybody on their own phone. Null only when this build has no project,
  /// which draws the card explained rather than absent.
  final VoidCallback? onPlayOnline;

  /// Back to Home.
  final VoidCallback onBack;

  const ModeScreen({
    super.key,
    required this.onPlayOffline,
    required this.onPlayOnline,
    required this.onBack,
  });

  static const Key offlineCard = ValueKey('mode_offline');
  static const Key onlineCard = ValueKey('mode_online');
  static const Key unavailableText = ValueKey('mode_unavailable');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: ExperienceSurface(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(spacing.screenMargin),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: BackAction(onPressed: onBack),
                    ),
                    SizedBox(height: spacing.lg),
                    Text(
                      l10n.modeTitle,
                      style: type.headline.copyWith(color: colors.textPrimary),
                    ),
                    SizedBox(height: spacing.lg),
                    const ExperienceHero(asset: ExperienceArt.council),
                    SizedBox(height: spacing.md),
                    Text(
                      l10n.councilInvitation,
                      style: type.body,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.lg),
                    _ModeCard(
                      cardKey: ModeScreen.onlineCard,
                      icon: Icons.groups_outlined,
                      title: l10n.modeOnlineTitle,
                      body: l10n.modeOnlineBody,
                      emphasised: true,
                      onPressed: onPlayOnline,
                      footnote: onPlayOnline == null ? l10n.modeNoServer : null,
                      footnoteKey: ModeScreen.unavailableText,
                    ),
                    SizedBox(height: spacing.md),
                    _ModeCard(
                      cardKey: ModeScreen.offlineCard,
                      icon: Icons.phone_android_outlined,
                      title: l10n.modeOnePhoneTitle,
                      body: l10n.modeOnePhoneBody,
                      emphasised: false,
                      onPressed: onPlayOffline,
                    ),
                    SizedBox(height: spacing.lg),
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

/// One of the two answers.
///
/// Both cards are built by the same widget with the same padding and the same
/// three lines, so neither reads as the real option and the other as a
/// concession. The only difference between them is the border and the label
/// colour.
class _ModeCard extends StatelessWidget {
  final Key cardKey;
  final IconData icon;
  final String title;
  final String body;
  final bool emphasised;
  final VoidCallback? onPressed;
  final String? footnote;
  final Key? footnoteKey;

  const _ModeCard({
    required this.cardKey,
    required this.icon,
    required this.title,
    required this.body,
    required this.emphasised,
    required this.onPressed,
    this.footnote,
    this.footnoteKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    final enabled = onPressed != null;
    final accent = emphasised ? colors.accentGold : colors.textSecondary;

    return Semantics(
      button: true,
      enabled: enabled,
      label: title,
      child: Material(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radii.card),
        child: InkWell(
          key: cardKey,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radii.card),
          child: Container(
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radii.card),
              border: Border.all(
                color: emphasised ? colors.accentGold : colors.borderSubtle,
              ),
            ),
            child: Opacity(
              // Dimmed rather than hidden, and still readable: the point of
              // drawing it at all is that somebody can read why.
              opacity: enabled ? 1 : 0.55,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: accent),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: type.title.copyWith(color: colors.textPrimary),
                        ),
                        SizedBox(height: spacing.xs),
                        Text(
                          body,
                          style: type.caption.copyWith(color: colors.textMuted),
                        ),
                        if (footnote != null) ...[
                          SizedBox(height: spacing.xs),
                          Text(
                            key: footnoteKey,
                            footnote!,
                            style: type.caption.copyWith(
                              color: colors.accentCrimson,
                            ),
                          ),
                        ],
                      ],
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
