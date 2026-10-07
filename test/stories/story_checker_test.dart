import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/stories/story_checker.dart';
import 'package:mafia_master/stories/story_model.dart';

void main() {
  final files = Directory(
    'assets/stories',
  ).listSync().whereType<File>().where((file) => file.path.endsWith('.json'));

  for (final file in files) {
    test('${file.path} is uniquely solvable for player counts 1-10', () {
      final story = StoryDefinition.decode(file.readAsStringSync());
      final report = const StorySolvabilityChecker().check(story);
      expect(report.issues, isEmpty, reason: report.issues.join('\n'));
    });
  }

  test('rejects a clue that names all but one culprit', () {
    final original = StoryDefinition.decode(
      File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
    );
    final revealing = StoryClue(
      id: 'bad',
      title: 'bad',
      body: 'bad',
      proves: const ['bad'],
      excludes: StoryExclusions(
        culprits: original.characters.skip(1).map((c) => c.id).toList(),
      ),
      buckets: StoryBucket.values.toSet(),
    );
    final broken = StoryDefinition(
      id: original.id,
      number: original.number,
      title: original.title,
      category: original.category,
      synopsis: original.synopsis,
      difficulty: original.difficulty,
      lengthMinutes: original.lengthMinutes,
      coverImage: original.coverImage,
      actionBudget: original.actionBudget,
      discussionSeconds: original.discussionSeconds,
      characters: original.characters,
      locations: original.locations,
      motives: original.motives,
      methods: original.methods,
      truth: original.truth,
      clues: [...original.clues, revealing],
      actions: [
        StoryInvestigationAction(
          id: original.actions.first.id,
          title: original.actions.first.title,
          description: original.actions.first.description,
          cost: original.actions.first.cost,
          clueIds: [...original.actions.first.clueIds, 'bad'],
        ),
        ...original.actions.skip(1),
      ],
    );
    expect(
      const StorySolvabilityChecker()
          .check(broken)
          .issues
          .any((issue) => issue.message.contains('reveals the culprit alone')),
      isTrue,
    );
  });
}
