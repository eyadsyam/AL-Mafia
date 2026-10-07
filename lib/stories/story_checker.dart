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
