import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../../platform/monetization/ad_formats.dart' show BannerPlacement;
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';
import '../../widgets/experience_surface.dart';

/// «اختار طريقة اللعب», the one screen behind Home's «ابدأ اللعبة»: every
/// way to play, each named after the player's situation rather than the
/// technology — with friends on one phone, online on everyone's own phone,
/// alone against the computer, alone with a case. One decision, all above
/// the fold.
///
/// Every card is the deck's ArtCard with a face in its arched window
/// (docs/design/DECK-SYSTEM.md), dealt in one after another as the screen
/// opens. Online without a server stays on screen, explained, rather than
/// vanishing.
class ModeScreen extends StatelessWidget {
  /// One phone, passed around. The existing setup flow.
  final VoidCallback onPlayOffline;

  /// Everybody on their own phone. Null only when this build has no project,
  /// which draws the card explained rather than absent.
  final VoidCallback? onPlayOnline;

  /// Alone, the other seats played by the computer.
  final VoidCallback? onPlayBots;

  /// «قصص وتحقيقات»: a case to crack alone. Null hides the card.
  final VoidCallback? onPlayStories;

  /// Back to Home.
  final VoidCallback onBack;

  const ModeScreen({
    super.key,
    required this.onPlayOffline,
    required this.onPlayOnline,
    this.onPlayBots,
    this.onPlayStories,
    required this.onBack,
  });

  static const Key offlineCard = ValueKey('mode_offline');
  static const Key onlineCard = ValueKey('mode_online');
  static const Key botsCard = ValueKey('mode_bots');
  static const Key storiesCard = ValueKey('mode_stories');
  static const Key unavailableText = ValueKey('mode_unavailable');

  /// A story's scene rather than a face: the case, not a character.
  static const String storiesArt = 'assets/images/stories/covers/cover_01.webp';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = context.spacing;
    // A short phone gets the same hand, drawn smaller, rather than a scroll.
    final compact =
        MediaQuery.sizeOf(context).height < DeckTokens.compactBelow;
    final cards = <Widget>[
      ArtCard.list(
        compact: compact,
        key: offlineCard,
        title: l10n.modeOnePhoneTitle,
        meta: l10n.modeOnePhoneBody,
        art: const ArtWindow(asset: ExperienceArt.council),
        onTap: onPlayOffline,
      ),
      ArtCard.list(
        compact: compact,
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
      if (onPlayBots != null)
        ArtCard.list(
          compact: compact,
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
      if (onPlayStories != null)
        ArtCard.list(
          compact: compact,
          key: storiesCard,
          title: l10n.modeStoriesCardTitle,
          meta: l10n.modeStoriesCardBody,
          art: const ArtWindow(asset: storiesArt),
          onTap: onPlayStories,
        ),
    ];
    return DeckScaffold(
      title: l10n.modeTitle,
      onBack: onBack,
      banner: BannerPlacement.home,
      body: ListView(
        padding: EdgeInsets.only(bottom: s.lg),
        children: [
          for (final (i, card) in cards.indexed) ...[
            if (i > 0) SizedBox(height: compact ? s.sm : s.md),
            DeckRise(index: i, child: card),
          ],
        ],
      ),
    );
  }
}
