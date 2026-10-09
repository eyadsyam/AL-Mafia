import 'story_model.dart';

class StoryCheckIssue {
  const StoryCheckIssue(this.storyId, this.playerCount, this.message);

  final String storyId;
  final int? playerCount;
  final String message;

  @override
  String toString() =>
      '$storyId${playerCount == null ? '' : ' [$playerCount players]'}: $message';
}

class StoryCheckReport {
  const StoryCheckReport({required this.storyId, required this.issues});

  final String storyId;
  final List<StoryCheckIssue> issues;

  bool get passed => issues.isEmpty;
}

/// Exhaustive finite-domain proof for one authored story.
///
/// The checker intentionally knows no Arabic and invents no facts. It only
/// intersects the explicit `excludes` tags carried by the authored clue cards.
class StorySolvabilityChecker {
  const StorySolvabilityChecker();

  StoryCheckReport check(StoryDefinition story) {
    final issues = <StoryCheckIssue>[];
    final characterIds = story.characters.map((value) => value.id).toSet();
    final motiveIds = story.motives.map((value) => value.id).toSet();
    final methodIds = story.methods.map((value) => value.id).toSet();
    final clueIds = story.clues.map((value) => value.id).toSet();

    void require(bool condition, String message) {
      if (!condition) issues.add(StoryCheckIssue(story.id, null, message));
    }

    require(story.characters.length >= 10, 'needs at least ten characters');
    require(story.truth.culprits.isNotEmpty, 'truth has no culprit');
    require(
      characterIds.contains(story.truth.primaryCulprit),
      'primary culprit is not a character',
    );
    require(
      story.truth.culprits.every(characterIds.contains),
      'truth names an unknown culprit',
    );
    require(
      story.truth.involvedCharacters.every(characterIds.contains),
      'group involvement names an unknown character',
    );
    require(motiveIds.contains(story.truth.motive), 'truth motive is unknown');
    require(methodIds.contains(story.truth.method), 'truth method is unknown');
    require(clueIds.length == story.clues.length, 'duplicate clue id');
    require(
      story.clues.every(
        (clue) => clue.proves.isNotEmpty && clue.buckets.isNotEmpty,
      ),
      'every clue must say what it proves and name at least one bucket',
    );
    require(
      story.actions.expand((action) => action.clueIds).every(clueIds.contains),
      'an investigation action names an unknown clue',
    );
    require(
      story.characters.every(
        (character) =>
            character.privateClueIds.length == 3 &&
            character.privateClueIds.every(clueIds.contains),
      ),
      'every character needs three valid private round clues',
    );

    require(
      story.actions.length >= StoryRealism.rounds,
      'needs at least ${StoryRealism.rounds} shared investigation actions',
    );
    for (final bucket in StoryBucket.values) {
      if (bucket == StoryBucket.solo) continue;
      for (final action in story.actions) {
        final yields = action.clueIds
            .where(clueIds.contains)
            .any((id) => story.clue(id).buckets.contains(bucket));
        require(
          yields,
          'shared action ${action.id} yields no clue for bucket ${bucket.key}',
        );
      }
    }

    for (var playerCount = 1; playerCount <= 10; playerCount++) {
      final clues = story.availableClues(playerCount);
      if (clues.isEmpty) {
        issues.add(
          StoryCheckIssue(story.id, playerCount, 'no clues are available'),
        );
        continue;
      }
      final solutions = <({String culprit, String motive, String method})>[];
      for (final culprit in characterIds) {
        for (final motive in motiveIds) {
          for (final method in methodIds) {
            if (_survives(clues, culprit, motive, method)) {
              solutions.add((culprit: culprit, motive: motive, method: method));
            }
          }
        }
      }
      final expected = (
        culprit: story.truth.primaryCulprit,
        motive: story.truth.motive,
        method: story.truth.method,
      );
      if (solutions.length != 1 || solutions.singleOrNull != expected) {
        final sample = solutions
            .take(4)
            .map((s) => '${s.culprit}/${s.motive}/${s.method}');
        issues.add(
          StoryCheckIssue(
            story.id,
            playerCount,
            'not uniquely deducible: ${solutions.length} solutions '
            '(${sample.join(', ')})',
          ),
        );
      }
      for (final clue in clues) {
        final remaining = characterIds
            .where((id) => !clue.excludes.culprits.contains(id))
            .length;
        if (remaining <= 1) {
          issues.add(
            StoryCheckIssue(
              story.id,
              playerCount,
              'clue ${clue.id} reveals the culprit alone',
            ),
          );
        }
      }
    }
    // Analyze actual play only after validating all referenced content.
    if (issues.isEmpty) {
      for (final row in const StoryRealism().analyze(story)) {
        if (row.impossible) {
          issues.add(
            StoryCheckIssue(
              story.id,
              row.playerCount,
              'not deducible within the solo budget or three shared picks '
              '(0/${row.total} plays)',
            ),
          );
        }
      }
    }
    return StoryCheckReport(storyId: story.id, issues: issues);
  }

