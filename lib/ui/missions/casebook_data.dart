import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/enums.dart';
import '../../transport/online_backend.dart';
import '../economy/economy_capabilities.dart';
import '../economy/wallet.dart';
import '../screens/online/online_session.dart';

/// «ملف القضايا» — the Casebook: tonight's cases, the season track and the
/// player's legacy, in one place.
///
/// Nothing here is decided on the device. Every figure is the server's, and
/// the server counts only rooms that are finished with a public outcome, so
/// no read can say anything about a match in progress — and none is made
/// during one.

int _int(Object? value, [int fallback = 0]) =>
    (value as num?)?.toInt() ?? fallback;

bool _bool(Object? value) => value == true;

String? _str(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _rows(Object? value) => [
  if (value is List)
    for (final row in value)
      if (row is Map) Map<String, dynamic>.from(row),
];

/// One case on tonight's page or the week's.
class CaseMission {
  final int slot;
  final String code;
  final String metric;

  /// The character who hands the case over — flavour only.
  final Role voice;
  final int target;
  final int progress;
  final int coins;
  final int xp;
  final bool claimed;
  final bool claimable;

  const CaseMission({
    required this.slot,
    required this.code,
    required this.metric,
    required this.voice,
    required this.target,
    required this.progress,
    required this.coins,
    required this.xp,
    required this.claimed,
    required this.claimable,
  });

  double get fraction =>
      target <= 0 ? 0 : (progress / target).clamp(0, 1).toDouble();

  factory CaseMission.fromJson(Map<String, dynamic> json) => CaseMission(
    slot: _int(json['slot']),
    code: _str(json['code']) ?? '',
    metric: _str(json['metric']) ?? '',
    voice: voiceOf(json['voice'], _int(json['slot'])),
    target: _int(json['target'], 1),
    progress: _int(json['progress']),
    coins: _int(json['coins']),
    xp: _int(json['xp']),
    claimed: _bool(json['claimed']),
    claimable: _bool(json['claimable']),
  );
}

/// The character named by the server, or a fixed one per slot so the same
/// case always speaks with the same face.
Role voiceOf(Object? name, int slot) {
  for (final role in Role.values) {
    if (role.name == name) return role;
  }
  return casebookVoices[slot.abs() % casebookVoices.length];
}

const casebookVoices = [Role.detective, Role.doctor, Role.mafia, Role.citizen];

class CaseBonus {
  final int coins;
  final int xp;
  final bool claimed;
  final bool claimable;

  const CaseBonus({
    this.coins = 0,
    this.xp = 0,
    this.claimed = false,
    this.claimable = false,
  });

  factory CaseBonus.fromJson(Map<String, dynamic> json) => CaseBonus(
    coins: _int(json['coins']),
    xp: _int(json['xp']),
    claimed: _bool(json['claimed']),
    claimable: _bool(json['claimable']),
  );
}

class CasePage {
  final String period;
  final List<CaseMission> missions;
  final CaseBonus? bonus;

  const CasePage({this.period = '', this.missions = const [], this.bonus});

  factory CasePage.fromJson(Map<String, dynamic> json) => CasePage(
    period: _str(json['period']) ?? '',
    missions: [
      for (final row in _rows(json['missions'])) CaseMission.fromJson(row),
    ],
    bonus: json['bonus'] is Map ? CaseBonus.fromJson(_map(json['bonus'])) : null,
  );

  int get ready =>
      missions.where((m) => m.claimable).length +
      ((bonus?.claimable ?? false) ? 1 : 0);
}

/// A stop on the season track.
class SeasonStop {
  final int level;
  final int coins;
  final String? item;
  final String? title;
  final bool claimed;
  final bool claimable;

  const SeasonStop({
    required this.level,
    this.coins = 0,
    this.item,
    this.title,
    this.claimed = false,
    this.claimable = false,
  });

  bool get empty => coins == 0 && item == null && title == null;

  factory SeasonStop.fromJson(Map<String, dynamic> json) => SeasonStop(
    level: _int(json['level']),
    coins: _int(json['coins']),
    item: _str(json['item']),
    title: _str(json['title']),
    claimed: _bool(json['claimed']),
    claimable: _bool(json['claimable']),
  );
}

class CaseSeason {
  final String code;
  final DateTime? endsAt;
  final int level;
  final int xp;
  final int xpPerLevel;
  final int maxLevel;
  final List<SeasonStop> stops;

  const CaseSeason({
    this.code = '',
    this.endsAt,
    this.level = 0,
    this.xp = 0,
    this.xpPerLevel = 200,
    this.maxLevel = 20,
    this.stops = const [],
  });

  /// XP gathered toward the next level (the server's figure is the total).
  int get levelXp => xpPerLevel <= 0 ? 0 : xp - level * xpPerLevel;
  bool get complete => level >= maxLevel;
  double get levelFraction => complete || xpPerLevel <= 0
      ? 1
      : (levelXp / xpPerLevel).clamp(0, 1).toDouble();

  int daysLeft(DateTime now) {
    final end = endsAt;
    if (end == null) return 0;
    final left = end.difference(now);
    if (left.isNegative) return 0;
    return (left.inHours / 24).ceil();
  }

  SeasonStop stop(int level) => stops.firstWhere(
    (s) => s.level == level,
    orElse: () => SeasonStop(level: level),
  );

  int get ready => stops.where((s) => s.claimable).length;

  factory CaseSeason.fromJson(Map<String, dynamic> json) => CaseSeason(
    code: _str(json['code']) ?? '',
    endsAt: DateTime.tryParse(_str(json['endsAt']) ?? '')?.toUtc(),
    level: _int(json['level']),
    xp: _int(json['xp']),
    xpPerLevel: _int(json['xpPerLevel'], 200),
    maxLevel: _int(json['maxLevel'], 20),
    stops: [for (final row in _rows(json['rewards'])) SeasonStop.fromJson(row)],
  );
}

class CaseAchievement {
  final String code;
  final String metric;
  final int target;
  final int progress;
  final int coins;
  final int xp;
  final bool unlocked;
  final bool claimed;
  final bool claimable;

  const CaseAchievement({
    required this.code,
    required this.metric,
    required this.target,
    required this.progress,
    this.coins = 0,
    this.xp = 0,
    this.unlocked = false,
    this.claimed = false,
    this.claimable = false,
  });

  double get fraction =>
      target <= 0 ? 0 : (progress / target).clamp(0, 1).toDouble();

  factory CaseAchievement.fromJson(Map<String, dynamic> json) =>
      CaseAchievement(
        code: _str(json['code']) ?? '',
        metric: _str(json['metric']) ?? '',
        target: _int(json['target'], 1),
        progress: _int(json['progress']),
        coins: _int(json['coins']),
        xp: _int(json['xp']),
        unlocked: _bool(json['unlocked']),
        claimed: _bool(json['claimed']),
        claimable: _bool(json['claimable']),
      );
}

class CaseRank {
  final int level;
  final int xp;
  final int next;

  const CaseRank({this.level = 0, this.xp = 0, this.next = 0});

  factory CaseRank.fromJson(Map<String, dynamic> json) => CaseRank(
    level: _int(json['level']),
    xp: _int(json['xp']),
    next: _int(json['next']),
  );
}

class Casebook {
  final bool enabled;
  final CaseSeason season;
  final CasePage daily;
  final CasePage weekly;
  final List<CaseAchievement> achievements;
  final CaseRank rank;

  const Casebook({
    this.enabled = false,
    this.season = const CaseSeason(),
    this.daily = const CasePage(),
    this.weekly = const CasePage(),
    this.achievements = const [],
    this.rank = const CaseRank(),
  });

  static const off = Casebook();

  /// Everything waiting to be taken, across the three pages.
  int get ready =>
      daily.ready +
      weekly.ready +
      season.ready +
      achievements.where((a) => a.claimable).length;

  factory Casebook.fromJson(Map<String, dynamic> json) {
    if (!_bool(json['enabled'])) return off;
    return Casebook(
      enabled: true,
      season: CaseSeason.fromJson(_map(json['season'])),
      daily: CasePage.fromJson(_map(json['daily'])),
      weekly: CasePage.fromJson(_map(json['weekly'])),
      achievements: [
        for (final row in _rows(json['achievements']))
          CaseAchievement.fromJson(row),
      ],
      rank: CaseRank.fromJson(_map(json['rank'])),
    );
  }
}

/// What a claim paid, for the moment that celebrates it.
class CaseGrant {
  final int coins;
  final int xp;
  const CaseGrant(this.coins, this.xp);
}

class CaseClaimFailed implements Exception {
  final String? code;
  const CaseClaimFailed(this.code);
}

/// The economy actions the Casebook speaks (docs/CASEBOOK-CONTRACT.md).
abstract final class CasebookActions {
  static const hub = 'missionHub';
  static const mission = 'missionClaim';
  static const season = 'seasonClaim';
  static const achievement = 'achievementClaim';
}

final casebookProvider = AsyncNotifierProvider<CasebookController, Casebook>(
  CasebookController.new,
);

class CasebookController extends AsyncNotifier<Casebook> {
  @override
  Future<Casebook> build() async {
    final caps = await ref.watch(economyCapabilitiesProvider.future);
    if (!caps.missions) return Casebook.off;
    return Casebook.fromJson(await _call({'action': CasebookActions.hub}));
  }

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('economy', body);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<Casebook>().copyWithPrevious(state);
    state = await AsyncValue.guard(build);
  }

  Future<CaseGrant> _claim(Map<String, Object?> body) async {
    Map<String, dynamic> answer;
    try {
      answer = await _call(body);
    } on BackendException catch (error) {
      await refresh();
      throw CaseClaimFailed(error.code);
    } catch (_) {
      throw const CaseClaimFailed(null);
    }
    if (answer['ok'] == false) {
      await refresh();
      throw CaseClaimFailed(_str(answer['code']));
    }
    if (answer['hub'] is Map) {
      state = AsyncData(Casebook.fromJson(_map(answer['hub'])));
    } else {
      await refresh();
    }
    ref.invalidate(walletProvider);
    return CaseGrant(_int(answer['coins']), _int(answer['xp']));
  }

  /// A daily or weekly case; the request names the server's period.
  Future<CaseGrant> claimMission({required bool weekly, required int slot}) {
    final book = state.valueOrNull ?? Casebook.off;
    final page = weekly ? book.weekly : book.daily;
    return _claim({
      'action': CasebookActions.mission,
      'layer': weekly ? 'weekly' : 'daily',
      'period': page.period,
      'slot': slot,
    });
  }

  Future<CaseGrant> claimSeason(int level) {
    final book = state.valueOrNull ?? Casebook.off;
    return _claim({
      'action': CasebookActions.season,
      'season': book.season.code,
      'level': level,
    });
  }

  Future<CaseGrant> claimAchievement(String code) =>
      _claim({'action': CasebookActions.achievement, 'code': code});
}
