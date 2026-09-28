import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/asset_constants.dart';
import '../../app/l10n/app_localizations.dart';
import '../../engine/models/enums.dart' hide Alignment;
import '../economy/mafia_coin.dart';
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
    final controller = ref.read(casebookProvider.notifier);

    final Widget body;
    if (book == null) {
      body = async.hasError
          ? _Failed(onRetry: controller.refresh)
          : const Center(child: CircularProgressIndicator());
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

    final season = book?.season;
    return SafeArea(
      child: Column(
        children: [
          // The case room itself, dissolving into the sheet: no header bar.
          SizedBox(
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
                PositionedDirectional(
                  start: s.screenMargin,
                  end: s.screenMargin,
                  bottom: s.sm,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.casebookTitle,
                        textAlign: TextAlign.center,
                        style: type.headline.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (season != null && season.endsAt != null)
                        Text(
                          l.casebookDaysLeft(
                            season.daysLeft(DateTime.now().toUtc()),
                          ),
                          textAlign: TextAlign.center,
                          style: type.bodySmall.copyWith(
                            color: colors.accentGold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
              duration: CasebookTokens.pageTurn,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  final VoidCallback onRetry;
  const _Failed({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.casebookFailed, style: context.typography.body),
          SizedBox(height: context.spacing.sm),
          OutlinedButton(onPressed: onRetry, child: Text(l.casebookRetry)),
        ],
      ),
    );
  }
}

/// Three words across the top, the open one underlined in red string, a wax
/// dot on any page with something waiting.
class _Tabs extends StatelessWidget {
  final int page;
  final List<int> ready;
  final ValueChanged<int> onPage;
  const _Tabs({required this.page, required this.ready, required this.onPage});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final labels = [l.casebookTonight, l.casebookSeason, l.casebookLegacy];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.screenMargin),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              labels[i],
                              style: type.title.copyWith(
                                color: i == page
                                    ? colors.textPrimary
                                    : colors.textMuted,
                              ),
                            ),
                            if (ready[i] > 0) ...[
                              SizedBox(width: s.xs),
                              const _WaxDot(),
                            ],
                          ],
                        ),
                        ),
                        SizedBox(height: s.xs),
                        AnimatedContainer(
                          duration: CasebookTokens.pageTurn,
                          height: CasebookTokens.stringWidth,
                          width: i == page ? CasebookTokens.tabRule : 0,
                          color: colors.accentCrimson,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WaxDot extends StatelessWidget {
  const _WaxDot();

  @override
  Widget build(BuildContext context) => Container(
    width: CasebookTokens.waxDot,
    height: CasebookTokens.waxDot,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [CouncilLifeTokens.gemLight, CouncilLifeTokens.sealOuter],
      ),
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
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final bonus = book.daily.bonus;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        s.screenMargin,
        s.md,
        s.screenMargin,
        s.xl,
      ),
      children: [
        for (final mission in book.daily.missions)
          _CaseSlip(
            mission: mission,
            busy: busy == 'd${mission.slot}',
            onClaim: () => onClaim(false, mission.slot),
          ),
        if (bonus != null && (bonus.coins > 0 || bonus.xp > 0))
          Padding(
            padding: EdgeInsets.only(top: s.xs, bottom: s.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    bonus.claimed ? l.casebookBonusTaken : l.casebookBonus,
                    style: type.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ),
                SizedBox(width: s.sm),
                _Reward(coins: bonus.coins, xp: bonus.xp),
              ],
            ),
          ),
        for (final mission in book.weekly.missions) ...[
          Padding(
            padding: EdgeInsets.only(top: s.md, bottom: s.xs),
            child: Text(
              l.casebookWeekly,
              style: type.title.copyWith(color: colors.accentGold),
            ),
          ),
          _CaseSlip(
            mission: mission,
            weekly: true,
            busy: busy == 'w${mission.slot}',
            onClaim: () => onClaim(true, mission.slot),
          ),
        ],
      ],
    );
  }
}