  bool _survives(
    List<StoryClue> clues,
    String culprit,
    String motive,
    String method,
  ) => clues.every(
    (clue) =>
        !clue.excludes.culprits.contains(culprit) &&
        !clue.excludes.motives.contains(motive) &&
        !clue.excludes.methods.contains(method),
  );
}

/// How many of the ways a real table can play still pin the answer down.
class StoryRealismRow {
  const StoryRealismRow({
    required this.storyId,
    required this.playerCount,
    required this.deducing,
    required this.total,
  });

  final String storyId;
  final int playerCount;

  /// Plays (action subsets / 3-pick combinations) that leave exactly the
  /// true culprit + motive + method standing.
  final int deducing;
  final int total;

  /// No play at all can solve it at this table size.
  bool get impossible => deducing == 0;

  /// Some plays can, some cannot.
  bool get partial => deducing > 0 && deducing < total;
}

/// Realism: the exhaustive check above assumes every clue is on the table.
/// A real player has a budget (solo) or three searches (group), so this
/// enumerates the plays and counts which still deduce the truth. The checker
/// rejects impossible rows; partial rows remain diagnostic (solo includes
/// stopping early, even without investigating).
class StoryRealism {
  const StoryRealism();

  static const rounds = 3;

  List<StoryRealismRow> analyze(StoryDefinition story) => [
    for (var n = 1; n <= 10; n++) _row(story, n),
  ];

  StoryRealismRow _row(StoryDefinition story, int playerCount) {
    final bucket = StoryBucket.forPlayers(playerCount);
    bool appears(String id) => story.clue(id).buckets.contains(bucket);
    final base = <String>{};
    final List<List<StoryInvestigationAction>> plays;
    if (playerCount == 1) {
      plays = _affordable(story.actions, story.actionBudget);
    } else {
      for (final c in story.characters.take(playerCount)) {
        base.addAll(c.privateClueIds.where(appears));
      }
      final usable = story.sharedActions(playerCount);
      plays = _combinations(usable, rounds);
    }
    var deducing = 0;
    for (final play in plays) {
      final ids = {
        ...base,
        for (final action in play) ...action.clueIds.where(appears),
      };
      if (_solves(story, [for (final id in ids) story.clue(id)])) deducing++;
    }
    return StoryRealismRow(
      storyId: story.id,
      playerCount: playerCount,
      deducing: deducing,
      total: plays.length,
    );
  }

  List<List<StoryInvestigationAction>> _affordable(
    List<StoryInvestigationAction> actions,
    int budget,
  ) {
    final out = <List<StoryInvestigationAction>>[];
    for (var mask = 0; mask < 1 << actions.length; mask++) {
      final picked = [
        for (var i = 0; i < actions.length; i++)
          if (mask & (1 << i) != 0) actions[i],
      ];
      if (picked.fold<int>(0, (t, a) => t + a.cost) <= budget) out.add(picked);
    }
    return out;
  }

  List<List<StoryInvestigationAction>> _combinations(
    List<StoryInvestigationAction> actions,
    int size,
  ) {
    if (actions.length <= size) return [actions];
    final out = <List<StoryInvestigationAction>>[];
    void walk(int start, List<StoryInvestigationAction> chosen) {
      if (chosen.length == size) {
        out.add(List.of(chosen));
        return;
      }
      for (var i = start; i < actions.length; i++) {
        walk(i + 1, [...chosen, actions[i]]);
      }
    }

    walk(0, const []);
    return out;
  }

  bool _solves(StoryDefinition story, List<StoryClue> clues) {
    var count = 0;
    var match = false;
    for (final c in story.characters) {
      for (final m in story.motives) {
        for (final h in story.methods) {
          final alive = clues.every(
            (clue) =>
                !clue.excludes.culprits.contains(c.id) &&
                !clue.excludes.motives.contains(m.id) &&
                !clue.excludes.methods.contains(h.id),
          );
          if (!alive) continue;
          count++;
          if (c.id == story.truth.primaryCulprit &&
              m.id == story.truth.motive &&
              h.id == story.truth.method) {
            match = true;
          }
          if (count > 1) return false;
        }
      }
    }
    return count == 1 && match;
  }
}
