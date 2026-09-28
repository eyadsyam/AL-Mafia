import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/asset_constants.dart';
import '../../app/l10n/app_localizations.dart';
import '../../engine/models/enums.dart' hide Alignment;
import '../economy/mafia_coin.dart';
import '../fun/character_dossiers.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/feathered_art.dart';
import '../l10n_ext.dart';
import 'case_of_day_data.dart';
import 'casebook_data.dart';

Future<void> showCaseOfDaySheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surfaceBase,
      builder: (_) => const FractionallySizedBox(
        heightFactor: CasebookTokens.sheetHeight,
        child: CaseOfDaySheet(),
      ),
    );

/// A suspect's name in the player's language, from its key (`n01`…).
String suspectName(AppLocalizations l, String key) {
  final names = l.caseNames.split('|');
  final index = int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  if (index < 1 || index > names.length) return key;
  return names[index - 1];
}

/// One clue, said as a sentence with the suspects' names in it.
String clueLine(AppLocalizations l, CaseOfDay day, Clue clue) {
  String name(String? id) => suspectName(l, day.suspect(id)?.name ?? '');
  String names(List<String> ids) =>
      ids.map(name).join(l.caseListJoin);
  return switch (clue.kind) {
    'not_mafia' => l.clueNotMafia(name(clue.a)),
    'one_of' => l.clueOneOf(name(clue.a), name(clue.b)),
    'in_group' => l.clueInGroup(names(clue.group)),
    'outside_group' => l.clueOutsideGroup(names(clue.group)),
    'next_to' => l.clueNextTo(name(clue.a)),
    'not_next_to' => l.clueNotNextTo(name(clue.a)),
    'distance' => l.clueDistance(name(clue.a), clue.k),
    _ => '',
  };
}

class CaseOfDaySheet extends ConsumerStatefulWidget {
  const CaseOfDaySheet({super.key});

  static Key seatKey(String id) => ValueKey('case_seat_$id');
  static const accuseKey = ValueKey('case_accuse');
  static const verdictKey = ValueKey('case_verdict');

  @override
  ConsumerState<CaseOfDaySheet> createState() => _CaseOfDaySheetState();
}

