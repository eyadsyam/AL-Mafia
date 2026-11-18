import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/rating_prompt.dart';
import '../friendly_error.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/deck/deck_buttons.dart';
import 'feedback_api.dart';

/// «إيه رأيك في اللعبة؟»: opened over the result screen, never as a page.
/// «مش دلوقتي» (or dismissing) counts as a closing; a sent rating is final
/// and says «شكرًا!» once.
Future<void> showRatingSheet(BuildContext context, WidgetRef ref) async {
  final prompt = ref.read(ratingPromptProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final thanks = context.l10n.ratingThanks;
  unawaited(prompt.markShownToday());
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const RatingSheet(),
  );
  if (sent == true) {
    await prompt.sent();
    messenger?.showSnackBar(SnackBar(content: Text(thanks)));
  } else {
    await prompt.dismissed();
  }
}

class RatingSheet extends ConsumerStatefulWidget {
  const RatingSheet({super.key});

  static const sendKey = ValueKey('rating_send');
  static const fieldKey = ValueKey('rating_body');
  static const notNowKey = ValueKey('rating_not_now');
  static const errorKey = ValueKey('rating_error');
  static Key starKey(int stars) => ValueKey('rating_star_$stars');

  @override
  ConsumerState<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<RatingSheet> {
  final _body = TextEditingController();
  int _stars = 0;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_stars == 0 || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(ratingApiProvider).rate(_stars, _body.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = friendlyError(context.l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.md, 0, s.md, s.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: FeedbackSheetTokens.sheetMaxWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.ratingTitle,
                  style: type.headline,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: s.md),
                // One to five, left to right, whatever the language.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var n = 1; n <= 5; n++)
                        Semantics(
                          button: true,
                          selected: _stars == n,
                          label: l.ratingStars(n),
                          excludeSemantics: true,
                          onTap: () => setState(() => _stars = n),
                          child: InkResponse(
                            key: RatingSheet.starKey(n),
                            onTap: () => setState(() => _stars = n),
                            radius: FeedbackSheetTokens.starTarget / 2,
                            child: SizedBox(
                              width: FeedbackSheetTokens.starTarget,
                              height: FeedbackSheetTokens.starTarget,
                              child: Icon(
                                Icons.star_rounded,
                                size: FeedbackSheetTokens.starIcon,
                                color: n <= _stars
                                    ? colors.accentGold
                                    : colors.textMuted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_stars > 0) ...[
                  SizedBox(height: s.md),
                  TextField(
                    key: RatingSheet.fieldKey,
                    controller: _body,
                    maxLength: FeedbackSheetTokens.maxLength,
                    minLines: FeedbackSheetTokens.fieldMinLines,
                    maxLines: FeedbackSheetTokens.fieldMaxLines,
                    decoration: InputDecoration(
                      hintText: l.ratingHint,
                      counterText: '',
                    ),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: s.xs),
                    Text(
                      _error!,
                      key: RatingSheet.errorKey,
                      style: type.bodySmall,
                    ),
                  ],
                  SizedBox(height: s.sm),
                  BoneButton(
                    key: RatingSheet.sendKey,
                    label: l.feedbackSend,
                    onPressed: _sending ? null : _send,
                  ),
                ],
                SizedBox(height: s.xs),
                TextButton(
                  key: RatingSheet.notNowKey,
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    l.notNowAction,
                    style: type.body.copyWith(color: colors.textMuted),
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
