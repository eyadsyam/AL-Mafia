import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/request_id.dart';
import '../../../transport/online_backend.dart';
import '../../economy/account_protection.dart';
import '../../economy/vault_kit.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../online/online_session.dart';
import '../online/safety_center.dart' show safetyCategories;

/// The owner's report queue (F11; web only, `/admin/safety`, hidden from every
/// menu). Like the payments page, reaching it grants nothing: every read and
/// decision is a `player_safety` admin action the database refuses to anyone
/// outside `commerce_admins`, and the page shows nothing until the server has
/// said yes.
///
/// A report shows only what the server kept as evidence — the context, the
/// room's code and title, the reported name and seat — and the reporter's own
/// words. Never a role, an action, a whisper or voice.
class SafetyAdminScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final bool web;

  const SafetyAdminScreen({super.key, this.onBack, this.web = kIsWeb});

  static Key report(String id) => ValueKey('safety_admin_report_$id');
  static Key action(String id, String action) =>
      ValueKey('safety_admin_${action}_$id');
  static Key filter(String name) => ValueKey('safety_admin_filter_$name');
  static const guard = ValueKey('safety_admin_guard');

  @override
  ConsumerState<SafetyAdminScreen> createState() => _SafetyAdminScreenState();
}

class _SafetyAdminScreenState extends ConsumerState<SafetyAdminScreen> {
  bool? _admin;
  String _status = 'open';
  String? _category;
  final _items = <Map<String, dynamic>>[];
  String? _next;
  String? _error;
  bool _busy = false;
  final _notes = <String, TextEditingController>{};

  /// One per intended decision, reused if the answer is lost and retried.
  final _requests = <String, String>{};

  @override
  void dispose() {
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('player_safety', body);
  }

  String _explain(Object error) {
    final l = context.l10n;
    final code = error is BackendException ? error.code : '';
    return code == 'NOT_ADMIN' ? l.adminNotAdmin : l.adminErrorGeneric;
  }

