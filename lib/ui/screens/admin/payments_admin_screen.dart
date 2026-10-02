import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart' show Routes;
import '../../../transport/account_service.dart';
import '../../../transport/online_backend.dart';
import '../../economy/account_protection.dart';
import '../../economy/coin_packs.dart';
import '../../economy/vault_kit.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../online/online_session.dart';

/// The owner's payment review page (web only, `/admin`, hidden from every
/// menu). Reaching it grants nothing: the page asks the server whether this
/// signed-in account is in `commerce_admins` and shows nothing else until it
/// is, and every read and decision goes through `coin_orders` admin actions,
/// which the database refuses to anyone else. Sign-in is the email one-time
/// code of the account-protection card, or the email's link: it lands back
/// on this page, where the web client takes the session from the URL.
///
/// Approve only money seen arriving in the InstaPay / Vodafone Cash app: the
/// amount, the sender name and the screenshot must match.
class PaymentsAdminScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  /// From the Telegram deep link (`/admin?order=<id>`): shown first.
  final String? focusOrder;

  /// Client-side guard: the page exists on the web build only.
  final bool web;

  /// The F11 report queue, on its own page.
  final VoidCallback? onSafety;

  const PaymentsAdminScreen({
    super.key,
    this.onBack,
    this.onSafety,
    this.focusOrder,
    this.web = kIsWeb,
  });

  static Key approve(String id) => ValueKey('admin_approve_$id');
  static Key reject(String id) => ValueKey('admin_reject_$id');
  static Key refund(String id) => ValueKey('admin_refund_$id');
  static Key reason(String id) => ValueKey('admin_reason_$id');
  static Key order(String id) => ValueKey('admin_order_$id');
  static Key filter(String name) => ValueKey('admin_filter_$name');
  static const guard = ValueKey('admin_guard');
  static const signedInAs = ValueKey('admin_signed_in_as');

  @override
  ConsumerState<PaymentsAdminScreen> createState() =>
      _PaymentsAdminScreenState();
}

class _PaymentsAdminScreenState extends ConsumerState<PaymentsAdminScreen> {
  /// null = not asked yet; the server's answer otherwise.
  bool? _admin;
  List<Map<String, dynamic>>? _orders;
  String _filter = 'pending';
  String? _error;
  bool _busy = false;
  bool _asking = false;
  final _reasons = <String, TextEditingController>{};
  StreamSubscription<AccountStatus>? _auth;

  @override
  void initState() {
    super.initState();
    // A session can arrive from the emailed link (the web client reads it
    // from the URL), not only from the code typed into the card.
    if (widget.web) {
      _auth = ref.read(accountServiceProvider).changes().listen((status) {
        if (!mounted) return;
        final known = ref.read(accountStatusProvider).valueOrNull;
        if (status.recoverable != (known?.recoverable ?? false) ||
            status.email != known?.email) {
          ref.invalidate(accountStatusProvider);
        }
      }, onError: (_) {});
    }
  }

  /// Where the recovery email's link should land: back here. The server
  /// uses it only when listed in the project's redirect URLs.
  static String? get _linkReturn {
    final base = Uri.base;
    if (base.scheme != 'http' && base.scheme != 'https') return null;
    return '${base.origin}${Routes.admin}';
  }

