import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SignOutScope;

import '../../platform/clipboard.dart';
import '../../platform/links/external_link.dart';
import '../../data/online_session_store.dart';
import '../../transport/online_backend.dart';
import '../../transport/supabase_backend.dart';
import '../economy/account_protection.dart' show accountStatusProvider;
import '../economy/economy_capabilities.dart';
import '../economy/wallet.dart';
import '../friendly_error.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../screens/online/room_invite.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// What «احذف حسابي وبياناتي» does, separated from the sheet so a test can
/// stand in for the server.
///
/// Calls the `delete_account` Edge Function (the account is the JWT's own),
/// then drops the local session so the next online step starts a fresh guest.
/// A player with no session has nothing on the server to delete.
typedef DeleteAccountAction = Future<void> Function();

final deleteAccountActionProvider = Provider<DeleteAccountAction>((ref) {
  return () async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    if (backend.userId == null) return;
    await backend.call('delete_account', {'confirm': true});
    if (backend is SupabaseBackend) {
      try {
        await backend.client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        /* The account is already gone on the server; the session is stale. */
      }
    }
    await OnlineSessionStore.clear();
    ref.invalidate(accountStatusProvider);
    ref.invalidate(economyCapabilitiesProvider);
    ref.invalidate(walletProvider);
  };
});

/// The confirm sheet. Closing it (scrim, back, «مش دلوقتي») deletes nothing.
Future<void> showDeleteAccountSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surfaceBase,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const DeleteAccountSheet(),
      ),
    );

class DeleteAccountSheet extends ConsumerStatefulWidget {
  const DeleteAccountSheet({super.key});

  static const confirmKey = ValueKey('delete_account_confirm');
  static const actionKey = ValueKey('delete_account_action');
  static const cancelKey = ValueKey('delete_account_cancel');
  static const errorKey = ValueKey('delete_account_error');
  static const doneKey = ValueKey('delete_account_done');
  static const webKey = ValueKey('delete_account_web');

  @override
  ConsumerState<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<DeleteAccountSheet> {
  bool _sure = false;
  bool _busy = false;
  bool _done = false;
  String? _error;
  String? _notice;

  String _refusal(Object error) {
    final l = context.l10n;
    if (error is BackendException) {
      if (error.code == 'IN_MATCH') return l.deleteAccountInRoom;
      if (error.code == 'ORDER_OPEN') return l.deleteAccountOrder;
    }
    return friendlyError(l, error);
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(deleteAccountActionProvider)();
      if (mounted) setState(() => _done = true);
    } catch (error) {
      if (mounted) setState(() => _error = _refusal(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The website's page: opened on the web; everywhere else (no browser
  /// launcher in this app) its link is copied instead.
  Future<void> _web() async {
    const url = '${RoomInvite.site}delete-data/';
    if (ref.read(externalLinkOpenerProvider)(url)) return;
    final copied = await AppClipboard.copy(url);
    if (mounted && copied) {
      setState(() => _notice = context.l10n.deleteAccountWebCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    if (_done) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(s.screenMargin),
          child: Column(
            key: DeleteAccountSheet.doneKey,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.check_circle_outline, color: colors.accentGold),
              SizedBox(height: s.sm),
              Text(
                l.deleteAccountDone,
                textAlign: TextAlign.center,
                style: type.headline.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: s.xs),
              Text(
                l.deleteAccountDoneHint,
                textAlign: TextAlign.center,
                style: type.body.copyWith(color: colors.textSecondary),
              ),
              SizedBox(height: s.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(s.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.deleteAccountTitle,
              textAlign: TextAlign.center,
              style: type.headline.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: s.sm),
            Text(
              l.deleteAccountBody,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: s.sm),
            Text(
              l.deleteAccountKept,
              style: type.bodySmall.copyWith(color: colors.textMuted),
            ),
            SizedBox(height: s.md),
            CheckboxListTile(
              key: DeleteAccountSheet.confirmKey,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _sure,
              onChanged: _busy ? null : (v) => setState(() => _sure = v!),
              title: Text(l.deleteAccountConfirm),
            ),
            if (_error != null) ...[
              SizedBox(height: s.sm),
              Text(
                _error!,
                key: DeleteAccountSheet.errorKey,
                textAlign: TextAlign.center,
                style: type.bodySmall.copyWith(color: colors.accentCrimson),
              ),
            ],
            SizedBox(height: s.md),
            FilledButton(
              key: DeleteAccountSheet.actionKey,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accentCrimson,
              ),
              onPressed: _sure && !_busy ? _delete : null,
              child: _busy
                  ? const SizedBox.square(
                      dimension: AccountTokens.progress,
                      child: CircularProgressIndicator(
                        strokeWidth: AccountTokens.progressStroke,
                      ),
                    )
                  : Text(l.deleteAccountAction),
            ),
            SizedBox(height: s.xs),
            TextButton(
              key: DeleteAccountSheet.cancelKey,
              onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
              child: Text(l.deleteAccountCancel),
            ),
            Divider(color: colors.borderSubtle, height: s.lg),
            Text(
              l.deleteAccountWebTitle,
              style: type.caption.copyWith(color: colors.textMuted),
            ),
            TextButton(
              key: DeleteAccountSheet.webKey,
              onPressed: _busy ? null : _web,
              child: Text(l.deleteAccountWebOpen),
            ),
            if (_notice != null)
              Text(
                _notice!,
                textAlign: TextAlign.center,
                style: type.caption.copyWith(color: colors.accentGold),
              ),
          ],
        ),
      ),
    );
  }
}
