import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/story_catalog.dart';
import 'package:mafia_master/engine/models/player.dart' show PlayerGender;
import 'package:mafia_master/ui/screens/online/council/council_band.dart';
import 'package:mafia_master/ui/widgets/player_avatar.dart';

import '../support/localized.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the app reads its story cases once per process', () async {
    final first = await const StoryCatalog().load();
    final second = await const StoryCatalog().load();
    expect(first, isNotEmpty);
    expect(identical(first, second), isTrue);
  });

  test('a catalogue with its own bundle is read each time', () {
    final bundle = _Counting();
    StoryCatalog(bundle: bundle).load();
    StoryCatalog(bundle: bundle).load();
    expect(bundle.reads, StoryCatalog.assetPaths.length * 2);
  });

  testWidgets('a seat avatar keeps its art at the size it is drawn', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      localizedApp(
        const Center(
          child: PlayerAvatar(
            name: 'ليلى',
            gender: PlayerGender.female,
            diameter: 48,
          ),
        ),
      ),
    );
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, isNotEmpty);
    for (final image in images) {
      expect(image.image, isA<ResizeImage>());
      final width = (image.image as ResizeImage).width!;
      expect(width, lessThanOrEqualTo((48 * 3).ceil()));
    }
  });

  test('every council band shares one decode of its art', () {
    expect(
      identical(
        CouncilBand.sharedArt(rootBundle),
        CouncilBand.sharedArt(rootBundle),
      ),
      isTrue,
    );
  });
}

class _Counting extends CachingAssetBundle {
  int reads = 0;

  @override
  Future<ByteData> load(String key) {
    reads++;
    return Future.error(StateError('not here'));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    reads++;
    return Future.error(StateError('not here'));
  }
}