  @override
  void dispose() {
    _auth?.cancel();
    for (final c in _reasons.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('coin_orders', body);
  }

  String _explain(Object error) {
    final l = context.l10n;
    final code = error is BackendException ? error.code : '';
    return switch (code) {
      'NOT_ADMIN' => l.adminNotAdmin,
      'ALREADY_OWNED' => l.adminErrorOwned,
      'PROOF_REQUIRED' => l.adminErrorProof,
      'TRANSFER_ALREADY_USED' => l.adminErrorUsed,
      _ => l.adminErrorGeneric,
    };
  }

  Future<void> _whoami() async {
    if (_asking) return;
    _asking = true;
    try {
      final answer = await _call({'action': 'admin_whoami'});
      if (!mounted) return;
      setState(() => _admin = answer['admin'] == true);
      if (_admin!) await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _admin = false;
          _error = _explain(error);
        });
      }
    } finally {
      _asking = false;
    }
  }

  Future<void> _load() async {
    try {
      final answer = await _call({'action': 'admin_list', 'status': _filter});
      if (!mounted) return;
      final orders = [
        for (final o
            in (answer['orders'] as List? ?? const []).whereType<Map>())
          Map<String, dynamic>.from(o),
      ];
      // The deep-linked order first; otherwise newest first as served.
      final focus = widget.focusOrder;
      if (focus != null) {
        orders.sort(
          (a, b) => (b['id'] == focus ? 1 : 0) - (a['id'] == focus ? 1 : 0),
        );
      }
      setState(() {
        _error = null;
        _orders = orders;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _explain(error));
    }
  }

  TextEditingController _reason(String id) =>
      _reasons.putIfAbsent(id, TextEditingController.new);

  Future<void> _act(Map<String, Object?> body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _call(body);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(_explain(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _withReason(String id, String action, String field) {
    final text = _reason(id).text.trim();
    if (text.length < 3) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.adminReasonRequired)),
      );
      return;
    }
    _act({'action': action, 'order': id, field: text});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final account = ref.watch(accountStatusProvider);
    // Asked once per signed-in account; signing in re-asks.
    ref.listen(accountStatusProvider, (_, next) {
      if (widget.web && next.valueOrNull?.recoverable == true) {
        setState(() => _admin = null);
        _whoami();
      }
    });
    final signedIn = account.valueOrNull?.recoverable == true;
    final email = account.valueOrNull?.email ?? '';
    if (widget.web && signedIn && _admin == null && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _admin == null) _whoami();
      });
    }
    final orders = _orders;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.adminPaymentsTitle),
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        actions: [
          if (_admin == true && widget.onSafety != null)
            IconButton(
              onPressed: widget.onSafety,
              tooltip: l.adminSafetyOpenQueue,
              icon: const Icon(Icons.flag_outlined),
            ),
          if (_admin == true)
            IconButton(
              onPressed: _busy ? null : _load,
              tooltip: MaterialLocalizations.of(
                context,
              ).refreshIndicatorSemanticLabel,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: s.maxContentWidth),
          child: ListView(
            padding: EdgeInsets.all(s.md),
            children: [
              if (!widget.web)
                Text(
                  key: PaymentsAdminScreen.guard,
                  l.adminWebOnly,
                  style: context.typography.body,
                )
              else if (!signedIn) ...[
                Text(l.adminSignInHint, style: context.typography.body),
                SizedBox(height: s.sm),
                AccountProtectionCard(recoveryRedirect: _linkReturn),
              ] else ...[
                Text(
                  key: PaymentsAdminScreen.signedInAs,
                  l.adminSignedInAs(email),
                  style: context.typography.bodySmall,
                ),
                SizedBox(height: s.sm),
              ],
              if (widget.web && signedIn && _admin != true) ...[
                if (_admin == false)
                  Text(
                    key: PaymentsAdminScreen.guard,
                    _error ?? l.adminNotAdmin,
                    style: context.typography.body,
                  )
                else
                  const VaultSkeleton(cards: 1),
                SizedBox(height: s.sm),
                const AccountProtectionCard(),
              ] else if (widget.web && signedIn) ...[
                Text(l.adminCheckFirst, style: context.typography.bodySmall),
                SizedBox(height: s.sm),
                Wrap(
                  spacing: s.sm,
                  runSpacing: s.xs,
                  children: [
                    for (final (name, label) in [
                      ('pending', l.adminFilterPending),
                      ('approved', l.adminFilterApproved),
                      ('rejected', l.adminFilterRejected),
                      ('expired', l.adminFilterExpired),
                    ])
                      ChoiceChip(
                        key: PaymentsAdminScreen.filter(name),
                        label: Text(label),
                        selected: _filter == name,
                        onSelected: (_) {
                          setState(() => _filter = name);
                          _load();
                        },
                      ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: s.md),
                    child: Text(_error!, style: context.typography.body),
                  ),
                if (orders != null && orders.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: s.md),
                    child: Text(l.adminEmpty),
                  ),
                for (final order in orders ?? const <Map<String, dynamic>>[])
                  Padding(
                    padding: EdgeInsets.only(top: s.md),
                    child: _card(order),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> order) {
    final l = context.l10n;
    final s = context.spacing;
    final id = order['id'] as String;
    final status = order['status'] as String? ?? '';
    final parsed = CoinOrder.fromJson(order);
    final url = order['proofUrl'] as String?;
    final when = (order['submittedAt'] ?? order['createdAt'] ?? '').toString();
    return VaultCard(
      key: PaymentsAdminScreen.order(id),
      lit: id == widget.focusOrder,
      children: [
        SelectableText(
          '${parsed.reference} · #${id.substring(0, id.length < 8 ? id.length : 8)}',
          style: context.typography.title.copyWith(
            color: VaultTokens.goldLight,
          ),
        ),
        Text(
          l.adminOrderMeta(
            orderProduct(context, parsed),
            egp(parsed.amountPiastres),
            methodName(context, parsed.method),
          ),
          style: context.typography.body,
        ),
        SelectableText(
          l.adminSender(
            parsed.senderName ?? order['payerHint'] as String? ?? '—',
          ),
          style: context.typography.body.emphasised,
        ),
        Text(
          l.adminPlayer(order['displayName'] as String? ?? '—'),
          style: context.typography.bodySmall,
        ),
        Text(
          '$status · $when',
          style: context.typography.caption.copyWith(
            color: context.colors.textMuted,
          ),
        ),
        if ((parsed.note ?? '').isNotEmpty)
          Text(parsed.note!, style: context.typography.bodySmall),
        SizedBox(height: s.sm),
        if (url != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(context.radii.button),
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                height: VaultTokens.skeletonCard * 3,
                errorBuilder: (_, _, _) => Text(l.adminErrorProof),
              ),
            ),
          )
        else
          Text(
            order['proofPurged'] == true ? l.adminProofGone : l.adminErrorProof,
            style: context.typography.caption,
          ),
        SizedBox(height: s.sm),
        if (status == 'claimed' ||
            status == 'needs_info' ||
            status == 'expired') ...[
          TextField(
            key: PaymentsAdminScreen.reason(id),
            controller: _reason(id),
            maxLength: 300,
            decoration: InputDecoration(labelText: l.adminRejectReason),
          ),
          Wrap(
            spacing: s.sm,
            children: [
              FilledButton(
                key: PaymentsAdminScreen.approve(id),
                style: vaultGoldStyle(context),
                onPressed: _busy || order['proofSubmitted'] != true
                    ? null
                    : () => _act({'action': 'admin_approve', 'order': id}),
                child: Text(l.adminApproveShort),
              ),
              OutlinedButton(
                key: PaymentsAdminScreen.reject(id),
                style: vaultOutlineStyle(context),
                onPressed: _busy
                    ? null
                    : () => _withReason(id, 'admin_reject', 'reason'),
                child: Text(l.adminRejectShort),
              ),
            ],
          ),
        ] else if (status == 'paid') ...[
          TextField(
            key: PaymentsAdminScreen.reason(id),
            controller: _reason(id),
            maxLength: 300,
            decoration: InputDecoration(labelText: l.adminNote),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              key: PaymentsAdminScreen.refund(id),
              style: vaultOutlineStyle(context),
              onPressed: _busy
                  ? null
                  : () => _withReason(id, 'admin_refund', 'note'),
              child: Text(l.adminRefundShort),
            ),
          ),
        ],
      ],
    );
  }
}
