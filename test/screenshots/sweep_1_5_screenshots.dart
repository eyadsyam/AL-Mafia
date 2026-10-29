/// Visual inventory for Update 1.5. Writes PNGs; this is not a golden test.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/sweep_1_5_cases.dart';

void main() {
  for (final size in sweepSizes) {
    final sizeName = '${size.width.toInt()}x${size.height.toInt()}';
    for (final item in sweepCases()) {
      testWidgets('$sizeName ${item.name}', (tester) async {
        await tester.runAsync(loadSweepFonts);
        final errors = <String>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) =>
            errors.add(describeSweepError(details));
        try {
          await pumpSweepCase(tester, item, size);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('shot')),
          );
          final image = boundary.toImageSync(pixelRatio: 1);
          final directory = Directory('build/sweep_1_5/$sizeName')
            ..createSync(recursive: true);
          await tester.runAsync(() async {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '${directory.path}/${item.name}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
          });
          image.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 5));
        } finally {
          FlutterError.onError = oldHandler;
        }
        for (final error in errors) {
          // A visual sweep records existing problems; the guard test fails them.
          // ignore: avoid_print
          print('SWEEP_ERROR $sizeName ${item.name}: $error');
        }
        while (tester.takeException() != null) {
          /* drain for visual inventory */
        }
      });
    }
  }
}
