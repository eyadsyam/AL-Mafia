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
import 'vault_kit.dart';
import '../widgets/feathered_art.dart';

/// What a contract asks, in the player's words.
String contractName(AppLocalizations l, CouncilContract c) =>
    switch (c.metric) {
      'finish' =>
        c.target <= 1 ? l.contractFinishOne : l.contractFinishMany(c.target),
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
void _say(BuildContext context, String message) =>
    ScaffoldMessenger.maybeOf(context)
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
    final reduce = MediaQuery.disableAnimationsOf(context);
    // Scrolls rather than overflows on a short phone held sideways.
    return SingleChildScrollView(
      key: sheetKey,
      padding: EdgeInsets.fromLTRB(s.lg, 0, s.lg, s.lg),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? 1 : 0, end: 1),
        duration: reduce ? Duration.zero : VaultTokens.revealDuration,
        builder: (context, t, _) {
          // The crest rises first; the words follow it in.
          final crest = Curves.easeOutBack.transform((t / 0.7).clamp(0.0, 1.0));
          final words = Curves.easeOut.transform(
            ((t - 0.35) / 0.65).clamp(0.0, 1.0),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: s.sm),
              Center(
                // The crest's own box: the rays paint past it into the
                // sheet's margin, so they cost no height.
                child: SizedBox.square(
                  dimension: CouncilLifeTokens.emblemHero + s.lg,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Light behind the crest: the art pass's rays once
                      // delivered, painted rays until then.
                      OverflowBox(
                        maxWidth:
                            CouncilLifeTokens.emblemHero *
                            VaultTokens.raysExtent,
                        maxHeight:
                            CouncilLifeTokens.emblemHero *
                            VaultTokens.raysExtent,
                        child: Opacity(
                          opacity: crest.clamp(0.0, 1.0),
                          child: RasterOr(
                            path: CouncilRaster.levelUpRays,
                            width:
                                CouncilLifeTokens.emblemHero *
                                VaultTokens.raysExtent,
                            height:
                                CouncilLifeTokens.emblemHero *
                                VaultTokens.raysExtent,
                            fallback: CustomPaint(
                              size: Size.square(
                                CouncilLifeTokens.emblemHero *
                                    VaultTokens.raysExtent,
                              ),
                              painter: RaysPainter(turn: t * 0.08),
                            ),
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale:
                            VaultTokens.revealFromScale +
                            (1 - VaultTokens.revealFromScale) * crest,
                        child: RankEmblem(
                          level: level,
                          size: CouncilLifeTokens.emblemHero,
                          shimmer: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Opacity(
                opacity: words,
                child: Transform.translate(
                  offset: Offset(0, s.sm * (1 - words)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          l.levelUpTitle(title),
                          textAlign: TextAlign.center,
                          style: context.typography.headline.copyWith(
                            color: VaultTokens.goldLight,
                          ),
                        ),
                      ),
                      SizedBox(height: s.xs),
                      Text(
                        l.levelUpBody(level, coins),
                        textAlign: TextAlign.center,
                        style: context.typography.body.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: s.lg),
              VaultPress(
                child: FilledButton(
                  style: vaultGoldStyle(context),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.continueAction),
                ),
              ),
            ],
          );
        },
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
      return council.hasError
          ? VaultRetry(
              message: l.councilFailed,
              action: l.videoRetry,
              onRetry: () => ref.read(councilProvider.notifier).refresh(),
            )
          : const VaultSkeleton();
    }
    final controller = ref.read(councilProvider.notifier);
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(
          s.md,
          (box.maxWidth - DailyTokens.cardMaxWidth) / 2,
        );
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

Widget _card(
  BuildContext context,
  List<Widget> children, {
  Key? key,
  bool lit = false,
}) => VaultCard(key: key, lit: lit, children: children);

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
  Widget build(BuildContext context) =>
      VaultBar(value: value, height: CouncilLifeTokens.barHeight);
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
          LampGlow(child: RankEmblem(level: rank.level)),
          SizedBox(width: s.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.councilRankTitle,
                  style: context.typography.caption.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  rankTitle(l, rankTier(rank.level)),
                  style: context.typography.headline.copyWith(
                    color: VaultTokens.goldLight,
                    height: 1.3,
                  ),
                ),
                _LevelPill(text: l.councilLevel(rank.level)),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: s.md),
      Row(
        children: [
          Expanded(
            child: Text(
              next == null
                  ? l.councilMaxLevel
                  : l.councilXpProgress(rank.xp, next),
              style: context.typography.bodySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          if (rank.nextReward case final coins?)
            Text(
              l.councilNextLevel(coins),
              style: context.typography.bodySmall.emphasised.copyWith(
                color: VaultTokens.gold,
              ),
            ),
        ],
      ),
      SizedBox(height: s.xs),
      CouncilBar(value: rank.progress),
      SizedBox(height: s.sm),
      Text(
        '${l.councilWeekXp(rank.weekXp)} · ${l.councilHowXp}',
        style: context.typography.caption.copyWith(color: colors.textMuted),
      ),
      if (leaderboard) ...[
        SizedBox(height: s.md),
        VaultPress(
          child: OutlinedButton.icon(
            key: CouncilHubTab.leaderboardKey,
            style: vaultOutlineStyle(context),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              builder: (_) => const LeaderboardSheet(),
            ),
            icon: const Icon(Icons.emoji_events_outlined),
            label: Text(l.leaderboardOpen),
          ),
        ),
      ],
    ]);
  }
}

