import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/stories/story_progress.dart';

void main() {
  test('keeps best score and unlocks a category after three solved files', () {
    var progress = const StoryProgress();
    progress = progress.record(
      storyId: 'a',
      category: 'cat',
      score: 900,
      solved: true,
    );
    progress = progress.record(
      storyId: 'a',
      category: 'cat',
      score: 700,
      solved: true,
    );
    progress = progress.record(
      storyId: 'b',
      category: 'cat',
      score: 800,
      solved: true,
    );
    progress = progress.record(
      storyId: 'c',
      category: 'cat',
      score: 850,
      solved: true,
    );

    expect(progress.bestFor('a'), 900);
    expect(progress.solvedCount('cat'), 3);
    expect(progress.isNearImpossibleUnlocked('cat'), isTrue);
    expect(
      StoryProgress.fromJson(progress.toJson()).isNearImpossibleUnlocked('cat'),
      isTrue,
    );
  });

  test('an unsolved run never sets a best score', () {
    var progress = const StoryProgress().record(
      storyId: 'a',
      category: 'cat',
      score: 500,
      solved: false,
    );
    expect(progress.bestFor('a'), 0);
    expect(progress.solvedStoryIds, isEmpty);
    progress = progress.record(
      storyId: 'a',
      category: 'cat',
      score: 900,
      solved: true,
    );
    progress = progress.record(
      storyId: 'a',
      category: 'cat',
      score: 950,
      solved: false,
    );
    expect(progress.bestFor('a'), 900);
  });
}
