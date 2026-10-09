import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/stories/story_checker.dart';
import 'package:mafia_master/stories/story_model.dart';

void main() {
  final files = Directory(
    'assets/stories',
  ).listSync().whereType<File>().where((file) => file.path.endsWith('.json'));

  // Authored stories whose JSON still has a shared search that yields no clue
  // for a small table (the app hides such a search). Content owner: fix the
  // data, then empty this set; a NEW offender fails the test.
  const knownEmptySearches = {
    '2asr_garden_city',
    'mahal_el_dahab',
    'matba3et_el_gornal',
    'shoqaq_el_tamleek',
    'waraqet_el_yanaseeb',
  };
  bool emptySearch(StoryCheckIssue i) => i.message.contains('yields no clue');

  for (final file in files) {
    test('${file.path} is uniquely solvable for player counts 1-10', () {
      final story = StoryDefinition.decode(file.readAsStringSync());
      final report = const StorySolvabilityChecker().check(story);
      final hard = report.issues.where((i) => !emptySearch(i)).toList();
      expect(hard, isEmpty, reason: hard.join('\n'));
      final empty = report.issues.where(emptySearch).toList();
      if (knownEmptySearches.contains(story.id)) {
        expect(empty, isNotEmpty, reason: 'fixed: drop it from the list');
      } else {
        expect(empty, isEmpty, reason: empty.join('\n'));
      }
    });
  }

  test('realism enumerates plays for every table size', () {
    final story = StoryDefinition.decode(
      File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
    );
    final rows = const StoryRealism().analyze(story);
    expect(rows, hasLength(10));
    // Solo: every affordable subset is enumerated, at least one solves it.
    expect(rows.first.total, greaterThan(1));
    expect(rows.first.deducing, greaterThan(0));
    expect(rows.every((r) => r.deducing <= r.total), isTrue);
  });

  test('rejects a story with fewer than three shared searches', () {
    final original = StoryDefinition.decode(
      File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
    );
    final thin = StoryDefinition(
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
      clues: original.clues,
      actions: original.actions.take(2).toList(),
    );
    expect(
      const StorySolvabilityChecker()
          .check(thin)
          .issues
          .any((i) => i.message.contains('shared investigation actions')),
      isTrue,
    );
  });

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
