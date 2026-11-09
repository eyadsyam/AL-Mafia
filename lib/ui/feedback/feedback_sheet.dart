import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/asset_constants.dart';
import '../../data/player_profile.dart' show playerProfileProvider;
import '../../transport/account_auth.dart' show AccountProfile;
import '../../transport/online_backend.dart';
import '../account/account_sheet.dart'
    show AccountStep, accountProfileProvider, showAccountSheet;
import '../account/guest_save_card.dart' show signInWithGoogle;
import '../l10n_ext.dart';
import '../social/directory.dart' show directoryApiProvider;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/deck/deck_buttons.dart';
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
  static const googleKey = ValueKey('feedback_google');
  static const emailKey = ValueKey('feedback_email');
  static const senderKey = ValueKey('feedback_sender');
  static const hintKey = ValueKey('feedback_short_hint');
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

  /// The server said this session is not an account (stale sign-in): the
  /// sign-in state shows again until the identity changes.
  bool _needSignIn = false;

  /// The server turned the text away as too short.
  bool _serverShort = false;
  bool _googleBusy = false;
  String? _handle;

  static const _kinds = [
    ('roles', Icons.theater_comedy_outlined),
    ('online', Icons.public),
    ('store', Icons.storefront_outlined),
    ('look', Icons.palette_outlined),
    ('idea', Icons.lightbulb_outline),
    ('problem', Icons.bug_report_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _loadHandle();
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  /// The @handle shown beside the name; best effort, the sheet works without.
  Future<void> _loadHandle() async {
    try {
      final me = await ref.read(directoryApiProvider).me();
      if (mounted && me.handle != null) setState(() => _handle = me.handle);
    } catch (_) {
      // No handle line; sending does not depend on it.
    }
  }

  bool get _bodyReady {
    final text = _body.text.trim();
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final letters = text.replaceAll(RegExp(r'\s'), '').runes.length;
    return words >= FeedbackTokens.minWords &&
        letters >= FeedbackTokens.minLetters;
  }

  bool get _ready => _kind != null && _bodyReady;

  Future<void> _google() async {
    setState(() => _googleBusy = true);
    try {
      final failed = await signInWithGoogle(context, ref);
      if (mounted && failed) {
        setState(() => _error = context.l10n.feedbackError);
      }
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _send() async {
    if (!_ready || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
      _serverShort = false;
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
      final code = error is BackendException ? error.code : null;
      setState(() {
        _sending = false;
        if (code == 'SIGN_IN_REQUIRED') _needSignIn = true;
        if (code == 'TOO_SHORT') _serverShort = true;
        _error = switch (code) {
          'RATE_LIMITED' => context.l10n.feedbackRateLimited,
          'SIGN_IN_REQUIRED' || 'TOO_SHORT' => null,
          _ => context.l10n.feedbackError,
        };
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
    ref.listen<AsyncValue<AccountProfile>>(accountProfileProvider, (
      previous,
      next,
    ) {
      final before = previous?.valueOrNull;
      final now = next.valueOrNull;
      if (now != null &&
          now.signedIn &&
          (before == null || before.differs(now))) {
        setState(() => _needSignIn = false);
        _loadHandle();
      }
    });
    final profile =
        ref.watch(accountProfileProvider).valueOrNull ?? AccountProfile.guest;
    final signedIn = profile.signedIn && !_needSignIn;
    final name = ref.watch(playerProfileProvider).valueOrNull?.name ?? '';
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
                : !signedIn
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.l10n.feedbackSignInTitle,
                        style: type.headline,
                      ),
                      SizedBox(height: s.sm),
                      Text(context.l10n.feedbackSignInLine, style: type.body),
                      SizedBox(height: s.md),
                      BoneButton(
                        key: FeedbackSheet.googleKey,
                        label: context.l10n.accountSaveGoogle,
                        onPressed: _googleBusy ? null : _google,
                      ),
                      SizedBox(height: s.sm),
                      RimButton(
                        key: FeedbackSheet.emailKey,
                        label: context.l10n.accountSaveEmail,
                        onPressed: () => showAccountSheet(
                          context,
                          initial: AccountStep.signUp,
                        ),
                      ),
                      if (_error != null) ...[
                        SizedBox(height: s.sm),
                        Text(_error!, style: type.bodySmall),
                      ],
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.l10n.feedbackTitle, style: type.headline),
                      SizedBox(height: s.xs),
                      Row(
                        key: FeedbackSheet.senderKey,
                        children: [
                          Expanded(
                            child: Text(
                              [
                                if (name.isNotEmpty) name,
                                if (_handle != null) '@$_handle',
                              ].join('  '),
                              style: type.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            context.l10n.feedbackSignedIn,
                            style: type.bodySmall.copyWith(
                              color: colors.accentGold,
                            ),
                          ),
                        ],
                      ),
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
                        onChanged: (_) => setState(() => _serverShort = false),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: !_bodyReady || _serverShort
                                ? Text(
                                    context.l10n.feedbackTooShort,
                                    key: FeedbackSheet.hintKey,
                                    style: type.caption.copyWith(
                                      color: _serverShort
                                          ? colors.accentCrimson
                                          : colors.textMuted,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          Text(
                            '${_digits(_body.text.characters.length)} / ${_digits(FeedbackTokens.maxLength)}',
                            style: type.caption,
                          ),
                        ],
                      ),
                      SizedBox(height: s.sm),
                      BoneButton(
                        key: FeedbackSheet.sendKey,
                        label: _sending ? '...' : context.l10n.feedbackSend,
                        onPressed: _ready && !_sending ? _send : null,
                        disabledReason: _kind == null
                            ? context.l10n.feedbackStep1
                            : null,
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
