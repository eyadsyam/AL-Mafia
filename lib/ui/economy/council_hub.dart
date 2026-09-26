import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/asset_constants.dart';
import '../../app/l10n/app_localizations.dart';
import '../../platform/clipboard.dart';
import '../../platform/haptics.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'council.dart';
import 'council_art.dart';
import 'economy_capabilities.dart';
import 'mafia_coin.dart';

/// What a contract asks, in the player's words.
String contractName(AppLocalizations l, CouncilContract c) => switch (c.metric) {
  'finish' => c.target <= 1 ? l.contractFinishOne : l.contractFinishMany(c.target),
  'town' => l.contractTown,
  'mafia' => l.contractMafia,
  'win' => c.target <= 1 ? l.contractWinOne : l.contractWinMany(c.target),
  'host' => l.contractHost,
  _ => l.contractReunion,
};

String _refusal(AppLocalizations l, String? code) => switch (code) {
  'CONTRACT_INCOMPLETE' => l.contractIncomplete,
  'DAY_CHANGED' => l.dailyDayChanged,
  'WEEK_CHANGED' => l.dailyDayChanged,
  'INVITE_SELF' => l.inviteSelf,
  'INVITE_EXPIRED' => l.inviteExpired,
  'INVITE_NOT_NEW' => l.inviteNotNew,
  'INVITE_ALREADY' => l.inviteAlready,
  'INVITE_LOOP' => l.inviteLoop,
  'INVITE_LIMIT' => l.inviteLimit,
  'INVITE_RATE_LIMIT' => l.inviteRateLimit,
  _ => l.councilFailed,
};

/// The newest word replaces the last: a second tap's answer never waits
/// behind the first one's.
void _say(BuildContext context, String message) => ScaffoldMessenger.maybeOf(
  context,
)
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// Shows the celebration for any level the server has paid and nobody has
/// celebrated yet. One sheet for the highest new level, with every coin.
Future<void> celebrateLevelUps(BuildContext context, WidgetRef ref) async {
  final ups = ref.read(councilProvider.notifier).takeLevelUps();
  if (ups.isEmpty || !context.mounted) return;
  final top = ups.reduce((a, b) => a.level >= b.level ? a : b);
  final coins = ups.fold<int>(0, (sum, up) => sum + up.coins);
  Haptics.confirm();
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => LevelUpSheet(level: top.level, coins: coins),
  );
}

class LevelUpSheet extends StatelessWidget {
  final int level;
  final int coins;
  const LevelUpSheet({super.key, required this.level, required this.coins});

  static const Key sheetKey = ValueKey('council_level_up');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final title = rankTitle(l, rankTier(level));
    return Padding(
      key: sheetKey,
      padding: EdgeInsets.fromLTRB(s.lg, 0, s.lg, s.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: RankEmblem(
              level: level,
              size: CouncilLifeTokens.emblemHero,
              shimmer: true,
            ),
          ),
          SizedBox(height: s.md),
          Semantics(
            liveRegion: true,
            child: Text(
              l.levelUpTitle(title),
              textAlign: TextAlign.center,
              style: context.typography.headline.copyWith(
                color: context.colors.accentGold,
              ),
            ),
          ),
          SizedBox(height: s.xs),
          Text(
            l.levelUpBody(level, coins),
            textAlign: TextAlign.center,
            style: context.typography.body,
          ),
          SizedBox(height: s.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.continueAction),
          ),
        ],
      ),
    );
  }
}

/// «المجلس»: rank, today's contracts, the weekly contract, the board and
/// invites. Shown only when the server negotiated at least one of them.
class CouncilHubTab extends ConsumerStatefulWidget {
  const CouncilHubTab({super.key});

  static Key claimKey(int slot) => ValueKey('council_claim_$slot');
  static const weeklyKey = ValueKey('council_weekly_claim');
  static const rankKey = ValueKey('council_rank_card');
  static const contractsKey = ValueKey('council_contracts');
  static const leaderboardKey = ValueKey('council_leaderboard_open');
  static const inviteKey = ValueKey('council_invite');

  @override
  ConsumerState<CouncilHubTab> createState() => _CouncilHubTabState();
}

class _CouncilHubTabState extends ConsumerState<CouncilHubTab> {
  bool _busy = false;

