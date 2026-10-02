import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../engine/models/enums.dart' as game;
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';

class ResultShareButton extends StatefulWidget {
  final game.Alignment winner;
  final int days;

  const ResultShareButton({
    super.key,
    required this.winner,
    required this.days,
  });

  @override
  State<ResultShareButton> createState() => _ResultShareButtonState();
}

class _ResultShareButtonState extends State<ResultShareButton> {
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
      final bytes = await _cardPng(
        title: l10n.appTitle,
        winner: winner,
        days: widget.days,
        footer: 'almafia.vercel.app',
        rtl: Directionality.of(context) == TextDirection.rtl,
      );
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
