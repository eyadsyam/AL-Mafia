import 'dart:convert';
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

  test(
    'rejects full evidence that cannot be reached within the solo budget',
    () {
      final json =
          jsonDecode(
                File(
                  'assets/stories/qahwet_el_moallem.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      json['actionBudget'] = 0;
      final story = StoryDefinition.decode(jsonEncode(json));
      final report = const StorySolvabilityChecker().check(story);
      expect(
        report.issues.any(
          (i) => i.playerCount == 1 && i.message.contains('not deducible'),
        ),
        isTrue,
      );
    },
  );

  test('rejects full evidence requiring four group searches', () {
    final json =
        jsonDecode(
              File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final character in json['characters'] as List) {
      character['privateClueIds'] = [
        'flavor_torn_label',
        'flavor_domino',
        'flavor_lighter',
      ];
    }
    final actions = json['actions'] as List;
    actions[0]['clueIds'] = ['culprit_lane'];
    actions[1]['clueIds'] = ['culprit_shift'];
    actions[2]['clueIds'] = ['culprit_coal'];
    actions[3]['clueIds'] = [
      'motive_ledger',
      'motive_voice_note',
      'method_clean_cup',
      'method_bowl_residue',
    ];
    final story = StoryDefinition.decode(jsonEncode(json));
    final rows = const StoryRealism().analyze(story);
    expect(rows.first.impossible, isFalse);
    expect(rows.skip(1).every((row) => row.impossible), isTrue);
    final report = const StorySolvabilityChecker().check(story);
    expect(report.issues, hasLength(9));
    expect(
      report.issues.every((i) => i.message.contains('not deducible')),
      isTrue,
    );
  });

  test('rejects a shared search empty in a small-table bucket', () {
    final json =
        jsonDecode(
              File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    (json['actions'] as List)[3]['clueIds'] = ['flavor_receipt'];
    final story = StoryDefinition.decode(jsonEncode(json));
    final report = const StorySolvabilityChecker().check(story);
    expect(
      report.issues.any(
        (i) =>
            i.message == 'shared action timeline yields no clue for bucket 2',
      ),
      isTrue,
    );
  });

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
