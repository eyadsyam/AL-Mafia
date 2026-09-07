/// The host half of `flutter drive`. Writes whatever an integration test hands
/// back — for `council_frames_test.dart`, the timeline summary doc 15 §5's
/// frame-budget box is closed by reading.
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final out = Directory('build/integration_response_data')
      ..createSync(recursive: true);
    for (final entry in data.entries) {
      File('${out.path}/${entry.key}.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(entry.value),
      );
      // ignore: avoid_print
      print('wrote ${out.path}/${entry.key}.json');
    }
  },
);
