import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/request_id.dart';
import '../../transport/online_backend.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../screens/match_controller.dart' show gameTransportProvider;
import '../../engine/models/enums.dart' show DiscussionMode;
import '../theme/mafia_theme.dart';
import 'table_tool_names.g.dart';
import 'wallet.dart';

/// «أدوات القعدة» (docs/plans/STORE-ROLES-STORIES-PLAN.md, v3): consumable
/// tools bought in charges and spent inside an online match. The server owns
/// the catalogue, the prices, the charges and every limit; this file only
/// shows them and forwards a tap.

enum ToolTier { light, medium, heavy }

class TableTool {
  final String code;
  final ToolTier tier;
  final Map<int, int> packs;
  final int perMatch;
  final String phase;
  final int targets;
  final int charges;

  const TableTool({
    required this.code,
    required this.tier,
    required this.packs,
    required this.perMatch,
    required this.phase,
    required this.targets,
    required this.charges,
  });

  bool get takesNote => code == 'anon_note' || code == 'last_will';
  bool get takesFace => code == 'impersonate';

  static TableTool? fromJson(Map<String, dynamic> j) {
    final tier = switch (j['tier']) {
      'light' => ToolTier.light,
      'medium' => ToolTier.medium,
      'heavy' => ToolTier.heavy,
      _ => null,
    };
    final packs = j['packs'];
    if (tier == null || packs is! Map || j['code'] is! String) return null;
    return TableTool(
      code: j['code'] as String,
      tier: tier,
      packs: {
        for (final e in packs.entries)
          if (int.tryParse('${e.key}') case final n?)
            if (e.value is num) n: (e.value as num).toInt(),
      },
      perMatch: (j['perMatch'] as num?)?.toInt() ?? 1,
      phase: j['phase'] as String? ?? 'discuss',
      targets: (j['targets'] as num?)?.toInt() ?? 0,
      charges: (j['charges'] as num?)?.toInt() ?? 0,
    );
  }

  /// [fromJson] for one row of a list: a row that cannot be read is skipped,
  /// never allowed to blank the whole shelf.
  static TableTool? tryParse(Object? row) {
    if (row is! Map) return null;
    try {
      return fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }
}

class TableToolsState {
  final List<TableTool> tools;
  final int balance;
  const TableToolsState({required this.tools, required this.balance});

  factory TableToolsState.fromJson(Map<String, dynamic> j) => TableToolsState(
    tools: [
      for (final t in (j['tools'] as List? ?? const []))
        if (TableTool.tryParse(t) case final tool?) tool,
    ],
    balance: (j['balance'] as num?)?.toInt() ?? 0,
  );

  List<TableTool> owned() => [
    for (final t in tools)
      if (t.charges > 0) t,
  ];
}

/// Thrown by tool actions with the server's refusal code.
class ToolActionFailed implements Exception {
  final String? code;
  const ToolActionFailed(this.code);
}

final tableToolsProvider =
    AsyncNotifierProvider<TableToolsController, TableToolsState>(
      TableToolsController.new,
    );

class TableToolsController extends AsyncNotifier<TableToolsState> {
  @override
  Future<TableToolsState> build() async =>
      TableToolsState.fromJson(await _call({'action': 'toolsGet'}));

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('economy', body);
  }

  /// Buys [pack] charges of [code]. [requestId] is the attempt's idempotency
  /// key: pass the same one when retrying an attempt whose answer was lost, so
  /// the server applies it once; a fresh key is minted when none is given.
  Future<void> buy(String code, int pack, {String? requestId}) async {
    try {
      state = AsyncData(
        TableToolsState.fromJson(
          await _call({
            'action': 'toolBuy',
            'tool': code,
            'pack': pack,
            'requestId': requestId ?? newRequestId(),
          }),
        ),
      );
    } on BackendException catch (e) {
      await _reconcile();
      throw ToolActionFailed(e.code);
    } catch (_) {
      // The server may have applied the purchase before the answer was lost.
      // Show its truth, not the shelf from before, so a retry is not blind.
      await _reconcile();
      throw const ToolActionFailed(null);
    }
    try {
      await ref.read(walletProvider.notifier).settle();
    } catch (_) {}
  }

  /// Best effort: re-reads the shelf and the wallet, keeping what is shown if
  /// the server still cannot be reached.
  Future<void> _reconcile() async {
    try {
      state = AsyncData(
        TableToolsState.fromJson(await _call({'action': 'toolsGet'})),
      );
    } catch (_) {}
    try {
      await ref.read(walletProvider.notifier).settle();
    } catch (_) {}
  }

  /// A shelf that failed to load stays failed for as long as the provider
  /// lives; opening the store or the tools sheet calls this to try again.
  void retryIfFailed() {
    if (state.hasError) ref.invalidateSelf();
  }

