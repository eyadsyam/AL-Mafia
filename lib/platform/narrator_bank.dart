import 'dart:convert';
import 'dart:math';

/// F16 — «صوت الراوي»: the spoken lines, and which one plays.
///
/// The bank is data (`assets/voice/<pack>/manifest.json`, written by
/// `tool/voice/install_kratos.py` from lines that passed the listener gate).
/// Each clip names a public-table [NarratorBeat], a condition on facts the
/// whole table can already see, and whether it is gentle enough for family
/// mode. An empty or missing bank is a silent narrator, never an error: the
/// words on screen carry every moment on their own.
///
/// ## Why the conditions cannot leak
///
/// A condition reads [NarrationFacts] only: how many died last night, how many
/// the vote removed, whether this is a revote, who won. Each is announced on
/// screen at the moment its line plays, and the caller constructs the facts
/// from the public view. There is no field for a role, a target or an actor.
enum NarratorBeat { night, morning, discussion, voting, result, win }

/// The pack the app speaks with at launch: the owner's «Kratos».
const narratorManifest = 'assets/voice/kratos/manifest.json';

/// What the table already knows when a beat plays.
class NarrationFacts {
  final int? nightEliminated;
  final int? dayEliminated;
  final int round;
  final bool revote;

  /// 'town' or 'mafia', and only once the result is on screen.
  final String? winner;

  const NarrationFacts({
    this.nightEliminated,
    this.dayEliminated,
    this.round = 1,
    this.revote = false,
    this.winner,
  });

  static const none = NarrationFacts();
}

class NarratorClip {
  final String id;
  final NarratorBeat beat;
  final String when;
  final bool family;

  /// Relative to `assets/`.
  final String file;

  const NarratorClip({
    required this.id,
    required this.beat,
    required this.when,
    required this.family,
    required this.file,
  });
}

class NarratorBank {
  final List<NarratorClip> clips;
  final Random _random;
  final Map<NarratorBeat, String> _last = {};

  NarratorBank(this.clips, {Random? random}) : _random = random ?? Random();

  static final empty = NarratorBank(const []);

  bool get isEmpty => clips.isEmpty;

  /// Reads a manifest. Unknown beats and malformed rows are skipped, so an
  /// older app reading a newer pack plays what it understands.
  factory NarratorBank.fromJson(String source, {Random? random}) {
    final json = jsonDecode(source);
    final rows = json is Map ? json['clips'] : null;
    final clips = <NarratorClip>[];
    for (final row in rows is List ? rows : const []) {
      if (row is! Map) continue;
      final beat = NarratorBeat.values
          .where((b) => b.name == row['beat'])
          .firstOrNull;
      final id = row['id'];
      final file = row['file'];
      final when = row['when'];
      if (beat == null || id is! String || file is! String || when is! String) {
        continue;
      }
      clips.add(
        NarratorClip(
          id: id,
          beat: beat,
          when: when,
          family: row['family'] == true,
          file: file,
        ),
      );
    }
    return NarratorBank(clips, random: random);
  }

  /// A clip for [beat] whose condition holds, never the same clip twice in a
  /// row for a beat when another would do. Null when nothing fits.
  NarratorClip? pick(
    NarratorBeat beat,
    NarrationFacts facts, {
    bool familyOnly = false,
  }) {
    final fits = [
      for (final c in clips)
        if (c.beat == beat &&
            (!familyOnly || c.family) &&
            conditionHolds(c.when, facts))
          c,
    ];
    if (fits.isEmpty) return null;
    final fresh = fits.length > 1
        ? fits.where((c) => c.id != _last[beat]).toList()
        : fits;
    final chosen = fresh[_random.nextInt(fresh.length)];
    _last[beat] = chosen.id;
    return chosen;
  }

  /// The line bank's small condition language: `always`, `revote`,
  /// `outside_match`, or `<fact> <==|>=> <value>`. Anything else is false —
  /// an unreadable condition never plays.
  static bool conditionHolds(String when, NarrationFacts facts) {
    final w = when.trim();
    if (w == 'always') return true;
    if (w == 'revote') return facts.revote;
    if (w == 'outside_match') return false;
    final m = RegExp(r'^(\w+)\s*(==|>=)\s*(\w+)$').firstMatch(w);
    if (m == null) return false;
    final name = m.group(1);
    final op = m.group(2);
    final value = m.group(3)!;
    if (name == 'winner') return op == '==' && facts.winner == value;
    final actual = switch (name) {
      'night_eliminated' => facts.nightEliminated,
      'day_eliminated' => facts.dayEliminated,
      'round' => facts.revote ? null : facts.round,
      _ => null,
    };
    final expected = int.tryParse(value);
    if (actual == null || expected == null) return false;
    return op == '==' ? actual == expected : actual >= expected;
  }
}
