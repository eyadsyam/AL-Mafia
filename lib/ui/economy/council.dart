import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/online_backend.dart';
import '../screens/online/online_session.dart';
import 'daily_rewards.dart';
import 'economy_capabilities.dart';
import 'wallet.dart';

/// Council Life (phase 107): contracts, rank, the weekly board and invites.
///
/// Nothing is decided on the device. Every figure comes back from the
/// `economy` function, which counts only matches that are already over — so
/// no read here can say anything about a match in progress, and none is made
/// during one.

int _int(Object? value, [int fallback = 0]) =>
    (value as num?)?.toInt() ?? fallback;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _rows(Object? value) => [
  for (final row in (value as List?) ?? const [])
    if (row is Map) Map<String, dynamic>.from(row),
];

class LevelUp {
  final int level;
  final int coins;
  const LevelUp(this.level, this.coins);

  static List<LevelUp> list(Object? json) => [
    for (final row in _rows(json))
      LevelUp(_int(row['level'], 1), _int(row['coins'])),
  ];
}

class CouncilContract {
  final int slot;
  final String code;
  final String metric;
  final int target;
  final int progress;
  final int coins;
  final bool claimed;
  final bool claimable;
  const CouncilContract({
    required this.slot,
    required this.code,
    required this.metric,
    required this.target,
    required this.progress,
    required this.coins,
    required this.claimed,
    required this.claimable,
  });

  factory CouncilContract.fromJson(Map<String, dynamic> j) => CouncilContract(
    slot: _int(j['slot']),
    code: j['code'] as String? ?? '',
    metric: j['metric'] as String? ?? 'finish',
    target: _int(j['target'], 1),
    progress: _int(j['progress']),
    coins: _int(j['coins']),
    claimed: j['claimed'] == true,
    claimable: j['claimable'] == true,
  );
}

class WeeklyContract {
  final String week;
  final int target;
  final int progress;
  final int coins;
  final int xp;
  final bool claimed;
  final bool claimable;
  const WeeklyContract({
    required this.week,
    required this.target,
    required this.progress,
    required this.coins,
    required this.xp,
    required this.claimed,
    required this.claimable,
  });

  factory WeeklyContract.fromJson(Map<String, dynamic> j) => WeeklyContract(
    week: j['week'] as String? ?? '',
    target: _int(j['target'], 1),
    progress: _int(j['progress']),
    coins: _int(j['coins']),
    xp: _int(j['xp']),
    claimed: j['claimed'] == true,
    claimable: j['claimable'] == true,
  );
}

class CouncilContracts {
  final bool enabled;
  final String day;
  final List<CouncilContract> contracts;
  final int bonusCoins;
  final bool bonusClaimed;
  final WeeklyContract? weekly;
  const CouncilContracts({
    required this.enabled,
    required this.day,
    required this.contracts,
    required this.bonusCoins,
    required this.bonusClaimed,
    required this.weekly,
  });

  static const off = CouncilContracts(
    enabled: false,
    day: '',
    contracts: [],
    bonusCoins: 0,
    bonusClaimed: false,
    weekly: null,
  );

  factory CouncilContracts.fromJson(Map<String, dynamic> j) {
    if (j['enabled'] != true) return off;
    final bonus = _map(j['bonus']);
    final weekly = _map(j['weekly']);
    return CouncilContracts(
      enabled: true,
      day: j['day'] as String? ?? '',
      contracts: [
        for (final row in _rows(j['contracts'])) CouncilContract.fromJson(row),
      ]..sort((a, b) => a.slot.compareTo(b.slot)),
      bonusCoins: _int(bonus['coins']),
      bonusClaimed: bonus['claimed'] == true,
      weekly: weekly.isEmpty ? null : WeeklyContract.fromJson(weekly),
    );
  }

  bool get anyClaimable =>
      contracts.any((c) => c.claimable) || (weekly?.claimable ?? false);
}

class CouncilRank {
  final bool enabled;
  final int xp;
  final int level;
  final int levelXp;
  final int? nextLevelXp;
  final int? nextReward;
  final int weekXp;
  final bool leaderboardVisible;
  const CouncilRank({
    required this.enabled,
    required this.xp,
    required this.level,
    required this.levelXp,
    required this.nextLevelXp,
    required this.nextReward,
    required this.weekXp,
    required this.leaderboardVisible,
  });

  static const off = CouncilRank(
    enabled: false,
    xp: 0,
    level: 1,
    levelXp: 0,
    nextLevelXp: null,
    nextReward: null,
    weekXp: 0,
    leaderboardVisible: true,
  );

