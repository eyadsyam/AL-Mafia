import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../engine/models/enums.dart' as game;
import '../../economy/council.dart' show councilProvider;
import '../../economy/council_art.dart' show rankTier, rankTitle;
import '../../economy/cosmetic_paint.dart'
    show paintCosmeticFrame, paintCosmeticPlate, plateTextColor;
import '../../economy/cosmetics.dart' show Cosmetics, FrameStyle, PlateStyle;
import '../../economy/my_cosmetics.dart';
import '../../../data/player_profile.dart';
import '../../../platform/clipboard.dart';
import '../../fun/award_ribbon.dart' show awardName, onlineAwardsProvider;
import '../../fun/match_awards.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';

class ResultShareButton extends ConsumerStatefulWidget {
  final game.Alignment winner;
  final int days;

  /// Phase 109: the room whose awards (the sharer's own) go on the card. The
  /// match is over when this button exists, and the card carries only this
  /// player's awards and rank title — nobody else's role, nothing private.
  final String? roomId;

  const ResultShareButton({
    super.key,
    required this.winner,
    required this.days,
    this.roomId,
  });

  @override
  ConsumerState<ResultShareButton> createState() => _ResultShareButtonState();
}

class _ResultShareButtonState extends ConsumerState<ResultShareButton> {
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final l10n = context.l10n;
      final winner = widget.winner == game.Alignment.mafia
          ? l10n.mafiaWins
          : l10n.townWins;
      final message = l10n.shareResultText(winner, widget.days);
      final room = widget.roomId;
      final awards = room == null
          ? const OnlineAwards()
          : ref.read(onlineAwardsProvider(room)).valueOrNull ??
                const OnlineAwards();
      final mine = [
        for (final kind in AwardKind.values)
          if (awards.mine.contains(kind)) awardName(l10n, kind),
      ];
      final rank = ref.read(councilProvider).valueOrNull?.rank;
      // Store truth: the sharer's own name on the plate they equipped, inside
      // the frame they equipped, drawn by the table's own painters.
      final dress = ref.read(myCosmeticsProvider);
      final myName = ref.read(playerProfileProvider).valueOrNull?.name ?? '';
      final bytes = await _cardPng(
        title: l10n.appTitle,
        winner: winner,
        days: widget.days,
        footer: 'almafia.vercel.app',
        rtl: Directionality.of(context) == TextDirection.rtl,
        rank: rank != null && rank.enabled
            ? rankTitle(l10n, rankTier(rank.level))
            : null,
        awards: mine.isEmpty ? null : l10n.shareCardAwards(mine.join(' · ')),
        name: myName.trim().isEmpty ? null : myName.trim(),
        frame: Cosmetics.frames[dress.frame],
        plate: Cosmetics.plates[dress.plate],
      );
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      try {
        await SharePlus.instance.share(
          ShareParams(
            title: l10n.shareResult,
            text: message,
            files: [
              XFile.fromData(
                bytes,
                mimeType: 'image/png',
                name: 'mafia-master-result.png',
              ),
            ],
            fileNameOverrides: const ['mafia-master-result.png'],
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      } catch (_) {
        // A browser without the Web Share API (or one that refuses files):
        // the sentence goes on the clipboard instead of an unhandled error.
        final copied = await AppClipboard.copy(message);
        if (mounted) {
          _say(copied ? l10n.shareTextCopied : l10n.shareUnavailable);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) =>
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    onPressed: _busy ? null : _share,
    icon: _busy
        ? SizedBox.square(
            dimension: context.spacing.md,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.ios_share_rounded),
    tooltip: context.l10n.shareResult,
  );
}

Future<Uint8List> _cardPng({
  required String title,
  required String winner,
  required int days,
  required String footer,
  required bool rtl,
  String? rank,
  String? awards,
  String? name,
  FrameStyle? frame,
  PlateStyle? plate,
}) async {
  const size = Size(ShareCardTokens.width, ShareCardTokens.height);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final background = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [ShareCardTokens.groundTop, ShareCardTokens.groundBottom],
    ).createShader(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, background);
  canvas.drawRect(
    Rect.fromLTWH(
      ShareCardTokens.edge,
      ShareCardTokens.edge,
      ShareCardTokens.ruleWidth,
      size.height - ShareCardTokens.edge * 2,
    ),
    Paint()..color = ShareCardTokens.gold,
  );

  void line(String value, double top, double fontSize, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: rtl ? 1.6 : 1.2,
          letterSpacing: rtl ? 0 : null,
        ),
      ),
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      maxLines: 2,
    )..layout(maxWidth: size.width - ShareCardTokens.edge * 3);
    painter.paint(canvas, Offset(ShareCardTokens.edge * 1.5, top));
  }

  line(
    title,
    ShareCardTokens.edge,
    ShareCardTokens.titleSize,
    ShareCardTokens.gold,
  );
  if (name != null) {
    _paintIdentity(canvas, size, rtl, name, frame, plate);
  }
  line(
    winner,
    size.height * 0.36,
    ShareCardTokens.resultSize,
    ShareCardTokens.headline,
  );
  line(
    '$days',
    size.height * 0.58,
    ShareCardTokens.resultSize,
    ShareCardTokens.gold,
  );
  if (rank != null) {
    line(
      rank,
      size.height * 0.72,
      ShareCardTokens.bodySize,
      ShareCardTokens.gold,
    );
  }
  if (awards != null) {
    line(
      awards,
      size.height * 0.775,
      ShareCardTokens.bodySize,
      ShareCardTokens.headline,
    );
  }
  line(
    footer,
    size.height - ShareCardTokens.edge * 2,
    ShareCardTokens.bodySize,
    ShareCardTokens.footer,
  );
  final image = await recorder.endRecording().toImage(
    ShareCardTokens.width.toInt(),
    ShareCardTokens.height.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// The sharer's own seal and name on the card: their frame around it and
/// their plate under the name, through the same painters the table uses.
void _paintIdentity(
  Canvas canvas,
  Size size,
  bool rtl,
  String name,
  FrameStyle? frame,
  PlateStyle? plate,
) {
  const diameter = ShareCardTokens.identityAvatar;
  final centre = Offset(
    size.width / 2,
    size.height * ShareCardTokens.identityTop + diameter / 2,
  );
  canvas.drawCircle(
    centre,
    diameter / 2,
    Paint()..color = ShareCardTokens.identitySeal,
  );
  final direction = rtl ? TextDirection.rtl : TextDirection.ltr;
  final initial = TextPainter(
    text: TextSpan(
      text: name.characters.first,
      style: const TextStyle(
        color: ShareCardTokens.gold,
        fontSize: ShareCardTokens.titleSize,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: direction,
  )..layout();
  initial.paint(
    canvas,
    centre - Offset(initial.width / 2, initial.height / 2),
  );
  if (frame != null) paintCosmeticFrame(canvas, centre, diameter, frame);
  final label = TextPainter(
    text: TextSpan(
      text: name,
      style: TextStyle(
        color: plate == null ? ShareCardTokens.headline : plateTextColor(plate),
        fontSize: ShareCardTokens.bodySize,
        fontWeight: FontWeight.w700,
        height: rtl ? 1.6 : 1.2,
        letterSpacing: rtl ? 0 : null,
      ),
    ),
    textDirection: direction,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: size.width - ShareCardTokens.edge * 4);
  final origin = Offset(
    centre.dx - label.width / 2,
    centre.dy + diameter / 2 + ShareCardTokens.identityNameGap,
  );
  if (plate != null) {
    paintCosmeticPlate(canvas, origin, Size(label.width, label.height), plate);
  }
  label.paint(canvas, origin);
}
