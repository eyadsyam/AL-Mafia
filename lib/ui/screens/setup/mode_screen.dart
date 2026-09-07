import 'package:flutter/material.dart';

import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/textured_surface.dart';

/// S-01a — «هتلعبوا إزاي؟»
///
/// ## Why this screen exists
///
/// Online used to be a quiet text button under the gold one on Home, offered
/// only when the build had a project to talk to. That put the two modes at
/// different weights and hid one of them behind a compile-time flag: a group
/// that had never been told the app could do it never found out.
///
/// The two modes are not a feature and its footnote. They are two different
/// physical situations — one phone in the middle of a table, or ten phones in
/// ten hands — and the question of which one you are in is the first thing
/// anybody actually knows. So Play asks it, once, and both answers are the
/// same size.
///
/// ## Online is offered unconditionally
///
/// Including when this build has no server compiled into it. A vanishing
/// button is the worst of the three possible behaviours: the player cannot
/// tell it apart from a feature that does not exist, and neither can whoever
/// built the APK. So the card is always drawn, and a build with no project
/// says so on the card instead of disappearing — which is a sentence somebody
/// can act on, and the only honest thing to put there.
///
/// Connectivity is *not* checked here. A phone that is offline finds out when
/// it tries, from the transport, in the one place that actually knows — and
/// pre-flighting it here would mean a second source of truth about the
/// network that could disagree with the first.
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
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
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
                  const Spacer(),
                  _ModeCard(
                    cardKey: ModeScreen.offlineCard,
                    icon: Icons.phone_android_outlined,
                    title: l10n.modeOnePhoneTitle,
                    body: l10n.modeOnePhoneBody,
                    // The gold one, because it is the mode the app was built
                    // around and the one a group with one phone can always do.
                    emphasised: true,
                    onPressed: onPlayOffline,
                  ),
                  SizedBox(height: spacing.md),
                  _ModeCard(
                    cardKey: ModeScreen.onlineCard,
                    icon: Icons.groups_outlined,
                    title: l10n.modeOnlineTitle,
                    body: l10n.modeOnlineBody,
                    emphasised: false,
                    onPressed: onPlayOnline,
                    // Only reason a build refuses this, and it is a fact about
                    // the build rather than about the phone's network.
                    footnote: onPlayOnline == null ? l10n.modeNoServer : null,
                    footnoteKey: ModeScreen.unavailableText,
                  ),
                  const Spacer(),
                ],
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
                            style: type.caption
                                .copyWith(color: colors.accentCrimson),
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