  factory CouncilRank.fromJson(Map<String, dynamic> j) => j['enabled'] != true
      ? off
      : CouncilRank(
          enabled: true,
          xp: _int(j['xp']),
          level: _int(j['level'], 1),
          levelXp: _int(j['levelXp']),
          nextLevelXp: (j['nextLevelXp'] as num?)?.toInt(),
          nextReward: (j['nextReward'] as num?)?.toInt(),
          weekXp: _int(j['weekXp']),
          leaderboardVisible: j['leaderboardVisible'] != false,
        );

  /// Progress through the current level, 0..1 (1 at the top level).
  double get progress {
    final next = nextLevelXp;
    if (next == null || next <= levelXp) return 1;
    return ((xp - levelXp) / (next - levelXp)).clamp(0.0, 1.0);
  }
}

class LeaderboardEntry {
  final int position;
  final int xp;
  final String name;
  final String gender;
  final String? frame;
  final int level;
  final bool me;
  const LeaderboardEntry({
    required this.position,
    required this.xp,
    required this.name,
    required this.gender,
    required this.frame,
    required this.level,
    required this.me,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
    position: _int(j['position'], 1),
    xp: _int(j['xp']),
    name: j['name'] as String? ?? '',
    gender: j['gender'] as String? ?? 'unspecified',
    frame: j['frame'] as String?,
    level: _int(j['level'], 1),
    me: j['me'] == true,
  );
}

class Leaderboard {
  final bool enabled;
  final String week;
  final List<LeaderboardEntry> entries;
  final int? myPosition;
  final int myXp;
  final bool visible;
  const Leaderboard({
    required this.enabled,
    required this.week,
    required this.entries,
    required this.myPosition,
    required this.myXp,
    required this.visible,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> j) {
    final me = _map(j['me']);
    return Leaderboard(
      enabled: j['enabled'] == true,
      week: j['week'] as String? ?? '',
      entries: [for (final row in _rows(j['entries'])) LeaderboardEntry.fromJson(row)],
      myPosition: (me['position'] as num?)?.toInt(),
      myXp: _int(me['xp']),
      visible: j['visible'] != false,
    );
  }
}

class InviteStatus {
  final bool enabled;
  final String? code;
  final int inviterCoins;
  final int inviteeCoins;
  final int cap;
  final int rewarded;
  final int pending;
  final bool redeemed;
  final bool redeemedRewarded;
  final bool canRedeem;

  /// Economy v3 (row 6): settled invites against the 10/season and
  /// 40/lifetime caps, what they unlocked, and the lines the inviter has not
  /// read yet. Absent (zero/empty) on the older scheme.
  final int settledSeason;
  final int settledLifetime;
  final int seasonCap;
  final int lifetimeCap;
  final List<String> unlocks;
  final List<InviteNotice> notices;
  const InviteStatus({
    required this.enabled,
    required this.code,
    required this.inviterCoins,
    required this.inviteeCoins,
    required this.cap,
    required this.rewarded,
    required this.pending,
    required this.redeemed,
    required this.redeemedRewarded,
    required this.canRedeem,
    this.settledSeason = 0,
    this.settledLifetime = 0,
    this.seasonCap = 0,
    this.lifetimeCap = 0,
    this.unlocks = const [],
    this.notices = const [],
  });

  bool get v3 => lifetimeCap > 0;

  factory InviteStatus.fromJson(Map<String, dynamic> j) {
    final redeemed = j['redeemed'];
    final v3 = j['v3'] is Map ? Map<String, dynamic>.from(j['v3'] as Map) : null;
    final caps = v3?['caps'] is Map ? v3!['caps'] as Map : const {};
    return InviteStatus(
      settledSeason: _int(v3?['settledSeason']),
      settledLifetime: _int(v3?['settledLifetime']),
      seasonCap: _int(caps['season']),
      lifetimeCap: _int(caps['lifetime']),
      unlocks: [
        for (final code in (v3?['unlocks'] as List?) ?? const [])
          if (code is String) code,
      ],
      notices: [
        for (final row in (v3?['notices'] as List?) ?? const [])
          if (row is Map && InviteNotice.kinds.contains(row['kind']))
            InviteNotice.fromJson(Map<String, dynamic>.from(row)),
      ],
      enabled: j['enabled'] == true,
      code: j['code'] as String?,
      inviterCoins: _int(j['inviterCoins']),
      inviteeCoins: _int(j['inviteeCoins']),
      cap: _int(j['cap']),
      rewarded: _int(j['rewarded']),
      pending: _int(j['pending']),
      redeemed: redeemed is Map,
      redeemedRewarded: redeemed is Map && redeemed['rewarded'] == true,
      canRedeem: j['canRedeem'] == true,
    );
  }
}

/// One unread invite line. The server keeps the kind, the invitee's display
/// name and the count; the copy lives in the ARB files.
class InviteNotice {
  static const kinds = {'first_match', 'progress', 'settled'};
  final int id;
  final String kind;
  final String name;
  final int progress;
  final int coins;
  const InviteNotice({
    required this.id,
    required this.kind,
    required this.name,
    required this.progress,
    required this.coins,
  });

