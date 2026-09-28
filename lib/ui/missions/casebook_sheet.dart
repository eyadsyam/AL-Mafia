import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/asset_constants.dart';
import '../../app/l10n/app_localizations.dart';
import '../../engine/models/enums.dart' hide Alignment;
import '../economy/council_art.dart';
import '../economy/vault_kit.dart';
import '../fun/character_dossiers.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/feathered_art.dart';
import 'casebook_data.dart';

/// Opens «ملف القضايا» over whatever screen asked for it.
Future<void> showCasebookSheet(BuildContext context, {int page = 0}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surfaceBase,
      builder: (_) => FractionallySizedBox(
        heightFactor: CasebookTokens.sheetHeight,
        child: CasebookSheet(initialPage: page),
      ),
    );

/// The sentence a case is written in, from its metric and target.
String caseLine(AppLocalizations l, String metric, int target) =>
    switch (metric) {
      'finish' || 'matches' => l.caseFinish(target),
      'win' => l.caseWin(target),
      'host' => l.caseHost(target),
      'reunion' => l.caseReunion(target),
      'public_room' || 'public' => l.casePublic(target),
      'invite_joined' || 'invite' => l.caseInvite(target),
      'streak_days' || 'streak' => l.caseStreak(target),
      'daily_all' || 'dailies' => l.caseDailies(target),
      'season_level' || 'level' => l.caseLevel(target),
      _ => l.caseFinish(target),
    };

/// The Council's contract art that stands for a case [metric] inside its
/// seal on the record wall.
String _sealArt(String metric) => switch (metric) {
  'win' => 'win',
  'host' => 'host',
  'reunion' || 'invite_joined' || 'invite' => 'reunion',
  'public_room' || 'public' => 'town',
  'daily_all' || 'dailies' => 'bonus_all3',
  'streak_days' || 'streak' || 'season_level' || 'level' => 'weekly',
  _ => 'finish',
};

Color casebookRoleColor(BuildContext context, Role role) {
  final colors = context.colors;
  return switch (role) {
    Role.mafia => colors.roleMafia,
    Role.doctor => colors.roleDoctor,
    Role.detective => colors.roleDetective,
    Role.citizen => colors.roleCitizen,
  };
}

class CasebookSheet extends ConsumerStatefulWidget {
  final int initialPage;
  const CasebookSheet({super.key, this.initialPage = 0});

  static const tonightKey = ValueKey('casebook_tonight');
  static const seasonKey = ValueKey('casebook_season');
  static const legacyKey = ValueKey('casebook_legacy');
  static Key claimKey(String id) => ValueKey('casebook_claim_$id');

  @override
  ConsumerState<CasebookSheet> createState() => _CasebookSheetState();
}

