import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/store_art.dart';
import 'package:mafia_master/ui/social/titles_partner.dart';

void main() {
  for (final code in const [
    'season_zero_night_scribe',
    'season_zero_casekeeper',
    'kabir_elshella',
  ]) {
    testWidgets('title row seal $code uses its painted asset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TitleSeal(code: code)),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/titles/title_seal_$code.webp',
      );
    });
  }

  testWidgets('invite frame product uses the store artwork', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StoreProductArt(code: 'frame_invite')),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as ResizeImage).imageProvider,
      isA<AssetImage>().having(
        (asset) => asset.assetName,
        'path',
        'assets/images/store_v2/frame_invite.webp',
      ),
    );
  });
}
