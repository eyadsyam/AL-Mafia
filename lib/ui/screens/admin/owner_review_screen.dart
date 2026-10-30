import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transport/online_backend.dart';
import '../../economy/account_protection.dart';
import '../../economy/vault_kit.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../online/online_session.dart';

/// Read-only owner data. Every request is independently checked on the server.
class OwnerReviewScreen extends ConsumerStatefulWidget {
  const OwnerReviewScreen({super.key, this.onBack, this.web = kIsWeb});

  final VoidCallback? onBack;
  final bool web;

  static const guard = ValueKey('admin_review_guard');
  static Key tab(String action) => ValueKey('admin_review_tab_$action');
  static const search = ValueKey('admin_review_search');
  static const retry = ValueKey('admin_review_retry');

  @override
  ConsumerState<OwnerReviewScreen> createState() => _OwnerReviewScreenState();
}

class _OwnerReviewScreenState extends ConsumerState<OwnerReviewScreen> {
  static const _actions = [
    'overview',
    'players',
    'rooms',
    'store',
    'config',
    'push',
    'testers',
  ];
  String _action = 'overview';
  String _query = '';
  Map<String, dynamic>? _data;
  String? _error;
  bool? _admin;
  bool _loading = false;
  int _request = 0;

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      final answer = await backend.call('owner_review', {
        'action': _action,
        if (_action == 'players') 'query': _query,
      });
      if (!mounted || request != _request) return;
      setState(() {
        _admin = true;
        _data = answer;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        if (error is BackendException && error.code == 'NOT_ADMIN') {
          _admin = false;
          _data = null;
        }
        _error = error is BackendException && error.code == 'NOT_ADMIN'
            ? context.l10n.adminNotAdmin
            : context.l10n.adminReviewError;
        _loading = false;
      });
    }
  }

  void _select(String action) {
    if (action == _action) return;
    setState(() {
      _action = action;
      _data = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final signedIn =
        ref.watch(accountStatusProvider).valueOrNull?.recoverable == true;
    if (widget.web &&
        signedIn &&
        _admin == null &&
        !_loading &&
        _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _admin == null && !_loading && _error == null) _load();
      });
    }
    return MafiaScaffold(
      appBar: AppBar(
        title: Text(l.adminReviewTitle),
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        actions: [
          if (_admin == true)
            IconButton(
              onPressed: _loading ? null : _load,
              tooltip: MaterialLocalizations.of(
                context,
              ).refreshIndicatorSemanticLabel,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AdminTokens.contentWidth),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(s.md),
              children: [
                if (!widget.web)
                  Text(key: OwnerReviewScreen.guard, l.adminWebOnly)
                else if (!signedIn) ...[
                  Text(l.adminSignInHint, style: context.typography.body),
                  SizedBox(height: s.sm),
                  const AccountProtectionCard(),
                ] else if (_admin == false)
                  Text(key: OwnerReviewScreen.guard, l.adminNotAdmin)
                else ...[
                  Wrap(
                    spacing: AdminTokens.tabGap,
                    runSpacing: AdminTokens.tabGap,
                    children: [
                      for (final action in _actions)
                        ChoiceChip(
                          key: OwnerReviewScreen.tab(action),
                          label: Text(_tabLabel(action)),
                          selected: _action == action,
                          onSelected: (_) => _select(action),
                        ),
                    ],
                  ),
                  if (_action == 'players') ...[
                    SizedBox(height: s.md),
                    TextField(
                      key: OwnerReviewScreen.search,
                      maxLength: AdminTokens.searchMaxLength,
                      decoration: InputDecoration(
                        labelText: l.adminReviewSearch,
                      ),
                      onChanged: (value) {
                        _query = value;
                        _load();
                      },
                    ),
                  ],
                  SizedBox(height: s.md),
                  if (_loading)
                    const SizedBox(
                      height: AdminTokens.progressHeight,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null) ...[
                    Text(_error!, style: context.typography.body),
                    TextButton(
                      key: OwnerReviewScreen.retry,
                      onPressed: _load,
                      child: Text(l.adminReviewRetry),
                    ),
                  ] else if (_data != null)
                    ..._content(_data!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _tabLabel(String action) {
    final l = context.l10n;
    return switch (action) {
      'players' => l.adminReviewPlayers,
      'rooms' => l.adminReviewRooms,
      'store' => l.adminReviewStore,
      'config' => l.adminReviewConfig,
      'push' => l.adminReviewPush,
      'testers' => l.adminReviewTesters,
      _ => l.adminReviewOverview,
    };
  }

  List<Widget> _content(Map<String, dynamic> data) {
    final l = context.l10n;
    if (_action == 'overview') {
      final labels = <String, String>{
        'accountsTotal': l.adminReviewAccountsTotal,
        'accountsNew7d': l.adminReviewAccountsNew7d,
        'signedIn7d': l.adminReviewSignedIn7d,
        'roomsOpen': l.adminReviewRoomsOpen,
        'matches7d': l.adminReviewMatches7d,
        'matchesEver': l.adminReviewMatchesEver,
        'pushTokens': l.adminReviewPushTokens,
        'safetyOpen': l.adminReviewSafetyOpen,
      };
      final pending = data['pendingItems'];
      return [
        for (final entry in labels.entries)
          if (data.containsKey(entry.key))
            _tile(entry.value, '${data[entry.key]}'),
        if (pending is Map) ...[
          _tile(l.adminReviewPendingItems, ''),
          for (final entry in pending.entries)
            _tile('${entry.key}', '${entry.value}'),
        ],
        if (data.isEmpty) Text(l.adminReviewEmpty),
      ];
    }
    if (_action == 'config') {
      final app = data['app'];
      final economy = data['economy'];
      return [
        ..._configRows(l.adminReviewAppConfig, app),
        ..._configRows(l.adminReviewEconomyConfig, economy),
        if ((app is! Map || app.isEmpty) &&
            (economy is! Map || economy.isEmpty))
          Text(l.adminReviewEmpty),
      ];
    }
    final rows = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final grants = (data['grants'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    return [
      if (rows.isEmpty && grants.isEmpty) Text(l.adminReviewEmpty),
      for (final row in rows) _row(row),
      if (_action == 'store' && grants.isNotEmpty) ...[
        SizedBox(height: context.spacing.md),
        Text(l.adminReviewGrants, style: context.typography.body),
        for (final grant in grants)
          _tile(
            '${grant['displayName'] ?? ''}',
            '${l.adminReviewSince}: ${grant['since'] ?? ''}',
          ),
      ],
    ];
  }

  List<Widget> _configRows(String heading, Object? value) {
    if (value is! Map || value.isEmpty) return [];
    return [
      Text(heading, style: context.typography.body),
      for (final entry in value.entries)
        _tile('${entry.key}', '${entry.value}'),
    ];
  }

  Widget _row(Map<String, dynamic> row) {
    final l = context.l10n;
    String field(String key) => '${row[key] ?? ''}';
    switch (_action) {
      case 'players':
        return _tile(
          field('displayName'),
          '${l.adminReviewCreated}: ${field('createdAt')} · ${l.adminReviewLastSignIn}: ${field('lastSignIn')} · ${l.adminReviewLevel}: ${field('level')}${row['allAccess'] == true ? ' · ${l.adminReviewAllAccess}' : ''}',
        );
      case 'rooms':
        return _tile(
          field('code'),
          '${l.adminReviewStatus}: ${field('status')} · ${l.adminReviewPhase}: ${field('phase')} · ${l.adminReviewPlayerCount}: ${field('playerCount')} · ${l.adminReviewHost}: ${field('hostName')} · ${l.adminReviewCreated}: ${field('createdAt')}',
        );
      case 'store':
        return _tile(
          field('code'),
          '${l.adminReviewKind}: ${field('kind')} · ${l.adminReviewPrice}: ${field('coinPrice')} · ${l.adminReviewActive}: ${row['active'] == true ? l.adminReviewYes : l.adminReviewNo} · ${l.adminReviewOwners}: ${field('owners')}',
        );
      case 'push':
        return _tile(
          field('kind'),
          '${l.adminReviewStatus}: ${field('status')} · ${l.adminReviewCount}: ${field('count')}',
        );
      default:
        return _tile(
          field('name'),
          '${l.adminReviewStatus}: ${field('status')} · ${l.adminReviewCreated}: ${field('createdAt')}',
        );
    }
  }

  Widget _tile(String title, String detail) => Padding(
    padding: const EdgeInsets.only(bottom: AdminTokens.rowGap),
    child: ListTile(
      dense: true,
      title: Text(title, style: context.typography.body),
      subtitle: detail.isEmpty
          ? null
          : Text(detail, style: context.typography.bodySmall),
    ),
  );
}