  /// Bumped on each successful claim, per slot (-1 is the weekly), so the
  /// coin burst plays over the button that was tapped.
  final Map<int, int> _bursts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(councilProvider.notifier).refresh();
      if (mounted) await celebrateLevelUps(context, ref);
    });
  }

  Future<void> _claim(Future<CouncilGrant> Function() action, int slot) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      final grant = await action();
      if (!mounted) return;
      if (grant.granted > 0) {
        Haptics.confirm();
        setState(() => _bursts[slot] = (_bursts[slot] ?? 0) + 1);
        _say(
          context,
          grant.bonus > 0
              ? '${l.dailyCofferGranted(grant.granted)} ${l.contractBonusGranted(grant.bonus)}'
              : l.dailyCofferGranted(grant.granted),
        );
      }
      await celebrateLevelUps(context, ref);
    } on CouncilActionFailed catch (error) {
      if (mounted) _say(context, _refusal(l, error.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final caps =
        ref.watch(economyCapabilitiesProvider).valueOrNull?.council ??
        CouncilCapabilities.off;
    final council = ref.watch(councilProvider);
    final value = council.valueOrNull;
    if (value == null) {
      return Center(
        child: council.hasError
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.councilFailed, style: context.typography.body),
                  TextButton(
                    onPressed: () =>
                        ref.read(councilProvider.notifier).refresh(),
                    child: Text(l.videoRetry),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      );
    }
    final controller = ref.read(councilProvider.notifier);
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(s.md, (box.maxWidth - DailyTokens.cardMaxWidth) / 2);
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: side, vertical: s.md),
            children: [
              if (value.rank.enabled) ...[
                _RankCard(rank: value.rank, leaderboard: caps.leaderboard),
                SizedBox(height: s.md),
              ],
              if (value.contracts.enabled) ...[
                _ContractsCard(
                  contracts: value.contracts,
                  busy: _busy,
                  bursts: _bursts,
                  onClaim: (slot) => _claim(() => controller.claim(slot), slot),
                ),
                SizedBox(height: s.md),
                if (value.contracts.weekly case final weekly?) ...[
                  _WeeklyCard(
                    weekly: weekly,
                    busy: _busy,
                    burst: _bursts[-1],
                    onClaim: () => _claim(controller.claimWeekly, -1),
                  ),
                  SizedBox(height: s.md),
                ],
              ],
              if (caps.invites) const InviteCard(),
            ],
          ),
        );
      },
    );
  }
}

Widget _card(BuildContext context, List<Widget> children, {Key? key, bool lit = false}) =>
    DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(context.radii.card),
        border: Border.all(
          color: lit ? context.colors.accentGold : context.colors.borderSubtle,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );

Widget _title(BuildContext context, String text) => Semantics(
  header: true,
  child: Text(
    text,
    style: context.typography.title.copyWith(color: context.colors.textPrimary),
  ),
);

/// A thin bar in the vault's gold.
class CouncilBar extends StatelessWidget {
  final double value;
  const CouncilBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(CouncilLifeTokens.barRadius),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: CouncilLifeTokens.barHeight,
      color: context.colors.accentGold,
      backgroundColor: context.colors.surfaceBase,
    ),
  );
}

