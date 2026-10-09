import 'dart:io';

import 'package:mafia_master/stories/story_checker.dart';
import 'package:mafia_master/stories/story_model.dart';

void main() {
  final directory = Directory('assets/stories');
  if (!directory.existsSync()) {
    stderr.writeln('FAIL: assets/stories does not exist');
    exitCode = 2;
    return;
  }
  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stderr.writeln('FAIL: no story JSON files found');
    exitCode = 2;
    return;
  }

  var failed = false;
  final realism = <String>[];
  for (final file in files) {
    try {
      final story = StoryDefinition.decode(file.readAsStringSync());
      final report = const StorySolvabilityChecker().check(story);
      for (final row in const StoryRealism().analyze(story)) {
        if (row.impossible) {
          realism.add(
            '${story.id} [${row.playerCount} players]: NOT DEDUCIBLE '
            '(0/${row.total} plays)',
          );
        } else if (row.partial) {
          realism.add(
            '${story.id} [${row.playerCount} players]: partial '
            '${row.deducing}/${row.total} plays',
          );
        }
      }
      if (report.passed) {
        stdout.writeln(
          'PASS ${story.id}: players 1-10 uniquely deduce '
          'culprit + motive + method; no clue reveals culprit alone',
        );
      } else {
        failed = true;
        stderr.writeln('FAIL ${story.id}');
        for (final issue in report.issues) {
          stderr.writeln('  $issue');
        }
      }
    } on Object catch (error, trace) {
      failed = true;
      stderr.writeln('FAIL ${file.path}: $error');
      stderr.writeln(trace);
    }
  }
  stdout.writeln(
    '\nREALISM (report only, does not fail): '
    '${realism.length} table sizes below full',
  );
  realism.forEach(stdout.writeln);
  if (failed) exitCode = 1;
}
