import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'council_art.dart';

/// Local, bounded artwork. Unknown catalog codes never become asset paths.
abstract final class StoreArt {
  static const hero = 'assets/images/store_v2/store_hero.webp';
  static const dailyCoffer = 'assets/images/economy_v2/daily_coffer.webp';
  static const quietPass = 'assets/images/economy_v2/quiet_pass.webp';

  /// Council Coins pack art for a Play coins product (`mm_coins_500` →
  /// `coins_500`).
  static String? forPlayProduct(String productId) =>
      productId.startsWith('mm_') ? forCode(productId.substring(3)) : null;
  static const codes = {
    'frame_gilded',
    'frame_crimson',
    'frame_moonlit',
    'plate_noir',
    'plate_gilded',
    'plate_ember',
    'pack_midnight_manor',
    'pack_old_town',
    'pack_moonlit_archive',
    'narrator_storyteller',
    'narrator_keeper',
    'narrator_noir',
    'bundle_council',
    'bundle_identity',
    'bundle_nocturne',
    'coins_500',
    'coins_1200',
    'coins_2500',
  };
  static String? forCode(String code) =>
      codes.contains(code) ? 'assets/images/store_v2/$code.webp' : null;
}

class StoreProductArt extends StatelessWidget {
  final String code;
  const StoreProductArt({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    // Drawn in code, not an image: the Starter Bundle's frame.
    if (code == 'frame_council_seal') {
      return const RepaintBoundary(child: CouncilSealArt());
    }
    final asset = StoreArt.forCode(code);
    return RepaintBoundary(
      child: asset == null
          ? const Icon(Icons.inventory_2_outlined)
          : Image.asset(
              asset,
              fit: BoxFit.contain,
              cacheWidth: StoreTokens.decodeWidth,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => Icon(
                Icons.inventory_2_outlined,
                color: context.colors.accentGold,
              ),
            ),
    );
  }
}
