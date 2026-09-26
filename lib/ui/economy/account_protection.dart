import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/account_service.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/mafia_theme.dart';
import 'wallet.dart';

final accountServiceProvider = Provider<AccountService>(
  (ref) => SupabaseAccountService(ref.read(onlineBackendFactoryProvider)),
);

final accountStatusProvider = FutureProvider<AccountStatus>(
  (ref) => ref.read(accountServiceProvider).status(),
);

enum _Mode { idle, link, recover }

/// Optional email protection for coins and items. Shown in the store for
/// every build (it guards earned coins too) and required before a web
/// payment. Free play never asks for it.
class AccountProtectionCard extends ConsumerStatefulWidget {
  const AccountProtectionCard({super.key});

  static const linkButton = ValueKey('account_link');
  static const recoverButton = ValueKey('account_recover');
  static const emailField = ValueKey('account_email');
  static const codeField = ValueKey('account_code');
  static const sendButton = ValueKey('account_send');
  static const confirmButton = ValueKey('account_confirm');
  static const errorText = ValueKey('account_error');

  @override
  ConsumerState<AccountProtectionCard> createState() =>
      _AccountProtectionCardState();
}

class _AccountProtectionCardState extends ConsumerState<AccountProtectionCard> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  _Mode _mode = _Mode.idle;
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  String _message(String code) {
    final l = context.l10n;
    return switch (code) {
      'INVALID_EMAIL' => l.accountErrorEmail,
      'EMAIL_TAKEN' => l.accountErrorTaken,
      'INVALID_CODE' => l.accountErrorCode,
      'RATE_LIMITED' => l.accountErrorRate,
      _ => l.accountErrorUnavailable,
    };
  }

  Future<void> _run(Future<void> Function(AccountService) step) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await step(ref.read(accountServiceProvider));
    } on AccountFailure catch (failure) {
      if (mounted) setState(() => _error = _message(failure.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run((service) async {
    if (_mode == _Mode.link) {
      await service.requestLink(_email.text);
    } else {
      await service.requestRecovery(_email.text);
    }
    if (mounted) setState(() => _sent = true);
  });

  Future<void> _confirm() => _run((service) async {
    if (_mode == _Mode.link) {
      await service.confirmLink(_email.text, _code.text);
    } else {
      await service.confirmRecovery(_email.text, _code.text);
    }
    // A recovered account has a different wallet; a linked one the same.
    ref.invalidate(accountStatusProvider);
    await ref.read(walletProvider.notifier).refresh();
    if (mounted) {
      setState(() {
        _mode = _Mode.idle;
        _sent = false;
        _code.clear();
      });
    }
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final status = ref.watch(accountStatusProvider).valueOrNull;
    if (status?.recoverable == true) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.verified_user_outlined,
          color: context.colors.accentGold,
        ),
        title: Text(l.accountTitle),
        subtitle: Text(l.accountProtected(status!.email ?? '')),
      );
    }
    return Card(
      child: Padding(
        padding: EdgeInsets.all(s.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.accountTitle, style: context.typography.title),
            SizedBox(height: s.xs),
            Text(l.accountAnonymousHint, style: context.typography.bodySmall),
            SizedBox(height: s.sm),
            if (_mode == _Mode.idle)
              Wrap(
                spacing: s.sm,
                children: [
                  FilledButton(
                    key: AccountProtectionCard.linkButton,
                    onPressed: () => setState(() => _mode = _Mode.link),
                    child: Text(l.accountLink),
                  ),
                  TextButton(
                    key: AccountProtectionCard.recoverButton,
                    onPressed: () => setState(() => _mode = _Mode.recover),
                    child: Text(l.accountRecover),
                  ),
                ],
              )
            else ...[
              if (_mode == _Mode.recover)
                Text(
                  l.accountRecoverWarning,
                  style: context.typography.bodySmall,
                ),
              TextField(
                key: AccountProtectionCard.emailField,
                controller: _email,
                enabled: !_sent,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: l.accountEmail),
              ),
              if (_sent) ...[
                Text(
                  l.accountCodeSent(_email.text.trim()),
                  style: context.typography.bodySmall,
                ),
                TextField(
                  key: AccountProtectionCard.codeField,
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: InputDecoration(labelText: l.accountCode),
                ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  key: AccountProtectionCard.errorText,
                  style: context.typography.bodySmall.copyWith(
                    color: context.colors.accentCrimson,
                  ),
                ),
              SizedBox(height: s.sm),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: _sent
                          ? AccountProtectionCard.confirmButton
                          : AccountProtectionCard.sendButton,
                      onPressed: _busy ? null : (_sent ? _confirm : _send),
                      child: Text(_sent ? l.accountConfirm : l.accountSendCode),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _mode = _Mode.idle;
                            _sent = false;
                            _error = null;
                          }),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
