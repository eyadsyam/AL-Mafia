import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../engine/models/enums.dart' show PlayerStatus, Role;
import '../../../../transport/game_snapshot.dart';
import '../../../../transport/witness_channel.dart';
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';
import '../council/card_rise.dart' show faceFor;
import '../../../widgets/hint_slot.dart';
import 'own_record.dart';

/// What an eliminated player has instead of nothing (doc 12 §4.1).
///
/// Three panels behind the table, never over it: doc 12 §4.1's first row is
/// *"spectate the table — full view of every phase, live"*, and a chat that
/// covered the game they are still watching would defeat the row above it. The
/// sheet is a third of the screen and the table keeps the rest.
class WitnessPanel extends ConsumerStatefulWidget {
  final GameSnapshot snapshot;

  /// The graveyard, or null when this transport has none — offline, where an
  /// eliminated player is still at the table and this panel never appears.
  final WitnessChannel? channel;

  /// The open table — every role and night choice — or null while it has not
  /// been read yet. Owned by the table flow, which polls it.
  final WitnessTable? table;

  static Key whisper(String id) => ValueKey('witness_whisper_$id');

  const WitnessPanel({
    super.key,
    required this.snapshot,
    this.channel,
    this.table,
  });

  static const Key tabs = ValueKey('witness_tabs');
  static const Key chatField = ValueKey('witness_chat_field');
  static const Key chatSend = ValueKey('witness_chat_send');

  @override
  ConsumerState<WitnessPanel> createState() => _WitnessPanelState();
}

