import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/sweep_1_5_cases.dart';

/// Every screen and sheet of Update 1.5, at 360x640, 390x844 and 640x360, with
/// 20-character Arabic names: any FlutterError (a RenderFlex overflow, a
/// negative constraint, a thrown build) fails the case, naming the screen, the
/// size and the widget Flutter blames.
///
/// Defects that were already there are not hidden: each is listed in [known]
/// with the screen, the size and what is wrong, and its case is skipped with
/// that reason. They are fix items. `SWEEP_UNSKIP=1 flutter test ...` runs the
/// skipped cases too, so a fix can be proven by deleting its line.
void main() {
  const known = <String, String>{};
  final unskip = Platform.environment['SWEEP_UNSKIP'] == '1';
  for (final size in sweepSizes) {
    final sizeName = '${size.width.toInt()}x${size.height.toInt()}';
    for (final item in sweepCases()) {
      final knownReason = known['$sizeName ${item.name}'];
      final skipped = knownReason != null && !unskip;
      testWidgets('$sizeName ${item.name} has no FlutterError'
          '${knownReason == null ? '' : ' (KNOWN: $knownReason)'}', (
        tester,
      ) async {
        await tester.runAsync(loadSweepFonts);
        final errors = <String>{};
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) =>
            errors.add(describeSweepError(details));
        try {
          await pumpSweepCase(tester, item, size);
          Object? pending;
          while ((pending = tester.takeException()) != null) {
            errors.add('$pending');
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 5));
          while ((pending = tester.takeException()) != null) {
            errors.add('$pending');
          }
        } finally {
          FlutterError.onError = oldHandler;
        }
        expect(
          errors,
          isEmpty,
          reason: '$sizeName ${item.name}: ${errors.join(' | ')}',
        );
      }, skip: skipped);
    }
  }
}
