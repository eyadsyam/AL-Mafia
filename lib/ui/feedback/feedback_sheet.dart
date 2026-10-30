import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/asset_constants.dart';
import '../../transport/online_backend.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'feedback_api.dart';

Future<void> showFeedbackSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FeedbackSheet(),
    );

class FeedbackSheet extends ConsumerStatefulWidget {
  const FeedbackSheet({super.key});

  static const sendKey = ValueKey('feedback_send');
  static const fieldKey = ValueKey('feedback_body');
  static Key kindKey(String kind) => ValueKey('feedback_kind_$kind');

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  final _body = TextEditingController();
  String? _kind;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  static const _kinds = [
    ('roles', Icons.theater_comedy_outlined),
    ('online', Icons.public),
    ('store', Icons.storefront_outlined),
    ('look', Icons.palette_outlined),
    ('idea', Icons.lightbulb_outline),
    ('problem', Icons.bug_report_outlined),
  ];

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  bool get _ready =>
      _kind != null &&
      _body.text
              .trim()
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty)
              .length >=
          2;

  Future<void> _send() async {
    if (!_ready || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(feedbackApiProvider).submit(_kind!, _body.text);
      if (mounted) {
        setState(() {
          _sending = false;
          _sent = true;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error is BackendException && error.code == 'RATE_LIMITED'
            ? context.l10n.feedbackRateLimited
            : context.l10n.feedbackError;
      });
    }
  }

  String _name(String kind) {
    final l = context.l10n;
    return switch (kind) {
      'roles' => l.feedbackRoles,
      'online' => l.feedbackOnline,
      'store' => l.feedbackStore,
      'look' => l.feedbackLook,
      'idea' => l.feedbackIdea,
      _ => l.feedbackProblem,
    };
  }

  String _digits(int value) {
    final raw = '$value';
    if (Localizations.localeOf(context).languageCode != 'ar') return raw;
    return String.fromCharCodes(
      raw.codeUnits.map((unit) => unit - 0x30 + 0x660),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(s.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: FeedbackTokens.sheetMaxWidth,
            ),
            child: _sent
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            AppCouncilArt.whisperSeal,
                            width: FeedbackTokens.sealSize,
                            height: FeedbackTokens.sealSize,
                            excludeFromSemantics: true,
                          ),
                          Icon(
                            Icons.check,
                            color: colors.textPrimary,
                            size: FeedbackTokens.tileIcon,
                          ),
                        ],
                      ),
                      SizedBox(height: s.sm),
                      Text(
                        context.l10n.feedbackSentTitle,
                        style: type.headline,
                      ),
                      Text(
                        context.l10n.feedbackSentLine,
                        style: type.body,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: s.md),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.l10n.feedbackDone),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.l10n.feedbackTitle, style: type.headline),
                      SizedBox(height: s.sm),
                      for (final (number, line) in [
                        (1, context.l10n.feedbackStep1),
                        (2, context.l10n.feedbackStep2),
                        (3, context.l10n.feedbackStep3),
                      ])
                        Text('${_digits(number)}. $line', style: type.body),
                      SizedBox(height: s.md),
                      for (var row = 0; row < 2; row++) ...[
                        Row(
                          children: [
                            for (
                              var col = 0;
                              col < FeedbackTokens.gridColumns;
                              col++
                            )
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.all(s.xs),
                                  child: InkWell(
                                    key: FeedbackSheet.kindKey(
                                      _kinds[row * 3 + col].$1,
                                    ),
                                    onTap: () => setState(
                                      () => _kind = _kinds[row * 3 + col].$1,
                                    ),
                                    child: Container(
                                      height: FeedbackTokens.tileHeight,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          context.radii.card,
                                        ),
                                        border: Border.all(
                                          color:
                                              _kind == _kinds[row * 3 + col].$1
                                              ? colors.accentGold
                                              : colors.borderSubtle,
                                          width:
                                              _kind == _kinds[row * 3 + col].$1
                                              ? FeedbackTokens.selectedBorder
                                              : FeedbackTokens.selectedBorder /
                                                    2,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _kinds[row * 3 + col].$2,
                                            size: FeedbackTokens.tileIcon,
                                            color: colors.accentGold,
                                          ),
                                          Text(
                                            _name(_kinds[row * 3 + col].$1),
                                            style: type.caption,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      SizedBox(height: s.sm),
                      TextField(
                        key: FeedbackSheet.fieldKey,
                        controller: _body,
                        maxLength: FeedbackTokens.maxLength,
                        maxLines: null,
                        minLines: FeedbackTokens.fieldMinLines,
                        decoration: InputDecoration(
                          hintText: context.l10n.feedbackHint,
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          '${_digits(_body.text.characters.length)} / ${_digits(FeedbackTokens.maxLength)}',
                          style: type.caption,
                        ),
                      ),
                      SizedBox(height: s.sm),
                      FilledButton(
                        key: FeedbackSheet.sendKey,
                        onPressed: _ready && !_sending ? _send : null,
                        child: _sending
                            ? const SizedBox(
                                height: FeedbackTokens.progressSize,
                                width: FeedbackTokens.progressSize,
                                child: CircularProgressIndicator(),
                              )
                            : Text(context.l10n.feedbackSend),
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: type.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
