import 'dart:convert';

/// A Stories V2 case: one setting whose culprit, cast and traces change with
/// the table (docs/plans/STORIES-WORLD-FORMAT.md). Pure data, no Flutter.
class StoryWorld {
  const StoryWorld({
    required this.id,
    required this.title,
    required this.category,
    required this.victimName,
    required this.victimTag,
    required this.opening,
    required this.openingAudio,
    required this.detective,
    required this.marks,
    required this.places,
    required this.baseFacts,
    required this.suspects,
  });

  final String id;
  final String title;
  final String category;
  final String victimName;
  final String victimTag;

  /// The narrator's words, true in every version.
  final String opening;
  final String? openingAudio;
  final WorldPerson detective;

  /// What can stick to a person's hands tonight; every suspect carries two.
  final List<WorldMark> marks;
  final List<WorldPlace> places;
  final List<String> baseFacts;
  final List<WorldSuspect> suspects;

  WorldSuspect suspect(String id) => suspects.firstWhere((s) => s.id == id);
  WorldPlace place(String id) => places.firstWhere((p) => p.id == id);

  /// The only world format the engine reads (docs/plans/STORIES-WORLD-FORMAT.md).
  static const formatVersion = 3;

  static StoryWorld decode(String source) =>
      StoryWorld.fromJson(_map(jsonDecode(source), 'world'));

  factory StoryWorld.fromJson(Map<String, Object?> json) {
    if (json['format'] != formatVersion) {
      throw FormatException(
        'not a format $formatVersion story world (format: ${json['format']})',
      );
    }
    final victim = _map(json['victim'], 'victim');
    return StoryWorld(
      id: _str(json, 'id'),
      title: _str(json, 'title'),
      category: _str(json, 'category'),
      victimName: _str(victim, 'name'),
      victimTag: _str(victim, 'tag'),
      opening: _str(json, 'opening'),
      openingAudio: json['openingAudio'] as String?,
      detective: WorldPerson.fromJson(_map(json['detective'], 'detective')),
      marks: [
        for (final m in _list(json, 'marks'))
          WorldMark.fromJson(_map(m, 'mark')),
      ],
      places: [
        for (final p in _list(json, 'places'))
          WorldPlace.fromJson(_map(p, 'place')),
      ],
      baseFacts: [for (final f in _list(json, 'baseFacts')) f as String],
      suspects: [
        for (final s in _list(json, 'suspects'))
          WorldSuspect.fromJson(_map(s, 'suspect')),
      ],
    );
  }
}

enum WorldGender { male, female }

/// The detective: an in-story person, never an outsider.
class WorldPerson {
  const WorldPerson({
    required this.name,
    required this.gender,
    required this.tag,
    required this.image,
    required this.card,
    required this.goal,
  });

  final String name;
  final WorldGender gender;
  final String tag;
  final String image;
  final String card;
  final String goal;

  factory WorldPerson.fromJson(Map<String, Object?> json) => WorldPerson(
    name: _str(json, 'name'),
    gender: _gender(json),
    tag: _str(json, 'tag'),
    image: _str(json, 'image'),
    card: _str(json, 'card'),
    goal: _str(json, 'goal'),
  );
}

class WorldPlace {
  const WorldPlace({
    required this.id,
    required this.name,
    required this.line,
    required this.baseTrace,
  });

  final String id;
  final String name;
  final String line;

  /// What the place shows in every version; empty when it shows nothing but
  /// what the assembled version puts there.
  final String baseTrace;

  factory WorldPlace.fromJson(Map<String, Object?> json) => WorldPlace(
    id: _str(json, 'id'),
    name: _str(json, 'name'),
    line: _str(json, 'line'),
    baseTrace: _text(json, 'baseTrace'),
  );
}

/// Something that sticks to a person's hands from somewhere he went tonight.
class WorldMark {
  const WorldMark({required this.id, required this.name, required this.words});

  final String id;
  final String name;

  /// The exact phrases that name the mark inside trace texts.
  final List<String> words;

  factory WorldMark.fromJson(Map<String, Object?> json) => WorldMark(
    id: _str(json, 'id'),
    name: _str(json, 'name'),
    words: _strings(json, 'words'),
  );
}

class WorldTrace {
  const WorldTrace({
    required this.placeId,
    required this.text,
    required this.marks,
  });

  final String placeId;
  final String text;

  /// The mark ids this line names; a culprit's trace shows only marks he has.
  final List<String> marks;

