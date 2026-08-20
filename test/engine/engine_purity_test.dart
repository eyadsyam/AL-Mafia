import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Engine Purity', () {
    test('no Flutter or dart:ui imports in lib/engine', () {
      final engineDir = Directory('lib/engine');

      if (!engineDir.existsSync()) {
        fail('lib/engine directory does not exist');
      }

      final files = engineDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      if (files.isEmpty) {
        // No dart files yet, test passes trivially
        return;
      }

      final violations = <String>[];

      for (final file in files) {
        final content = file.readAsStringSync();
        final lines = content.split('\n');

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Check for Flutter package imports
          if (line.contains("import 'package:flutter/")) {
            violations.add(
              '${file.path}:${i + 1}: Found package:flutter import: $line',
            );
          }
          // Check for dart:ui imports
          if (line.contains("import 'dart:ui'")) {
            violations.add(
              '${file.path}:${i + 1}: Found dart:ui import: $line',
            );
          }
        }
      }

      if (violations.isNotEmpty) {
        fail(
          'Engine purity violations found:\n${violations.join('\n')}',
        );
      }
    });
  });
}
