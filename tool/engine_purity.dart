/// The engine purity rule, as a library so both the test suite and CI can run
/// it, and as a standalone script so a pre-commit hook can too.
///
/// ```
/// dart run tool/engine_purity.dart
/// ```
///
/// # What it enforces, and why each clause is here
///
/// `PROMPT-build-online-and-information-engine.md`, prime directive 3:
/// *"`lib/engine/` has zero Flutter imports, zero `DateTime.now()`, zero
/// unseeded `Random()`. This is checked by a lint rule you will add."*
///
/// The three clauses are not stylistic. Each one, if violated, breaks a
/// specific thing downstream:
///
/// | Banned | What breaks without the ban |
/// |---|---|
/// | `package:flutter`, `dart:ui` | The engine stops being unit-testable without a widget binding, and stops being portable to the Edge Function reference port |
/// | `dart:io` | Same, plus it opens the door to reading files and env from inside game logic |
/// | `DateTime.now()` | Two devices resolving the same night write different event logs. Online and offline diverge (doc 10 §5.1), and a fuzz failure cannot be reproduced from its seed |
/// | `Random()`, `Random.secure()` | The same, non-deterministically. Doc 09 §4: *"`Random()` is **forbidden**. Always `Random(seed)`"* |
///
/// # Why it is written by hand and not as a custom analyzer plugin
///
/// A `custom_lint` plugin would be the tidy answer and costs a build_runner
/// step, a dependency, and a plugin that silently stops running when the
/// analyzer version moves. This is forty lines, has no dependencies, and fails
/// loudly. When the rule set grows past what a regex can honestly express,
/// revisit it — not before.
///
/// # Comments are not code
///
/// The scanner strips `//`, `///` and `/* */` before matching, because the
/// engine's own doc comments talk *about* `DateTime.now()` at length. A checker
/// that flagged its own explanation of the rule would be turned off within a
/// week.
library tool.engine_purity;

import 'dart:io';

/// One violation of the purity rule.
class PurityViolation {
  final String path;
  final int line;
  final String rule;
  final String source;

  const PurityViolation({
    required this.path,
    required this.line,
    required this.rule,
    required this.source,
  });

  @override
  String toString() => '$path:$line  [$rule]  ${source.trim()}';
}

/// A banned construct.
class _Ban {
  final String rule;
  final RegExp pattern;
  final String why;

  /// Whether string literals are blanked before matching.
  ///
  /// False for the import bans, and that distinction is load-bearing: an import
  /// *is* a string literal, so blanking literals first turns
  /// `import 'package:flutter/material.dart';` into `import '';` and the ban
  /// matches nothing. The probe suite in `engine_purity_test.dart` caught this
  /// on the checker's first run, which is the entire reason those probes exist.
  final bool stripStrings;

  const _Ban(this.rule, this.pattern, this.why, {this.stripStrings = true});
}

final List<_Ban> _bans = [
  _Ban(
    'no-flutter',
    RegExp(r"""import\s+['"]package:flutter/"""),
    'the engine must run without a widget binding',
    stripStrings: false,
  ),
  _Ban(
    'no-dart-ui',
    RegExp(r"""import\s+['"]dart:ui['"]"""),
    'the engine must run without a widget binding',
    stripStrings: false,
  ),
  _Ban(
    'no-dart-io',
    RegExp(r"""import\s+['"]dart:io['"]"""),
    'game logic may not touch the filesystem, the network or the environment',
    stripStrings: false,
  ),
  _Ban(
    'no-wall-clock',
    // `DateTime.now()` and the timestamp accessors that are the same read by
    // another name.
    RegExp(r'DateTime\s*\.\s*now\s*\(|DateTime\s*\.\s*timestamp\s*\(|'
        r'Stopwatch\s*\(\)'),
    'time is an argument: take a Clock (engine/clock.dart), never read one',
  ),
  _Ban(
    'no-unseeded-random',
    // `Random()` with nothing between the parentheses, and `Random.secure()`,
    // which has no seed by construction. `Random(expr)` is fine and is the
    // whole point.
    RegExp(r'Random\s*\(\s*\)|Random\s*\.\s*secure\s*\('),
    'derive every stream from Match.seed via deriveSeed (engine/seed.dart)',
  ),
];

/// Strips line comments.
String _stripComments(String line) => line.replaceAll(RegExp(r'//.*'), '');

/// Blanks string literals, for the bans that match code constructs.
///
/// Needed because the engine's own error messages quote the names of the things
/// they refuse to do (`'... run winCheck first'`), and one of them will
/// eventually contain a banned word. Deliberately *not* applied to the import
/// bans — see [_Ban.stripStrings].
String _stripStrings(String line) {
  var s = line;
  s = s.replaceAll(RegExp(r"'(?:\\.|[^'\\])*'"), "''");
  s = s.replaceAll(RegExp(r'"(?:\\.|[^"\\])*"'), '""');
  return s;
}

/// Scans [root] (default `lib/engine`) and returns every violation found.
List<PurityViolation> scanEnginePurity({String root = 'lib/engine'}) {
  final dir = Directory(root);
  if (!dir.existsSync()) {
    throw StateError('engine purity: $root does not exist');
  }

  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    // Stable order so two runs report violations in the same sequence.
    ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    throw StateError('engine purity: no Dart files under $root — the check '
        'would pass vacuously, which is worse than failing');
  }

  final violations = <PurityViolation>[];
  for (final file in files) {
    final lines = file.readAsStringSync().split('\n');
    var inBlockComment = false;

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      if (inBlockComment) {
        final end = line.indexOf('*/');
        if (end < 0) continue;
        line = line.substring(end + 2);
        inBlockComment = false;
      }
      final open = line.indexOf('/*');
      if (open >= 0 && !line.substring(open).contains('*/')) {
        line = line.substring(0, open);
        inBlockComment = true;
      }

      final withoutComments = _stripComments(line);
      final withoutStrings = _stripStrings(withoutComments);
      for (final ban in _bans) {
        final subject = ban.stripStrings ? withoutStrings : withoutComments;
        if (ban.pattern.hasMatch(subject)) {
          violations.add(PurityViolation(
            path: file.path.replaceAll(r'\', '/'),
            line: i + 1,
            rule: ban.rule,
            source: lines[i],
          ));
        }
      }
    }
  }
  return violations;
}

/// The rules, for a failure message that explains itself.
String get purityRulesSummary =>
    _bans.map((b) => '  ${b.rule}: ${b.why}').join('\n');

void main() {
  final violations = scanEnginePurity();
  if (violations.isEmpty) {
    stdout.writeln('engine purity: clean');
    return;
  }
  stderr.writeln('engine purity: ${violations.length} violation(s)\n');
  for (final v in violations) {
    stderr.writeln('  $v');
  }
  stderr.writeln('\nrules:\n$purityRulesSummary');
  exitCode = 1;
}