  Future<void> _load({bool more = false}) async {
    try {
      final answer = await _call({
        'action': 'admin_list',
        'status': _status,
        'category': _category,
        'cursor': more ? _next : null,
      });
      if (!mounted) return;
      setState(() {
        _admin = true;
        _error = null;
        if (!more) _items.clear();
        _items.addAll([
          for (final r in (answer['items'] as List? ?? const []))
            if (r is Map && r['id'] is String) Map<String, dynamic>.from(r),
        ]);
        _next = answer['next'] as String?;
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

  Future<void> _act(Map<String, Object?> body, String key) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _call({...body, 'requestId': _requests[key] ??= newRequestId()});
      _requests.remove(key);
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

  TextEditingController _note(String id) =>
      _notes.putIfAbsent(id, TextEditingController.new);

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
        title: Text(l.adminSafetyTitle),
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
                  key: SafetyAdminScreen.guard,
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
                        key: SafetyAdminScreen.guard,
                        _error ?? l.adminNotAdmin,
                        style: context.typography.body,
                      )
                    : const SizedBox(
                        height: VaultTokens.skeletonCard,
                        child: VaultSkeleton(cards: 1),
                      )
              else ...[
                Wrap(
                  spacing: s.sm,
                  runSpacing: s.xs,
                  children: [
                    for (final (name, label) in [
                      ('open', l.adminSafetyOpen),
                      ('actioned', l.adminSafetyActioned),
                      ('dismissed', l.adminSafetyDismissed),
                    ])
                      ChoiceChip(
                        key: SafetyAdminScreen.filter(name),
                        label: Text(label),
                        selected: _status == name,
                        onSelected: (_) {
                          setState(() => _status = name);
                          _load();
                        },
                      ),
                  ],
                ),
                SizedBox(height: s.xs),
                Wrap(
                  spacing: s.xs,
                  runSpacing: s.xs,
                  children: [
                    for (final name in safetyCategories)
                      FilterChip(
                        label: Text(_categoryLabel(name)),
                        selected: _category == name,
                        onSelected: (on) {
                          setState(() => _category = on ? name : null);
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
                if (_items.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: s.md),
                    child: Text(l.adminEmpty),
                  ),
                for (final r in _items)
                  Padding(
                    padding: EdgeInsets.only(top: s.md),
                    child: _card(r),
                  ),
                if (_next != null)
                  TextButton(
                    onPressed: _busy ? null : () => _load(more: true),
                    child: Text(l.adminSafetyMore),
                  ),
                SizedBox(height: s.lg),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _act({'action': 'admin_purge'}, 'purge'),
                  child: Text(l.adminSafetyPurge),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String name) {
    final l = context.l10n;
    return switch (name) {
      'harassment' => l.safetyCatHarassment,
      'hate' => l.safetyCatHate,
      'sexual' => l.safetyCatSexual,
      'threat' => l.safetyCatThreat,
      'spam' => l.safetyCatSpam,
      'cheating' => l.safetyCatCheating,
      'inappropriate_name' => l.safetyCatName,
      _ => l.safetyCatOther,
    };
  }

  String _contextLabel(Object? name) {
    final l = context.l10n;
    return switch (name) {
      'lobby' => l.adminSafetyCtxLobby,
      'match' => l.adminSafetyCtxMatch,
      'result' => l.adminSafetyCtxResult,
      'friends' => l.adminSafetyCtxFriends,
      _ => '—',
    };
  }

  Widget _card(Map<String, dynamic> r) {
    final l = context.l10n;
    final s = context.spacing;
    final id = r['id'] as String;
    final evidence = r['evidence'] is Map
        ? Map<String, dynamic>.from(r['evidence'] as Map)
        : const <String, dynamic>{};
    final open = r['status'] == 'pending' || r['status'] == 'reviewing';
    final room = [
      evidence['roomCode'],
      evidence['roomTitle'],
    ].whereType<String>().where((v) => v.isNotEmpty).join(' · ');
    final restrictions = (r['targetRestrictions'] as List? ?? const []).join(
      ', ',
    );
    return VaultCard(
      key: SafetyAdminScreen.report(id),
      children: [
        Text(
          '${_categoryLabel(r['category'] as String? ?? '')} · '
          '${_contextLabel(r['context'])}',
          style: context.typography.title.copyWith(
            color: VaultTokens.goldLight,
          ),
        ),
        SelectableText(
          l.adminSafetyTarget(
            evidence['targetName'] as String? ?? '—',
            (r['targetOpenReports'] as num?)?.toInt() ?? 0,
            (r['targetActioned'] as num?)?.toInt() ?? 0,
          ),
          style: context.typography.body.emphasised,
        ),
        if (room.isNotEmpty)
          SelectableText(room, style: context.typography.bodySmall),
        if (restrictions.isNotEmpty)
          Text(
            restrictions,
            style: context.typography.caption.copyWith(
              color: context.colors.accentCrimson,
            ),
          ),
        if ((r['details'] as String? ?? '').isNotEmpty)
          SelectableText(
            r['details'] as String,
            style: context.typography.body,
          ),
        Text(
          '${r['status']} · ${r['createdAt']}',
          style: context.typography.caption.copyWith(
            color: context.colors.textMuted,
          ),
        ),
        if ((r['note'] as String? ?? '').isNotEmpty)
          Text(r['note'] as String, style: context.typography.bodySmall),
        if (open) ...[
          SizedBox(height: s.sm),
          TextField(
            controller: _note(id),
            maxLength: 1000,
            decoration: InputDecoration(labelText: l.adminNote),
          ),
          Wrap(
            spacing: s.sm,
            runSpacing: s.xs,
            children: [
              for (final (action, days, label) in <(String, int?, String)>[
                ('dismiss', null, l.adminSafetyDismiss),
                ('warn', null, l.adminSafetyWarn),
                ('restrict_voice', 7, l.adminSafetyNoVoice),
                ('restrict_public', 7, l.adminSafetyNoPublic),
                ('suspend', 1, l.adminSafetySuspendDays(1)),
                ('suspend', 7, l.adminSafetySuspendDays(7)),
                ('suspend', 30, l.adminSafetySuspendDays(30)),
                ('suspend', null, l.adminSafetySuspendForever),
              ])
                OutlinedButton(
                  key: SafetyAdminScreen.action(id, '$action${days ?? ''}'),
                  style: vaultOutlineStyle(context),
                  onPressed: _busy
                      ? null
                      : () => _act({
                          'action': 'admin_resolve',
                          'reportId': id,
                          'decision': action,
                          'durationDays': days,
                          'note': _note(id).text.trim(),
                        }, '$id/$action/$days'),
                  child: Text(label),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