  factory InviteNotice.fromJson(Map<String, dynamic> j) => InviteNotice(
    id: _int(j['id']),
    kind: j['kind'] as String,
    name: j['name'] is String ? j['name'] as String : '',
    progress: _int(j['progress']),
    coins: _int(j['coins']),
  );
}

/// Contracts and rank together: the hub's two always-present cards.
class CouncilState {
  final CouncilContracts contracts;
  final CouncilRank rank;
  const CouncilState({required this.contracts, required this.rank});

  CouncilState copyWith({CouncilContracts? contracts, CouncilRank? rank}) =>
      CouncilState(
        contracts: contracts ?? this.contracts,
        rank: rank ?? this.rank,
      );
}

/// Levels the server paid for, not yet celebrated. The server reports each
/// level once, in whichever read landed it, so every reader adds here and the
/// celebration takes from here.
final pendingLevelUpsProvider = StateProvider<List<LevelUp>>((ref) => const []);

void _notePending(Ref ref, List<LevelUp> ups) {
  if (ups.isEmpty) return;
  final notifier = ref.read(pendingLevelUpsProvider.notifier);
  notifier.state = [
    ...notifier.state,
    for (final up in ups)
      if (!notifier.state.any((u) => u.level == up.level)) up,
  ];
}

class CouncilActionFailed implements Exception {
  final String? code;
  const CouncilActionFailed(this.code);
}

/// What a claim granted, for the reveal.
class CouncilGrant {
  final int granted;
  final int bonus;
  const CouncilGrant(this.granted, [this.bonus = 0]);
}

final councilProvider = AsyncNotifierProvider<CouncilController, CouncilState?>(
  CouncilController.new,
);

class CouncilController extends AsyncNotifier<CouncilState?> {
  @override
  Future<CouncilState?> build() async => null;

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('economy', body);
  }

  /// Reads contracts and rank (and so records finished matches and pays any
  /// level reward). Off features read as off.
  Future<void> refresh() async {
    final caps = await ref.read(economyCapabilitiesProvider.future);
    if (!caps.council.hub) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading<CouncilState?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final contracts = caps.council.contracts
          ? await _call({'action': 'contracts_get'})
          : const <String, dynamic>{};
      final rank = caps.council.rank
          ? await _call({'action': 'rank_get'})
          : const <String, dynamic>{};
      final ups = [
        ...LevelUp.list(contracts['levelUps']),
        ...LevelUp.list(rank['levelUps']),
      ];
      if (ups.isNotEmpty) ref.invalidate(walletProvider);
      _notePending(ref, ups);
      return CouncilState(
        contracts: CouncilContracts.fromJson(contracts),
        rank: CouncilRank.fromJson(rank),
      );
    });
  }

  /// Takes the contracts and rank a `resultSummary` already read (D7), exactly
  /// as [refresh] would have stored them from its two calls.
  void absorbSummary(Map<String, dynamic> summary) {
    Map<String, dynamic> part(String key) => summary[key] is Map
        ? Map<String, dynamic>.from(summary[key] as Map)
        : const <String, dynamic>{};
    final contracts = part('contracts');
    final rank = part('rank');
    final ups = [
      ...LevelUp.list(contracts['levelUps']),
      ...LevelUp.list(rank['levelUps']),
    ];
    if (ups.isNotEmpty) ref.invalidate(walletProvider);
    _notePending(ref, ups);
    state = AsyncData(
      CouncilState(
        contracts: CouncilContracts.fromJson(contracts),
        rank: CouncilRank.fromJson(rank),
      ),
    );
  }

  /// Hands the uncelebrated level-ups to exactly one caller.
  List<LevelUp> takeLevelUps() {
    final notifier = ref.read(pendingLevelUpsProvider.notifier);
    final ups = notifier.state;
    notifier.state = const [];
    return ups;
  }

  Future<Map<String, dynamic>> _act(Map<String, Object?> body) async {
    try {
      return await _call(body);
    } on BackendException catch (error) {
      if (error.code == 'DAY_CHANGED' || error.code == 'WEEK_CHANGED') {
        await refresh();
      }
      throw CouncilActionFailed(error.code);
    } catch (_) {
      throw const CouncilActionFailed(null);
    }
  }

  Future<void> _absorb(Map<String, dynamic> answer) async {
    final current = state.valueOrNull;
    _notePending(ref, LevelUp.list(answer['levelUps']));
    state = AsyncData(
      (current ??
              const CouncilState(
                contracts: CouncilContracts.off,
                rank: CouncilRank.off,
              ))
          .copyWith(contracts: CouncilContracts.fromJson(answer)),
    );
    ref.invalidate(walletProvider);
    ref.invalidate(councilAttentionProvider);
    // XP from a weekly claim moves the rank card.
    if (answer['xpGranted'] is num && (answer['xpGranted'] as num) > 0) {
      final rank = await _call({'action': 'rank_get'});
      final now = state.valueOrNull;
      _notePending(ref, LevelUp.list(rank['levelUps']));
      if (now != null) {
        state = AsyncData(now.copyWith(rank: CouncilRank.fromJson(rank)));
      }
    }
  }

  /// Claims today's contract in [slot]; the request names the server day.
  Future<CouncilGrant> claim(int slot) async {
    final day = state.valueOrNull?.contracts.day;
    if (day == null || day.isEmpty) throw const CouncilActionFailed(null);
    final answer = await _act({
      'action': 'contract_claim',
      'day': day,
      'slot': slot,
    });
    await _absorb(answer);
    return CouncilGrant(_int(answer['granted']), _int(answer['bonusGranted']));
  }

  Future<CouncilGrant> claimWeekly() async {
    final week = state.valueOrNull?.contracts.weekly?.week;
    if (week == null || week.isEmpty) throw const CouncilActionFailed(null);
    final answer = await _act({'action': 'weekly_claim', 'week': week});
    await _absorb(answer);
    return CouncilGrant(_int(answer['granted']));
  }

  /// The player's leaderboard choice, server-enforced.
  Future<void> setLeaderboardVisible(bool visible) async {
    await _act({'action': 'leaderboard_visibility', 'visible': visible});
    final current = state.valueOrNull;
    if (current != null) {
      final r = current.rank;
      state = AsyncData(
        current.copyWith(
          rank: CouncilRank(
            enabled: r.enabled,
            xp: r.xp,
            level: r.level,
            levelXp: r.levelXp,
            nextLevelXp: r.nextLevelXp,
            nextReward: r.nextReward,
            weekXp: r.weekXp,
            leaderboardVisible: visible,
          ),
        ),
      );
    }
    ref.invalidate(leaderboardProvider);
  }
}

