import 'package:flutter/material.dart';

import '../../../engine/models/enums.dart' as engine;
import '../../../engine/models/match.dart';
import '../../../engine/models/timeline_event.dart';
import '../../fun/award_ribbon.dart' show awardBody;
import '../../fun/match_awards.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_paper.dart';
import '../../widgets/deck/deck_public.dart';
import 'result_screen.dart' show RoleGalleryPortrait, ResultRow;

enum MatchFileKind { killed, saved, quiet, expelled }

/// One thing that happened in a night or a day, from the finished log only.
class MatchFileLine {
  final MatchFileKind kind;
  final List<int> seats;
  final int votes;
  const MatchFileLine(this.kind, {this.seats = const [], this.votes = 0});
}

class MatchFileNight {
  final bool day;
  final int number;
  final List<MatchFileLine> lines;
  const MatchFileNight({
    required this.day,
    required this.number,
    required this.lines,
  });
}

/// «ملف الماتش»: the finished match, night by night.
///
/// Built from the engine's own log of a finished pass-and-play or bot match;
/// nothing is inferred. A match without a local log has no file.
class MatchFile {
  final int days;
  final List<MatchFileNight> nights;
  const MatchFile({required this.days, required this.nights});

  bool get isEmpty => nights.isEmpty;
}

MatchFile? matchFileOf(Match match) {
  final outcome = match.outcome;
  if (outcome == null) return null;
  if (match.phase != engine.GamePhase.result &&
      match.phase != engine.GamePhase.analytics) {
    return null;
  }
  final nights = <MatchFileNight>[];
  var days = 0;
  for (final e in match.eventLog) {
    if (e is NightResolved) {
      final victims = e.victimSeats.isNotEmpty
          ? e.victimSeats
          : [if (e.victimSeat != null) e.victimSeat!];
      final line = victims.isNotEmpty
          ? MatchFileLine(MatchFileKind.killed, seats: victims)
          : e.savedSeat != null
          ? MatchFileLine(MatchFileKind.saved, seats: [e.savedSeat!])
          : const MatchFileLine(MatchFileKind.quiet);
      nights.add(
        MatchFileNight(day: false, number: e.phaseRef.number, lines: [line]),
      );
    } else if (e is DayResolved) {
      days = days < e.phaseRef.number ? e.phaseRef.number : days;
      nights.add(
        MatchFileNight(
          day: true,
          number: e.phaseRef.number,
          lines: [
            MatchFileLine(
              MatchFileKind.expelled,
              seats: [e.eliminatedSeat],
              votes: e.tally[e.eliminatedSeat] ?? 0,
            ),
          ],
        ),
      );
    }
  }
  if (nights.isEmpty) return null;
  return MatchFile(days: days, nights: nights);
}

/// Opens «ملف الماتش» over the result.
Future<void> showMatchFile(
  BuildContext context, {
  required MatchFile file,
  required List<ResultRow> rows,
  required List<MatchAward> awards,
  required VoidCallback onShare,
}) => showDeckSheet<void>(
  context: context,
  title: context.l10n.matchFileTitle,
  primary: RimButton(
    key: MatchFileSheet.shareKey,
    label: context.l10n.matchFileShare,
    onPressed: onShare,
  ),
  body: (_) => MatchFileSheet(file: file, rows: rows, awards: awards),
);

class MatchFileSheet extends StatelessWidget {
  final MatchFile file;
  final List<ResultRow> rows;
  final List<MatchAward> awards;

  const MatchFileSheet({
    super.key,
    required this.file,
    required this.rows,
    required this.awards,
  });

  static const shareKey = ValueKey('match_file_share');
  static const mvpKey = ValueKey('match_file_mvp');

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = context.l10n;
    final type = context.typography;
    final colors = context.colors;
    final byseat = {for (final r in rows) r.seat: r};
    MatchAward? mvp;
    for (final a in awards) {
      if (a.kind == AwardKind.mvp && a.names.isNotEmpty) mvp = a;
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mvp != null) ...[
            DeckPanel(
              key: mvpKey,
              padding: EdgeInsets.all(s.md),
              child: Row(
                children: [
                  Container(
                    width: ResultTokens.medal,
                    height: ResultTokens.medal,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DeckTokens.gold,
                        width: ResultTokens.medalBorder,
                      ),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: DeckTokens.gold,
                    ),
                  ),
                  SizedBox(width: s.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.matchFileMvp(mvp.names.join(' · ')),
                          style: type.body.emphasised.copyWith(
                            color: DeckTokens.text,
                          ),
                        ),
                        Text(
                          awardBody(l, AwardKind.mvp),
                          style: type.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: s.md),
          ],
          Text(
            l.matchFileNights,
            style: type.caption.copyWith(color: colors.textMuted),
          ),
          SizedBox(height: s.sm),
          for (final night in file.nights)
            _NightEntry(night: night, byseat: byseat),
        ],
      ),
    );
  }
}

class _NightEntry extends StatelessWidget {
  final MatchFileNight night;
  final Map<int, ResultRow> byseat;
  const _NightEntry({required this.night, required this.byseat});

  String _names(BuildContext context, List<int> seats) => seats
      .map((s) => byseat[s]?.name ?? '')
      .where((n) => n.isNotEmpty)
      .join(context.l10n.listSeparator);

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = context.l10n;
    final type = context.typography;
    final colors = context.colors;
    final dot = night.day ? DeckTokens.bone : DeckTokens.ink;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: ResultTokens.railDot + s.xs,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned.fill(
                  top: s.xs,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: ResultTokens.railWidth,
                      color: DeckTokens.silver,
                    ),
                  ),
                ),
                Container(
                  width: ResultTokens.railDot,
                  height: ResultTokens.railDot,
                  margin: EdgeInsets.only(top: s.xs),
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: night.day
                          ? DeckTokens.bone
                          : DeckTokens.silverLight,
                      width: ResultTokens.railDotBorder,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: s.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    night.day
                        ? l.dayNumbered(night.number)
                        : l.nightNumbered(night.number),
                    style: type.body.emphasised.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  for (final line in night.lines)
                    _LineView(line: line, byseat: byseat, names: _names),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineView extends StatelessWidget {
  final MatchFileLine line;
  final Map<int, ResultRow> byseat;
  final String Function(BuildContext, List<int>) names;
  const _LineView({
    required this.line,
    required this.byseat,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    final who = names(context, line.seats);
    final text = switch (line.kind) {
      MatchFileKind.killed => l.matchFileKilled(who),
      MatchFileKind.saved => l.matchFileSaved(who),
      MatchFileKind.quiet => l.matchFileQuiet,
      MatchFileKind.expelled => l.matchFileExpelled(who, line.votes),
    };
    return Padding(
      padding: EdgeInsets.only(top: s.xs),
      child: Row(
        children: [
          for (final seat in line.seats.take(1))
            if (byseat[seat] != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(context.radii.button / 2),
                child: SizedBox(
                  width: s.lg,
                  height: s.lg + s.xs,
                  child: Image.asset(
                    RoleGalleryPortrait.art(byseat[seat]!.role),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    cacheHeight: ResultTokens.thumbDecode,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              SizedBox(width: s.sm),
            ],
          Expanded(
            child: Text(
              text,
              style: type.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
