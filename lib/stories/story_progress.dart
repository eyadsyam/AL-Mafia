class StoryProgress {
  const StoryProgress({
    this.bestScores = const {},
    this.solvedStoryIds = const {},
    this.solvedByCategory = const {},
  });

  final Map<String, int> bestScores;
  final Set<String> solvedStoryIds;
  final Map<String, Set<String>> solvedByCategory;

  int bestFor(String storyId) => bestScores[storyId] ?? 0;

  int solvedCount(String category) => solvedByCategory[category]?.length ?? 0;

  bool isNearImpossibleUnlocked(String category) => solvedCount(category) >= 3;

  StoryProgress record({
    required String storyId,
    required String category,
    required int score,
    required bool solved,
  }) {
    final nextScores = Map<String, int>.of(bestScores);
    if (score > (nextScores[storyId] ?? 0)) nextScores[storyId] = score;
    final nextSolved = Set<String>.of(solvedStoryIds);
    final nextCategories = {
      for (final entry in solvedByCategory.entries)
        entry.key: Set<String>.of(entry.value),
    };
    if (solved) {
      nextSolved.add(storyId);
      (nextCategories[category] ??= <String>{}).add(storyId);
    }
    return StoryProgress(
      bestScores: nextScores,
      solvedStoryIds: nextSolved,
      solvedByCategory: nextCategories,
    );
  }

  Map<String, Object?> toJson() => {
    'bestScores': bestScores,
    'solvedStoryIds': solvedStoryIds.toList()..sort(),
    'solvedByCategory': {
      for (final entry in solvedByCategory.entries)
        entry.key: entry.value.toList()..sort(),
    },
  };

  factory StoryProgress.fromJson(Map<String, Object?> json) {
    final scores = (json['bestScores'] as Map<Object?, Object?>? ?? const {})
        .map((key, value) => MapEntry(key as String, value as int));
    final categories =
        (json['solvedByCategory'] as Map<Object?, Object?>? ?? const {}).map(
          (key, value) => MapEntry(
            key as String,
            (value as List<Object?>).cast<String>().toSet(),
          ),
        );
    return StoryProgress(
      bestScores: scores,
      solvedStoryIds: (json['solvedStoryIds'] as List<Object?>? ?? const [])
          .cast<String>()
          .toSet(),
      solvedByCategory: categories,
    );
  }
}