  /// Spends one charge in [roomId]. The effect is applied by the match
  /// functions from the server's record of the use. Returns the narrator's
  /// private answer for the two whisper tools, null otherwise.
  Future<bool?> use(
    String roomId,
    String code, {
    List<int> targets = const [],
    String? note,
  }) async {
    final phaseNumber = code == 'sense' || code == 'narrator_whisper'
        ? ref.read(gameTransportProvider).snapshot.dayNumber
        : null;
    try {
      final res = await _call({
        'action': 'toolUse',
        'roomId': roomId,
        'tool': code,
        'targets': targets,
        'note': ?note,
      });
      ref.invalidateSelf();
      return res['answer'] as bool?;
    } on BackendException catch (e) {
      unawaited(_reconcile());
      throw ToolActionFailed(e.code);
    } catch (_) {
      // The use may have been recorded before the answer was lost.
      unawaited(_reconcile());
      final kept = code == 'sense' || code == 'narrator_whisper'
          ? await _keptAnswer(roomId, code, phaseNumber!, targets)
          : null;
      if (kept != null) return kept;
      throw const ToolActionFailed(null);
    }
  }

  /// The narrator's answer the server kept for this caller's latest [code]
  /// use in [roomId] (only the two whisper tools have one), or null.
  Future<bool?> _keptAnswer(
    String roomId, String code, int phaseNumber, List<int> targets,
  ) async {
    try {
      final res = await _call({'action': 'toolAnswers', 'roomId': roomId});
      final rows = res['answers'];
      if (rows is! List) return null;
      for (final row in rows.reversed) {
        if (row is Map &&
            recoveredToolAnswerMatches(row, code, phaseNumber, targets) &&
            row['answer'] is bool) {
          return row['answer'] as bool;
        }
      }
    } catch (_) {
      // Still unreachable: the use stays unconfirmed.
    }
    return null;
  }
}

bool recoveredToolAnswerMatches(
  Map row, String code, int phaseNumber, List<int> targets, {String? requestId}
) {
  final savedTargets = row['targets'];
  if (row['tool'] != code || row['phaseNumber'] != phaseNumber ||
      savedTargets is! List ||
      (requestId != null && row['requestId'] != requestId)) {
    return false;
  }
  final requested = [...targets]..sort();
  final saved = [for (final target in savedTargets) if (target is int) target]..sort();
  return saved.length == savedTargets.length &&
      saved.length == requested.length &&
      List.generate(saved.length, (i) => saved[i] == requested[i]).every((same) => same);
}

String toolTierLabel(BuildContext context, ToolTier tier) {
  final l = context.l10n;
  return switch (tier) {
    ToolTier.light => l.toolTierLight,
    ToolTier.medium => l.toolTierMedium,
    ToolTier.heavy => l.toolTierHeavy,
  };
}

/// The tool's engraved icon (assets/images/tools/tool_<code>.webp); nothing
/// when a tool has no art yet.
class ToolIcon extends StatelessWidget {
  final String code;
  final double size;
  const ToolIcon({super.key, required this.code, required this.size});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/tools/tool_$code.webp',
    width: size,
    height: size,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
  );
}

/// The tools a player holds, opened from the online table. [seats] are the
/// living seats other than the player's own, with their names, for tools that
/// take targets. [phase] is the room's current phase; [alive] the player's.
Future<void> showTableToolsSheet(
  BuildContext context, {
  required String roomId,
  required String phase,
  required bool alive,
  required bool freeTalk,
  required Map<int, String> seats,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _ToolsSheet(roomId: roomId, phase: phase, alive: alive,
            freeTalk: freeTalk, seats: seats),
  );
}

bool _toolFits(TableTool t, String phase, bool alive, bool freeTalk) {
  if (freeTalk && const {'extra_minute', 'objection'}.contains(t.code)) return false;
  if (t.phase == 'dead') return !alive;
  if (!alive) return false;
  return switch (t.phase) {
    'night' => phase == 'night',
    'vote' => const {'vote', 'discuss', 'defense'}.contains(phase),
    _ => const {
      'discuss',
      'opening',
      'confront',
      'defense',
      'morning',
    }.contains(phase),
  };
}

class _ToolsSheet extends ConsumerStatefulWidget {
  final String roomId;
  final String phase;
  final bool alive;
  final bool freeTalk;
  final Map<int, String> seats;

  const _ToolsSheet({
    required this.roomId,
    required this.phase,
    required this.alive,
    required this.freeTalk,
    required this.seats,
  });

  @override
  ConsumerState<_ToolsSheet> createState() => _ToolsSheetState();
}

class _ToolsSheetState extends ConsumerState<_ToolsSheet> {
  TableTool? _picked;
  final Set<int> _targets = {};
  final _note = TextEditingController();
  String? _face;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(tableToolsProvider.notifier).retryIfFailed();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _complete {
    final t = _picked;
    if (t == null) return false;
    if (_targets.length != t.targets) return false;
    if (t.takesNote && _note.text.trim().isEmpty) return false;
    if (t.takesFace && _face == null) return false;
    return true;
  }

