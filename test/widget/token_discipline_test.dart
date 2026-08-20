import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Token Discipline', () {
    test('no hardcoded style literals in lib/ui (except theme)', () {
      final uiDir = Directory('lib/ui');

      if (!uiDir.existsSync()) {
        // lib/ui doesn't exist yet, test passes trivially
        return;
      }

      final files = uiDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.replaceAll('\\', '/').contains('theme/'))
          .toList();

      if (files.isEmpty) {
        // No dart files in lib/ui (except theme), test passes trivially
        return;
      }

      final violations = <String>[];

      // Patterns for hardcoded literals
      final colorLiteralPattern = RegExp(r'Color\s*\(\s*0x');
      final constColorPattern = RegExp(r'const\s+Color\s*\(');
      final hexPattern = RegExp(r'0xFF[0-9A-Fa-f]{6}');
      final edgeInsetsPattern = RegExp(r'EdgeInsets\.all\s*\(\s*\d+');

      for (final file in files) {
        final content = file.readAsStringSync();
        final lines = content.split('\n');

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];

          if (colorLiteralPattern.hasMatch(line)) {
            violations.add(
              '${file.path}:${i + 1}: Hardcoded Color(0x...): $line',
            );
          }

          if (constColorPattern.hasMatch(line)) {
            violations.add(
              '${file.path}:${i + 1}: Hardcoded const Color(...): $line',
            );
          }

          if (hexPattern.hasMatch(line)) {
            violations.add(
              '${file.path}:${i + 1}: Hardcoded hex color (0xFF...): $line',
            );
          }

          if (edgeInsetsPattern.hasMatch(line)) {
            violations.add(
              '${file.path}:${i + 1}: Hardcoded EdgeInsets.all(...): $line',
            );
          }
        }
      }

      if (violations.isNotEmpty) {
        fail(
          'Token discipline violations found:\n${violations.join('\n')}',
        );
      }
    });
  });
}
