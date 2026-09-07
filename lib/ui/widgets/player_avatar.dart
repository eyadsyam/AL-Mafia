import 'package:flutter/material.dart';

import '../../app/asset_constants.dart';
import '../../engine/models/player.dart' show PlayerGender;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// Which piece of character art a player is drawn with (task 7).
///
/// A path and not a widget, so the online council — which is one
/// `CustomPainter` for the whole band and may not become fifteen widgets — can
/// use the same answer this file gives the offline lists. There is exactly one
/// mapping from a gender to a face in the app, and it is here.
///
/// `unspecified` gets no art and falls back to the initial. That is not a
/// placeholder waiting to be filled: a player who did not say is not going to
/// be assigned a body by the software.
abstract final class AvatarArt {
  static String? forGender(PlayerGender gender) => switch (gender) {
    PlayerGender.male => AppCouncilArt.avatarMale,
    PlayerGender.female => AppCouncilArt.avatarFemale,
    PlayerGender.unspecified => null,
  };
}

/// One player, inside the ornamental ring (task 7).
///
/// ## Why offline and online share this and still look different in code
///
/// The *appearance* has one owner — this file — and two renderers, because the
/// two surfaces are built differently for reasons that predate the avatar. Doc
/// 15 §3 forbids the council from being fifteen widgets with fifteen tickers,
/// so band 2 draws its seats in a single painter; every other surface in the
/// app is an ordinary list of rows. What must not be duplicated is the
/// decision — which ring, which art, what happens when there is no art — and
/// that lives in [AvatarArt] and in the layout constants below, which both
/// renderers read.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final PlayerGender gender;
  final double diameter;

  /// The ring's colour. Defaults to the subtle border, which is what an
  /// ordinary seat is drawn in.
  final Color? ringColor;

  /// False draws the ring and nothing inside it — the "stepped away" state of
  /// task 4, and the reason the art and the ring are two layers rather than
  /// one composited image.
  final bool occupied;

  const PlayerAvatar({
    super.key,
    required this.name,
    required this.gender,
    required this.diameter,
    this.ringColor,
    this.occupied = true,
  });

  /// How much of the ring's diameter the art fills. The ring art has its own
  /// margin painted into it, so the face has to sit inside that rather than
  /// against it.
  static const double artRatio = CouncilTokens.avatarSizeRatio;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = ringColor ?? colors.borderSubtle;
    final art = occupied ? AvatarArt.forGender(gender) : null;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            AppCouncilArt.seatRingIdle,
            width: diameter,
            height: diameter,
            color: tint,
            filterQuality: FilterQuality.medium,
          ),
          if (art != null)
            ClipOval(
              child: Image.asset(
                art,
                width: diameter * artRatio,
                height: diameter * artRatio,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            )
          else if (occupied && name.isNotEmpty)
            Text(
              name.characters.first,
              style: context.typography.title.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

/// The size the offline lists draw an avatar at.
const double kListAvatarDiameter = CouncilTokens.viewerSeatSize + 8;
