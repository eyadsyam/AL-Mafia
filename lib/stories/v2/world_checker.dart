import 'world.dart';

/// Checker V3: the rules of docs/plans/STORIES-WORLD-FORMAT.md that a machine
/// can prove. Human review still reads every card against all ten versions
/// (and checks that every name in a text is the victim, the detective or a
/// suspect: a name cannot be recognised by a program).
class StoryWorldChecker {
  const StoryWorldChecker();

  static const suspectCount = 10;
  static const placeCount = 5;
  static const markCount = 5;
  static const marksPerSuspect = 2;
  static const searches = 3;
  static const maxCardSentences = 3;
  static const maxTraceSentences = 2;
  static const maxSuspicionSentences = 2;
  static const hookSentences = 1;
  static const maxRevealSentences = 6;

  static final _clock = RegExp(
    r'[0-9٠-٩]+\s*(دقيق|دقايق|ثاني|ثواني|ساع)|[0-9٠-٩]{1,2}\s*[:٫]\s*[0-9٠-٩]{2}',
  );
  static final _latin = RegExp('[A-Za-z]');
  static final _sentenceEnd = RegExp('[.!؟?]+');

  List<String> check(StoryWorld world) {
    final problems = <String>[];
    final places = {for (final p in world.places) p.id};
    final markIds = {for (final m in world.marks) m.id};
    final markWords = <String, List<String>>{
      for (final m in world.marks) m.id: m.words,
    };
    final allWords = [for (final m in world.marks) ...m.words];

    if (world.suspects.length != suspectCount) {
      problems.add(
        'needs $suspectCount suspects, has ${world.suspects.length}',
      );
    }
    if (world.places.length != placeCount) {
      problems.add('needs $placeCount places, has ${world.places.length}');
    }
    if (world.marks.length != markCount) {
      problems.add('needs $markCount marks, has ${world.marks.length}');
    }
    if (markIds.length != world.marks.length) {
      problems.add('two marks share an id');
    }
    if (places.length != world.places.length) {
      problems.add('two places share an id');
    }
    if ({for (final s in world.suspects) s.id}.length !=
        world.suspects.length) {
      problems.add('two suspects share an id');
    }
    for (final m in world.marks) {
      if (m.words.isEmpty || m.words.any((w) => w.trim().isEmpty)) {
        problems.add('mark ${m.id}: needs at least one non-empty word');
      }
    }

    final texts = <(String, String)>[
      ('opening', world.opening),
      ('detective.card', world.detective.card),
      ('detective.goal', world.detective.goal),
      for (final m in world.marks) ('mark.${m.id}.name', m.name),
      for (final p in world.places) ...[
        ('${p.id}.line', p.line),
        ('${p.id}.baseTrace', p.baseTrace),
      ],
      for (final f in world.baseFacts) ('baseFact', f),
    ];
    if (_sentences(world.detective.card) > maxCardSentences) {
      problems.add(
        'detective: card is longer than $maxCardSentences sentences',
      );
    }

    // Each suspect's mark pair, to find two suspects that share one.
    final pairs = <String, String>{};
    for (final s in world.suspects) {
      texts.addAll([
        ('${s.id}.card', s.card),
        ('${s.id}.goal', s.goal),
        ('${s.id}.hook', s.hook),
        ('${s.id}.suspicion', s.suspicion.text),
        ('${s.id}.motive', s.guilty.motive.label),
        ('${s.id}.method', s.guilty.method.label),
        ('${s.id}.reveal', s.guilty.reveal),
      ]);

      // His hands.
      final own = s.marks.toSet();
      final pairKey = (own.toList()..sort()).join('+');
      if (s.marks.length != marksPerSuspect ||
          own.length != marksPerSuspect ||
          own.any((m) => !markIds.contains(m))) {
        problems.add(
          '${s.id}: needs $marksPerSuspect distinct known marks, '
          'has ${s.marks}',
        );
      } else {
        final other = pairs[pairKey];
        if (other != null) {
          problems.add('${s.id}: has the same marks as $other ($pairKey)');
        } else {
          pairs[pairKey] = s.id;
        }
      }

      // What is found against him in every version.
      if (!places.contains(s.suspicion.placeId)) {
        problems.add(
          '${s.id}: suspicion in unknown place ${s.suspicion.placeId}',
        );
      }
      if (_sentences(s.suspicion.text) > maxSuspicionSentences) {
        problems.add(
          '${s.id}: suspicion is longer than $maxSuspicionSentences sentences',
        );
      }
      for (final (where, text) in [
        ('suspicion', s.suspicion.text),
        ('card', s.card),
        ('hook', s.hook),
        ('goal', s.goal),
      ]) {
        final leaked = allWords.where(text.contains).toList();
        if (leaked.isNotEmpty) {
          problems.add('${s.id}: $where names a mark: ${leaked.first}');
        }
      }
      if (_sentences(s.card) > maxCardSentences) {
        problems.add(
          '${s.id}: card is longer than $maxCardSentences sentences',
        );
      }
      if (_sentences(s.hook) != hookSentences) {
        problems.add('${s.id}: hook must be $hookSentences sentence');
      }
      if (_sentences(s.guilty.reveal) > maxRevealSentences) {
        problems.add(
          '${s.id}: reveal is longer than $maxRevealSentences sentences',
        );
      }

      // His guilty version.
      final traces = s.guilty.traces;
      final tracePlaces = {for (final t in traces) t.placeId};
      if (traces.length != placeCount ||
          tracePlaces.length != placeCount ||
          !tracePlaces.containsAll(places)) {
        problems.add(
          '${s.id}: guilty version needs exactly one trace in each of the '
          '$placeCount places',
        );
      }
      for (final t in traces) {
        texts.add(('${s.id}.trace', t.text));
        if (!places.contains(t.placeId)) {
          problems.add('${s.id}: trace in unknown place ${t.placeId}');
        }
        if (t.marks.isEmpty) {
          problems.add('${s.id}: a trace in ${t.placeId} carries no mark');
        }
        for (final m in t.marks) {
          if (!own.contains(m)) {
            problems.add(
              '${s.id}: a trace in ${t.placeId} carries $m, '
              'which is not on his hands',
            );
          }
        }
        for (final entry in markWords.entries) {
          final listed = t.marks.contains(entry.key);
          final named = entry.value.any(t.text.contains);
          if (listed && !named) {
            problems.add(
              '${s.id}: the trace in ${t.placeId} lists ${entry.key} '
              'but its text never names it',
            );
          } else if (!listed && named) {
            problems.add(
              '${s.id}: the trace in ${t.placeId} names ${entry.key} '
              'but does not list it',
            );
          }
        }
        if (_sentences(t.text) > maxTraceSentences) {
          problems.add(
            '${s.id}: a trace is longer than $maxTraceSentences sentences',
          );
        }
      }

      final partner = s.guilty.partner;
      if (partner != null) {
        problems.add('${s.id}: format 3 has no partners');
        for (final t in partner.traces) {
          texts.add(('${s.id}.partnerTrace', t.text));
        }
        texts.add(('${s.id}.partnerReveal', partner.reveal));
      }
    }

    // Fairness: any three searches find marks that add up to the culprit's
    // pair and to no one else's.
    for (final s in world.suspects) {
      problems.addAll(_fairness(world, s));
    }

    for (final (where, text) in texts) {
      final clock = _clock.firstMatch(text);
      if (clock != null) problems.add('clock time in $where: ${clock[0]}');
      if (_latin.hasMatch(text)) problems.add('latin letters in $where');
    }
    return problems;
  }

