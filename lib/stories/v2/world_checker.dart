import 'world.dart';

/// Checker V3: the rules of docs/plans/STORIES-WORLD-FORMAT.md that a machine
/// can prove. Human review still reads every card against all ten versions.
class StoryWorldChecker {
  const StoryWorldChecker();

  static const suspectCount = 10;
  static const placeCount = 5;
  static const searches = 3;
  static const maxCardSentences = 3;
  static const maxTraceSentences = 2;

  static final _clock = RegExp(
    r'[0-9٠-٩]+\s*(دقيق|دقايق|ثاني|ثواني|ساع)|[0-9٠-٩]{1,2}\s*[:٫]\s*[0-9٠-٩]{2}',
  );
  static final _latin = RegExp('[A-Za-z]');
  static final _sentenceEnd = RegExp('[.!؟?]+');

  List<String> check(StoryWorld world) {
    final problems = <String>[];
    final ids = {for (final s in world.suspects) s.id};
    final places = {for (final p in world.places) p.id};

    if (world.suspects.length != suspectCount) {
      problems.add(
        'needs $suspectCount suspects, has ${world.suspects.length}',
      );
    }
    if (world.places.length != placeCount) {
      problems.add('needs $placeCount places, has ${world.places.length}');
    }

    final texts = <(String, String)>[
      ('opening', world.opening),
      ('detective.card', world.detective.card),
      ('detective.goal', world.detective.goal),
      for (final p in world.places) ...[
        ('${p.id}.line', p.line),
        ('${p.id}.baseTrace', p.baseTrace),
      ],
      for (final f in world.baseFacts) ('baseFact', f),
    ];

    for (final s in world.suspects) {
      texts.addAll([
        ('${s.id}.card', s.card),
        ('${s.id}.goal', s.goal),
        ('${s.id}.hook', s.hook),
        ('${s.id}.innocent', s.innocentTrace.text),
        ('${s.id}.reveal', s.guilty.reveal),
      ]);
      final alibi = s.innocentTrace;
      if (!places.contains(alibi.placeId)) {
        problems.add('${s.id}: alibi in unknown place ${alibi.placeId}');
      }
      if (alibi.excludes.length != 1 || alibi.excludes.single != s.id) {
        problems.add('${s.id}: an alibi clears its own suspect only');
      }
      if (_sentences(s.card) > maxCardSentences) {
        problems.add(
          '${s.id}: card is longer than $maxCardSentences sentences',
        );
      }

      final traces = s.guilty.traces;
      final tracePlaces = {for (final t in traces) t.placeId};
      if (traces.length != searches || tracePlaces.length != searches) {
        problems.add(
          '${s.id}: guilty version needs $searches traces in $searches places',
        );
      }
      final partner = s.guilty.partner;
      for (final t in [...traces, ...?partner?.traces]) {
        texts.add(('${s.id}.trace', t.text));
        if (!places.contains(t.placeId)) {
          problems.add('${s.id}: trace in unknown place ${t.placeId}');
        }
        if (t.excludes.contains(s.id) ||
            (partner != null && t.excludes.contains(partner.partnerId))) {
          problems.add('${s.id}: a guilty trace rules out a culprit');
        }
        if (t.excludes.any((e) => !ids.contains(e))) {
          problems.add('${s.id}: a trace rules out an unknown suspect');
        }
        if (_sentences(t.text) > maxTraceSentences) {
          problems.add(
            '${s.id}: a trace is longer than $maxTraceSentences sentences',
          );
        }
      }
      if (partner != null) {
        texts.add(('${s.id}.partnerReveal', partner.reveal));
        if (!ids.contains(partner.partnerId) || partner.partnerId == s.id) {
          problems.add('${s.id}: unknown partner ${partner.partnerId}');
        }
      }
      if (!_everyPathFinds(tracePlaces, places)) {
        problems.add('${s.id}: some three searches miss every trace of his');
      }
    }

    for (final (where, text) in texts) {
      final clock = _clock.firstMatch(text);
      if (clock != null) problems.add('clock time in $where: ${clock[0]}');
      if (_latin.hasMatch(text)) problems.add('latin letters in $where');
    }
    return problems;
  }

  /// Format rule 8: any [searches] places out of the world's places meet at
  /// least one of the culprit's.
  static bool _everyPathFinds(Set<String> tracePlaces, Set<String> places) {
    final all = places.toList();
    for (var a = 0; a < all.length; a++) {
      for (var b = a + 1; b < all.length; b++) {
        for (var c = b + 1; c < all.length; c++) {
          if (!{all[a], all[b], all[c]}.any(tracePlaces.contains)) return false;
        }
      }
    }
    return true;
  }

  static int _sentences(String text) =>
      text.split(_sentenceEnd).where((s) => s.trim().isNotEmpty).length;
}
