import 'dart:convert';

/// The six hand-authored player-count variants shared by every story.
enum StoryBucket {
  solo('1', 1, 1),
  duo('2', 2, 2),
  small('3-4', 3, 4),
  medium('5-6', 5, 6),
  large('7-8', 7, 8),
  full('9-10', 9, 10);

  const StoryBucket(this.key, this.minimum, this.maximum);

  final String key;
  final int minimum;
  final int maximum;

  static StoryBucket forPlayers(int count) {
    if (count < 1 || count > 10) {
      throw RangeError.range(count, 1, 10, 'playerCount');
    }
    return values.firstWhere(
      (bucket) => count >= bucket.minimum && count <= bucket.maximum,
    );
  }

  static StoryBucket fromKey(String value) =>
      values.firstWhere((bucket) => bucket.key == value);
}

class StoryTruth {
  const StoryTruth({
    required this.culprits,
    required this.primaryCulprit,
    required this.involvedCharacters,
    required this.motive,
    required this.method,
    required this.timeline,
  });

  final List<String> culprits;
  final String primaryCulprit;
  final List<String> involvedCharacters;
  final String motive;
  final String method;
  final List<StoryTimelineBeat> timeline;

  factory StoryTruth.fromJson(Map<String, Object?> json) => StoryTruth(
    culprits: _strings(json['culprits']),
    primaryCulprit: json['primaryCulprit']! as String,
    involvedCharacters: _strings(json['involvedCharacters']),
    motive: json['motive']! as String,
    method: json['method']! as String,
    timeline: _maps(json['timeline']).map(StoryTimelineBeat.fromJson).toList(),
  );
}

class StoryTimelineBeat {
  const StoryTimelineBeat({required this.time, required this.text});

  final String time;
  final String text;

  factory StoryTimelineBeat.fromJson(Map<String, Object?> json) =>
      StoryTimelineBeat(
        time: json['time']! as String,
        text: json['text']! as String,
      );
}

class StoryOption {
  const StoryOption({required this.id, required this.label});

  final String id;
  final String label;

  factory StoryOption.fromJson(Map<String, Object?> json) =>
      StoryOption(id: json['id']! as String, label: json['label']! as String);
}

class StoryCharacter {
  const StoryCharacter({
    required this.id,
    required this.name,
    required this.image,
    required this.background,
    required this.objective,
    required this.privateClueIds,
  });

  final String id;
  final String name;
  final String image;
  final String background;
  final String objective;

  /// Exactly one private clue per round. The hand is authored, never generated.
  final List<String> privateClueIds;

  factory StoryCharacter.fromJson(Map<String, Object?> json) => StoryCharacter(
    id: json['id']! as String,
    name: json['name']! as String,
    image: json['image']! as String,
    background: json['background']! as String,
    objective: json['objective']! as String,
    privateClueIds: _strings(json['privateClueIds']),
  );
}

