import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// Local, bounded artwork. Unknown catalog codes never become asset paths.
abstract final class StoreArt {
  static const hero = 'assets/images/store_v2/store_hero.webp';
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
