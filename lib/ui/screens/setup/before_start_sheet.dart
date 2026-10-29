import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';

/// Keys for «قبل ما تبدأوا».
abstract final class BeforeStartKeys {
  static const sheet = ValueKey('before_start_sheet');
  static const go = ValueKey('before_start_go');
  static ValueKey<String> line(int n) => ValueKey('before_start_line_$n');
}

/// «قبل ما تبدأوا»: five plain lines on how one phone is played, as a deck
/// sheet over setup, right before an offline match is dealt.
///
/// Resolves `true` only from «يلا نبدأ». Swiping it away, tapping outside, the
/// close button and the system back all resolve `null`: the match does not
/// start, and the host is still on setup.
///
/// Nothing here depends on a role or on who is holding the phone: the same
/// five lines for everyone, shown before any role exists (Doc 05).
Future<bool?> showBeforeStartSheet(BuildContext context) => showDeckSheet<bool>(
  context: context,
  title: context.l10n.beforeStartTitle,
  body: (_) => const BeforeStartBody(key: BeforeStartKeys.sheet),
  primary: Builder(
    builder: (context) => BoneButton(
      key: BeforeStartKeys.go,
      label: context.l10n.beforeStartGo,
      onPressed: () => Navigator.of(context).pop(true),
    ),
  ),
);

class BeforeStartBody extends StatelessWidget {
  const BeforeStartBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lines = [
      l.beforeStartLine1,
      l.beforeStartLine2,
      l.beforeStartLine3,
      l.beforeStartLine4,
      l.beforeStartLine5,
    ];
    final locale = Localizations.localeOf(context).toString();
    final number = NumberFormat('#', locale);
    Widget column(Iterable<int> indexes) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final i in indexes) ...[
          if (i != indexes.first)
            const SizedBox(height: BeforeStartTokens.lineGap),
          _Line(
            key: BeforeStartKeys.line(i + 1),
            number: number.format(i + 1),
            text: lines[i],
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        // A wide, short sheet (a phone on its side) sets the lines in two
        // columns, read in order, so all five stand in view at once.
        if (box.maxWidth < BeforeStartTokens.twoColumnMinWidth) {
          return column(const [0, 1, 2, 3, 4]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: column(const [0, 1])),
            SizedBox(width: context.spacing.lg),
            Expanded(child: column(const [2, 3, 4])),
          ],
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  final String number;
  final String text;
  const _Line({super.key, required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    final body = DeckTokens.meta(type).copyWith(color: colors.textPrimary);
    // The badge sits on the first line of the text, whatever its height.
    final lineHeight = body.fontSize! * body.height!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: (lineHeight - BeforeStartTokens.badge) / 2,
          ),
          child: ExcludeSemantics(
            child: Container(
              width: BeforeStartTokens.badge,
              height: BeforeStartTokens.badge,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: DeckTokens.bone,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: type.caption.copyWith(
                  color: DeckTokens.ink,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: s.sm),
        Expanded(child: Text(text, style: body)),
      ],
    );
  }
}
