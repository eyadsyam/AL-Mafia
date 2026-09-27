import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/council_art.dart';

/// Phase 107 art slots: a raster is used only when the build bundles it; the
/// painted art stands in otherwise and on any decode failure.
void main() {
  tearDown(() => CouncilRaster.bundledForTest = null);

  Widget host(Widget child) => MaterialApp(home: Center(child: child));

  const fallbackKey = ValueKey('painted');
  const slot = RasterOr(
    path: 'assets/images/council/rank_tier_01.webp',
    width: 48,
    height: 48,
    fallback: SizedBox.square(key: fallbackKey, dimension: 48),
  );

  testWidgets('absent from the build: the painting, never an image', (
    tester,
  ) async {
    CouncilRaster.bundledForTest = const {};
    await tester.pumpWidget(host(slot));
    expect(find.byKey(fallbackKey), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('bundled: the file is preferred, and stays decorative', (
    tester,
  ) async {
    CouncilRaster.bundledForTest = {'assets/images/council/rank_tier_01.webp'};
    await tester.pumpWidget(host(slot));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.excludeFromSemantics, isTrue);
    expect(image.errorBuilder, isNotNull);
  });

  test('paths are bounded: unknown kinds never become asset paths', () {
    expect(
      CouncilRaster.contract('finish'),
      'assets/images/council/contract_finish.webp',
    );
    expect(CouncilRaster.contract('../x'), isNull);
    expect(CouncilRaster.rankTier(0), endsWith('rank_tier_01.webp'));
    expect(CouncilRaster.rankTier(10), endsWith('rank_tier_10.webp'));
    expect(CouncilRaster.coinPack(2), endsWith('coins_pack_large.webp'));
  });

  test('the delivered list matches the art folders on disk', () {
    final onDisk = <String>{
      for (final dir in const [
        CouncilRaster.council,
        CouncilRaster.storeV3,
        'assets/images/ads',
        'assets/images/awards',
        'assets/images/economy_v2',
        'assets/images/launch',
        'assets/images/profile',
        'assets/images/reactions',
      ])
        if (Directory(dir).existsSync())
          for (final f in Directory(dir).listSync().whereType<File>())
            if (f.path.endsWith('.webp')) '$dir/${f.uri.pathSegments.last}',
    };
    expect(
      CouncilRaster.delivered,
      onDisk,
      reason: 'list a delivered file in CouncilRaster.delivered (or remove it)',
    );
  });
}
