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

      String asset() =>
          ((tester.widget<Image>(find.byType(Image))).image as AssetImage)
              .assetName;
      await show();
      expect(asset(), AppVideo.bgVoteLoop);
      await show(reduced: true);
      expect(asset(), AppImages.bgVote);
      await show(active: false);
      expect(asset(), AppImages.bgVote);
      expect(find.byType(ClipRect), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
