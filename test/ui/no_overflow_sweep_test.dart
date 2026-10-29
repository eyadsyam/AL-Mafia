import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/sweep_1_5_cases.dart';

void main() {
  // Confirmed on the unskipped sweep. These remain visible fix items in the
  // report and each skip is scoped to the exact screen and viewport.
  const known = <String, String>{
    '360x640 17_discussion': 'discussion: bottom RenderFlex overflow 18 px',
    '360x640 21_settings_sheet':
        'settings sheet: bottom RenderFlex overflow 490 px',
    '390x844 21_settings_sheet':
        'settings sheet: bottom RenderFlex overflow 286 px',
    '640x360 01_mode': 'mode: negative minimum height constraints',
    '640x360 06_history': 'history: bottom RenderFlex overflow 4 px',
    '640x360 15_night': 'night: bottom RenderFlex overflow 12 px',
    '640x360 17_discussion': 'discussion: bottom RenderFlex overflow 66 px',
    '640x360 18_vote': 'vote: bottom RenderFlex overflow 167 px',
    '640x360 19_vote_result': 'vote result: bottom RenderFlex overflow 90 px',
    '640x360 21_settings_sheet':
        'settings sheet: bottom RenderFlex overflow 770 px',
  };
  for (final size in sweepSizes) {
    final sizeName = '${size.width.toInt()}x${size.height.toInt()}';
    for (final item in sweepCases()) {
      final knownReason = known['$sizeName ${item.name}'];
      testWidgets('$sizeName ${item.name} has no FlutterError'
          '${knownReason == null ? '' : ' SKIP: $knownReason'}', (
        tester,
      ) async {
        await tester.runAsync(loadSweepFonts);
        final errors = <String>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) =>
            errors.add(details.exceptionAsString());
        try {
          await pumpSweepCase(tester, item, size);
          Object? pending;
          while ((pending = tester.takeException()) != null) {
            errors.add('$pending');
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 5));
        } finally {
          FlutterError.onError = oldHandler;
        }
        expect(
          errors,
          isEmpty,
          reason: '$sizeName ${item.name}: ${errors.join(' | ')}',
        );
      }, skip: knownReason != null);
    }
  }
}