class _WitnessPanelState extends ConsumerState<WitnessPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  final TextEditingController _draft = TextEditingController();
  final ScrollController _scroll = ScrollController();

  StreamSubscription<List<GhostMessage>>? _feed;
  List<GhostMessage> _messages = const [];

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final channel = widget.channel;
    if (channel == null) return;

    _feed = channel.messages().listen((messages) {
      if (!mounted) return;
      setState(() => _messages = messages);
      // Only ever scrolled after a rebuild, and only to the end: a graveyard
      // that jumps while somebody is reading back is worse than one that does
      // not follow.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    });
  }

  @override
  void dispose() {
    unawaited(_feed?.cancel());
    _tabs.dispose();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final channel = widget.channel;
    final body = _draft.text.trim();
    if (channel == null || body.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await channel.say(body);
      _draft.clear();
    } catch (_) {
      // A message that did not send stays in the field, which is the only
      // recovery anybody wants. No banner: this is a side conversation, and an
      // error toast over a live match is the modal doc 12 §5 forbids in a
      // different hat.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radii.dialog),
        border: Border.all(color: colors.borderSubtle),
      ),
      // Doc 15 §S-O14 put this inside the band system rather than over it, so
      // it takes the height band 4 gives it instead of naming one of its own.
      // The tabs and the walled-off line are fixed; the conversation is what
      // gives, which is the right thing to give — a shorter transcript is
      // still a transcript, and a clipped tab bar is a broken screen.
      child: Column(
        children: [
          // Doc 13 4.2's seventh trigger, and the only one that is online
          // only: offline an eliminated player is still sitting at the table,
          // so there is nothing to explain. Here the game carries on without
          // them and the panel is new, so it says once what it is.
          //
          // Reserved space above the tabs whether or not there is a line to
          // draw, for the same reason as everywhere else: the panel would
          // otherwise be one height on the first elimination of an install and
          // another on every elimination after it.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.sm),
            // Doc 14 Part 6: reserved, and empty inside a match.
            child: SizedBox(height: HintSlot.reservedHeight(context)),
          ),
          TabBar(
            key: WitnessPanel.tabs,
            controller: _tabs,
            labelColor: colors.accentGold,
            unselectedLabelColor: colors.textMuted,
            indicatorColor: colors.accentGold,
            labelStyle: type.caption,
            tabs: [
              Tab(text: l10n.witnessTabTable),
              Tab(text: l10n.witnessTabChat),
              Tab(text: l10n.witnessTabRecord),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_table(context), _chat(context), _record(context)],
            ),
          ),
        ],
      ),
    );
  }

  // ── the graveyard ────────────────────────────────────────────────────────

  Widget _chat(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final l10n = context.l10n;

    return Column(
      children: [
        // The wall, said where it applies: under the graveyard's own words.
        Padding(
          padding: EdgeInsets.only(top: spacing.xs),
          child: Text(
            l10n.witnessChatWalled,
            textAlign: TextAlign.center,
            style: type.caption.copyWith(color: colors.textMuted),
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    l10n.witnessChatEmpty,
                    style: type.caption.copyWith(color: colors.textMuted),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.symmetric(horizontal: spacing.md),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: spacing.xs / 2),
                      child: RichText(
                        text: TextSpan(
                          style: type.body.copyWith(color: colors.textPrimary),
                          children: [
                            TextSpan(
                              text: '${message.authorName}  ',
                              style: type.caption.copyWith(
                                color: message.mine
                                    ? colors.accentGold
                                    : colors.textSecondary,
                              ),
                            ),
                            TextSpan(text: message.body),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: WitnessPanel.chatField,
                  controller: _draft,
                  maxLength: 240,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: type.body.copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    counterText: '',
                    isDense: true,
                    hintText: l10n.witnessChatHint,
                    hintStyle: type.body.copyWith(color: colors.textMuted),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              TextButton(
                key: WitnessPanel.chatSend,
                onPressed: _sending ? null : _send,
                child: Text(
                  l10n.witnessChatSend,
                  style: type.caption.copyWith(color: colors.accentGold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Whispers reported from this panel, so the flag is not offered twice.
  final Set<String> _reported = {};

  // ── the open table ───────────────────────────────────────────────────────

  /// Every seat as its card, then every night choice, newest night first.
  /// Owner decision 2026-09-23 (doc 12 §4.1): the dead see the whole game.
  Widget _table(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final l10n = context.l10n;

    final table = widget.table;
    if (table == null) {
      return Center(
        child: Text(
          l10n.witnessTableLoading,
          style: type.caption.copyWith(color: colors.textMuted),
        ),
      );
    }

    final players = [...widget.snapshot.public.players]
      ..sort((a, b) => a.seat.compareTo(b.seat));
    final names = {for (final p in players) p.seat: p.name};
    final nights = {for (final a in table.actions) a.night}.toList()
      ..sort((a, b) => b.compareTo(a));

    String line(WitnessAction a) {
      final actor = names[a.seat] ?? '';
      final target = names[a.targetSeat] ?? '';
      return switch (a.action) {
        'kill' => l10n.witnessActionKill(actor, target),
        'protect' => l10n.witnessActionProtect(actor, target),
        'investigate' => l10n.witnessActionInvestigate(actor, target),
        _ => l10n.witnessActionSuspect(actor, target),
      };
    }

    return ListView(
      padding: EdgeInsets.all(spacing.md),
      children: [
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.xs,
          children: [
            for (final player in players)
              _CastChip(
                name: player.name,
                role: table.roles[player.seat],
                out: player.status != PlayerStatus.alive,
                isViewer: player.seat == widget.snapshot.viewerSeat,
              ),
          ],
        ),
        SizedBox(height: spacing.md),
        if (nights.isEmpty)
          Text(
            l10n.witnessTableNoActions,
            textAlign: TextAlign.center,
            style: type.caption.copyWith(color: colors.textMuted),
          ),
        for (final night in nights) ...[
          Padding(
            padding: EdgeInsets.only(bottom: spacing.xs),
            child: Text(
              l10n.nightNumbered(night),
              style: type.caption.copyWith(color: colors.accentGold),
            ),
          ),
          for (final action in table.actions.where((a) => a.night == night))
            Padding(
              padding: EdgeInsets.only(bottom: spacing.xs),
              child: Row(
                children: [
                  if (table.roles[action.seat] != null)
                    RoleFace(
                      role: table.roles[action.seat]!,
                      size: CouncilTokens.witnessActionThumb,
                    ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: Text(
                      line(action),
                      style: type.body.copyWith(color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
        // F21a: every delivered whisper, newest first. Text is plain Text, so
        // markup in a message renders as the characters it is.
        if (table.whispers.isNotEmpty) ...[
          SizedBox(height: spacing.md),
          Text(
            l10n.witnessWhispersTitle,
            style: type.caption.copyWith(color: colors.accentGold),
          ),
          SizedBox(height: spacing.xs),
          for (final w in table.whispers.reversed)
            Padding(
              key: WitnessPanel.whisper(w.id),
              padding: EdgeInsets.only(bottom: spacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.witnessWhisperLine(
                            names[w.fromSeat] ?? '',
                            names[w.toSeat] ?? '',
                          ),
                          style: type.caption.copyWith(color: colors.textMuted),
                        ),
                        Text(
                          w.masked ? l10n.witnessWhisperMasked : w.text ?? '',
                          style: type.body.copyWith(
                            color: w.masked
                                ? colors.textMuted
                                : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_reported.contains(w.id))
                    IconButton(
                      tooltip: l10n.witnessWhisperReport,
                      icon: const Icon(Icons.flag_outlined),
                      onPressed: () async {
                        final done =
                            await widget.channel?.reportWhisper(w.id) ?? false;
                        if (done && mounted) {
                          setState(() => _reported.add(w.id));
                        }
                      },
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  // ── the record ───────────────────────────────────────────────────────────

  Widget _record(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final l10n = context.l10n;

    final entries = ref.watch(ownRecordProvider);
    if (entries.isEmpty) {
      return Center(
        child: Text(
          l10n.witnessRecordEmpty,
          style: type.caption.copyWith(color: colors.textMuted),
        ),
      );
    }

    final names = {
      for (final player in widget.snapshot.public.players)
        player.seat: player.name,
    };

    return ListView.builder(
      padding: EdgeInsets.all(spacing.md),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final parts = <String>[
          if (entry.accused != null)
            '${l10n.openingRoundTitle}: ${names[entry.accused] ?? ''}',
          if (entry.whisperedTo != null)
            '${l10n.whisperLabel}: ${names[entry.whisperedTo] ?? ''}',
        ];
        return Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.xs / 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  l10n.dayNumbered(entry.day),
                  style: type.caption.copyWith(color: colors.textMuted),
                ),
              ),
              Expanded(
                child: Text(
                  parts.join('  ·  '),
                  // No tick, no cross, no colour. See [OwnRecord]'s comment:
                  // correctness marking here is a channel from the graveyard to
                  // itself that reveals a living player's role.
                  style: type.body.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One seat of the open table: the face, the name, the role.
class _CastChip extends StatelessWidget {
  final String name;
  final Role? role;
  final bool out;
  final bool isViewer;

  const _CastChip({
    required this.name,
    required this.role,
    required this.out,
    required this.isViewer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;
    final role = this.role;

    return Opacity(
      opacity: out ? CouncilTokens.witnessOutOpacity : 1,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          spacing.xs,
          spacing.xs,
          spacing.sm,
          spacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceOverlay,
          borderRadius: BorderRadius.circular(radii.button),
          border: Border.all(
            color: isViewer ? colors.accentGold : colors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (role != null)
              RoleFace(role: role, size: CouncilTokens.witnessChipFace),
            SizedBox(width: spacing.xs),
            Text(
              name,
              style: type.caption.copyWith(
                color: colors.textPrimary,
                decoration: out ? TextDecoration.lineThrough : null,
              ),
            ),
            if (role != null) ...[
              SizedBox(width: spacing.xs),
              Text(
                EngineCopy.roleName(context.l10n, role),
                style: type.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A character's face, lifted out of its card and set in a circle — the same
/// crop the council's seats use, so a face means the same thing everywhere.
class RoleFace extends StatelessWidget {
  final Role role;
  final double size;

  const RoleFace({super.key, required this.role, required this.size});

  /// The overflow alignment that puts the card's face (at
  /// [CouncilTokens.portraitFaceY] of its height) in the middle of the circle:
  /// with k = card height / circle, solve (1 − k)(a + 1)/2 + f·k = ½ for a.
  static const double _k =
      CouncilTokens.portraitZoom / CouncilTokens.cardArtAspect;
  static const double _faceAlignment =
      (1 - 2 * CouncilTokens.portraitFaceY * _k) / (1 - _k) - 1;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: OverflowBox(
          maxWidth: size * CouncilTokens.portraitZoom,
          maxHeight:
              size * CouncilTokens.portraitZoom / CouncilTokens.cardArtAspect,
          alignment: const Alignment(0, _faceAlignment),
          child: Image.asset(
            faceFor(role),
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
