import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../../platform/monetization/ad_formats.dart' show BannerPlacement;
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';
import '../../widgets/experience_surface.dart';

/// «اختار طريقة اللعب»: three ways to play, each named after the player's
/// situation rather than the technology — with friends on one phone, online
/// on everyone's own phone, alone against the computer. Stories have their
/// own door on Home, so this screen is one decision, all above the fold.
///
/// Every card is the deck's ArtCard with a face in its arched window
/// (docs/design/DECK-SYSTEM.md). Online without a server stays on screen,
/// explained, rather than vanishing.
class ModeScreen extends StatelessWidget {
  /// One phone, passed around. The existing setup flow.
  final VoidCallback onPlayOffline;

  /// Everybody on their own phone. Null only when this build has no project,
  /// which draws the card explained rather than absent.
  final VoidCallback? onPlayOnline;

  /// Alone, the other seats played by the computer.
  final VoidCallback? onPlayBots;

  /// Back to Home.
  final VoidCallback onBack;

  const ModeScreen({
    super.key,
    required this.onPlayOffline,
    required this.onPlayOnline,
    this.onPlayBots,
    required this.onBack,
  });

  static const Key offlineCard = ValueKey('mode_offline');
  static const Key onlineCard = ValueKey('mode_online');
  static const Key botsCard = ValueKey('mode_bots');
  static const Key unavailableText = ValueKey('mode_unavailable');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = context.spacing;
    return DeckScaffold(
      title: l10n.modeTitle,
      onBack: onBack,
      banner: BannerPlacement.home,
      body: ListView(
        padding: EdgeInsets.only(bottom: s.lg),
        children: [
          ArtCard.list(
            key: offlineCard,
            title: l10n.modeOnePhoneTitle,
            meta: l10n.modeOnePhoneBody,
            art: const ArtWindow(asset: ExperienceArt.council),
            onTap: onPlayOffline,
          ),
          SizedBox(height: s.md),
          ArtCard.list(
            key: onlineCard,
            title: l10n.modeOnlineTitle,
            meta: l10n.modeOnlineBody,
            art: const ArtWindow(
              asset: AppImages.cardFaceDoctor,
              focus: ModeTokens.faceFocus,
              zoom: ModeTokens.faceZoom,
            ),
            onTap: onPlayOnline,
            lockedReason: onPlayOnline == null ? l10n.modeNoServer : null,
            lockedKey: unavailableText,
          ),
          if (onPlayBots != null) ...[
            SizedBox(height: s.md),
            ArtCard.list(
              key: botsCard,
              title: l10n.modeBotsCardTitle,
              meta: l10n.modeBotsBody,
              art: const ArtWindow(
                asset: AppImages.cardFaceCitizen,
                focus: ModeTokens.faceFocus,
                zoom: ModeTokens.faceZoom,
              ),
              onTap: onPlayBots,
            ),
          ],
        ],
      ),
    );
  }
}