class _RankCard extends ConsumerWidget {
  final CouncilRank rank;
  final bool leaderboard;
  const _RankCard({required this.rank, required this.leaderboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final next = rank.nextLevelXp;
    return _card(context, key: CouncilHubTab.rankKey, [
      Row(
        children: [
          RankEmblem(level: rank.level),
          SizedBox(width: s.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.councilRankTitle,
                  style: context.typography.caption.copyWith(color: colors.textMuted),
                ),
                Text(
                  rankTitle(l, rankTier(rank.level)),
                  style: context.typography.title.copyWith(color: colors.accentGold),
                ),
                Text(l.councilLevel(rank.level), style: context.typography.bodySmall),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: s.sm),
      CouncilBar(value: rank.progress),
      SizedBox(height: s.xs),
      Row(
        children: [
          Expanded(
            child: Text(
              next == null ? l.councilMaxLevel : l.councilXpProgress(rank.xp, next),
              style: context.typography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),
          if (rank.nextReward case final coins?)
            Text(
              l.councilNextLevel(coins),
              style: context.typography.bodySmall.copyWith(color: colors.accentGold),
            ),
        ],
      ),
      SizedBox(height: s.xs),
      Text(
        '${l.councilWeekXp(rank.weekXp)} · ${l.councilHowXp}',
        style: context.typography.caption.copyWith(color: colors.textMuted),
      ),
      if (leaderboard) ...[
        SizedBox(height: s.sm),
        OutlinedButton.icon(
          key: CouncilHubTab.leaderboardKey,
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => const LeaderboardSheet(),
          ),
          icon: const Icon(Icons.leaderboard_outlined),
          label: Text(l.leaderboardOpen),
        ),
      ],
    ]);
  }
}

class _ContractsCard extends StatelessWidget {
  final CouncilContracts contracts;
  final bool busy;
  final Map<int, int> bursts;
  final void Function(int slot) onClaim;
  const _ContractsCard({
    required this.contracts,
    required this.busy,
    required this.bursts,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final done = contracts.contracts.where((c) => c.claimed).length;
    return _card(context, key: CouncilHubTab.contractsKey, [
      _title(context, l.contractsTitle),
      Text(
        l.contractsReset,
        style: context.typography.caption.copyWith(color: colors.textMuted),
      ),
      for (final c in contracts.contracts) ...[
        SizedBox(height: s.sm),
        _ContractRow(
          contract: c,
          busy: busy,
          burst: bursts[c.slot],
          onClaim: () => onClaim(c.slot),
        ),
      ],
      if (contracts.bonusCoins > 0) ...[
        SizedBox(height: s.md),
        Row(
          children: [
            MafiaCoin(shine: contracts.bonusClaimed),
            SizedBox(width: s.xs),
            Expanded(
              child: Text(
                contracts.bonusClaimed
                    ? l.contractsBonusDone
                    : l.contractsBonus(contracts.bonusCoins),
                style: context.typography.bodySmall.copyWith(
                  color: contracts.bonusClaimed ? colors.accentGold : colors.textSecondary,
                ),
              ),
            ),
            Text(
              l.contractProgress(done, contracts.contracts.length),
              style: context.typography.bodySmall,
            ),
          ],
        ),
      ],
    ]);
  }
}

class _ContractRow extends StatelessWidget {
  final CouncilContract contract;
  final bool busy;
  final int? burst;
  final VoidCallback onClaim;
  const _ContractRow({
    required this.contract,
    required this.busy,
    required this.burst,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final c = contract;
    // Two lines, so a 320 dp phone keeps the name, the bar and a full
    // 48 dp button without squeezing any of them.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ContractIcon(metric: c.metric, done: c.claimed || c.claimable),
            SizedBox(width: s.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contractName(l, c),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySmall.copyWith(
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: s.xs),
                  Row(
                    children: [
                      Expanded(child: CouncilBar(value: c.progress / c.target)),
                      SizedBox(width: s.xs),
                      Text(
                        l.contractProgress(c.progress, c.target),
                        style: context.typography.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: s.xs),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: CoinBurst(
            trigger: burst,
            child: c.claimed
                ? Text(
                    l.contractClaimed,
                    style: context.typography.bodySmall.copyWith(
                      color: context.colors.accentGold,
                    ),
                  )
                : FilledButton(
                    key: CouncilHubTab.claimKey(c.slot),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, StoreTokens.touchTarget),
                      padding: EdgeInsets.symmetric(horizontal: s.md),
                    ),
                    onPressed: c.claimable && !busy ? onClaim : null,
                    child: Text(l.contractClaim(c.coins)),
                  ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  final WeeklyContract weekly;
  final bool busy;
  final int? burst;
  final VoidCallback onClaim;
  const _WeeklyCard({
    required this.weekly,
    required this.busy,
    required this.burst,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    return _card(context, lit: weekly.claimable, [
      Row(
        children: [
          const ContractIcon(metric: 'finish'),
          SizedBox(width: s.sm),
          Expanded(child: _title(context, l.weeklyTitle)),
        ],
      ),
      SizedBox(height: s.xs),
      Text(l.weeklyBody(weekly.target), style: context.typography.bodySmall),
      SizedBox(height: s.sm),
      Row(
        children: [
          Expanded(child: CouncilBar(value: weekly.progress / weekly.target)),
          SizedBox(width: s.xs),
          Text(
            l.contractProgress(weekly.progress, weekly.target),
            style: context.typography.caption,
          ),
        ],
      ),
      SizedBox(height: s.xs),
      Text(
        weekly.xp > 0
            ? l.weeklyReward(weekly.coins, weekly.xp)
            : l.weeklyRewardCoins(weekly.coins),
        style: context.typography.bodySmall.copyWith(color: colors.accentGold),
      ),
      Text(
        l.weeklyReset,
        style: context.typography.caption.copyWith(color: colors.textMuted),
      ),
      SizedBox(height: s.sm),
      CoinBurst(
        trigger: burst,
        child: FilledButton(
          key: CouncilHubTab.weeklyKey,
          onPressed: weekly.claimable && !busy ? onClaim : null,
          child: Text(
            weekly.claimed ? l.contractClaimed : l.contractClaim(weekly.coins),
          ),
        ),
      ),
    ]);
  }
}

/// The weekly board: top 50 and the caller's own place. Names, looks and
/// levels only.
class LeaderboardSheet extends ConsumerWidget {
  const LeaderboardSheet({super.key});

  static const Key listKey = ValueKey('council_leaderboard');
  static Key rowKey(int position) => ValueKey('leaderboard_row_$position');
  static const Key meKey = ValueKey('leaderboard_me');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = context.spacing;
    final board = ref.watch(leaderboardProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: SheetTokens.previewInitialFraction,
      builder: (context, scroll) => board.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(leaderboardProvider),
            child: Text(l.councilFailed),
          ),
        ),
        data: (board) {
          final meListed = board.entries.any((e) => e.me);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: s.md),
                child: _title(context, l.leaderboardTitle),
              ),
              Expanded(
                child: board.entries.isEmpty
                    ? Center(
                        child: Text(
                          l.leaderboardEmpty,
                          style: context.typography.body,
                        ),
                      )
                    : ListView.builder(
                        key: listKey,
                        controller: scroll,
                        itemCount: board.entries.length,
                        itemBuilder: (context, i) =>
                            _LeaderboardRow(entry: board.entries[i]),
                      ),
              ),
              Padding(
                key: meKey,
                padding: EdgeInsets.all(s.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!meListed)
                      Text(
                        board.myPosition == null
                            ? l.leaderboardNone
                            : '${l.leaderboardYou(board.myPosition!)} · ${l.councilXpTotal(board.myXp)}',
                        style: context.typography.body.copyWith(
                          color: context.colors.accentGold,
                        ),
                      ),
                    if (!board.visible)
                      Text(
                        l.leaderboardHidden,
                        style: context.typography.caption.copyWith(
                          color: context.colors.textMuted,
                        ),
                      ),
                    const LeaderboardVisibilitySwitch(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  const _LeaderboardRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final colors = context.colors;
    return Container(
      key: LeaderboardSheet.rowKey(entry.position),
      color: entry.me ? colors.accentGold.withValues(alpha: StoreTokens.badgeWash) : null,
      padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
      child: Row(
        children: [
          SizedBox(
            width: CouncilLifeTokens.leaderboardAvatar,
            child: Text(
              '${entry.position}',
              style: context.typography.title.copyWith(
                color: entry.position <= 3 ? colors.accentGold : colors.textSecondary,
              ),
            ),
          ),
          ClipOval(
            child: Image.asset(
              entry.gender == 'female'
                  ? AppCouncilArt.avatarFemale
                  : AppCouncilArt.avatarMale,
              width: CouncilLifeTokens.leaderboardAvatar,
              height: CouncilLifeTokens.leaderboardAvatar,
              cacheWidth: StoreTokens.frameDecodeWidth,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  const SizedBox.square(dimension: CouncilLifeTokens.leaderboardAvatar),
            ),
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.body,
            ),
          ),
          RankEmblem(level: entry.level, size: CouncilLifeTokens.emblemRow),
          SizedBox(width: s.sm),
          Text(
            context.l10n.councilXpTotal(entry.xp),
            style: context.typography.bodySmall.copyWith(color: colors.accentGold),
          ),
        ],
      ),
    );
  }
}

/// «اظهر في ترتيب الأسبوع»: the player's own choice, kept by the server.
/// Shown only while the leaderboard exists.
class LeaderboardVisibilitySwitch extends ConsumerStatefulWidget {
  const LeaderboardVisibilitySwitch({super.key});

  static const Key switchKey = ValueKey('leaderboard_visible');

  @override
  ConsumerState<LeaderboardVisibilitySwitch> createState() =>
      _LeaderboardVisibilitySwitchState();
}

class _LeaderboardVisibilitySwitchState
    extends ConsumerState<LeaderboardVisibilitySwitch> {
  bool _busy = false;

  /// Never the first to reach the server: the switch uses what the vault or
  /// Home already negotiated, and asks for the rank only when the board is
  /// known to exist.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.exists(economyCapabilitiesProvider)) return;
      final board =
          ref.read(economyCapabilitiesProvider).valueOrNull?.council.leaderboard ??
          false;
      if (board && ref.read(councilProvider).valueOrNull == null) {
        ref.read(councilProvider.notifier).refresh();
      }
    });
  }

  Future<void> _set(bool visible) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(councilProvider.notifier).setLeaderboardVisible(visible);
    } on CouncilActionFailed {
      if (mounted) _say(context, context.l10n.councilFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!ref.exists(economyCapabilitiesProvider)) return const SizedBox.shrink();
    final caps = ref.watch(economyCapabilitiesProvider).valueOrNull?.council;
    final rank = ref.watch(councilProvider).valueOrNull?.rank;
    if (!(caps?.leaderboard ?? false) || rank == null || !rank.enabled) {
      return const SizedBox.shrink();
    }
    return SwitchListTile(
      key: LeaderboardVisibilitySwitch.switchKey,
      contentPadding: EdgeInsets.zero,
      value: rank.leaderboardVisible,
      onChanged: _busy ? null : _set,
      title: Text(l.leaderboardVisibleLabel),
      subtitle: Text(l.leaderboardVisibleBody),
    );
  }
}

/// «ادعي صاحبك»: the player's code to share, and one to use if theirs is a
/// new account.
class InviteCard extends ConsumerStatefulWidget {
  const InviteCard({super.key});

  static const Key codeKey = ValueKey('invite_code');
  static const Key copyKey = ValueKey('invite_copy');
  static const Key shareKey = ValueKey('invite_share');
  static const Key fieldKey = ValueKey('invite_field');
  static const Key redeemKey = ValueKey('invite_redeem');

  @override
  ConsumerState<InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<InviteCard> {
  final _field = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_busy) return;
    final code = _field.text.trim().toUpperCase();
    if (code.length != 7) return;
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      final status = await ref.read(inviteProvider.notifier).redeem(code);
      if (!mounted) return;
      _say(context, status == 'not_found' ? l.inviteNotFound : l.inviteRedeemed);
      if (status != 'not_found') _field.clear();
    } on CouncilActionFailed catch (error) {
      if (mounted) _say(context, _refusal(l, error.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final invite = ref.watch(inviteProvider);
    final status = invite.valueOrNull;
    if (status == null) {
      return invite.hasError
          ? TextButton(
              onPressed: () => ref.invalidate(inviteProvider),
              child: Text(l.councilFailed),
            )
          : const Center(child: CircularProgressIndicator());
    }
    if (!status.enabled) return const SizedBox.shrink();
    final code = status.code ?? '';
    return _card(context, key: InviteCard.codeKey, [
      _title(context, l.inviteTitle),
      SizedBox(height: s.xs),
      Text(
        l.inviteBody(status.inviterCoins, status.inviteeCoins),
        style: context.typography.bodySmall.copyWith(color: colors.textSecondary),
      ),
      SizedBox(height: s.sm),
      // An identifier in a Latin alphabet: always left to right.
      Directionality(
        textDirection: TextDirection.ltr,
        child: SelectableText(
          code,
          textAlign: TextAlign.center,
          style: context.typography.title.copyWith(
            color: colors.accentGold,
            fontSize:
                (context.typography.title.fontSize ?? CouncilLifeTokens.emblemSeat) *
                CouncilLifeTokens.inviteCodeScale,
          ),
        ),
      ),
      SizedBox(height: s.sm),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: s.sm,
        runSpacing: s.xs,
        children: [
          OutlinedButton.icon(
            key: InviteCard.copyKey,
            onPressed: code.isEmpty
                ? null
                : () async {
                    final copied = await AppClipboard.copy(code);
                    if (copied && context.mounted) _say(context, l.inviteCopied);
                  },
            icon: const Icon(Icons.copy_rounded),
            label: Text(l.inviteCopy),
          ),
          FilledButton.icon(
            key: InviteCard.shareKey,
            onPressed: code.isEmpty
                ? null
                : () => SharePlus.instance.share(
                    ShareParams(text: l.inviteShareText(code)),
                  ),
            icon: const Icon(Icons.share_rounded),
            label: Text(l.inviteShare),
          ),
        ],
      ),
      SizedBox(height: s.sm),
      Text(
        l.inviteCounters(status.rewarded, status.cap, status.pending),
        textAlign: TextAlign.center,
        style: context.typography.caption.copyWith(color: colors.textMuted),
      ),
      if (status.redeemed) ...[
        SizedBox(height: s.sm),
        Text(
          status.redeemedRewarded ? l.inviteRewarded : l.inviteRedeemed,
          style: context.typography.bodySmall.copyWith(color: colors.accentGold),
        ),
      ] else if (status.canRedeem) ...[
        SizedBox(height: s.md),
        Text(l.inviteHaveCode, style: context.typography.bodySmall),
        SizedBox(height: s.xs),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: InviteCard.fieldKey,
                controller: _field,
                maxLength: 7,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l.inviteField,
                  counterText: '',
                ),
                onSubmitted: (_) => _redeem(),
              ),
            ),
            SizedBox(width: s.sm),
            ListenableBuilder(
              listenable: _field,
              builder: (context, _) => FilledButton(
                key: InviteCard.redeemKey,
                onPressed: _busy || _field.text.trim().length != 7 ? null : _redeem,
                child: Text(l.inviteRedeem),
              ),
            ),
          ],
        ),
      ],
    ]);
  }
}

