import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/online_backend.dart';
import '../economy/economy_capabilities.dart';
import '../economy/wallet.dart';
import '../screens/online/online_session.dart';
import 'casebook_data.dart';

/// «قضية اليوم» — one small deduction case a day, the same for everyone
/// (docs/CASE-OF-DAY-CONTRACT.md). Fiction from end to end: nothing here is
/// read from, or written about, any real match.

int _int(Object? value, [int fallback = 0]) =>
    (value as num?)?.toInt() ?? fallback;

String _str(Object? value) => value is String ? value : '';

List<Map<String, dynamic>> _rows(Object? value) => [
  if (value is List)
    for (final row in value)
      if (row is Map) Map<String, dynamic>.from(row),
];

class Suspect {
  final String id;

  /// A name key (`n01`…`n24`); the client says it in its own language.
  final String name;
  const Suspect(this.id, this.name);
}

class Clue {
  final String id;
  final String kind;
  final String? a;
  final String? b;
  final List<String> group;
  final int k;

  const Clue({
    required this.id,
    required this.kind,
    this.a,
    this.b,
    this.group = const [],
    this.k = 0,
  });

  factory Clue.fromJson(Map<String, dynamic> json) => Clue(
    id: _str(json['id']),
    kind: _str(json['kind']),
    a: json['a'] is String ? json['a'] as String : null,
    b: json['b'] is String ? json['b'] as String : null,
    group: [
      if (json['group'] is List)
        for (final id in json['group'] as List)
          if (id is String) id,
    ],
    k: _int(json['k']),
  );
}

class RevealStep {
  final String clue;
  final List<String> eliminates;
  const RevealStep(this.clue, this.eliminates);
}

class CaseOfDay {
  final bool enabled;
  final String day;
  final int attempts;
  final int maxAttempts;
  final bool solved;
  final bool failed;
  final int streak;
  final int bestStreak;
  final int rewardCoins;
  final int rewardXp;
  final List<Suspect> suspects;
  final bool seats;
  final List<Clue> clues;
  final int difficulty;
  final String? answer;
  final List<RevealStep> chain;

  const CaseOfDay({
    this.enabled = false,
    this.day = '',
    this.attempts = 0,
    this.maxAttempts = 3,
    this.solved = false,
    this.failed = false,
    this.streak = 0,
    this.bestStreak = 0,
    this.rewardCoins = 0,
    this.rewardXp = 0,
    this.suspects = const [],
    this.seats = false,
    this.clues = const [],
    this.difficulty = 1,
    this.answer,
    this.chain = const [],
  });

  static const off = CaseOfDay();

  bool get closed => solved || failed;
  int get attemptsLeft => (maxAttempts - attempts).clamp(0, maxAttempts);

  Suspect? suspect(String? id) {
    for (final s in suspects) {
      if (s.id == id) return s;
    }
    return null;
  }

  factory CaseOfDay.fromJson(Map<String, dynamic> json) {
    if (json['enabled'] != true) return off;
    final puzzle = json['puzzle'] is Map
        ? Map<String, dynamic>.from(json['puzzle'] as Map)
        : const <String, dynamic>{};
    final reward = json['reward'] is Map
        ? Map<String, dynamic>.from(json['reward'] as Map)
        : const <String, dynamic>{};
    final reveal = json['reveal'] is Map
        ? Map<String, dynamic>.from(json['reveal'] as Map)
        : null;
    return CaseOfDay(
      enabled: true,
      day: _str(json['day']),
      attempts: _int(json['attempts']),
      maxAttempts: _int(json['maxAttempts'], 3),
      solved: json['solved'] == true,
      failed: json['failed'] == true,
      streak: _int(json['streak']),
      bestStreak: _int(json['bestStreak']),
      rewardCoins: _int(reward['coins']),
      rewardXp: _int(reward['xp']),
      suspects: [
        for (final row in _rows(puzzle['suspects']))
          Suspect(_str(row['id']), _str(row['name'])),
      ],
      seats: puzzle['seats'] == true,
      clues: [for (final row in _rows(puzzle['clues'])) Clue.fromJson(row)],
      difficulty: _int(puzzle['difficulty'], 1),
      answer: reveal == null ? null : _str(reveal['answer']),
      chain: [
        for (final row in _rows(reveal?['chain']))
          RevealStep(_str(row['clue']), [
            if (row['eliminates'] is List)
              for (final id in row['eliminates'] as List)
                if (id is String) id,
          ]),
      ],
    );
  }
}

/// The outcome of one accusation.
class CaseVerdict {
  final bool correct;
  final CaseGrant? grant;
  const CaseVerdict(this.correct, this.grant);
}

final caseOfDayProvider =
    AsyncNotifierProvider<CaseOfDayController, CaseOfDay>(
      CaseOfDayController.new,
    );

class CaseOfDayController extends AsyncNotifier<CaseOfDay> {
  /// This session's wrong picks, so a crossed-out seat stays crossed out.
  final wrong = <String>{};

  @override
  Future<CaseOfDay> build() async {
    final caps = await ref.watch(economyCapabilitiesProvider.future);
    if (!caps.caseOfDay) return CaseOfDay.off;
    return CaseOfDay.fromJson(await _call({'action': 'casePuzzle'}));
  }

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('economy', body);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<CaseOfDay>().copyWithPrevious(state);
    state = await AsyncValue.guard(build);
  }

  Future<CaseVerdict> accuse(String pick) async {
    final today = state.valueOrNull ?? CaseOfDay.off;
    Map<String, dynamic> answer;
    try {
      answer = await _call({
        'action': 'casePuzzleSolve',
        'day': today.day,
        'pick': pick,
      });
    } on BackendException catch (error) {
      await refresh();
      throw CaseClaimFailed(error.code);
    } catch (_) {
      throw const CaseClaimFailed(null);
    }
    if (answer['ok'] == false) {
      await refresh();
      throw CaseClaimFailed(answer['code'] is String ? answer['code'] as String : null);
    }
    final correct = answer['correct'] == true;
    if (!correct) wrong.add(pick);
    if (answer['state'] is Map) {
      state = AsyncData(
        CaseOfDay.fromJson(Map<String, dynamic>.from(answer['state'] as Map)),
      );
    } else {
      await refresh();
    }
    final grant = answer['grant'] is Map
        ? CaseGrant(
            _int((answer['grant'] as Map)['coins']),
            _int((answer['grant'] as Map)['xp']),
          )
        : null;
    if (grant != null) {
      ref.invalidate(walletProvider);
      ref.invalidate(casebookProvider);
    }
    return CaseVerdict(correct, grant);
  }
}
