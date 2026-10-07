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
  for (final file in files) {
    try {
      final story = StoryDefinition.decode(file.readAsStringSync());
      final report = const StorySolvabilityChecker().check(story);
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
  if (failed) exitCode = 1;
}
