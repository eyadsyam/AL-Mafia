import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mafia_master/ui/missions/casebook_data.dart';

/// A mid-season Casebook in the shape docs/CASEBOOK-CONTRACT.md promises.
Map<String, dynamic> casebookJson({bool enabled = true}) => {
  'enabled': enabled,
  'season': {
    'code': 'season_zero',
    'startsAt': '2026-09-28T18:00:00Z',
    'endsAt': '2026-10-26T18:00:00Z',
    'level': 6,
    'xp': 1330,
    'xpPerLevel': 200,
    'maxLevel': 20,
    'rewards': [
      for (final (level, coins) in [
        (2, 25),
        (5, 50),
        (8, 50),
        (11, 50),
        (14, 75),
        (17, 50),
        (19, 50),
        (20, 50),
      ])
        {
          'level': level,
          'coins': coins,
          'item': null,
          'title': level == 20 ? 'season_zero_legend' : null,
          'claimed': level == 2,
          'claimable': level == 5,
        },
      {
        'level': 10,
        'coins': 0,
        'item': null,
        'title': 'season_zero_sleuth',
        'claimed': false,
        'claimable': false,
      },
    ],
  },
  'daily': {
    'period': '2026-09-28',
    'missions': [
      {
        'slot': 0,
        'code': 'finish_1',
        'metric': 'finish',
        'voice': 'citizen',
        'target': 1,
        'progress': 1,
        'coins': 5,
        'xp': 25,
        'claimed': true,
        'claimable': false,
      },
      {
        'slot': 1,
        'code': 'finish_3',
        'metric': 'finish',
        'voice': 'detective',
        'target': 3,
        'progress': 3,
        'coins': 10,
        'xp': 40,
        'claimed': false,
        'claimable': true,
      },
      {
        'slot': 2,
        'code': 'host_1',
        'metric': 'host',
        'voice': 'mafia',
        'target': 1,
        'progress': 0,
        'coins': 10,
        'xp': 40,
        'claimed': false,
        'claimable': false,
      },
    ],
    'bonus': {'coins': 10, 'xp': 25, 'claimed': false, 'claimable': false},
  },
  'weekly': {
    'period': '2026-W40',
    'missions': [
      {
        'slot': 0,
        'code': 'weekly_finish_10',
        'metric': 'finish',
        'voice': 'doctor',
        'target': 10,
        'progress': 4,
        'coins': 75,
        'xp': 180,
        'claimed': false,
        'claimable': false,
      },
    ],
  },
  'achievements': [
    for (final (code, metric, target, progress, claimed) in [
      ('first_case', 'finish', 1, 1, true),
      ('first_win', 'win', 1, 1, false),
      ('host_5', 'host', 5, 2, false),
      ('reunion_5', 'reunion', 5, 1, false),
      ('finish_25', 'finish', 25, 12, false),
      ('win_10', 'win', 10, 3, false),
    ])
      {
        'code': code,
        'metric': metric,
        'target': target,
        'progress': progress,
        'coins': 25,
        'xp': 50,
        'unlocked': progress >= target,
        'claimed': claimed,
        'claimable': progress >= target && !claimed,
      },
  ],
  'rank': {'level': 4, 'xp': 520, 'next': 660},
};

/// Serves [casebookJson] and records the claims instead of calling a server.
class FakeCasebookController extends CasebookController {
  FakeCasebookController([this.json]);

  final Map<String, dynamic>? json;
  final claims = <String>[];

  @override
  Future<Casebook> build() async => Casebook.fromJson(json ?? casebookJson());

  @override
  Future<void> refresh() async {
    state = AsyncData(await build());
  }

  @override
  Future<CaseGrant> claimMission({required bool weekly, required int slot}) async {
    claims.add('${weekly ? 'weekly' : 'daily'}:$slot');
    return const CaseGrant(10, 40);
  }

  @override
  Future<CaseGrant> claimSeason(int level) async {
    claims.add('season:$level');
    return const CaseGrant(50, 0);
  }

  @override
  Future<CaseGrant> claimAchievement(String code) async {
    claims.add('achievement:$code');
    return const CaseGrant(25, 50);
  }
}