/// «المستوى 8» on a small enamel plate.
class _LevelPill extends StatelessWidget {
  final String text;
  const _LevelPill({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(top: context.spacing.xs),
    padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
    decoration: BoxDecoration(
      color: VaultTokens.enamel,
      borderRadius: BorderRadius.circular(VaultTokens.chipHeight / 2),
      border: Border.all(color: VaultTokens.gold.withValues(alpha: 0.6)),
    ),
    child: Text(
      text,
      style: context.typography.caption.emphasised.copyWith(
        color: VaultTokens.goldLight,
      ),
    ),
  );
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
      VaultHeading(
        title: l.contractsTitle,
        subtitle: l.contractsReset,
        trailing: _CountPill(
          text: l.contractProgress(done, contracts.contracts.length),
          full: done == contracts.contracts.length,
        ),
      ),
      for (final (i, c) in contracts.contracts.indexed) ...[
        if (i == 0) SizedBox(height: s.sm) else const VaultDivider(),
        _ContractRow(
          contract: c,
          busy: busy,
          burst: bursts[c.slot],
          onClaim: () => onClaim(c.slot),
        ),
      ],
      if (contracts.bonusCoins > 0) ...[
        const VaultDivider(),
        Row(
          children: [
            MafiaCoin(
              size: CosmeticTokens.coinHeader / 1.6,
              shine: contracts.bonusClaimed,
            ),
            SizedBox(width: s.sm),
            Expanded(
              child: Text(
                contracts.bonusClaimed
                    ? l.contractsBonusDone
                    : l.contractsBonus(contracts.bonusCoins),
                style: context.typography.bodySmall.copyWith(
                  color: contracts.bonusClaimed
                      ? VaultTokens.gold
                      : colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    ]);
  }
}

/// «1/3» on a small plate; gold once every one is in.
class _CountPill extends StatelessWidget {
  final String text;
  final bool full;
  const _CountPill({required this.text, this.full = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
    decoration: BoxDecoration(
      color: full ? VaultTokens.gold : VaultTokens.enamel,
      borderRadius: BorderRadius.circular(VaultTokens.chipHeight / 2),
      border: Border.all(
        color: full ? VaultTokens.goldLight : context.colors.borderSubtle,
      ),
    ),
    child: Text(
      text,
      textDirection: TextDirection.ltr,
      style: context.typography.bodySmall.emphasised.copyWith(
        color: full ? VaultTokens.goldInk : context.colors.textSecondary,
      ),
    ),
  );
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
    final colors = context.colors;
    final c = contract;
    final ready = c.claimable && !c.claimed;
    // Name and count on one line; the bar and the claim on the next,
    // indented under the name, so a 320 dp phone keeps a full 48 dp button.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ready
            ? LampGlow(child: ContractIcon(metric: c.metric, done: true))
            : ContractIcon(metric: c.metric, done: c.claimed),
        SizedBox(width: s.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contractName(l, c),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.body.copyWith(
                        color: c.claimed
                            ? colors.textSecondary
                            : colors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: s.xs),
                  Text(
                    l.contractProgress(c.progress, c.target),
                    textDirection: TextDirection.ltr,
                    style: context.typography.caption.copyWith(
                      color: ready ? VaultTokens.gold : colors.textMuted,
                    ),
                  ),
                ],
              ),
              SizedBox(height: s.xs),
              Row(
                children: [
                  Expanded(child: CouncilBar(value: c.progress / c.target)),
                  SizedBox(width: s.sm),
                  CoinBurst(
                    trigger: burst,
                    child: c.claimed
                        ? SizedBox(
                            height: StoreTokens.touchTarget,
                            child: Center(
                              child: ClaimedMark(l.contractClaimed),
                            ),
                          )
                        : VaultPress(
                            child: FilledButton(
                              key: CouncilHubTab.claimKey(c.slot),
                              style:
                                  vaultGoldStyle(
                                    context,
                                    minimumSize: const Size(
                                      StoreTokens.touchTarget * 2,
                                      StoreTokens.touchTarget,
                                    ),
                                  ).merge(
                                    FilledButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: s.md,
                                      ),
                                    ),
                                  ),
                              onPressed: ready && !busy ? onClaim : null,
                              child: Text(l.contractClaim(c.coins)),
                            ),
                          ),
                  ),
                ],
              ),
            ],
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
    final waiting = weekly.claimable && !weekly.claimed;
    final card = _card(context, lit: waiting, [
      VaultHeading(
        leading: waiting
            ? const LampGlow(child: ContractIcon(metric: 'finish', done: true))
            : ContractIcon(metric: 'finish', done: weekly.claimed),
        title: l.weeklyTitle,
        subtitle: l.weeklyBody(weekly.target),
        trailing: _CountPill(
          text: l.contractProgress(weekly.progress, weekly.target),
          full: weekly.progress >= weekly.target,
        ),
      ),
      SizedBox(height: s.md),
      CouncilBar(value: weekly.progress / weekly.target),
      SizedBox(height: s.sm),
      Text(
        weekly.xp > 0
            ? l.weeklyReward(weekly.coins, weekly.xp)
            : l.weeklyRewardCoins(weekly.coins),
        style: context.typography.body.emphasised.copyWith(
          color: VaultTokens.gold,
        ),
      ),
      Text(
        l.weeklyReset,
        style: context.typography.caption.copyWith(color: colors.textMuted),
      ),
      SizedBox(height: s.md),
      CoinBurst(
        trigger: burst,
        child: VaultPress(
          child: FilledButton(
            key: CouncilHubTab.weeklyKey,
            style: vaultGoldStyle(context),
            onPressed: weekly.claimable && !busy ? onClaim : null,
            child: Text(
              weekly.claimed
                  ? l.contractClaimed
                  : l.contractClaim(weekly.coins),
            ),
          ),
        ),
      ),
    ]);
    return VaultGlint(play: waiting, child: card);
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
        loading: () => const VaultSkeleton(cards: 2),
        error: (_, _) => VaultRetry(
          message: l.councilFailed,
          action: l.videoRetry,
          onRetry: () => ref.invalidate(leaderboardProvider),
        ),
        data: (board) {
          final meListed = board.entries.any((e) => e.me);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FeatheredArt(
                feather: Feather.banner,
                child: RasterOr(
                  path: CouncilRaster.leaderboardHeader,
                  height: FeatherTokens.bannerHeight,
                  fit: BoxFit.cover,
                  fallback: Padding(
                    padding: EdgeInsets.only(bottom: s.xs),
                    child: const Center(
                      child: LampGlow(
                        child: Icon(
                          Icons.emoji_events_rounded,
                          size: CouncilLifeTokens.contractIcon,
                          color: VaultTokens.gold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: s.md),
                child: Semantics(
                  header: true,
                  child: Text(
                    l.leaderboardTitle,
                    textAlign: TextAlign.center,
                    style: context.typography.headline.copyWith(
                      color: VaultTokens.goldLight,
                    ),
                  ),
                ),
              ),
              SizedBox(height: s.xs),
              const VaultDivider(),
              Expanded(
                child: board.entries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(s.lg),
                          child: Text(
                            l.leaderboardEmpty,
                            textAlign: TextAlign.center,
                            style: context.typography.body.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        key: listKey,
                        controller: scroll,
                        padding: EdgeInsets.symmetric(horizontal: s.sm),
                        itemCount: board.entries.length,
                        itemBuilder: (context, i) =>
                            _LeaderboardRow(entry: board.entries[i]),
                      ),
              ),
              Padding(
                key: meKey,
                padding: EdgeInsets.fromLTRB(s.md, s.xs, s.md, s.md),
                // Its own Material: the switch's ink paints on the panel.
                child: Material(
                  color: context.colors.surfaceRaised,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.radii.card),
                    side: BorderSide(color: context.colors.borderSubtle),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(s.md, s.sm, s.md, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!meListed)
                          Text(
                            board.myPosition == null
                                ? l.leaderboardNone
                                : '${l.leaderboardYou(board.myPosition!)} · ${l.councilXpTotal(board.myXp)}',
                            style: context.typography.body.emphasised.copyWith(
                              color: VaultTokens.gold,
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A place on the board: a struck disc for the podium, a plain figure
/// after it.
class PodiumDisc extends StatelessWidget {
  final int position;
  const PodiumDisc({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    final type = context.typography;
    if (position > VaultTokens.podium.length) {
      return SizedBox(
        width: VaultTokens.podiumDisc,
        child: Text(
          '$position',
          textAlign: TextAlign.center,
          style: type.title.copyWith(color: context.colors.textMuted),
        ),
      );
    }
    final metal = VaultTokens.podium[position - 1];
    return Container(
      width: VaultTokens.podiumDisc,
      height: VaultTokens.podiumDisc,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          colors: [
            Color.lerp(metal, VaultTokens.goldLight, 0.55)!,
            metal,
            Color.lerp(metal, VaultTokens.goldInk, 0.55)!,
          ],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(color: Color.lerp(metal, VaultTokens.goldInk, 0.3)!),
        boxShadow: context.elevation.level1,
      ),
      child: Text(
        '$position',
        style: type.bodySmall.emphasised.copyWith(
          color: VaultTokens.goldInk,
          height: 1.1,
        ),
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
    final podium = entry.position <= VaultTokens.podium.length;
    return Container(
      key: LeaderboardSheet.rowKey(entry.position),
      margin: EdgeInsets.symmetric(vertical: s.xs / 2),
      decoration: BoxDecoration(
        color: entry.me
            ? VaultTokens.gold.withValues(alpha: StoreTokens.badgeWash)
            : podium
            ? colors.surfaceRaised
            : null,
        borderRadius: BorderRadius.circular(context.radii.button),
        border: entry.me
            ? Border.all(color: VaultTokens.gold)
            : podium
            ? Border.all(color: colors.borderSubtle)
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xs),
      child: Row(
        children: [
          Semantics(
            label: '${entry.position}',
            child: ExcludeSemantics(
              child: RasterOr(
                path: podium ? CouncilRaster.podium(entry.position) : null,
                width: CouncilLifeTokens.leaderboardAvatar,
                height: CouncilLifeTokens.leaderboardAvatar,
                fallback: PodiumDisc(position: entry.position),
              ),
            ),
          ),
          SizedBox(width: s.sm),
          Container(
            padding: const EdgeInsets.all(VaultTokens.chipRim),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: podium
                  ? VaultTokens.podium[entry.position - 1]
                  : colors.borderSubtle,
            ),
            child: ClipOval(
              child: Image.asset(
                entry.gender == 'female'
                    ? AppCouncilArt.avatarFemale
                    : AppCouncilArt.avatarMale,
                width: CouncilLifeTokens.leaderboardAvatar,
                height: CouncilLifeTokens.leaderboardAvatar,
                cacheWidth: StoreTokens.frameDecodeWidth,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.square(
                  dimension: CouncilLifeTokens.leaderboardAvatar,
                ),
              ),
            ),
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: entry.me || podium
                  ? context.typography.body.emphasised
                  : context.typography.body,
            ),
          ),
          RankEmblem(level: entry.level, size: CouncilLifeTokens.emblemRow),
          SizedBox(width: s.sm),
          Text(
            context.l10n.councilXpTotal(entry.xp),
            style: context.typography.bodySmall.copyWith(
              color: podium || entry.me
                  ? VaultTokens.gold
                  : colors.textSecondary,
            ),
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
          ref
              .read(economyCapabilitiesProvider)
              .valueOrNull
              ?.council
              .leaderboard ??
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
    if (!ref.exists(economyCapabilitiesProvider))
      return const SizedBox.shrink();
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
      activeThumbColor: VaultTokens.goldInk,
      activeTrackColor: VaultTokens.gold,
      title: Text(
        l.leaderboardVisibleLabel,
        style: context.typography.body.emphasised,
      ),
      subtitle: Text(
        l.leaderboardVisibleBody,
        style: context.typography.caption.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
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
      _say(
        context,
        status == 'not_found' ? l.inviteNotFound : l.inviteRedeemed,
      );
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
          ? VaultRetry(
              message: l.councilFailed,
              action: l.videoRetry,
              onRetry: () => ref.invalidate(inviteProvider),
            )
          : const SizedBox(
              height: VaultTokens.skeletonCard,
              child: VaultSkeleton(cards: 1),
            );
    }
    if (!status.enabled) return const SizedBox.shrink();
    final code = status.code ?? '';
    return _card(context, key: InviteCard.codeKey, [
      RasterOr(
        path: CouncilRaster.inviteIllustration,
        height: CouncilLifeTokens.emblemCard,
        fallback: VaultHeading(
          leading: const LampGlow(
            child: Icon(
              Icons.handshake_rounded,
              size: CouncilLifeTokens.contractIcon,
              color: VaultTokens.gold,
            ),
          ),
          title: l.inviteTitle,
          subtitle: l.inviteBody(status.inviterCoins, status.inviteeCoins),
        ),
      ),
      if (CouncilRaster.has(CouncilRaster.inviteIllustration)) ...[
        _title(context, l.inviteTitle),
        SizedBox(height: s.xs),
        Text(
          l.inviteBody(status.inviterCoins, status.inviteeCoins),
          style: context.typography.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
      SizedBox(height: s.md),
      // The code on a punched ticket. An identifier in a Latin alphabet:
      // always left to right.
      CustomPaint(
        painter: TicketPainter(
          radius: context.radii.button,
          ground: colors.surfaceRaised,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: s.sm, horizontal: s.lg),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              code,
              textAlign: TextAlign.center,
              style: context.typography.title.copyWith(
                color: VaultTokens.goldLight,
                fontSize:
                    (context.typography.title.fontSize ??
                        CouncilLifeTokens.emblemSeat) *
                    CouncilLifeTokens.inviteCodeScale,
              ),
            ),
          ),
        ),
      ),
      SizedBox(height: s.md),
      Row(
        children: [
          Expanded(
            child: VaultPress(
              child: OutlinedButton.icon(
                key: InviteCard.copyKey,
                style: vaultOutlineStyle(context),
                onPressed: code.isEmpty
                    ? null
                    : () async {
                        final copied = await AppClipboard.copy(code);
                        if (copied && context.mounted) {
                          Haptics.select();
                          _say(context, l.inviteCopied);
                        }
                      },
                icon: const Icon(Icons.copy_rounded),
                label: Text(l.inviteCopy, maxLines: 1),
              ),
            ),
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: VaultPress(
              child: FilledButton.icon(
                key: InviteCard.shareKey,
                style: vaultGoldStyle(context),
                onPressed: code.isEmpty
                    ? null
                    : () => SharePlus.instance.share(
                        ShareParams(text: l.inviteShareText(code)),
                      ),
                icon: const Icon(Icons.share_rounded),
                label: Text(l.inviteShare, maxLines: 1),
              ),
            ),
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
        const VaultDivider(),
        Center(
          child: ClaimedMark(
            status.redeemedRewarded ? l.inviteRewarded : l.inviteRedeemed,
          ),
        ),
      ] else if (status.canRedeem) ...[
        const VaultDivider(),
        Text(
          l.inviteHaveCode,
          style: context.typography.body.emphasised.copyWith(
            color: colors.textPrimary,
          ),
        ),
        SizedBox(height: s.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
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
              builder: (context, _) => VaultPress(
                child: FilledButton(
                  key: InviteCard.redeemKey,
                  style: vaultGoldStyle(context),
                  onPressed: _busy || _field.text.trim().length != 7
                      ? null
                      : _redeem,
                  child: Text(l.inviteRedeem),
                ),
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
        if (weekly != null &&
            weekly.claimable &&
            !(before?.contracts.weekly?.claimable ?? false))
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
                  : context.motion.standard +
                        CouncilLifeTokens.toastStagger * i,
              builder: (context, t, child) => Opacity(opacity: t, child: child),
              child: Padding(
                padding: EdgeInsets.only(bottom: s.xs),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        Color.alphaBlend(
                          VaultTokens.gold.withValues(
                            alpha: VaultTokens.lampWash * 2,
                          ),
                          colors.surfaceRaised,
                        ),
                        colors.surfaceRaised,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(context.radii.button),
                    border: Border.all(
                      color: VaultTokens.gold.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: s.sm,
                      vertical: s.xs,
                    ),
                    child: Row(
                      children: [
                        const LampGlow(child: MafiaCoin()),
                        SizedBox(width: s.xs),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              line,
                              style: context.typography.bodySmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
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
      child: Stack(
        key: dotKey,
        clipBehavior: Clip.none,
        children: [
          child,
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IgnorePointer(
              child: Container(
                width: CouncilLifeTokens.attentionDot,
                height: CouncilLifeTokens.attentionDot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.4),
                    colors: [VaultTokens.oxbloodLight, VaultTokens.oxblood],
                  ),
                  border: Border.all(
                    color: VaultTokens.goldLight,
                    width: VaultTokens.chipRim,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: VaultTokens.oxbloodLight.withValues(
                        alpha: VaultTokens.litGlowAlpha * 3,
                      ),
                      blurRadius: CouncilLifeTokens.attentionDot,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