class StoryLocation {
  const StoryLocation({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;

  factory StoryLocation.fromJson(Map<String, Object?> json) => StoryLocation(
    id: json['id']! as String,
    name: json['name']! as String,
    description: json['description']! as String,
  );
}

class StoryExclusions {
  const StoryExclusions({
    this.culprits = const [],
    this.motives = const [],
    this.methods = const [],
  });

  final List<String> culprits;
  final List<String> motives;
  final List<String> methods;

  factory StoryExclusions.fromJson(Map<String, Object?> json) =>
      StoryExclusions(
        culprits: _strings(json['culprits']),
        motives: _strings(json['motives']),
        methods: _strings(json['methods']),
      );
}

class StoryClue {
  const StoryClue({
    required this.id,
    required this.title,
    required this.body,
    required this.proves,
    required this.excludes,
    required this.buckets,
  });

  final String id;
  final String title;
  final String body;
  final List<String> proves;
  final StoryExclusions excludes;
  final Set<StoryBucket> buckets;

  bool appearsFor(int playerCount) =>
      buckets.contains(StoryBucket.forPlayers(playerCount));

  factory StoryClue.fromJson(Map<String, Object?> json) => StoryClue(
    id: json['id']! as String,
    title: json['title']! as String,
    body: json['body']! as String,
    proves: _strings(json['proves']),
    excludes: StoryExclusions.fromJson(_map(json['excludes'])),
    buckets: _strings(json['buckets']).map(StoryBucket.fromKey).toSet(),
  );
}

class StoryInvestigationAction {
  const StoryInvestigationAction({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.clueIds,
  });

  final String id;
  final String title;
  final String description;
  final int cost;
  final List<String> clueIds;

  factory StoryInvestigationAction.fromJson(Map<String, Object?> json) =>
      StoryInvestigationAction(
        id: json['id']! as String,
        title: json['title']! as String,
        description: json['description']! as String,
        cost: json['cost']! as int,
        clueIds: _strings(json['clueIds']),
      );
}

class StoryDefinition {
  const StoryDefinition({
    required this.id,
    required this.number,
    required this.title,
    required this.category,
    required this.synopsis,
    required this.difficulty,
    required this.lengthMinutes,
    required this.coverImage,
    this.sceneImage,
    required this.actionBudget,
    required this.discussionSeconds,
    required this.characters,
    required this.locations,
    required this.motives,
    required this.methods,
    required this.truth,
    required this.clues,
    required this.actions,
  });

  final String id;
  final int number;
  final String title;
  final String category;
  final String synopsis;
  final int difficulty;
  final int lengthMinutes;
  final String coverImage;

  /// The painted location the story plays in, behind its screens; optional.
  final String? sceneImage;
  final int actionBudget;
  final int discussionSeconds;
  final List<StoryCharacter> characters;
  final List<StoryLocation> locations;
  final List<StoryOption> motives;
  final List<StoryOption> methods;
  final StoryTruth truth;
  final List<StoryClue> clues;
  final List<StoryInvestigationAction> actions;

  bool get isNearImpossible => difficulty >= 5;

  StoryCharacter character(String id) =>
      characters.firstWhere((value) => value.id == id);

  StoryClue clue(String id) => clues.firstWhere((value) => value.id == id);

  StoryInvestigationAction action(String id) =>
      actions.firstWhere((value) => value.id == id);

  List<StoryClue> availableClues(int playerCount) {
    final applicable = {
      for (final clue in clues)
        if (clue.appearsFor(playerCount)) clue.id: clue,
    };
    if (playerCount == 1) {
      final reachable = actions.expand((action) => action.clueIds).toSet();
      return [
        for (final clue in applicable.values)
          if (reachable.contains(clue.id)) clue,
      ];
    }
    final participants = characters.take(playerCount);
    final privateIds = participants
        .expand((character) => character.privateClueIds)
        .toSet();
    final sharedIds = actions.expand((action) => action.clueIds).toSet();
    return [
      for (final clue in applicable.values)
        if (privateIds.contains(clue.id) || sharedIds.contains(clue.id)) clue,
    ];
  }

  factory StoryDefinition.fromJson(
    Map<String, Object?> json,
  ) => StoryDefinition(
    id: json['id']! as String,
    number: json['number']! as int,
    title: json['title']! as String,
    category: json['category']! as String,
    synopsis: json['synopsis']! as String,
    difficulty: json['difficulty']! as int,
    lengthMinutes: json['lengthMinutes']! as int,
    coverImage: json['coverImage']! as String,
    sceneImage: json['sceneImage'] as String?,
    actionBudget: json['actionBudget']! as int,
    discussionSeconds: json['discussionSeconds']! as int,
    characters: _maps(json['characters']).map(StoryCharacter.fromJson).toList(),
    locations: _maps(json['locations']).map(StoryLocation.fromJson).toList(),
    motives: _maps(json['motives']).map(StoryOption.fromJson).toList(),
    methods: _maps(json['methods']).map(StoryOption.fromJson).toList(),
    truth: StoryTruth.fromJson(_map(json['truth'])),
    clues: _maps(json['clues']).map(StoryClue.fromJson).toList(),
    actions: _maps(
      json['actions'],
    ).map(StoryInvestigationAction.fromJson).toList(),
  );

  factory StoryDefinition.decode(String source) =>
      StoryDefinition.fromJson(jsonDecode(source) as Map<String, Object?>);
}

Map<String, Object?> _map(Object? value) =>
    (value as Map<Object?, Object?>).cast<String, Object?>();

List<Map<String, Object?>> _maps(Object? value) =>
    (value as List<Object?>).map(_map).toList();

List<String> _strings(Object? value) =>
    value == null ? const [] : (value as List<Object?>).cast<String>();