  /// Format rule: for every choice of [searches] places, the marks of the
  /// culprit's traces found there make up his pair, and only he holds them.
  static List<String> _fairness(StoryWorld world, WorldSuspect culprit) {
    final problems = <String>[];
    final ids = [for (final p in world.places) p.id];
    final own = culprit.marks.toSet();
    for (var a = 0; a < ids.length; a++) {
      for (var b = a + 1; b < ids.length; b++) {
        for (var c = b + 1; c < ids.length; c++) {
          final path = {ids[a], ids[b], ids[c]};
          final found = <String>{
            for (final t in culprit.guilty.traces)
              if (path.contains(t.placeId)) ...t.marks,
          };
          final label = '${culprit.id}: searching ${path.join(', ')}';
          if (found.length != own.length || !found.containsAll(own)) {
            problems.add(
              '$label finds marks ${_sorted(found)}, '
              'not his ${_sorted(own)}',
            );
          }
          final fits = [
            for (final s in world.suspects)
              if (s.marks.toSet().containsAll(found)) s.id,
          ];
          if (fits.length != 1 || fits.single != culprit.id) {
            problems.add(
              '$label leaves ${fits.length} suspects: ${fits.join(', ')}',
            );
          }
        }
      }
    }
    return problems;
  }

  static String _sorted(Set<String> ids) =>
      '{${(ids.toList()..sort()).join(', ')}}';

  static int _sentences(String text) =>
      text.split(_sentenceEnd).where((s) => s.trim().isNotEmpty).length;
}