/// On the result screen, once the match is over: what this match moved in
/// the Council — contracts now ready, XP gained — then the celebration if a
/// level was reached. Nothing is claimed here, and nothing shows before the
/// result.
class CouncilResultStrip extends ConsumerStatefulWidget {
  final String roomId;
  const CouncilResultStrip({super.key, required this.roomId});

  static const Key stripKey = ValueKey('council_result_strip');

  @override
  ConsumerState<CouncilResultStrip> createState() => _CouncilResultStripState();
}

class _CouncilResultStripState extends ConsumerState<CouncilResultStrip> {
  List<String> _lines = const [];
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    try {
      final caps = await ref.read(economyCapabilitiesProvider.future);
      if (!caps.council.hub || !mounted) return;
      final before = ref.read(councilProvider).valueOrNull;
      // Records this match (idempotent), then reads what it moved.
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      await backend.call('economy', {'action': 'sync'});
      await ref.read(councilProvider.notifier).refresh();
      if (!mounted) return;
      final after = ref.read(councilProvider).valueOrNull;
      if (after == null) return;
      final l = context.l10n;
      final ready = [
        for (final c in after.contracts.contracts)
          if (c.claimable &&
              !(before?.contracts.contracts.any(
                    (b) => b.slot == c.slot && b.code == c.code && b.claimable,
                  ) ??
                  false))
            l.resultContractToast(contractName(l, c), c.coins),
      ];
      final weekly = after.contracts.weekly;
      final lines = [
        if (after.rank.enabled &&
            before != null &&
            before.rank.enabled &&
            after.rank.xp > before.rank.xp)
          l.resultXpGained(after.rank.xp - before.rank.xp),
        ...ready,
        if (weekly != null && weekly.claimable && !(before?.contracts.weekly?.claimable ?? false))
          l.resultWeeklyToast(weekly.coins),
      ];
      setState(() {
        _lines = lines;
        _shown = true;
      });
      await celebrateLevelUps(context, ref);
    } catch (_) {
      // The Council is never load-bearing for the result screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shown || _lines.isEmpty) return const SizedBox.shrink();
    final s = context.spacing;
    final colors = context.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Padding(
      key: CouncilResultStrip.stripKey,
      padding: EdgeInsets.only(bottom: s.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, line) in _lines.indexed)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: reduce ? 1 : 0, end: 1),
              duration: reduce
                  ? Duration.zero
                  : context.motion.standard + CouncilLifeTokens.toastStagger * i,
              builder: (context, t, child) => Opacity(opacity: t, child: child),
              child: Padding(
                padding: EdgeInsets.only(bottom: s.xs),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(context.radii.card),
                    border: Border.all(color: colors.accentGold),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
                    child: Row(
                      children: [
                        const MafiaCoin(),
                        SizedBox(width: s.xs),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(line, style: context.typography.bodySmall),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Text(
            context.l10n.resultClaimHint,
            textAlign: TextAlign.center,
            style: context.typography.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The small gold dot on the vault button when something waits there.
class CouncilAttentionBadge extends ConsumerWidget {
  final Widget child;
  const CouncilAttentionBadge({super.key, required this.child});

  static const Key dotKey = ValueKey('council_attention_dot');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(councilAttentionProvider).valueOrNull ?? false;
    if (!on) return child;
    return Semantics(
      label: context.l10n.councilAttention,
      child: Badge(
        key: dotKey,
        smallSize: CouncilLifeTokens.attentionDot,
        backgroundColor: context.colors.accentCrimson,
        child: child,
      ),
    );
  }
}