/// One case: the character who hands it over stands at the edge of the
/// slip, half inside it; the red string under the words is the progress.
class _CaseSlip extends StatelessWidget {
  final CaseMission mission;
  final bool weekly;
  final bool busy;
  final VoidCallback onClaim;
  const _CaseSlip({
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
    return Opacity(
      opacity: done ? CasebookTokens.doneOpacity : 1,
      child: Padding(
        padding: EdgeInsets.only(bottom: s.md),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The slip: aged paper tone, a stripe in the character's colour.
            Container(
              margin: const EdgeInsetsDirectional.only(
                start: CasebookTokens.slipInset,
              ),
              padding: EdgeInsetsDirectional.fromSTEB(
                CasebookTokens.portraitWidth - CasebookTokens.slipInset + s.sm,
                s.md,
                s.md,
                s.md,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [
                    tint.withValues(alpha: CasebookTokens.slipTintAlpha),
                    colors.surfaceRaised,
                  ],
                ),
                border: BorderDirectional(
                  end: BorderSide(
                    color: weekly ? colors.accentGold : tint,
                    width: CasebookTokens.stripe,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.casebookFrom(EngineCopy.roleName(l, mission.voice)),
                    style: type.caption.copyWith(color: tint),
                  ),
                  Text(
                    caseLine(l, mission.metric, mission.target),
                    style: type.body.copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: s.sm),
                  _RedString(
                    fraction: mission.fraction,
                    label: l.casebookProgress(
                      math.min(mission.progress, mission.target),
                      mission.target,
                    ),
                  ),
                  SizedBox(height: s.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _Reward(
                              coins: mission.coins,
                              xp: mission.xp,
                            ),
                          ),
                        ),
                      ),
                      _ClaimSeal(
                        key: mission.claimable
                            ? CasebookSheet.claimKey(
                                '${weekly ? 'w' : 'd'}${mission.slot}',
                              )
                            : null,
                        claimable: mission.claimable,
                        claimed: mission.claimed,
                        busy: busy,
                        onClaim: onClaim,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // The character, unframed, feet melting into the slip.
            PositionedDirectional(
              start: 0,
              top: -CasebookTokens.portraitRise,
              bottom: 0,
              width: CasebookTokens.portraitWidth,
              child: IgnorePointer(
                child: FeatheredArt(
                  feather: Feather.hero,
                  halo: false,
                  child: BondPortraitArt(
                    role: mission.voice,
                    fit: BoxFit.cover,
                    alignment: CasebookTokens.faceFocus,
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

/// Progress as a thread pulled taut: the done part in crimson, a knot where
/// it stops, the rest slack and faint.
class _RedString extends StatelessWidget {
  final double fraction;
  final String label;
  const _RedString({required this.fraction, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: CasebookTokens.knot,
            child: CustomPaint(
              painter: _StringPainter(
                fraction: fraction,
                done: colors.accentCrimson,
                slack: colors.borderSubtle,
                rtl: Directionality.of(context) == TextDirection.rtl,
              ),
            ),
          ),
        ),
        SizedBox(width: context.spacing.sm),
        Text(
          label,
          style: context.typography.caption.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StringPainter extends CustomPainter {
  final double fraction;
  final Color done;
  final Color slack;
  final bool rtl;
  const _StringPainter({
    required this.fraction,
    required this.done,
    required this.slack,
    required this.rtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    double x(double t) => rtl ? size.width * (1 - t) : size.width * t;
    final slackPaint = Paint()
      ..color = slack
      ..strokeWidth = CasebookTokens.stringWidth / 2
      ..style = PaintingStyle.stroke;
    // The slack part sags a little.
    final sag = Path()..moveTo(x(fraction), y);
    sag.quadraticBezierTo(
      x((fraction + 1) / 2),
      y + size.height * CasebookTokens.sag,
      x(1),
      y,
    );
    canvas.drawPath(sag, slackPaint);
    if (fraction <= 0) return;
    canvas.drawLine(
      Offset(x(0), y),
      Offset(x(fraction), y),
      Paint()
        ..color = done
        ..strokeWidth = CasebookTokens.stringWidth
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(x(fraction), y),
      CasebookTokens.knot / 2,
      Paint()..color = done,
    );
  }

  @override
  bool shouldRepaint(_StringPainter old) =>
      old.fraction != fraction ||
      old.done != done ||
      old.slack != slack ||
      old.rtl != rtl;
}

class _Reward extends StatelessWidget {
  final int coins;
  final int xp;
  const _Reward({required this.coins, required this.xp});

  @override
  Widget build(BuildContext context) {
    final type = context.typography;
    final colors = context.colors;
    return Wrap(
      spacing: context.spacing.sm,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (coins > 0)
          CoinAmount(
            coins,
            style: type.bodySmall.copyWith(color: colors.accentGold),
          ),
        if (xp > 0)
          Text(
            context.l10n.casebookXpGain(xp),
            style: type.bodySmall.copyWith(color: colors.textSecondary),
          ),
      ],
    );
  }
}

/// Take it: a wax seal to press. Taken: the seal stamped flat. Not yet:
/// nothing — the string already says how far.
class _ClaimSeal extends StatelessWidget {
  final bool claimable;
  final bool claimed;
  final bool busy;
  final VoidCallback onClaim;
  const _ClaimSeal({
    super.key,
    required this.claimable,
    required this.claimed,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    if (claimed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: CasebookTokens.stamp,
            color: colors.accentGold,
          ),
          SizedBox(width: context.spacing.xs),
          Text(
            l.casebookClaimed,
            style: context.typography.caption.copyWith(
              color: colors.accentGold,
            ),
          ),
        ],
      );
    }
    if (!claimable) return const SizedBox.shrink();
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: CouncilLifeTokens.sealOuter,
        foregroundColor: CouncilLifeTokens.sealStud,
      ),
      onPressed: busy ? null : onClaim,
      child: busy
          ? const SizedBox.square(
              dimension: CasebookTokens.stamp,
              child: CircularProgressIndicator(
                strokeWidth: CasebookTokens.stringWidth,
              ),
            )
          : Text(l.casebookClaim),
    );
  }
}

// ─── Season ────────────────────────────────────────────────────────────────

/// Twenty stops along one red thread, winding down the page like evidence
/// pinned to a wall. Reached stops are wax; the next one glows.
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
    final type = context.typography;
    final levels = [for (var i = 1; i <= season.maxLevel; i++) i];
    return ListView(
      padding: EdgeInsets.fromLTRB(
        s.screenMargin,
        s.md,
        s.screenMargin,
        s.xl,
      ),
      children: [
        Text(
          season.complete
              ? l.casebookSeasonDone
              // D4 — a season just begun reads «مستوى ١», never «٠». The
              // stops below still count the real level.
              : l.casebookLevel(math.max(1, season.level)),
          textAlign: TextAlign.center,
          style: type.title.copyWith(color: colors.textPrimary),
        ),
        if (!season.complete) ...[
          SizedBox(height: s.xs),
          _RedString(
            fraction: season.levelFraction,
            label: l.casebookProgress(season.levelXp, season.xpPerLevel),
          ),
        ],
        SizedBox(height: s.lg),
        SizedBox(
          height: levels.length * CasebookTokens.stopHeight,
          child: LayoutBuilder(
            builder: (context, box) {
              final rtl = Directionality.of(context) == TextDirection.rtl;
              Offset centre(int index) {
                final swing = math.sin(index * CasebookTokens.windFrequency);
                final dx = box.maxWidth / 2 +
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
                      painter: _TrailPainter(
                        points: [
                          for (var i = 0; i < levels.length; i++) centre(i),
                        ],
                        reached: season.level,
                        done: colors.accentCrimson,
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
      ],
    );
  }
}

class _TrailPainter extends CustomPainter {
  final List<Offset> points;
  final int reached;
  final Color done;
  final Color slack;
  const _TrailPainter({
    required this.points,
    required this.reached,
    required this.done,
    required this.slack,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i];
      final b = points[i + 1];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(a.dx, mid.dy, mid.dx, mid.dy)
        ..quadraticBezierTo(b.dx, mid.dy, b.dx, b.dy);
      final taut = i + 2 <= reached;
      canvas.drawPath(
        path,
        Paint()
          ..color = taut ? done : slack
          ..style = PaintingStyle.stroke
          ..strokeWidth = taut
              ? CasebookTokens.stringWidth
              : CasebookTokens.stringWidth / 2,
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.reached != reached ||
      old.points.length != points.length ||
      old.done != done ||
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
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    const d = CasebookTokens.seal;
    // The reward is written on the wider side of the thread.
    final leftSide = centre.dx > width / 2;
    final label = Column(
      crossAxisAlignment: leftSide
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stop.coins > 0)
          CoinAmount(
            stop.coins,
            style: type.bodySmall.copyWith(
              color: reached ? colors.accentGold : colors.textMuted,
            ),
          ),
        if (stop.title != null)
          Text(
            l.casebookTitleReward,
            style: type.caption.copyWith(color: colors.accentGold),
          ),
        if (stop.item != null)
          Text(
            l.casebookItemReward,
            style: type.caption.copyWith(color: colors.accentGold),
          ),
        if (stop.claimable) ...[
          SizedBox(height: s.xs),
          _ClaimSeal(
            key: CasebookSheet.claimKey('s${stop.level}'),
            claimable: true,
            claimed: false,
            busy: busy,
            onClaim: onClaim,
          ),
        ] else if (stop.claimed && !stop.empty)
          Icon(
            Icons.verified_rounded,
            size: CasebookTokens.stamp,
            color: colors.accentGold,
          ),
      ],
    );
    return Positioned(
      left: 0,
      right: 0,
      top: centre.dy - CasebookTokens.stopHeight / 2,
      height: CasebookTokens.stopHeight,
      child: Stack(
        children: [
          Positioned(
            left: centre.dx - d / 2,
            top: (CasebookTokens.stopHeight - d) / 2,
            width: d,
            height: d,
            child: _Seal(level: stop.level, reached: reached, next: next),
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

class _Seal extends StatelessWidget {
  final int level;
  final bool reached;
  final bool next;
  const _Seal({required this.level, required this.reached, required this.next});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: reached
            ? const RadialGradient(
                colors: [CouncilLifeTokens.gemLight, CouncilLifeTokens.sealOuter],
              )
            : null,
        color: reached ? null : colors.surfaceBase,
        border: Border.all(
          color: reached || next ? CouncilLifeTokens.sealInner : colors.borderSubtle,
          width: next ? CasebookTokens.stringWidth : CasebookTokens.stringWidth / 2,
        ),
        boxShadow: next
            ? [
                BoxShadow(
                  color: colors.accentGold.withValues(
                    alpha: CasebookTokens.glowAlpha,
                  ),
                  blurRadius: CasebookTokens.glowBlur,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '$level',
        style: context.typography.bodySmall.copyWith(
          color: reached ? CouncilLifeTokens.sealStud : colors.textMuted,
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
    final colors = context.colors;
    final type = context.typography;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        s.screenMargin,
        s.md,
        s.screenMargin,
        s.xl,
      ),
      children: [
        if (book.rank.level > 0)
          Text(
            l.casebookRank(math.max(1, book.rank.level)),
            textAlign: TextAlign.center,
            style: type.title.copyWith(color: colors.accentGold),
          ),
        if (book.achievements.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(top: s.lg, bottom: s.sm),
            child: Text(
              l.casebookAchievements,
              style: type.title.copyWith(color: colors.textSecondary),
            ),
          ),
          Wrap(
            spacing: s.md,
            runSpacing: s.md,
            alignment: WrapAlignment.center,
            children: [
              for (final a in book.achievements)
                _Medal(
                  achievement: a,
                  busy: busy == 'a${a.code}',
                  onClaim: () => onClaim(a.code),
                ),
            ],
          ),
        ],
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

/// An achievement as a medal: the ring fills as it comes, the face lights
/// when it is won.
class _Medal extends StatelessWidget {
  final CaseAchievement achievement;
  final bool busy;
  final VoidCallback onClaim;
  const _Medal({
    required this.achievement,
    required this.busy,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final won = achievement.unlocked || achievement.claimed;
    return SizedBox(
      width: CasebookTokens.medalWidth,
      child: Column(
        children: [
          SizedBox.square(
            dimension: CasebookTokens.medal,
            child: CustomPaint(
              painter: _MedalRing(
                fraction: achievement.fraction,
                ring: colors.accentGold,
                track: colors.borderSubtle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(CasebookTokens.medalInset),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: won
                          ? const [
                              FunTokens.medalLight,
                              FunTokens.medalMid,
                              FunTokens.medalDark,
                            ]
                          : [colors.surfaceRaised, colors.surfaceBase],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${achievement.target}',
                      style: type.title.copyWith(
                        color: won ? VaultTokens.goldInk : colors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: context.spacing.xs),
          Text(
            caseLine(l, achievement.metric, achievement.target),
            textAlign: TextAlign.center,
            maxLines: 3,
            style: type.caption.copyWith(
              color: won ? colors.textPrimary : colors.textSecondary,
            ),
          ),
          if (achievement.claimable)
            _ClaimSeal(
              key: CasebookSheet.claimKey('a${achievement.code}'),
              claimable: true,
              claimed: false,
              busy: busy,
              onClaim: onClaim,
            )
          else if (!won)
            _Reward(coins: achievement.coins, xp: achievement.xp),
        ],
      ),
    );
  }
}

class _MedalRing extends CustomPainter {
  final double fraction;
  final Color ring;
  final Color track;
  const _MedalRing({
    required this.fraction,
    required this.ring,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const stroke = CasebookTokens.stringWidth;
    final arc = rect.deflate(stroke);
    canvas.drawOval(
      arc,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke / 2,
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MedalRing old) =>
      old.fraction != fraction || old.ring != ring || old.track != track;
}

// ─── Entry ─────────────────────────────────────────────────────────────────

/// The Casebook's door on Online and in the Council: the four faces on the
/// case board, what is waiting to be taken. Nothing while the feature is off.
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
          onTap: () => showCasebookSheet(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: CasebookTokens.entryHeight,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Four faces pinned to the board, fading into the page.
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: CasebookTokens.entryFacesWidth,
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
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: CasebookTokens.entryFacesWidth + s.sm,
                    top: s.sm,
                    bottom: s.sm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              l.casebookTitle,
                              style: type.title.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (ready > 0) ...[
                            SizedBox(width: s.xs),
                            const _WaxDot(),
                          ],
                        ],
                      ),
                      Text(
                        ready > 0
                            ? l.casebookReady(ready)
                            : l.casebookLevel(book.season.level),
                        style: type.bodySmall.copyWith(
                          color: ready > 0
                              ? colors.accentGold
                              : colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: s.xs),
                      _RedString(
                        fraction: book.season.levelFraction,
                        label: '',
                      ),
                    ],
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
