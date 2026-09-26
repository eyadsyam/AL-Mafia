import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/asset_constants.dart';
import 'package:mafia_master/ui/widgets/ambient_media.dart';

void main() {
  testWidgets(
    'motion preferences and inactive routes use the static fallback',
    (tester) async {
      Future<void> show({bool reduced = false, bool active = true}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: TickerMode(
                enabled: active,
                child: const AmbientMedia(
                  still: AppImages.bgVote,
                  loop: AppVideo.bgVoteLoop,
                ),
              ),
            ),
          ),
        );
      }

      List<String> assets() => [
        for (final image in tester.widgetList<Image>(find.byType(Image)))
          (image.image as AssetImage).assetName,
      ];
      // The still is always the floor (owner, 2026-09-24: the backdrop used to
      // be missing until the loop had decoded); the loop is laid over it.
      await show();
      expect(assets(), [AppImages.bgVote, AppVideo.bgVoteLoop]);
      await show(reduced: true);
      expect(assets(), [AppImages.bgVote]);
      await show(active: false);
      expect(assets(), [AppImages.bgVote]);
      expect(find.byType(ClipRect), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
