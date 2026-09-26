import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transport/online_backend.dart';
import '../../economy/account_protection.dart';
import '../../economy/coin_packs.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../online/online_session.dart';

/// The owner's transfer review queue (web, /admin/coins).
///
/// Reaching this screen grants nothing: every read and every decision goes
/// through `coin_orders` admin actions, which the database refuses unless the
/// signed-in account is in `commerce_admins`. The admin signs in with their
/// protected email (the same one-time-code flow as players). Approving is only
/// for money the admin has seen arrive in their own bank or wallet records,
/// matched by amount, method and reference; anything unclear stays in review.
class CoinReviewScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const CoinReviewScreen({super.key, this.onBack});

  static Key approve(String id) => ValueKey('admin_approve_$id');
  static Key needsInfo(String id) => ValueKey('admin_needs_info_$id');
  static Key reject(String id) => ValueKey('admin_reject_$id');
  static Key refund(String id) => ValueKey('admin_refund_$id');
  static Key transaction(String id) => ValueKey('admin_txn_$id');
  static Key received(String id) => ValueKey('admin_received_$id');
  static Key note(String id) => ValueKey('admin_note_$id');

  @override
  ConsumerState<CoinReviewScreen> createState() => _CoinReviewScreenState();
}

class _CoinReviewScreenState extends ConsumerState<CoinReviewScreen> {
  List<Map<String, dynamic>>? _orders;
  String? _error;
  bool _busy = false;

  /// null = the review queue; 'paid' = paid orders (for refunds).
  String? _status;
  final _fields =
      <
        String,
        (TextEditingController, TextEditingController, TextEditingController)
      >{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final (a, b, c) in _fields.values) {
      a.dispose();
      b.dispose();
      c.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('coin_orders', body);
  }

  String _explain(String code) {
    final l = context.l10n;
    return switch (code) {
      'NOT_ADMIN' => l.adminNotAdmin,
      'AMOUNT_MISMATCH' => l.adminErrorAmount,
      'TRANSFER_ALREADY_USED' => l.adminErrorUsed,
      _ => l.adminErrorGeneric,
    };
  }

  Future<void> _load() async {
    try {
      final answer = await _call({
        'action': 'admin_list',
        if (_status != null) 'status': _status,
      });
      if (!mounted) return;
      setState(() {
        _error = null;
        _orders = [
          for (final o
              in (answer['orders'] as List? ?? const []).whereType<Map>())
            Map<String, dynamic>.from(o),
        ];
      });
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = _explain(e.code));
    }
  }

  (TextEditingController, TextEditingController, TextEditingController) _for(
    String id,
  ) => _fields.putIfAbsent(
    id,
    () => (
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ),
  );

  Future<void> _decide(String id, String action, [String? decision]) async {
    if (_busy) return;
    final (txn, received, note) = _for(id);
    final pounds = double.tryParse(received.text.trim());
    setState(() => _busy = true);
    try {
      await _call({
        'action': action,
        'order': id,
        if (decision != null) 'decision': decision,
        if (txn.text.trim().isNotEmpty) 'transaction': txn.text.trim(),
        if (pounds != null) 'receivedPiastres': (pounds * 100).round(),
        'note': note.text.trim(),
      });
      await _load();
    } on BackendException catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(_explain(e.code))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final orders = _orders;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.adminCoinsTitle),
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: s.maxContentWidth),
          child: ListView(
            padding: EdgeInsets.all(s.md),
            children: [
              const AccountProtectionCard(),
              SizedBox(height: s.sm),
              Text(l.adminCheckFirst, style: context.typography.bodySmall),
              SizedBox(height: s.sm),
              SegmentedButton<String?>(
                segments: [
                  ButtonSegment(value: null, label: Text(l.adminFilterOpen)),
                  ButtonSegment(value: 'paid', label: Text(l.adminFilterPaid)),
                ],
                selected: {_status},
                onSelectionChanged: (v) {
                  setState(() => _status = v.single);
                  _load();
                },
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
                _card(order),
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
    final (txn, received, note) = _for(id);
    final line = l.adminOrderLine(
      order['reference'] as String? ?? '',
      order['account'] as String? ?? '—',
      egp((order['amountPiastres'] as num?)?.toInt() ?? 0),
      methodName(context, order['method'] as String? ?? ''),
      order['claimReference'] as String? ?? '—',
    );
    return Card(
      child: Padding(
        padding: EdgeInsets.all(s.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(line, style: context.typography.body),
            Text(
              // A web Quiet Pass order grants the pass, not coins.
              '${order['pack'] == 'quiet_pass' ? '${l.quietPassTitle} · ' : ''}$status · ${order['payerHint'] ?? ''} · ${order['claimedAt'] ?? order['createdAt'] ?? ''}',
              style: context.typography.caption,
            ),
            if (status == 'paid')
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: CoinReviewScreen.note(id),
                      controller: note,
                      decoration: InputDecoration(labelText: l.adminNote),
                    ),
                  ),
                  TextButton(
                    key: CoinReviewScreen.refund(id),
                    onPressed: _busy ? null : () => _decide(id, 'admin_refund'),
                    child: Text(l.adminRefund),
                  ),
                ],
              )
            else ...[
              TextField(
                key: CoinReviewScreen.transaction(id),
                controller: txn,
                decoration: InputDecoration(labelText: l.adminProviderTxn),
              ),
              TextField(
                key: CoinReviewScreen.received(id),
                controller: received,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l.adminReceived),
              ),
              TextField(
                key: CoinReviewScreen.note(id),
                controller: note,
                decoration: InputDecoration(labelText: l.adminNote),
              ),
              SizedBox(height: s.sm),
              Wrap(
                spacing: s.sm,
                children: [
                  FilledButton(
                    key: CoinReviewScreen.approve(id),
                    onPressed: _busy
                        ? null
                        : () => _decide(id, 'admin_review', 'approve'),
                    child: Text(l.adminApprove),
                  ),
                  OutlinedButton(
                    key: CoinReviewScreen.needsInfo(id),
                    onPressed: _busy
                        ? null
                        : () => _decide(id, 'admin_review', 'needs_info'),
                    child: Text(l.adminNeedsInfo),
                  ),
                  TextButton(
                    key: CoinReviewScreen.reject(id),
                    onPressed: _busy
                        ? null
                        : () => _decide(id, 'admin_review', 'reject'),
                    child: Text(l.adminReject),
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
