/// The web is a 32-bit place for bitwise operators, and the app ships there.
///
/// # The bug this file exists to keep fixed
///
/// `newMatchSeed()` read `Random.secure().nextInt(1 << 32)`. On the VM that is
/// 4294967296. In JavaScript `<<` is defined on 32-bit integers, so dart2js
/// compiles it to `0`, `nextInt(0)` throws *"max must be in range 0 < max ≤
/// 2^32, was 0"*, and **every offline match on the web died on the tap that
/// should have started it** — silently, because a thrown exception inside a
/// button callback leaves the screen exactly as it was.
///
/// It compiled, it analysed clean, and the whole test suite passed, because the
/// suite runs on the VM where the expression is correct. Nothing short of
/// reading the source catches a bug whose two platforms disagree about
/// arithmetic, so that is what this does.
///
/// The rule: a shift whose result is used as a *magnitude* must not be written
/// as a shift. Write the number. 2^32 is far inside the 2^53 integers dart2js
/// represents exactly; it was only ever the operator that could not cross.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Every Dart file the app ships, excluding generated code.
  ///
  /// Generated Isar schemas are full of 64-bit collection ids that dart2js
  /// cannot represent — which is exactly why they are behind a conditional
  /// import and never reach a web build. See `lib/data/local_stores_web.dart`.
  List<File> sources() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('.g.dart'))
      .toList();

  test('no shift is used as a magnitude', () {
    // `1 << 32` and anything above it. Below 32 the shift is exact in
    // JavaScript too, so a flag mask like `1 << 3` is fine and stays legal.
    final offenders = <String>[];
    final shift = RegExp(r'<<\s*(\d+)');

    for (final file in sources()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Prose about the bug is allowed to name it.
        final code = line.trimLeft();
        if (code.startsWith('//') || code.startsWith('///')) continue;

        for (final match in shift.allMatches(line)) {
          final bits = int.parse(match.group(1)!);
          if (bits >= 32) {
            offenders.add('${file.path}:${i + 1}: ${line.trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'a shift of 32 or more is zero in JavaScript. Write the literal '
          'instead — dart2js represents integers exactly to 2^53.\n'
          '${offenders.join('\n')}',
    );
  });

  test('no integer literal is too large for the web', () {
    // dart2js represents integers exactly up to 2^53. Past that a literal is
    // a *compile* error in a web build, long before anything runs — which is
    // how the Isar schemas were found.
    const maxExact = 9007199254740992; // 2^53
    final offenders = <String>[];
    final literal = RegExp(r'(?<![\w.])(\d{16,})(?![\w.])');

    for (final file in sources()) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].trimLeft();
        if (code.startsWith('//') || code.startsWith('///')) continue;

        for (final match in literal.allMatches(lines[i])) {
          final value = int.tryParse(match.group(1)!);
          if (value != null && value > maxExact) {
            offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'this will not compile for the web:\n${offenders.join('\n')}',
    );
  });
}