  factory WorldTrace.fromJson(Map<String, Object?> json) => WorldTrace(
    placeId: _str(json, 'place'),
    text: _str(json, 'text'),
    marks: [for (final m in (json['marks'] as List? ?? const [])) m as String],
  );
}

/// Something found against a suspect that is true in every version and
/// appears whenever he is seated, guilty or not.
class WorldSuspicion {
  const WorldSuspicion({required this.placeId, required this.text});

  final String placeId;
  final String text;

  factory WorldSuspicion.fromJson(Map<String, Object?> json) =>
      WorldSuspicion(placeId: _str(json, 'place'), text: _str(json, 'text'));
}

class WorldSuspect {
  const WorldSuspect({
    required this.id,
    required this.name,
    required this.gender,
    required this.tag,
    required this.image,
    required this.card,
    required this.goal,
    required this.hook,
    required this.marks,
    required this.suspicion,
    required this.guilty,
  });

  final String id;
  final String name;
  final WorldGender gender;
  final String tag;
  final String image;

  /// Read aloud by his player; true whether or not he did it.
  final String card;
  final String goal;

  /// Why people suspect him, read in the case facts; true in every version.
  final String hook;

  /// The two mark ids on his hands tonight; his card says why in plain words.
  final List<String> marks;

  /// Found against him in every version, whether or not he did it.
  final WorldSuspicion suspicion;
  final WorldGuilt guilty;

  factory WorldSuspect.fromJson(Map<String, Object?> json) {
    return WorldSuspect(
      id: _str(json, 'id'),
      name: _str(json, 'name'),
      gender: _gender(json),
      tag: _str(json, 'tag'),
      image: _str(json, 'image'),
      card: _str(json, 'card'),
      goal: _str(json, 'goal'),
      hook: _str(json, 'hook'),
      marks: _strings(json, 'marks'),
      suspicion: WorldSuspicion.fromJson(_map(json['suspicion'], 'suspicion')),
      guilty: WorldGuilt.fromJson(_map(json['guilty'], 'guilty')),
    );
  }
}

class WorldLabel {
  const WorldLabel(this.id, this.label);

  final String id;
  final String label;

  factory WorldLabel.fromJson(Map<String, Object?> json) =>
      WorldLabel(_str(json, 'id'), _str(json, 'label'));
}

/// The version where this suspect did it.
class WorldGuilt {
  const WorldGuilt({
    required this.motive,
    required this.method,
    required this.traces,
    required this.reveal,
    this.partner,
  });

  final WorldLabel motive;
  final WorldLabel method;
  final List<WorldTrace> traces;
  final String reveal;
  final WorldPartnership? partner;

  factory WorldGuilt.fromJson(Map<String, Object?> json) {
    final partner = json['partner'];
    return WorldGuilt(
      motive: WorldLabel.fromJson(_map(json['motive'], 'motive')),
      method: WorldLabel.fromJson(_map(json['method'], 'method')),
      traces: [
        for (final t in _list(json, 'traces'))
          WorldTrace.fromJson(_map(t, 'trace')),
      ],
      reveal: _str(json, 'reveal'),
      partner: partner == null
          ? null
          : WorldPartnership.fromJson(_map(partner, 'partner')),
    );
  }
}

/// Read so the checker can refuse it: format 3 worlds have no partners.
class WorldPartnership {
  const WorldPartnership({
    required this.partnerId,
    required this.traces,
    required this.reveal,
  });

  final String partnerId;
  final List<WorldTrace> traces;
  final String reveal;

  factory WorldPartnership.fromJson(Map<String, Object?> json) =>
      WorldPartnership(
        partnerId: _str(json, 'id'),
        traces: [
          for (final t in _list(json, 'traces'))
            WorldTrace.fromJson(_map(t, 'trace')),
        ],
        reveal: _str(json, 'reveal'),
      );
}

Map<String, Object?> _map(Object? value, String what) {
  if (value is Map) return Map<String, Object?>.from(value);
  throw FormatException('$what is not an object');
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw FormatException('$key is not a list');
}

String _str(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$key is missing');
}

/// A string that may be empty (or absent, which reads as empty).
String _text(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return '';
  if (value is String) return value;
  throw FormatException('$key is not text');
}

List<String> _strings(Map<String, Object?> json, String key) => [
  for (final v in _list(json, key))
    if (v is String) v else throw FormatException('$key holds a non-text item'),
];

WorldGender _gender(Map<String, Object?> json) =>
    json['gender'] == 'f' ? WorldGender.female : WorldGender.male;