class _CaseOfDaySheetState extends ConsumerState<CaseOfDaySheet> {
  String? _pick;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(caseOfDayProvider.notifier).refresh());
  }

  Future<void> _accuse(CaseOfDay day) async {
    final pick = _pick;
    if (pick == null || _busy) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final verdict = await ref.read(caseOfDayProvider.notifier).accuse(pick);
      if (!mounted) return;
      setState(() {
        _pick = null;
        _message = verdict.correct
            ? null
            : l.caseDayWrong(suspectName(l, day.suspect(pick)?.name ?? ''));
      });
    } on CaseClaimFailed {
      if (mounted) setState(() => _message = l.casebookClaimError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(caseOfDayProvider);
    final day = async.valueOrNull;
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    if (day == null || !day.enabled) {
      return Center(
        child: async.isLoading || day == null
            ? const CircularProgressIndicator()
            : Text(l.casebookFailed, style: type.body),
      );
    }
    final wrong = ref.read(caseOfDayProvider.notifier).wrong;
    final pickName = suspectName(l, day.suspect(_pick)?.name ?? '');

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(s.screenMargin, 0, s.screenMargin, s.xl),
        children: [
          // The Detective leans into the case; no header bar.
          SizedBox(
            height: CaseDayTokens.heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FeatheredArt(
                  feather: Feather.banner,
                  child: Image.asset(
                    AppCouncilArt.backdropNight,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
                const PositionedDirectional(
                  end: 0,
                  top: 0,
                  bottom: 0,
                  width: CaseDayTokens.detectiveWidth,
                  child: FeatheredArt(
                    feather: Feather.hero,
                    halo: false,
                    child: BondPortraitArt(
                      role: Role.detective,
                      fit: BoxFit.cover,
                      alignment: CasebookTokens.faceFocus,
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  end: CaseDayTokens.detectiveWidth - s.lg,
                  bottom: s.sm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.caseDayTitle,
                        style: type.headline.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        l.caseDayIntro,
                        style: type.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: s.xs),
                      Text(
                        [
                          switch (day.difficulty) {
                            >= 3 => l.caseDayHard,
                            2 => l.caseDayMedium,
                            _ => l.caseDayEasy,
                          },
                          if (day.streak > 0) l.caseDayStreak(day.streak),
                        ].join(' · '),
                        style: type.caption.copyWith(color: colors.accentGold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: s.md),
          _Table(
            day: day,
            pick: _pick,
            wrong: wrong,
            onPick: day.closed || _busy
                ? null
                : (id) => setState(() {
                    _pick = id;
                    _message = null;
                  }),
          ),
          SizedBox(height: s.md),
          if (day.closed)
            _Verdict(day: day)
          else ...[
            FilledButton(
              key: CaseOfDaySheet.accuseKey,
              style: FilledButton.styleFrom(
                backgroundColor: CouncilLifeTokens.sealOuter,
                foregroundColor: CouncilLifeTokens.sealStud,
                minimumSize: const Size.fromHeight(kMinInteractiveDimension),
              ),
              onPressed: _pick == null || _busy ? null : () => _accuse(day),
              child: Text(
                _pick == null ? l.caseDayPick : l.caseDayAccuse(pickName),
              ),
            ),
            SizedBox(height: s.xs),
            Text(
              _message ?? l.caseDayAttempts(day.attemptsLeft),
              textAlign: TextAlign.center,
              style: type.bodySmall.copyWith(
                color: _message == null
                    ? colors.textSecondary
                    : colors.accentCrimson,
              ),
            ),
          ],
          SizedBox(height: s.lg),
          for (final clue in day.clues)
            _ClueNote(day: day, clue: clue),
        ],
      ),
    );
  }
}

/// The round table seen from above: seats clockwise from the top.
class _Table extends StatelessWidget {
  final CaseOfDay day;
  final String? pick;
  final Set<String> wrong;
  final ValueChanged<String>? onPick;
  const _Table({
    required this.day,
    required this.pick,
    required this.wrong,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    // Innocents the reveal cleared, so their seats dim with the explanation.
    final cleared = {for (final step in day.chain) ...step.eliminates};
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(box.maxWidth, CaseDayTokens.tableMax);
        const seat = CaseDayTokens.seat;
        final radius = side / 2 - seat / 2 - CaseDayTokens.labelRoom;
        final n = day.suspects.length;
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TablePainter(
                      rim: colors.accentGold,
                      felt: CouncilLifeTokens.field,
                      radius: radius - seat * CaseDayTokens.feltInset,
                    ),
                  ),
                ),
                for (var i = 0; i < n; i++)
                  () {
                    final suspect = day.suspects[i];
                    final angle = -math.pi / 2 + 2 * math.pi * i / n;
                    final centre = Offset(
                      side / 2 + radius * math.cos(angle),
                      side / 2 + radius * math.sin(angle),
                    );
                    final isAnswer = day.answer == suspect.id;
                    final isWrong =
                        wrong.contains(suspect.id) ||
                        (day.closed && cleared.contains(suspect.id));
                    final chosen = pick == suspect.id;
                    return Positioned(
                      left: centre.dx - CaseDayTokens.seatSlot / 2,
                      top: centre.dy - seat / 2,
                      width: CaseDayTokens.seatSlot,
                      child: Semantics(
                        button: onPick != null,
                        selected: chosen,
                        label: suspectName(l, suspect.name),
                        child: GestureDetector(
                          key: CaseOfDaySheet.seatKey(suspect.id),
                          onTap: onPick == null || isWrong
                              ? null
                              : () => onPick!(suspect.id),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: CasebookTokens.pageTurn,
                                width: seat,
                                height: seat,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    if (chosen || isAnswer)
                                      BoxShadow(
                                        color:
                                            (isAnswer
                                                    ? colors.roleMafia
                                                    : colors.accentGold)
                                                .withValues(
                                                  alpha: CasebookTokens
                                                      .glowAlpha,
                                                ),
                                        blurRadius: CasebookTokens.glowBlur,
                                        spreadRadius:
                                            CaseDayTokens.glowSpread,
                                      ),
                                  ],
                                ),
                                child: Opacity(
                                  opacity: isWrong
                                      ? CaseDayTokens.clearedOpacity
                                      : 1,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Image.asset(
                                        isWrong
                                            ? AppCouncilArt.seatRingCracked
                                            : AppCouncilArt.seatRingIdle,
                                        excludeFromSemantics: true,
                                      ),
                                      Text(
                                        suspectName(
                                          l,
                                          suspect.name,
                                        ).characters.first,
                                        style: type.title.copyWith(
                                          color: isAnswer
                                              ? colors.roleMafia
                                              : chosen
                                              ? colors.accentGold
                                              : colors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Text(
                                suspectName(l, suspect.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.caption.copyWith(
                                  color: isAnswer
                                      ? colors.roleMafia
                                      : isWrong
                                      ? colors.textMuted
                                      : colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TablePainter extends CustomPainter {
  final Color rim;
  final Color felt;
  final double radius;
  const _TablePainter({
    required this.rim,
    required this.felt,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    if (radius <= 0) return;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            felt.withValues(alpha: CaseDayTokens.feltCentre),
            felt,
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = rim.withValues(alpha: CaseDayTokens.rimAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = CasebookTokens.stringWidth,
    );
  }

  @override
  bool shouldRepaint(_TablePainter old) =>
      old.rim != rim || old.felt != felt || old.radius != radius;
}

/// A clue pinned under the table; once the case is closed, each note says
/// whom it cleared.
class _ClueNote extends StatelessWidget {
  final CaseOfDay day;
  final Clue clue;
  const _ClueNote({required this.day, required this.clue});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final step = day.chain.where((r) => r.clue == clue.id).firstOrNull;
    return Padding(
      padding: EdgeInsets.only(bottom: s.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: s.xs),
            child: Container(
              width: CasebookTokens.knot,
              height: CasebookTokens.knot,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: CouncilLifeTokens.sealOuter,
              ),
            ),
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clueLine(l, day, clue),
                  style: type.body.copyWith(color: colors.textPrimary),
                ),
                if (step != null && step.eliminates.isNotEmpty)
                  Text(
                    l.caseDayClears(
                      step.eliminates
                          .map((id) => suspectName(l, day.suspect(id)?.name ?? ''))
                          .join(l.caseListJoin),
                    ),
                    style: type.caption.copyWith(color: colors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  final CaseOfDay day;
  const _Verdict({required this.day});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final mafia = suspectName(l, day.suspect(day.answer)?.name ?? '');
    return Column(
      key: CaseOfDaySheet.verdictKey,
      children: [
        Text(
          day.solved ? l.caseDaySolved(mafia) : l.caseDayFailed(mafia),
          textAlign: TextAlign.center,
          style: type.title.copyWith(
            color: day.solved ? colors.accentGold : colors.textSecondary,
          ),
        ),
        if (day.solved) ...[
          SizedBox(height: s.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (day.rewardCoins > 0)
                CoinAmount(
                  day.rewardCoins,
                  style: type.bodySmall.copyWith(color: colors.accentGold),
                ),
              if (day.rewardXp > 0) ...[
                SizedBox(width: s.sm),
                Text(
                  l.casebookXpGain(day.rewardXp),
                  style: type.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ],
        SizedBox(height: s.xs),
        Text(
          [
            if (day.streak > 0) l.caseDayStreak(day.streak),
            l.caseDayTomorrow,
          ].join(' · '),
          textAlign: TextAlign.center,
          style: type.caption.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

/// The door: the Detective with today's case, on the Casebook's first page
/// and on Online when the Casebook itself is off.
class CaseOfDayCard extends ConsumerWidget {
  const CaseOfDayCard({super.key});

  static const cardKey = ValueKey('case_of_day_card');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(caseOfDayProvider).valueOrNull;
    if (day == null || !day.enabled) return const SizedBox.shrink();
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    return Padding(
      padding: EdgeInsets.only(bottom: s.md),
      child: Semantics(
        button: true,
        child: InkWell(
          key: cardKey,
          onTap: () => showCaseOfDaySheet(context),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: CaseDayTokens.cardHeight,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerEnd,
                end: AlignmentDirectional.centerStart,
                colors: [
                  colors.roleDetective.withValues(
                    alpha: CasebookTokens.slipTintAlpha,
                  ),
                  colors.surfaceRaised,
                ],
              ),
              border: BorderDirectional(
                start: BorderSide(
                  color: colors.roleDetective,
                  width: CasebookTokens.stripe,
                ),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const PositionedDirectional(
                  end: 0,
                  top: -CasebookTokens.portraitRise,
                  bottom: 0,
                  width: CasebookTokens.portraitWidth,
                  child: IgnorePointer(
                    child: FeatheredArt(
                      feather: Feather.hero,
                      halo: false,
                      child: BondPortraitArt(
                        role: Role.detective,
                        fit: BoxFit.cover,
                        alignment: CasebookTokens.faceFocus,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    s.md,
                    s.md,
                    CasebookTokens.portraitWidth,
                    s.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.caseDayTitle,
                        style: type.title.copyWith(color: colors.textPrimary),
                      ),
                      Text(
                        day.solved
                            ? l.caseDayDoneToday
                            : day.failed
                            ? l.caseDayTomorrow
                            : l.caseDayIntro,
                        style: type.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      if (day.streak > 0)
                        Text(
                          l.caseDayStreak(day.streak),
                          style: type.caption.copyWith(
                            color: colors.accentGold,
                          ),
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
