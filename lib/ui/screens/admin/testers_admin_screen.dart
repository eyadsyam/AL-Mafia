import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transport/online_backend.dart';
import '../../economy/account_protection.dart';
import '../../economy/vault_kit.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../online/online_session.dart';

/// The owner's tester page (web only, `/admin/testers`, in no menu but the
/// payments page): who opened saidalmafia.com/beta, from which link, and every
/// sign-up with a tick for "added to the Play group". Like the other admin
/// pages, every read and tick is a `tester_admin` action the database refuses
/// to anyone outside `commerce_admins`.
class TestersAdminScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final bool web;

  const TestersAdminScreen({super.key, this.onBack, this.web = kIsWeb});

  static Key signup(int id) => ValueKey('testers_admin_signup_$id');
  static const guard = ValueKey('testers_admin_guard');

  @override
  ConsumerState<TestersAdminScreen> createState() => _TestersAdminScreenState();
}

class _TestersAdminScreenState extends ConsumerState<TestersAdminScreen> {
  bool? _admin;
  Map<String, dynamic> _visits = const {};
  final _signups = <Map<String, dynamic>>[];
  String? _error;
  bool _busy = false;

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('tester_admin', body);
  }

  String _explain(Object error) {
    final l = context.l10n;
    final code = error is BackendException ? error.code : '';
    return code == 'NOT_ADMIN' ? l.adminNotAdmin : l.adminErrorGeneric;
  }

  Future<void> _load() async {
    try {
      final answer = await _call({'action': 'list'});
      if (!mounted) return;
      setState(() {
        _admin = true;
        _error = null;
        _visits = answer['visits'] is Map
            ? Map<String, dynamic>.from(answer['visits'] as Map)
            : const {};
        _signups
          ..clear()
          ..addAll([
            for (final r in (answer['signups'] as List? ?? const []))
              if (r is Map && r['id'] is num) Map<String, dynamic>.from(r),
          ]);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _admin = error is BackendException && error.code == 'NOT_ADMIN'
            ? false
            : _admin;
        _error = _explain(error);
      });
    }
  }

  Future<void> _mark(int id, bool added) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _call({'action': 'mark', 'id': id, 'added': added});
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

  Future<void> _copyPending() async {
    final emails = [
      for (final r in _signups)
        if (r['added'] != true) r['email'] as String? ?? '',
    ].where((e) => e.isNotEmpty).join(', ');
    await Clipboard.setData(ClipboardData(text: emails));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(context.l10n.adminTestersCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final account = ref.watch(accountStatusProvider);
    final signedIn = account.valueOrNull?.recoverable == true;
    if (widget.web && signedIn && _admin == null && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _admin == null && _error == null) _load();
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.adminTestersTitle),
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        actions: [
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
                  key: TestersAdminScreen.guard,
                  l.adminWebOnly,
                  style: context.typography.body,
                )
              else if (!signedIn) ...[
                Text(l.adminSignInHint, style: context.typography.body),
                SizedBox(height: s.sm),
                const AccountProtectionCard(),
              ] else if (_admin != true)
                _admin == false
                    ? Text(
                        key: TestersAdminScreen.guard,
                        _error ?? l.adminNotAdmin,
                        style: context.typography.body,
                      )
                    : const SizedBox(
                        height: VaultTokens.skeletonCard,
                        child: VaultSkeleton(cards: 1),
                      )
              else ...[
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: s.md),
                    child: Text(_error!, style: context.typography.body),
                  ),
                _visitsCard(),
                SizedBox(height: s.lg),
                _signupsHeader(),
                if (_signups.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: s.md),
                    child: Text(l.adminTestersEmpty),
                  ),
                for (final r in _signups)
                  Padding(
                    padding: EdgeInsets.only(top: s.sm),
                    child: _signupCard(r),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _int(Object? v) => v is num ? v.toInt() : 0;

  Widget _stat(String label, int value) => Column(
    children: [
      Text(
        '$value',
        style: context.typography.title.copyWith(color: VaultTokens.goldLight),
      ),
      Text(
        label,
        style: context.typography.caption.copyWith(
          color: context.colors.textMuted,
        ),
      ),
    ],
  );

  Widget _visitsCard() {
    final l = context.l10n;
    final s = context.spacing;
    final sources = (_visits['bySource'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final days = (_visits['byDay'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return VaultCard(
      children: [
        Text(l.adminTestersVisitors, style: context.typography.title),
        SizedBox(height: s.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat(l.adminTestersToday, _int(_visits['today'])),
            _stat(l.adminTestersAll, _int(_visits['total'])),
            _stat(l.adminTestersOpens, _int(_visits['hits'])),
          ],
        ),
        if (sources.isNotEmpty) ...[
          SizedBox(height: s.md),
          Text(l.adminTestersBySource, style: context.typography.body.emphasised),
          for (final row in sources)
            _line(
              (row['source'] as String? ?? '').isEmpty
                  ? l.adminTestersNoSource
                  : row['source'] as String,
              _int(row['visitors']),
            ),
        ],
        if (days.isNotEmpty) ...[
          SizedBox(height: s.md),
          Text(l.adminTestersByDay, style: context.typography.body.emphasised),
          for (final row in days)
            _line(_day(row['day']), _int(row['visitors'])),
        ],
      ],
    );
  }

  Widget _line(String label, int value) => Padding(
    padding: EdgeInsets.only(top: context.spacing.xs),
    child: Row(
      children: [
        Expanded(child: Text(label, style: context.typography.bodySmall)),
        Text('$value', style: context.typography.bodySmall.emphasised),
      ],
    ),
  );

  Widget _signupsHeader() {
    final l = context.l10n;
    final s = context.spacing;
    final pending = _signups.where((r) => r['added'] != true).length;
    return Wrap(
      spacing: s.sm,
      runSpacing: s.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          l.adminTestersSignups(_signups.length),
          style: context.typography.title,
        ),
        Text(
          l.adminTestersPending(pending),
          style: context.typography.body.copyWith(
            color: context.colors.textMuted,
          ),
        ),
        if (pending > 0)
          OutlinedButton.icon(
            style: vaultOutlineStyle(context),
            onPressed: _copyPending,
            icon: const Icon(Icons.copy_outlined),
            label: Text(l.adminTestersCopyPending),
          ),
      ],
    );
  }

  String _day(Object? iso) {
    final at = DateTime.tryParse(iso is String ? iso : '');
    if (at == null) return '';
    return MaterialLocalizations.of(context).formatMediumDate(at);
  }

  String _when(Object? iso) {
    final at = DateTime.tryParse(iso is String ? iso : '')?.toLocal();
    if (at == null) return '';
    final m = MaterialLocalizations.of(context);
    return '${m.formatMediumDate(at)} ${m.formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
  }

  Widget _signupCard(Map<String, dynamic> r) {
    final l = context.l10n;
    final id = _int(r['id']);
    final added = r['added'] == true;
    final source = r['source'] as String? ?? '';
    return VaultCard(
      key: TestersAdminScreen.signup(id),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r['name'] as String? ?? '',
                    style: context.typography.body.emphasised,
                  ),
                  SelectableText(
                    r['email'] as String? ?? '',
                    textDirection: TextDirection.ltr,
                    style: context.typography.bodySmall,
                  ),
                  Text(
                    [
                      if (source.isNotEmpty) source,
                      _when(r['createdAt']),
                      r['mailed'] == true
                          ? l.adminTestersMailed
                          : l.adminTestersNotMailed,
                    ].join(' · '),
                    style: context.typography.caption.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Checkbox(
                  value: added,
                  onChanged: _busy ? null : (on) => _mark(id, on == true),
                ),
                Text(l.adminTestersAdded, style: context.typography.caption),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
