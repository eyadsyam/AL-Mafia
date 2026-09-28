import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/request_id.dart';
import '../../../data/terms_consent.dart';
import '../../../transport/online_backend.dart';
import '../../economy/economy_capabilities.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/settings_kit.dart';
import 'online_session.dart';

const communityRulesKey = 'community_rules_2026_09';

Future<bool> _confirm(
  BuildContext context,
  String title,
  String body,
  String action,
) {
  final answer = Completer<bool>();
  late final OverlayEntry entry;
  void finish(bool value) {
    if (answer.isCompleted) return;
    entry.remove();
    entry.dispose();
    answer.complete(value);
  }

  entry = OverlayEntry(
    builder: (context) => Material(
      color: context.colors.surfaceOverlay,
      child: SafeArea(
        child: Center(
          child: AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(body)),
            actions: [
              TextButton(
                onPressed: () => finish(false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(onPressed: () => finish(true), child: Text(action)),
            ],
          ),
        ),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  return answer.future;
}

/// The community rules are part of the terms accepted during setup, so a
/// player with a current acceptance is never asked a second time before a
/// room. The dialog remains only for a state setup should have prevented.
Future<bool> acceptCommunityRules(BuildContext context) async {
  final terms = await TermsStore().load();
  if (terms?.current == true) return true;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(communityRulesKey) == true) return true;
  if (!context.mounted) return false;
  final accepted = await _confirm(
    context,
    context.l10n.safetyConsentTitle,
    context.l10n.safetyConsentBody,
    context.l10n.safetyAgree,
  );
  if (accepted != true) return false;
  await prefs.setBool(communityRulesKey, true);
  return true;
}

class SafetyButton extends StatefulWidget {
  final bool privacy;
  const SafetyButton({super.key, this.privacy = false});
  @override
  State<SafetyButton> createState() => _SafetyButtonState();
}

class _SafetyButtonState extends State<SafetyButton> {
  final _overlay = OverlayPortalController();
  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _overlay,
    overlayChildBuilder: (_) => Positioned.fill(
      child: SafetyCenter(onClose: _overlay.hide, privacy: widget.privacy),
    ),
    child: widget.privacy
        ? SettingsLinkRow(
            icon: Icons.privacy_tip_outlined,
            label: context.l10n.safetyTitle,
            onTap: _overlay.show,
          )
        : IconButton(
            tooltip: context.l10n.safetyTools,
            icon: const Icon(Icons.flag_outlined),
            onPressed: _overlay.show,
          ),
  );
}

class SafetyCenter extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final bool privacy;
  const SafetyCenter({super.key, this.onClose, this.privacy = false});
  static Key category(String name) => ValueKey('safety_category_$name');
  @override
  ConsumerState<SafetyCenter> createState() => _SafetyCenterState();
}

/// F11 report categories, in the order the form lists them.
const safetyCategories = [
  'harassment',
  'hate',
  'sexual',
  'threat',
  'spam',
  'cheating',
  'inappropriate_name',
  'other',
];

/// The body of one report or block. A v11 report names a seat and a category,
/// says where it was made, and carries a request id (retries reuse it);
/// otherwise it is the original room report.
Map<String, Object?> safetyReportBody({
  required String action,
  required bool v11,
  required String? roomId,
  required String? roomStatus,
  required int? seat,
  required String? category,
  required String details,
  required String Function() requestId,
}) {
  if (action == 'report' && v11 && seat != null && category != null) {
    return {
      'action': 'report_v11',
      'context': switch (roomStatus) {
        'playing' => 'match',
        'finished' => 'result',
        _ => 'lobby',
      },
      'roomId': roomId,
      'seat': seat,
      'category': category,
      'details': details,
      'requestId': requestId(),
    };
  }
  return {
    'action': action,
    'roomId': roomId,
    'seat': seat,
    'reason': 'other',
    'details': details,
  };
}

class _SafetyCenterState extends ConsumerState<SafetyCenter> {
  final _details = TextEditingController();
  int? _seat;
  String? _category;
  bool _busy = false;
  String? _message;

