import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/online_backend.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/mafia_theme.dart';
import 'mafia_coin.dart';
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
          if (int.tryParse('${e.key}') case final n?) n: (e.value as num).toInt(),
      },
      perMatch: (j['perMatch'] as num?)?.toInt() ?? 1,
      phase: j['phase'] as String? ?? 'discuss',
      targets: (j['targets'] as num?)?.toInt() ?? 0,
      charges: (j['charges'] as num?)?.toInt() ?? 0,
    );
  }
}

class TableToolsState {
  final List<TableTool> tools;
  final int balance;
  const TableToolsState({required this.tools, required this.balance});

  factory TableToolsState.fromJson(Map<String, dynamic> j) => TableToolsState(
    tools: [
      for (final t in (j['tools'] as List? ?? const []))
        if (t is Map<String, dynamic>)
          if (TableTool.fromJson(t) case final tool?) tool,
    ],
    balance: (j['balance'] as num?)?.toInt() ?? 0,
  );

  List<TableTool> owned() => [for (final t in tools) if (t.charges > 0) t];
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

  Future<void> buy(String code, int pack) async {
    try {
      state = AsyncData(
        TableToolsState.fromJson(
          await _call({'action': 'toolBuy', 'tool': code, 'pack': pack}),
        ),
      );
      await ref.read(walletProvider.notifier).settle();
    } on BackendException catch (e) {
      throw ToolActionFailed(e.code);
    }
  }

  /// Spends one charge in [roomId]. The effect is applied by the match
  /// functions from the server's record of the use.
  Future<void> use(
    String roomId,
    String code, {
    List<int> targets = const [],
    String? note,
  }) async {
    try {
      await _call({
        'action': 'toolUse',
        'roomId': roomId,
        'tool': code,
        'targets': targets,
        'note': ?note,
      });
      ref.invalidateSelf();
    } on BackendException catch (e) {
      throw ToolActionFailed(e.code);
    }
  }
}

String toolTierLabel(BuildContext context, ToolTier tier) {
  final l = context.l10n;
  return switch (tier) {
    ToolTier.light => l.toolTierLight,
    ToolTier.medium => l.toolTierMedium,
    ToolTier.heavy => l.toolTierHeavy,
  };
}

/// The store's «الأدوات» tab: every tool grouped by tier, with its packs.
class TableToolsShopTab extends ConsumerStatefulWidget {
  const TableToolsShopTab({super.key});

  static const buyKeyPrefix = 'tool_buy_';

  @override
  ConsumerState<TableToolsShopTab> createState() => _TableToolsShopTabState();
}

class _TableToolsShopTabState extends ConsumerState<TableToolsShopTab> {
  String? _busy;

  Future<void> _buy(TableTool tool, int pack) async {
    final l = context.l10n;
    setState(() => _busy = '${tool.code}:$pack');
    try {
      await ref.read(tableToolsProvider.notifier).buy(tool.code, pack);
    } on ToolActionFailed catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'INSUFFICIENT_COINS' ? l.toolNotEnough : l.toolBuyFailed,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    final state = ref.watch(tableToolsProvider);
    final data = state.valueOrNull;
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: EdgeInsets.all(s.screenMargin),
      children: [
        Text(
          l.toolsIntro,
          style: type.body.copyWith(color: colors.textMuted),
        ),
        for (final tier in ToolTier.values) ...[
          SizedBox(height: s.lg),
          Text(
            toolTierLabel(context, tier),
            style: type.title.copyWith(color: colors.accentGold),
          ),
          SizedBox(height: s.sm),
          for (final tool in data.tools.where((t) => t.tier == tier))
            _ToolCard(
              tool: tool,
              busy: _busy,
              balance: data.balance,
              onBuy: (pack) => _buy(tool, pack),
            ),
        ],
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  final TableTool tool;
  final String? busy;
  final int balance;
  final ValueChanged<int> onBuy;

  const _ToolCard({
    required this.tool,
    required this.busy,
    required this.balance,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    final copy = tableToolCopy(l, tool.code);
    if (copy == null) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.only(bottom: s.sm),
      child: Padding(
        padding: EdgeInsets.all(s.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    copy.$1,
                    style: type.title.copyWith(color: colors.textPrimary),
                  ),
                ),
                if (tool.charges > 0)
                  Text(
                    l.toolCharges(tool.charges),
                    style: type.caption.copyWith(color: colors.accentGold),
                  ),
              ],
            ),
            SizedBox(height: s.xs),
            Text(
              copy.$2,
              style: type.body.copyWith(color: colors.textMuted),
            ),
            SizedBox(height: s.sm),
            Wrap(
              spacing: s.sm,
              runSpacing: s.sm,
              children: [
                for (final pack in (tool.packs.keys.toList()..sort()))
                  OutlinedButton.icon(
                    key: ValueKey(
                      '${TableToolsShopTab.buyKeyPrefix}${tool.code}_$pack',
                    ),
                    onPressed: busy != null || balance < tool.packs[pack]!
                        ? null
                        : () => onBuy(pack),
                    icon: const MafiaCoin(),
                    label: Text(l.toolPack(pack, tool.packs[pack]!)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The tools a player holds, opened from the online table. [seats] are the
/// living seats other than the player's own, with their names, for tools that
/// take targets. [phase] is the room's current phase; [alive] the player's.
Future<void> showTableToolsSheet(
  BuildContext context, {
  required String roomId,
  required String phase,
  required bool alive,
  required Map<int, String> seats,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ToolsSheet(
      roomId: roomId,
      phase: phase,
      alive: alive,
      seats: seats,
    ),
  );
}

bool _toolFits(TableTool t, String phase, bool alive) {
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
  final Map<int, String> seats;

  const _ToolsSheet({
    required this.roomId,
    required this.phase,
    required this.alive,
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
      await ref
          .read(tableToolsProvider.notifier)
          .use(
            widget.roomId,
            t.code,
            targets: _targets.toList()..sort(),
            note: t.takesNote ? _note.text.trim() : _face,
          );
      if (mounted) Navigator.of(context).pop();
    } on ToolActionFailed {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.toolRefused)));
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
        if (_toolFits(t, widget.phase, widget.alive)) t,
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
class TableToolsButton extends StatelessWidget {
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
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: context.l10n.toolsInMatch,
    icon: const Icon(Icons.construction_rounded),
    onPressed: () => showTableToolsSheet(
      context,
      roomId: roomId,
      phase: phase,
      alive: alive,
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
