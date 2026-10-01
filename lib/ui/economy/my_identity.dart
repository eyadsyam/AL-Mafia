import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player_profile.dart';
import '../../engine/models/player.dart' show PlayerGender;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/player_avatar.dart';
import 'cosmetic_paint.dart';
import 'my_cosmetics.dart';

/// This player's own identity as others see it: their avatar inside the frame
/// they equipped and their name on the nameplate they equipped (store truth).
///
/// Used on Profile, the account sheet, Home, the friends sheet and the
/// result. Everything it draws is public and belongs to this player alone;
/// no screen that is private to a role imports it.
class MyIdentityBadge extends ConsumerWidget {
  /// Row (Home chip, lists) or column (Profile, account sheet).
  final Axis axis;
  final double diameter;

  /// Overrides the profile name, e.g. a name being edited.
  final String? name;
  final PlayerGender? gender;

  /// False draws the framed avatar alone (Home's corner row).
  final bool showName;

  const MyIdentityBadge({
    super.key,
    this.axis = Axis.horizontal,
    this.diameter = StoreTruthTokens.chipAvatar,
    this.name,
    this.gender,
    this.showName = true,
  });

  static const Key badgeKey = ValueKey('my_identity_badge');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final mine = ref.watch(myCosmeticsProvider);
    final shownName = name ?? profile?.name ?? '';
    final shownGender = gender ?? profile?.gender ?? PlayerGender.unspecified;
    final s = context.spacing;
    final avatar = CosmeticFrameRing(
      frame: mine.frame,
      diameter: diameter,
      child: PlayerAvatar(
        name: shownName,
        gender: shownGender,
        diameter: diameter,
      ),
    );
    final label = shownName.isEmpty
        ? const SizedBox.shrink()
        : CosmeticNameplate(
            name: shownName,
            plate: mine.plate,
            textAlign: axis == Axis.vertical ? TextAlign.center : null,
            style: context.typography.body.emphasised.copyWith(
              color: context.colors.textPrimary,
            ),
          );
    if (!showName) return KeyedSubtree(key: badgeKey, child: avatar);
    return KeyedSubtree(
      key: badgeKey,
      child: axis == Axis.horizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                SizedBox(width: s.sm),
                Flexible(child: label),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [avatar, SizedBox(height: s.sm), label],
            ),
    );
  }
}
