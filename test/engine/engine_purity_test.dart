import 'dart:io';

import 'package:test/test.dart';

import '../../tool/engine_purity.dart';

/// The purity rule of `PROMPT-build-online-and-information-engine.md` prime
/// directive 3, run as a test so it blocks a merge rather than sitting in a
/// script nobody invokes.
///
/// The rule itself lives in `tool/engine_purity.dart` so CI and a pre-commit
/// hook can run exactly the same check by a different route:
///
/// ```
/// dart run tool/engine_purity.dart
/// ```
void main() {
  group('engine purity', () {
    test('lib/engine is free of Flutter, wall-clock reads and loose randomness',
        () {
      final violations = scanEnginePurity();
      expect(
        violations,
        isEmpty,
        reason: 'The engine must stay a pure function of its arguments.\n'
            '${violations.join('\n')}\n\nrules:\n$purityRulesSummary',
      );
    });

    // A checker that has quietly stopped looking at anything is the failure
    // mode worth guarding: it reports success forever. These four assert the
    // scanner still bites.
    group('the checker itself', () {
      late Directory sandbox;

      setUp(() {
        sandbox = Directory.systemTemp.createTempSync('purity_probe');
      });
      tearDown(() => sandbox.deleteSync(recursive: true));

      void probe(String name, String source, String expectedRule) {
        test(name, () {
          File('${sandbox.path}/probe.dart').writeAsStringSync(source);
          final found = scanEnginePurity(root: sandbox.path);
          expect(
            found.map((v) => v.rule),
            contains(expectedRule),
            reason: 'the scanner missed: $source',
          );
        });
      }

      probe('catches a Flutter import',
          "import 'package:flutter/material.dart';\n", 'no-flutter');
      probe('catches a wall-clock read',
          'final x = DateTime.now();\n', 'no-wall-clock');
      probe('catches an unseeded Random',
          'final r = Random();\n', 'no-unseeded-random');
      probe('catches Random.secure',
          'final r = Random.secure();\n', 'no-unseeded-random');

      test('does not flag a seeded Random — the whole point is to use one', () {
        File('${sandbox.path}/probe.dart')
            .writeAsStringSync('final r = Random(deriveSeed(s, "salt", 3));\n');
        expect(scanEnginePurity(root: sandbox.path), isEmpty);
      });

      test('does not flag a comment that names a banned construct', () {
        File('${sandbox.path}/probe.dart').writeAsStringSync(
          '/// This used to call DateTime.now() and Random.secure().\n'
          '// It no longer does.\n'
          'final ok = 1;\n',
        );
        expect(
          scanEnginePurity(root: sandbox.path),
          isEmpty,
          reason: 'a checker that flags its own explanation of the rule '
              'gets switched off',
        );
      });

      test('refuses to pass vacuously on an empty tree', () {
        expect(
          () => scanEnginePurity(root: sandbox.path),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