class _CasebookSheetState extends ConsumerState<CasebookSheet> {
  late int _page = widget.initialPage;
  String? _busy;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(casebookProvider.notifier).refresh());
  }

  Future<void> _claim(String id, Future<CaseGrant> Function() run) async {
    if (_busy != null) return;
    setState(() {
      _busy = id;
      _error = null;
    });
    try {
      await run();
    } on CaseClaimFailed {
      if (mounted) setState(() => _error = context.l10n.casebookClaimError);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(casebookProvider);
    final book = async.valueOrNull;
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final controller = ref.read(casebookProvider.notifier);

    final Widget body;
    if (book == null) {
      body = async.hasError
          ? VaultRetry(
              message: l.casebookFailed,
              action: l.casebookRetry,
              onRetry: controller.refresh,
            )
          : const VaultSkeleton();
    } else {
      body = switch (_page) {
        0 => _TonightPage(
          key: CasebookSheet.tonightKey,
          book: book,
          busy: _busy,
          onClaim: (weekly, slot) => _claim(
            '${weekly ? 'w' : 'd'}$slot',
            () => controller.claimMission(weekly: weekly, slot: slot),
          ),
        ),
        1 => _SeasonPage(
          key: CasebookSheet.seasonKey,
          season: book.season,
          busy: _busy,
          onClaim: (level) =>
              _claim('s$level', () => controller.claimSeason(level)),
        ),
        _ => _LegacyPage(
          key: CasebookSheet.legacyKey,
          book: book,
          busy: _busy,
          onClaim: (code) =>
              _claim('a$code', () => controller.claimAchievement(code)),
        ),
      };
    }

    return SafeArea(
      child: Column(
        children: [
          _Hero(season: book?.season),
          _Tabs(
            page: _page,
            ready: [
              (book?.daily.ready ?? 0) + (book?.weekly.ready ?? 0),
              book?.season.ready ?? 0,
              book?.achievements.where((a) => a.claimable).length ?? 0,
            ],
            onPage: (page) => setState(() => _page = page),
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: s.sm),
              child: Text(
                _error!,
                style: type.bodySmall.copyWith(color: colors.accentCrimson),
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: reduce ? Duration.zero : CasebookTokens.pageTurn,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero ──────────────────────────────────────────────────────────────────

/// The case room dissolving into the sheet, the title struck in gold, and a
/// stamped plate: the season level on a gold disc, the days left beside it.
class _Hero extends StatelessWidget {
  final CaseSeason? season;
  const _Hero({required this.season});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final season = this.season;
    return SizedBox(
      height: CasebookTokens.heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FeatheredArt(
            feather: Feather.banner,
            child: Image.asset(
              AppCouncilArt.backdropVerdict,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.surfaceBase.withValues(alpha: 0),
                  colors.surfaceBase.withValues(
                    alpha: CasebookTokens.heroShade,
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            start: s.screenMargin,
            end: s.screenMargin,
            bottom: s.sm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.casebookTitle,
                    textAlign: TextAlign.center,
                    style: context.typography.headline.copyWith(
                      color: VaultTokens.goldLight,
                    ),
                  ),
                ),
                if (season != null) ...[
                  SizedBox(height: s.xs),
                  _SeasonPlate(season: season),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonPlate extends StatelessWidget {
  final CaseSeason season;
  const _SeasonPlate({required this.season});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    // D4 — a season just begun reads «١», never «٠».
    final level = math.max(1, season.level);
    final ends = season.endsAt;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: l.casebookLevel(level),
          child: ExcludeSemantics(
            child: LampGlow(
              child: _GoldDisc(
                level: level,
                size: CasebookTokens.plateDisc,
              ),
            ),
          ),
        ),
        if (ends != null) ...[
          SizedBox(width: s.sm),
          Flexible(
            child: Container(
              height: CasebookTokens.plateHeight,
              padding: EdgeInsets.symmetric(horizontal: s.sm + s.xs),
              decoration: BoxDecoration(
                color: VaultTokens.enamel,
                borderRadius: BorderRadius.circular(
                  CasebookTokens.plateHeight / 2,
                ),
                border: Border.all(
                  color: VaultTokens.gold.withValues(
                    alpha: CasebookTokens.plateRimAlpha,
                  ),
                ),
              ),
              child: Align(
                widthFactor: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    l.casebookDaysLeft(
                      season.daysLeft(DateTime.now().toUtc()),
                    ),
                    maxLines: 1,
                    style: context.typography.caption.emphasised.copyWith(
                      color: VaultTokens.goldLight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A struck-gold disc with a number pressed into it: the season level on
/// the plate, a reached stop on the thread.
class _GoldDisc extends StatelessWidget {
  final int level;
  final double size;
  const _GoldDisc({required this.level, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [VaultTokens.goldLight, VaultTokens.gold, VaultTokens.goldDeep],
      ),
      border: Border.all(
        color: VaultTokens.goldLight,
        width: CasebookTokens.sealRim,
      ),
      boxShadow: context.elevation.level1,
    ),
    child: _EngravedRing(
      color: VaultTokens.goldInk,
      child: _Numeral(level, color: VaultTokens.goldInk),
    ),
  );
}

/// A hairline ring engraved just inside a disc.
class _EngravedRing extends StatelessWidget {
  final Color color;
  final Widget child;
  const _EngravedRing({required this.color, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(CasebookTokens.sealInnerInset),
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: CasebookTokens.sealInnerAlpha),
          width: VaultTokens.engraveWidth,
        ),
      ),
      child: Center(child: child),
    ),
  );
}

class _Numeral extends StatelessWidget {
  final int value;
  final Color color;
  const _Numeral(this.value, {required this.color});

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      '$value',
      textDirection: TextDirection.ltr,
      style: context.typography.title.copyWith(color: color),
    ),
  );
}

// ─── Tabs ──────────────────────────────────────────────────────────────────

/// Three words across the top, the open one struck with a gold rule; a small
/// gold plate counts what is waiting on each page.
class _Tabs extends StatelessWidget {
  final int page;
  final List<int> ready;
  final ValueChanged<int> onPage;
  const _Tabs({required this.page, required this.ready, required this.onPage});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final type = context.typography;
    final colors = context.colors;
    final s = context.spacing;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final labels = [l.casebookTonight, l.casebookSeason, l.casebookLegacy];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.screenMargin),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: VaultTokens.gold.withValues(
                alpha: VaultTokens.engraveAlpha,
              ),
            ),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == page,
                  button: true,
                  child: InkWell(
                    onTap: () => onPage(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: kMinInteractiveDimension,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(height: s.sm),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  labels[i],
                                  style: type.title.copyWith(
                                    color: i == page
                                        ? VaultTokens.goldLight
                                        : colors.textMuted,
                                  ),
                                ),
                                if (ready[i] > 0) ...[
                                  SizedBox(width: s.xs),
                                  _CountPlate(ready[i]),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: s.xs),
                          AnimatedContainer(
                            duration: reduce
                                ? Duration.zero
                                : CasebookTokens.pageTurn,
                            curve: Curves.easeOutCubic,
                            height: CasebookTokens.tabRuleHeight,
                            width: i == page ? CasebookTokens.tabRule : 0,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                CasebookTokens.tabRuleHeight,
                              ),
                              gradient: const LinearGradient(
                                colors: [
                                  VaultTokens.goldDeep,
                                  VaultTokens.goldLight,
                                  VaultTokens.goldDeep,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: VaultTokens.gold.withValues(
                                    alpha: CasebookTokens.tabGlowAlpha,
                                  ),
                                  blurRadius: CasebookTokens.tabGlowBlur,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «2» on a small struck-gold plate: this many things are waiting.
class _CountPlate extends StatelessWidget {
  final int count;
  const _CountPlate(this.count);

  @override
  Widget build(BuildContext context) => Container(
    height: CasebookTokens.countPlate,
    constraints: const BoxConstraints(minWidth: CasebookTokens.countPlate),
    padding: EdgeInsets.symmetric(horizontal: context.spacing.xs),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(CasebookTokens.countPlate / 2),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [VaultTokens.goldLight, VaultTokens.gold],
      ),
      border: Border.all(
        color: VaultTokens.goldLight,
        width: VaultTokens.chipRim,
      ),
    ),
    alignment: Alignment.center,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '$count',
        textDirection: TextDirection.ltr,
        style: context.typography.caption.emphasised.copyWith(
          color: VaultTokens.goldInk,
        ),
      ),
    ),
  );
}

/// «3 من 5» on an enamel plate; gold once it is full.
class _ProgressPlate extends StatelessWidget {
  final String text;
  final bool full;
  const _ProgressPlate({required this.text, this.full = false});

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
      maxLines: 1,
      style: context.typography.caption.emphasised.copyWith(
        color: full ? VaultTokens.goldInk : context.colors.textSecondary,
      ),
    ),
  );
}

// ─── Motion ────────────────────────────────────────────────────────────────

/// A row rising into place once, a beat after the one above it. Still under
/// reduced motion.
class _Rise extends StatelessWidget {
  final int index;
  final Widget child;
  const _Rise({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final steps = math.min(index, CasebookTokens.riseMaxSteps);
    final delay = CasebookTokens.riseStep * steps;
    final total = CasebookTokens.rise + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * CasebookTokens.riseLift),
          child: child,
        ),
      ),
    );
  }
}

// ─── Claiming ──────────────────────────────────────────────────────────────

/// Struck gold to take a reward; the gold check once it is taken. A case
/// still open shows the same button as an empty slot.
class _ClaimButton extends StatelessWidget {
  final Key? claimKey;
  final bool claimable;
  final bool claimed;
  final bool busy;
  final bool expand;
  final VoidCallback onClaim;
  const _ClaimButton({
    required this.claimKey,
    required this.claimable,
    required this.claimed,
    required this.busy,
    required this.onClaim,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    if (claimed) {
      return SizedBox(
        height: StoreTokens.touchTarget,
        child: Center(child: ClaimedMark(l.casebookClaimed)),
      );
    }
    final button = VaultPress(
      child: FilledButton(
        key: claimable ? claimKey : null,
        style: vaultGoldStyle(
          context,
          minimumSize: Size(
            expand ? 0 : CasebookTokens.claimMinWidth,
            StoreTokens.touchTarget,
          ),
        ).merge(
          FilledButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: expand ? s.xs : s.md),
          ),
        ),
        onPressed: claimable && !busy ? onClaim : null,
        child: busy
            ? const SizedBox.square(
                dimension: CasebookTokens.busyIndicator,
                child: CircularProgressIndicator(
                  strokeWidth: CasebookTokens.busyStroke,
                  color: VaultTokens.gold,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(l.casebookClaim),
              ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _Rewards extends StatelessWidget {
  final int coins;
  final int xp;
  final bool muted;
  const _Rewards({required this.coins, required this.xp, this.muted = false});

  /// One line of chips, scaled down (never clipped) when the room is short.
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (coins > 0) RewardChip(coins, muted: muted),
        if (coins > 0 && xp > 0) SizedBox(width: context.spacing.xs),
        if (xp > 0) RewardChip(xp, muted: muted, unit: context.l10n.xpUnit),
      ],
    ),
  );
}

// ─── Tonight ────────────────────────────────────────────────────────────────

class _TonightPage extends StatelessWidget {
  final Casebook book;
  final String? busy;
  final void Function(bool weekly, int slot) onClaim;
  const _TonightPage({
    super.key,
    required this.book,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final bonus = book.daily.bonus;
    var row = 0;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        s.screenMargin,
        s.md + CasebookTokens.portraitRise,
        s.screenMargin,
        s.xl,
      ),
      children: [
        for (final mission in book.daily.missions)
          _Rise(
            index: row++,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: s.sm + CasebookTokens.portraitRise,
              ),
              child: _CaseCard(
                mission: mission,
                busy: busy == 'd${mission.slot}',
                onClaim: () => onClaim(false, mission.slot),
              ),
            ),
          ),
        if (bonus != null && (bonus.coins > 0 || bonus.xp > 0))
          _Rise(
            index: row++,
            child: _BonusCard(bonus: bonus),
          ),
        for (final mission in book.weekly.missions)
          _Rise(
            index: row++,
            child: Padding(
              padding: EdgeInsets.only(
                top: s.lg + CasebookTokens.weeklyPortraitRise,
                bottom: s.sm,
              ),
              child: _CaseCard(
                mission: mission,
                weekly: true,
                busy: busy == 'w${mission.slot}',
                onClaim: () => onClaim(true, mission.slot),
              ),
            ),
          ),
      ],
    );
  }
}

/// One case on an engraved panel: the character who hands it over stands at
/// the edge, half inside it; the metal bar is how far; the chips are what
/// it pays. The weekly case is lit and ribboned, its character on the other
/// side so the ribbon has room.
class _CaseCard extends StatelessWidget {
  final CaseMission mission;
  final bool weekly;
  final bool busy;
  final VoidCallback onClaim;
  const _CaseCard({
    required this.mission,
    required this.busy,
    required this.onClaim,
    this.weekly = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final tint = casebookRoleColor(context, mission.voice);
    final done = mission.claimed;
    final ready = mission.claimable && !done;
    final portrait = weekly
        ? CasebookTokens.weeklyPortraitWidth
        : CasebookTokens.portraitWidth;
    final rise = weekly
        ? CasebookTokens.weeklyPortraitRise
        : CasebookTokens.portraitRise;
    final lift = weekly ? VaultTokens.tagLift : 0.0;
    Widget claim({bool expand = false}) => _ClaimButton(
      claimKey: CasebookSheet.claimKey('${weekly ? 'w' : 'd'}${mission.slot}'),
      claimable: mission.claimable,
      claimed: done,
      busy: busy,
      expand: expand,
      onClaim: onClaim,
    );
    final card = VaultCard(
      lit: ready || (weekly && !done),
      tag: weekly ? l.casebookWeekly : null,
      padding: EdgeInsetsDirectional.fromSTEB(
        weekly ? s.md : portrait,
        s.md + lift / 2,
        weekly ? portrait : s.md,
        s.md,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.casebookFrom(EngineCopy.roleName(l, mission.voice)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.caption.emphasised.copyWith(color: tint),
              ),
            ),
            SizedBox(width: s.xs),
            _ProgressPlate(
              text: l.casebookProgress(
                math.min(mission.progress, mission.target),
                mission.target,
              ),
              full: mission.fraction >= 1 && !done,
            ),
          ],
        ),
        Text(
          caseLine(l, mission.metric, mission.target),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: (weekly ? type.title : type.body.emphasised).copyWith(
            color: done ? colors.textSecondary : colors.textPrimary,
          ),
        ),
        SizedBox(height: s.sm),
        VaultBar(value: mission.fraction, height: CouncilLifeTokens.barHeight),
        SizedBox(height: s.sm),
        // The weekly case pays out under a full-width bar of gold, the way
        // the Council's weekly contract does.
        if (weekly) ...[
          _Rewards(coins: mission.coins, xp: mission.xp, muted: done),
          SizedBox(height: s.sm),
          claim(expand: true),
        ] else
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _Rewards(
                    coins: mission.coins,
                    xp: mission.xp,
                    muted: done,
                  ),
                ),
              ),
              SizedBox(width: s.sm),
              claim(),
            ],
          ),
      ],
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        VaultGlint(play: ready, child: card),
        // The character, unframed, melting into the panel.
        PositionedDirectional(
          start: weekly ? null : 0,
          end: weekly ? 0 : null,
          top: lift - rise,
          bottom: 0,
          width: portrait,
          child: IgnorePointer(
            child: Opacity(
              opacity: done ? CasebookTokens.donePortraitOpacity : 1,
              child: FeatheredArt(
                feather: Feather.hero,
                halo: ready || weekly,
                child: BondPortraitArt(
                  role: mission.voice,
                  fit: BoxFit.cover,
                  alignment: CasebookTokens.faceFocus,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// All of tonight's cases closed pays a little more: the three seals.
class _BonusCard extends StatelessWidget {
  final CaseBonus bonus;
  const _BonusCard({required this.bonus});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final icon = ContractIcon(metric: 'bonus_all3', done: bonus.claimed);
    return VaultCard(
      lit: bonus.claimable && !bonus.claimed,
      children: [
        Row(
          children: [
            bonus.claimable && !bonus.claimed ? LampGlow(child: icon) : icon,
            SizedBox(width: s.sm),
            Expanded(
              child: Text(
                bonus.claimed ? l.casebookBonusTaken : l.casebookBonus,
                style: context.typography.bodySmall.copyWith(
                  color: bonus.claimed
                      ? VaultTokens.gold
                      : context.colors.textSecondary,
                ),
              ),
            ),
            SizedBox(width: s.sm),
            Flexible(
              child: _Rewards(
                coins: bonus.coins,
                xp: bonus.xp,
                muted: bonus.claimed,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Season ────────────────────────────────────────────────────────────────

/// Twenty stops along one gold thread, winding down the page. Walked stops
/// are struck gold, the next one glows, the rest wait in dim metal.
class _SeasonPage extends StatelessWidget {
  final CaseSeason season;
  final String? busy;
  final ValueChanged<int> onClaim;
  const _SeasonPage({
    super.key,
    required this.season,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final levels = [for (var i = 1; i <= season.maxLevel; i++) i];
    final waiting = season.ready > 0;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        s.screenMargin,
        s.md,
        s.screenMargin,
        s.xl,
      ),
      children: [
        _Rise(
          index: 0,
          child: VaultCard(
            lit: waiting,
            children: [
              VaultHeading(
                leading: const LampGlow(
                  child: ContractIcon(metric: 'weekly', done: true),
                ),
                // D4 — a season just begun reads «مستوى ١», never «٠». The
                // stops below still count the real level.
                title: season.complete
                    ? l.casebookSeasonDone
                    : l.casebookLevel(math.max(1, season.level)),
                titleColor: VaultTokens.goldLight,
                trailing: season.complete
                    ? null
                    : _ProgressPlate(
                        text: l.casebookProgress(
                          season.levelXp,
                          season.xpPerLevel,
                        ),
                      ),
              ),
              if (!season.complete) ...[
                SizedBox(height: s.md),
                VaultBar(value: season.levelFraction),
              ],
            ],
          ),
        ),
        SizedBox(height: s.lg),
        _Rise(
          index: 1,
          child: SizedBox(
            height: levels.length * CasebookTokens.stopHeight,
            child: LayoutBuilder(
              builder: (context, box) {
                final rtl = Directionality.of(context) == TextDirection.rtl;
                Offset centre(int index) {
                  final swing = math.sin(
                    index * CasebookTokens.windFrequency,
                  );
                  final dx =
                      box.maxWidth / 2 +
                      swing * box.maxWidth * CasebookTokens.windAmplitude;
                  return Offset(
                    rtl ? box.maxWidth - dx : dx,
                    (index + 0.5) * CasebookTokens.stopHeight,
                  );
                }

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ThreadPainter(
                          points: [
                            for (var i = 0; i < levels.length; i++) centre(i),
                          ],
                          reached: season.level,
                          partial: season.complete ? 0 : season.levelFraction,
                          slack: colors.borderSubtle,
                        ),
                      ),
                    ),
                    for (var i = 0; i < levels.length; i++)
                      _SeasonStopView(
                        centre: centre(i),
                        width: box.maxWidth,
                        stop: season.stop(levels[i]),
                        reached: levels[i] <= season.level,
                        next: levels[i] == season.level + 1,
                        busy: busy == 's${levels[i]}',
                        onClaim: () => onClaim(levels[i]),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// The thread: struck gold with a soft halo and a bright edge where it has
/// been walked (and part-way into the next stop, as far as the level's
/// points go), dashed dim metal ahead.
class _ThreadPainter extends CustomPainter {
  final List<Offset> points;
  final int reached;
  final double partial;
  final Color slack;
  const _ThreadPainter({
    required this.points,
    required this.reached,
    required this.partial,
    required this.slack,
  });

  Path _segment(Offset a, Offset b) {
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(a.dx, mid.dy, mid.dx, mid.dy)
      ..quadraticBezierTo(b.dx, mid.dy, b.dx, b.dy);
  }

  void _gold(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = CasebookTokens.threadHalo
        ..strokeCap = StrokeCap.round
        ..color = VaultTokens.gold.withValues(
          alpha: CasebookTokens.threadHaloAlpha,
        )
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          CasebookTokens.threadHalo / 2,
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = CasebookTokens.threadWidth
        ..strokeCap = StrokeCap.round
        ..color = VaultTokens.gold,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = CasebookTokens.threadWidth / 3
        ..strokeCap = StrokeCap.round
        ..color = VaultTokens.goldLight.withValues(
          alpha: CasebookTokens.threadShineAlpha,
        ),
    );
  }

  void _dashed(Canvas canvas, Path path, double from) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = CasebookTokens.threadSlackWidth
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        slack,
        VaultTokens.goldDeep,
        CasebookTokens.threadSlackAlpha,
      )!;
    for (final metric in path.computeMetrics()) {
      var d = metric.length * from;
      while (d < metric.length) {
        final end = math.min(d + CasebookTokens.threadDash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + CasebookTokens.threadGap;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i + 1 < points.length; i++) {
      final path = _segment(points[i], points[i + 1]);
      if (i + 2 <= reached) {
        _gold(canvas, path);
      } else if (i + 1 == reached && partial > 0) {
        for (final metric in path.computeMetrics()) {
          _gold(canvas, metric.extractPath(0, metric.length * partial));
        }
        _dashed(canvas, path, partial);
      } else {
        _dashed(canvas, path, 0);
      }
    }
  }

  @override
  bool shouldRepaint(_ThreadPainter old) =>
      old.reached != reached ||
      old.partial != partial ||
      old.points.length != points.length ||
      old.slack != slack;
}

class _SeasonStopView extends StatelessWidget {
  final Offset centre;
  final double width;
  final SeasonStop stop;
  final bool reached;
  final bool next;
  final bool busy;
  final VoidCallback onClaim;
  const _SeasonStopView({
    required this.centre,
    required this.width,
    required this.stop,
    required this.reached,
    required this.next,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    const d = CasebookTokens.seal;
    // The reward is written on the wider side of the thread.
    final leftSide = centre.dx > width / 2;
    Widget tag(String text) => Opacity(
      opacity: reached ? 1 : CasebookTokens.lockedMetalAlpha,
      child: VaultTag(text),
    );
    final label = Column(
      crossAxisAlignment: leftSide
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Waiting: the chip and the gold beside it, level with the stop.
        if (stop.claimable)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stop.coins > 0) ...[
                RewardChip(stop.coins),
                SizedBox(width: s.xs),
              ],
              _ClaimButton(
                claimKey: CasebookSheet.claimKey('s${stop.level}'),
                claimable: true,
                claimed: false,
                busy: busy,
                onClaim: onClaim,
              ),
            ],
          )
        else if (stop.coins > 0)
          RewardChip(stop.coins, muted: !reached),
        if (stop.title != null) ...[
          SizedBox(height: s.xs),
          tag(l.casebookTitleReward),
        ],
        if (stop.item != null) ...[
          SizedBox(height: s.xs),
          tag(l.casebookItemReward),
        ],
        if (!stop.claimable && stop.claimed && !stop.empty)
          ClaimedMark(l.casebookClaimed),
      ],
    );
    final seal = reached
        ? _GoldDisc(level: stop.level, size: d)
        : _MetalDisc(level: stop.level, next: next);
    return Positioned(
      left: 0,
      right: 0,
      top: centre.dy - CasebookTokens.stopHeight / 2,
      height: CasebookTokens.stopHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: centre.dx - d / 2,
            top: (CasebookTokens.stopHeight - d) / 2,
            width: d,
            height: d,
            child: stop.claimable || next ? LampGlow(child: seal) : seal,
          ),
          if (!stop.empty)
            Positioned(
              top: 0,
              bottom: 0,
              left: leftSide ? 0 : centre.dx + d / 2 + s.sm,
              right: leftSide ? width - centre.dx + d / 2 + s.sm : 0,
              child: Align(
                alignment: leftSide
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: FittedBox(fit: BoxFit.scaleDown, child: label),
              ),
            ),
        ],
      ),
    );
  }
}

/// A stop not reached yet: dark enamel in a dim metal rim; the next one's
/// rim is gold and glows.
class _MetalDisc extends StatelessWidget {
  final int level;
  final bool next;
  const _MetalDisc({required this.level, required this.next});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rim = next
        ? VaultTokens.gold
        : Color.lerp(
            colors.borderSubtle,
            VaultTokens.goldDeep,
            CasebookTokens.lockedMetalAlpha,
          )!;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [colors.surfaceRaised, VaultTokens.enamel],
        ),
        border: Border.all(
          color: rim,
          width: next ? CasebookTokens.sealRimNext : CasebookTokens.sealRim,
        ),
        boxShadow: next
            ? [
                BoxShadow(
                  color: VaultTokens.gold.withValues(
                    alpha: CasebookTokens.glowAlpha,
                  ),
                  blurRadius: CasebookTokens.glowBlur,
                ),
              ]
            : null,
      ),
      child: _EngravedRing(
        color: next ? VaultTokens.goldLight : rim,
        child: _Numeral(
          level,
          color: next ? VaultTokens.goldLight : colors.textMuted,
        ),
      ),
    );
  }
}

// ─── Legacy ────────────────────────────────────────────────────────────────

class _LegacyPage extends StatelessWidget {
  final Casebook book;
  final String? busy;
  final ValueChanged<String> onClaim;
  const _LegacyPage({
    super.key,
    required this.book,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final won = book.achievements
        .where((a) => a.unlocked || a.claimed)
        .length;
    final waiting = book.achievements.any((a) => a.claimable);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        s.screenMargin,
        s.md,
        s.screenMargin,
        s.xl,
      ),
      children: [
        if (book.rank.level > 0) ...[
          _Rise(
            index: 0,
            child: VaultCard(
              children: [
                VaultHeading(
                  leading: LampGlow(
                    child: RankEmblem(
                      level: book.rank.level,
                      size: CasebookTokens.rankEmblem,
                    ),
                  ),
                  title: l.casebookRank(math.max(1, book.rank.level)),
                  subtitle: rankTitle(l, rankTier(book.rank.level)),
                  titleColor: VaultTokens.goldLight,
                ),
              ],
            ),
          ),
          SizedBox(height: s.md),
        ],
        if (book.achievements.isNotEmpty)
          _Rise(
            index: 1,
            child: VaultCard(
              lit: waiting,
              children: [
                VaultHeading(
                  title: l.casebookAchievements,
                  trailing: _ProgressPlate(
                    text: l.casebookProgress(won, book.achievements.length),
                    full: won == book.achievements.length,
                  ),
                ),
                SizedBox(height: s.md),
                LayoutBuilder(
                  builder: (context, box) {
                    const columns = CasebookTokens.legacyColumns;
                    final tile =
                        (box.maxWidth - s.sm * (columns - 1)) / columns;
                    return Wrap(
                      spacing: s.sm,
                      runSpacing: s.lg,
                      children: [
                        for (final a in book.achievements)
                          SizedBox(
                            width: tile,
                            child: _SealTile(
                              achievement: a,
                              busy: busy == 'a${a.code}',
                              onClaim: () => onClaim(a.code),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: s.xl),
          child: CharacterDossiers(
            onOpen: () {
              Navigator.of(context).pop();
              GoRouter.maybeOf(context)?.push('/characters');
            },
          ),
        ),
      ],
    );
  }
}

/// An achievement as a seal on the wall: the Council's gold ring around the
/// case's own emblem. Locked, it is the same seal pressed grey and dim into
/// the page, with how far along it is under it.
class _SealTile extends StatelessWidget {
  final CaseAchievement achievement;
  final bool busy;
  final VoidCallback onClaim;
  const _SealTile({
    required this.achievement,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final a = achievement;
    final won = a.unlocked || a.claimed;
    const size = CasebookTokens.legacySeal;
    const g = CasebookTokens.luma;
    Widget seal = SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const RasterOr(
            path: CouncilRaster.councilSeal,
            width: size,
            height: size,
            fallback: CouncilSealArt(),
          ),
          ContractIcon(
            metric: _sealArt(a.metric),
            size: size * CasebookTokens.legacyIcon,
            done: won,
          ),
        ],
      ),
    );
    if (!won) {
      seal = Opacity(
        opacity: CasebookTokens.lockedSealOpacity,
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix([
            g[0], g[1], g[2], 0, 0, //
            g[0], g[1], g[2], 0, 0, //
            g[0], g[1], g[2], 0, 0, //
            0, 0, 0, 1, 0,
          ]),
          child: seal,
        ),
      );
    } else if (a.claimable) {
      seal = VaultGlint(
        borderRadius: BorderRadius.circular(size / 2),
        child: LampGlow(child: seal),
      );
    }
    return Column(
      children: [
        ExcludeSemantics(child: seal),
        SizedBox(height: s.xs),
        Text(
          caseLine(l, a.metric, a.target),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: context.typography.caption.copyWith(
            color: won ? colors.textPrimary : colors.textSecondary,
          ),
        ),
        SizedBox(height: s.xs),
        if (a.claimable)
          _ClaimButton(
            claimKey: CasebookSheet.claimKey('a${a.code}'),
            claimable: true,
            claimed: false,
            busy: busy,
            expand: true,
            onClaim: onClaim,
          )
        else if (a.claimed)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: ClaimedMark(l.casebookClaimed),
          )
        else if (!won) ...[
          VaultBar(value: a.fraction, height: CasebookTokens.legacyBar),
          SizedBox(height: s.xs),
          _Rewards(coins: a.coins, xp: a.xp, muted: true),
        ],
      ],
    );
  }
}

// ─── Entry ─────────────────────────────────────────────────────────────────

/// The Casebook's door on Online and in the Council: the four faces on an
/// engraved panel, what is waiting to be taken, the season's bar. Nothing
/// while the feature is off.
class CasebookEntry extends ConsumerWidget {
  const CasebookEntry({super.key});

  static const entryKey = ValueKey('casebook_entry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(casebookProvider).valueOrNull;
    if (book == null || !book.enabled) return const SizedBox.shrink();
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final ready = book.ready;
    return Padding(
      padding: EdgeInsets.only(bottom: s.md),
      child: Semantics(
        button: true,
        child: InkWell(
          key: entryKey,
          borderRadius: BorderRadius.circular(context.radii.card),
          onTap: () => showCasebookSheet(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: CasebookTokens.entryHeight,
            ),
            child: Stack(
              children: [
                VaultGlint(
                  play: ready > 0,
                  child: VaultCard(
                    lit: ready > 0,
                    padding: EdgeInsetsDirectional.fromSTEB(
                      CasebookTokens.entryFacesWidth + s.sm,
                      s.md,
                      s.md,
                      s.md,
                    ),
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              l.casebookTitle,
                              style: type.title.copyWith(
                                color: VaultTokens.goldLight,
                              ),
                            ),
                          ),
                          if (ready > 0) ...[
                            SizedBox(width: s.xs),
                            _CountPlate(ready),
                          ],
                        ],
                      ),
                      Text(
                        ready > 0
                            ? l.casebookReady(ready)
                            : l.casebookLevel(math.max(1, book.season.level)),
                        style: type.bodySmall.copyWith(
                          color: ready > 0
                              ? VaultTokens.gold
                              : colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: s.sm),
                      VaultBar(
                        value: book.season.levelFraction,
                        height: CouncilLifeTokens.barHeight,
                      ),
                    ],
                  ),
                ),
                // Four faces on the panel's edge, fading into it.
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: CasebookTokens.entryFacesWidth,
                  child: IgnorePointer(
                    child: FeatheredArt(
                      feather: Feather.banner,
                      halo: false,
                      child: Row(
                        children: [
                          for (final role in casebookVoices)
                            Expanded(
                              child: BondPortraitArt(
                                role: role,
                                fit: BoxFit.cover,
                                alignment: CasebookTokens.faceFocus,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