final leaderboardProvider = FutureProvider.autoDispose<Leaderboard>((ref) async {
  final backend = await ref.read(onlineBackendFactoryProvider)();
  await backend.ensureSession();
  return Leaderboard.fromJson(
    await backend.call('economy', {'action': 'leaderboard_get'}),
  );
});

final inviteProvider = AsyncNotifierProvider.autoDispose<InviteController, InviteStatus>(
  InviteController.new,
);

class InviteController extends AutoDisposeAsyncNotifier<InviteStatus> {
  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('economy', body);
  }

  @override
  Future<InviteStatus> build() async =>
      InviteStatus.fromJson(await _call({'action': 'invite_get'}));

  /// Marks the shown invite lines read. Never load-bearing: a failure leaves
  /// them to be shown once more on the next open.
  Future<void> acknowledge(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      await _call({'action': 'invite_ack', 'ids': ids.take(50).toList()});
    } catch (_) {}
  }

  /// Returns the server's status word (`redeemed` / `not_found`).
  Future<String> redeem(String code) async {
    try {
      final answer = await _call({'action': 'invite_redeem', 'code': code});
      state = AsyncData(InviteStatus.fromJson(answer));
      ref.invalidate(walletProvider);
      return answer['status'] as String? ?? 'redeemed';
    } on BackendException catch (error) {
      throw CouncilActionFailed(error.code);
    } catch (_) {
      throw const CouncilActionFailed(null);
    }
  }
}

/// Whether the vault holds something to collect today: the coffer, the
/// wheel or a finished contract. Read on Home only, never during a match.
final councilAttentionProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    final caps = await ref.watch(economyCapabilitiesProvider.future);
    if (!caps.daily && !caps.council.contracts) return false;
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    if (caps.daily) {
      final daily = DailyStatus.fromJson(
        await backend.call('economy', {'action': 'daily_status'}),
      );
      if (daily.enabled && (!daily.cofferClaimed || !daily.wheelSpun)) {
        return true;
      }
    }
    if (caps.council.contracts) {
      final answer = await backend.call('economy', {'action': 'contracts_get'});
      _notePending(ref, LevelUp.list(answer['levelUps']));
      if (CouncilContracts.fromJson(answer).anyClaimable) return true;
    }
    return false;
  } catch (_) {
    return false;
  }
});
