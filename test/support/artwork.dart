import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/asset_constants.dart';

/// Decodes every bundled image and parks it in the image cache.
///
/// ## Why this has to exist
///
/// `Image.asset` resolves and decodes asynchronously, and `pump` does not wait
/// for it. A widget that paints artwork therefore renders *without* that artwork
/// on its first frame and *with* it on some later frame, and which frame that is
/// depends on how loaded the machine is.
///
/// For the symmetry suites that is not a cosmetic problem, it is a correctness
/// one: they compare frames across roles, so a card that happened to be pumped
/// before the decode finished differs from one pumped after — and the suite
/// reports a leak that does not exist. That failure is load-dependent, which is
/// the worst kind: `reveal_symmetry_test.dart` passed on its own and failed in a
/// full parallel run.
///
/// The previous fix pumped a fixed number of times and hoped. This waits on the
/// actual [ImageStream] completions instead, so there is nothing left to race.
///
/// It weakens no assertion. Every comparison still happens between fully-painted
/// frames captured in the same cache state — which is the state a real device is
/// in by the time a second card is ever dealt.
Future<void> loadArtwork(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final path in <String>[...AppImages.values, ...AppIcons.values]) {
      final completer = Completer<void>();
      final stream = AssetImage(path).resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          stream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        },
        // A missing or corrupt asset is the manifest test's business, not this
        // helper's. Completing on error keeps a failure there from hanging every
        // suite that paints.
        onError: (Object error, StackTrace? stack) {
          stream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        },
      );
      stream.addListener(listener);
      await completer.future;
    }
  });
  await tester.pump();
}