  /// One per intended report: a retry after a lost answer reuses it, so the
  /// server files the report once. Editing the report starts a new one.
  String? _requestId;
  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send(String action) async {
    if (_busy) return;
    final l = context.l10n;
    if (action == 'delete') {
      final yes = await _confirm(
        context,
        l.safetyDelete,
        l.safetyDeleteConfirm,
        l.safetyDelete,
      );
      if (yes != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final session = ref.read(onlineSessionProvider);
      final backend =
          session.transport?.backend ??
          await ref.read(onlineBackendFactoryProvider)();
      final id = await backend.ensureSession();
      if (action == 'identity') {
        if (mounted) setState(() => _message = id);
      } else {
        final body = safetyReportBody(
          action: action,
          v11: action == 'report' && _v11,
          roomId: session.room?.roomId,
          roomStatus: session.transport?.roomStatus,
          seat: _seat,
          category: _category,
          details: _details.text.trim(),
          requestId: () => _requestId ??= newRequestId(),
        );
        final result = await backend.call('player_safety', body);
        if (action == 'block') await session.transport?.refreshBlocks();
        _requestId = null;
        if (mounted)
          setState(
            () => _message = action == 'block'
                ? l.safetyBlocked
                : '${l.safetyReceipt} ${result['receipt']}',
          );
      }
    } on BackendException catch (e) {
      if (mounted) {
        setState(
          () => _message = e.code == 'RATE_LIMITED'
              ? l.safetyLimited
              : l.safetyFailed,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _message = l.safetyFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _v11 =>
      ref.read(economyCapabilitiesProvider).valueOrNull?.safetyV11 ?? false;

  /// A different report is a different request.
  void _edit(VoidCallback change) => setState(() {
    change();
    _requestId = null;
  });

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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final spacing = context.spacing;
    final transport = ref.watch(onlineSessionProvider).transport;
    // Asked only where a report can be made: a room is open.
    final v11 =
        !widget.privacy &&
        transport != null &&
        (ref.watch(economyCapabilitiesProvider).valueOrNull?.safetyV11 ??
            false);
    final players = transport?.safetyPlayers ?? const <RoomPlayer>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.privacy ? l.safetyTitle : l.safetyTools),
        leading: widget.onClose == null
            ? null
            : IconButton(
                onPressed: widget.onClose,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
              ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
          child: ListView(
            padding: EdgeInsets.all(spacing.screenMargin),
            children: [
              if (widget.privacy)
                SelectableText(l.safetyPolicy, style: context.typography.body),
              SizedBox(height: spacing.lg),
              if (!widget.privacy && transport != null) ...[
                DropdownButtonFormField<int>(
                  initialValue: _seat,
                  hint: Text(l.safetyRoom),
                  isExpanded: true,
                  items: [
                    for (final player in players)
                      DropdownMenuItem(
                        value: player.seat,
                        child: Text(
                          player.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy ? null : (seat) => _edit(() => _seat = seat),
                ),
                if (v11 && _seat != null) ...[
                  SizedBox(height: spacing.sm),
                  Text(l.safetyCategory, style: context.typography.bodySmall),
                  Wrap(
                    spacing: spacing.xs,
                    runSpacing: spacing.xs,
                    children: [
                      for (final name in safetyCategories)
                        ChoiceChip(
                          key: SafetyCenter.category(name),
                          label: Text(_categoryLabel(name)),
                          selected: _category == name,
                          onSelected: _busy
                              ? null
                              : (_) => _edit(() => _category = name),
                        ),
                    ],
                  ),
                ],
                TextField(
                  controller: _details,
                  onChanged: (_) => _requestId = null,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l.safetyDetails),
                ),
                FilledButton(
                  onPressed:
                      _busy || (v11 && _seat != null && _category == null)
                      ? null
                      : () => _send('report'),
                  child: Text(l.safetyReport),
                ),
                OutlinedButton(
                  onPressed: _busy || _seat == null
                      ? null
                      : () => _send('block'),
                  child: Text(l.safetyBlock),
                ),
              ] else if (!widget.privacy)
                Text(l.safetyNoRoom),
              if (widget.privacy) ...[
                OutlinedButton(
                  onPressed: _busy ? null : () => _send('identity'),
                  child: Text(l.safetyIdentity),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _send('delete'),
                  child: Text(l.safetyDelete),
                ),
              ],
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (_message != null)
                SelectableText(_message!, style: context.typography.body),
            ],
          ),
        ),
      ),
    );
  }
}
