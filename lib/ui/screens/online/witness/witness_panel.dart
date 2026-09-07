import 'dart:async';

// `Alignment` here is the engine's win side, not Flutter's layout anchor.
// Hidden rather than prefixed: nothing in this file positions anything.
import 'package:flutter/material.dart' hide Alignment;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../engine/models/enums.dart'
    show Alignment, PlayerStatus, RoleX;
import '../../../../transport/game_snapshot.dart';
import '../../../../transport/online_backend.dart' show Prediction;
import '../../../../transport/witness_channel.dart';
import '../../../l10n_ext.dart';
import '../../../theme/mafia_theme.dart';
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

  const WitnessPanel({super.key, required this.snapshot, this.channel});

  static const Key tabs = ValueKey('witness_tabs');
  static const Key chatField = ValueKey('witness_chat_field');
  static const Key chatSend = ValueKey('witness_chat_send');
  static const Key predictionLock = ValueKey('witness_prediction_lock');

  static Key predictionSeat(int seat) => ValueKey('witness_predict_seat_$seat');

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

  Prediction? _locked;
  Alignment _winner = Alignment.town;
  final Set<int> _named = <int>{};
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

    unawaited(
      channel.myPrediction().then((prediction) {
        if (mounted && prediction != null) {
          setState(() => _locked = prediction);
        }
      }),
    );
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

  Future<void> _lock() async {
    final channel = widget.channel;
    if (channel == null) return;
    final prediction = Prediction(winner: _winner, mafiaSeats: {..._named});
    final accepted = await channel.predict(prediction);
    if (!mounted) return;
    // False means one was already lodged, which is the same end state as
    // success from this screen's point of view: it is locked either way.
    setState(() => _locked = accepted ? prediction : _locked ?? prediction);
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(radii.dialog)),
        border: Border(top: BorderSide(color: colors.borderSubtle)),
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
              Tab(text: l10n.witnessTabChat),
              Tab(text: l10n.witnessTabPrediction),
              Tab(text: l10n.witnessTabRecord),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _chat(context),
                _prediction(context),
                _record(context),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.xs),
            child: Text(
              l10n.witnessChatWalled,
              textAlign: TextAlign.center,
              style: type.caption.copyWith(color: colors.textMuted),
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

  // ── the call ─────────────────────────────────────────────────────────────

  Widget _prediction(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final l10n = context.l10n;

    final locked = _locked;
    if (locked != null) {
      return _lockedPrediction(context, locked);
    }

    final living = [
      for (final player in widget.snapshot.public.players)
        if (player.status == PlayerStatus.alive) player,
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.witnessPredictionWinner,
            style: type.caption.copyWith(color: colors.textMuted),
          ),
          SizedBox(height: spacing.xs),
          SegmentedButton<Alignment>(
            segments: [
              ButtonSegment(value: Alignment.town, label: Text(l10n.townWins)),
              ButtonSegment(
                value: Alignment.mafia,
                label: Text(l10n.mafiaWins),
              ),
            ],
            selected: {_winner},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                setState(() => _winner = value.first),
          ),
          SizedBox(height: spacing.md),
          Text(
            l10n.witnessPredictionMafia,
            style: type.caption.copyWith(color: colors.textMuted),
          ),
          SizedBox(height: spacing.xs),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: [
              for (final player in living)
                FilterChip(
                  key: WitnessPanel.predictionSeat(player.seat),
                  label: Text(player.name),
                  selected: _named.contains(player.seat),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _named.add(player.seat);
                    } else {
                      _named.remove(player.seat);
                    }
                  }),
                ),
            ],
          ),
          SizedBox(height: spacing.md),
          FilledButton(
            key: WitnessPanel.predictionLock,
            onPressed: _named.isEmpty ? null : _lock,
            child: Text(l10n.witnessPredictionLock),
          ),
        ],
      ),
    );
  }

  Widget _lockedPrediction(BuildContext context, Prediction locked) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final l10n = context.l10n;

    final names = {
      for (final player in widget.snapshot.public.players)
        player.seat: player.name,
    };

    // Scored only once the match has actually ended, and only against the
    // standings — which are the roles becoming public, not a peek at them.
    final standings = widget.snapshot.standings;
    final scored = standings.isNotEmpty;
    final actual = {
      for (final standing in standings)
        if (standing.role.alignment == Alignment.mafia) standing.seat,
    };

    return Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.witnessPredictionLocked,
            style: type.body.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: spacing.sm),
          Text(
            [
              locked.winner == Alignment.mafia ? l10n.mafiaWins : l10n.townWins,
              ...locked.mafiaSeats.map((seat) => names[seat] ?? ''),
            ].where((s) => s.isNotEmpty).join('  ·  '),
            style: type.caption.copyWith(color: colors.textSecondary),
          ),
          if (scored) ...[
            SizedBox(height: spacing.md),
            Text(
              l10n.witnessPredictionScore(
                locked.correctAgainst(actual),
                actual.length,
              ),
              style: type.title.copyWith(color: colors.accentGold),
            ),
          ],
        ],
      ),
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