  Future<void> _use() async {
    final t = _picked!;
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final answer = await ref
          .read(tableToolsProvider.notifier)
          .use(
            widget.roomId,
            t.code,
            targets: _targets.toList()..sort(),
            note: t.takesNote ? _note.text.trim() : _face,
          );
      if (!mounted) return;
      if (answer != null) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            content: Text(answer ? l.toolAnswerYes : l.toolAnswerNo),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(),
                child: Text(l.toolAnswerOk),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      // Any failure, not only the server's refusal: a sheet left busy with a
      // dead button is worse than a message.
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(switch (error) {
        ToolActionFailed(code: 'NOT_THIS_ROOM') => l.toolNeedsTurns,
        ToolActionFailed(code: 'SILENCED') => l.toolSilencedToday,
        _ => l.toolRefused,
      })));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    final data = ref.watch(tableToolsProvider).valueOrNull;
    final usable = [
      for (final t in data?.owned() ?? const <TableTool>[])
        if (_toolFits(t, widget.phase, widget.alive, widget.freeTalk)) t,
    ];
    final picked = _picked;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          s.screenMargin,
          0,
          s.screenMargin,
          s.screenMargin + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.toolsInMatch, style: type.title),
              SizedBox(height: s.sm),
              if (data == null)
                const Center(child: CircularProgressIndicator())
              else if (usable.isEmpty)
                Text(
                  l.toolNoneOwned,
                  style: type.body.copyWith(color: colors.textMuted),
                )
              else
                Wrap(
                  spacing: s.sm,
                  runSpacing: s.sm,
                  children: [
                    for (final t in usable)
                      ChoiceChip(
                        avatar: ToolIcon(code: t.code, size: s.lg),
                        label: Text(
                          '${tableToolCopy(l, t.code)?.$1 ?? t.code} · ${t.charges}',
                        ),
                        selected: picked?.code == t.code,
                        onSelected: (_) => setState(() {
                          _picked = t;
                          _targets.clear();
                          _face = null;
                        }),
                      ),
                  ],
                ),
              if (picked != null) ...[
                SizedBox(height: s.md),
                Text(
                  tableToolCopy(l, picked.code)?.$2 ?? '',
                  style: type.body.copyWith(color: colors.textMuted),
                ),
                if (picked.targets > 0) ...[
                  SizedBox(height: s.sm),
                  Text(l.toolPickTargets(picked.targets), style: type.caption),
                  Wrap(
                    spacing: s.sm,
                    runSpacing: s.sm,
                    children: [
                      for (final e in widget.seats.entries)
                        FilterChip(
                          label: Text(e.value),
                          selected: _targets.contains(e.key),
                          onSelected: (on) => setState(() {
                            if (!on) {
                              _targets.remove(e.key);
                            } else if (_targets.length < picked.targets) {
                              _targets.add(e.key);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                if (picked.takesNote) ...[
                  SizedBox(height: s.sm),
                  TextField(
                    controller: _note,
                    maxLength: 140,
                    autofocus: true,
                    decoration: InputDecoration(hintText: l.toolNoteHint),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                if (picked.takesFace) ...[
                  SizedBox(height: s.sm),
                  SegmentedButton<String>(
                    emptySelectionAllowed: true,
                    segments: [
                      ButtonSegment(
                        value: 'citizen',
                        label: Text(l.toolImpersonateCitizen),
                      ),
                      ButtonSegment(
                        value: 'mafia',
                        label: Text(l.toolImpersonateMafia),
                      ),
                    ],
                    selected: {?_face},
                    onSelectionChanged: (v) =>
                        setState(() => _face = v.firstOrNull),
                  ),
                ],
                SizedBox(height: s.md),
                FilledButton(
                  onPressed: _complete && !_busy ? _use : null,
                  child: Text(l.toolUse),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The match header's «أدواتك» control. Shown only in an online room (the
/// one place a [roomId] exists); it opens [showTableToolsSheet].
class TableToolsButton extends ConsumerWidget {
  final String roomId;
  final String phase;
  final bool alive;
  final Map<int, String> seats;

  const TableToolsButton({
    super.key,
    required this.roomId,
    required this.phase,
    required this.alive,
    required this.seats,
  });

  static const buttonKey = ValueKey('table_tools_button');

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: buttonKey,
    tooltip: context.l10n.toolsInMatch,
    icon: const Icon(Icons.construction_rounded),
    onPressed: () => showTableToolsSheet(
      context,
      roomId: roomId,
      phase: phase,
      alive: alive,
      freeTalk: ref.read(gameTransportProvider).snapshot.settings.discussionMode ==
          DiscussionMode.free,
      seats: seats,
    ),
  );
}

/// The server's phase name for an engine [phaseName] (`GamePhase.name`).
String serverPhaseOf(String phaseName) => switch (phaseName) {
  'night' || 'nightResolving' => 'night',
  'morning' => 'morning',
  'openingRound' => 'opening',
  'confrontation' => 'confront',
  'voting' || 'voteResolving' => 'vote',
  _ => 'discuss',
};
