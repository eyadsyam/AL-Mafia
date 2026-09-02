import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/balance_guard.dart';
import '../../../platform/clipboard.dart';
import '../../../engine/models/enums.dart';
import '../../../transport/game_snapshot.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/connection_banner.dart';
import '../../widgets/textured_surface.dart';
import '../setup/setup_draft.dart';
import 'online_session.dart';

/// S-21 — the room, before it is a match.
///
/// ## What the code is for
///
/// Six characters from an alphabet with no `I/1`, `O/0` or `Z/2` in it (doc 10
/// §10), because the only way a room code is ever transmitted is somebody
/// reading it out to a friend. It is the largest thing on the screen for the
/// same reason.
///
/// ## The connected dots, and the one place they are not shown
///
/// A player who has dropped is marked, so the room can see why nothing is
/// happening. That is true here and during the day — and **not during the
/// night** (doc 10 §6.3): a connection indicator that updates while roles are
/// acting is a channel that reports on who is acting. The lobby is before any
/// role exists, so it is the one screen where this is unambiguously safe.
///
/// ## The headphones line
///
/// V7. Two players in one room with two open microphones is a feedback loop,
/// and the fix is a sentence in the lobby rather than an echo canceller that
/// will not work.
class LobbyScreen extends ConsumerStatefulWidget {
  /// Where the match itself lives, once the host has started it.
  final VoidCallback onStarted;

  /// Leaving the room, back to somewhere that needs no server.
  final VoidCallback onLeave;

  const LobbyScreen({
    super.key,
    required this.onStarted,
    required this.onLeave,
  });

  static const Key codeText = ValueKey('lobby_code');
  static const Key startButton = ValueKey('lobby_start');
  static const Key leaveButton = ValueKey('lobby_leave');
  static const Key headphonesWarning = ValueKey('lobby_headphones');

  static Key seatTile(int seat) => ValueKey('lobby_seat_$seat');

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  StreamSubscription<GameSnapshot>? _feed;
  GameSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    final transport = ref.read(onlineSessionProvider).transport;
    _snapshot = transport?.snapshot;
    _feed = transport?.watch().listen((snapshot) {
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
      // The host started it; every other device finds out here, from the same
      // push, and goes to the same screen. Nobody is told anything early.
      if (snapshot.phase != GamePhase.setup) widget.onStarted();
    });
  }

  @override
  void dispose() {
    _feed?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final count = snapshot.public.players.length;
    // The recommended distribution for this many players, and the host's own
    // default rules. Both are the same values the offline setup screens start
    // from, so a room started here plays the game the host already knows.
    final started = await ref.read(onlineSessionProvider.notifier).start(
          roleCounts: BalanceGuard.recommended(count),
          settings: ref.read(setupDraftProvider).settings,
        );
    if (started && mounted) widget.onStarted();
  }

  Future<void> _copyCode(String code) async {
    await AppClipboard.copy(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.onlineCodeCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;
    final l10n = context.l10n;

    final session = ref.watch(onlineSessionProvider);
    final snapshot = _snapshot;
    final code = session.transport?.code ?? session.room?.code ?? '';
    final players = snapshot?.public.players ?? const [];
    final canStart = (snapshot?.canAdvance ?? false) && players.length >= 5;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: AppBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              ConnectionBanner(
                quality: snapshot?.connection ?? ConnectionQuality.connected,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(spacing.screenMargin),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: spacing.maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.onlineRoomCode,
                          style: type.caption.copyWith(color: colors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: spacing.xs),
                        GestureDetector(
                          onTap: code.isEmpty ? null : () => _copyCode(code),
                          child: Text(
                            key: LobbyScreen.codeText,
                            code,
                            style: type.display.copyWith(
                              color: colors.accentGold,
                              // The one place a wide letter gap is right: this
                              // is a string to be read out loud, one character
                              // at a time, over a phone line.
                              letterSpacing: spacing.sm,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: spacing.xs),
                        Text(
                          l10n.onlineShareCode,
                          style: type.caption.copyWith(color: colors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: spacing.lg),
                        Expanded(
                          child: players.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.onlineWaitingForPlayers,
                                    style: type.body
                                        .copyWith(color: colors.textSecondary),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: players.length,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(height: spacing.sm),
                                  itemBuilder: (context, index) {
                                    final player = players[index];
                                    return _SeatTile(
                                      key: LobbyScreen.seatTile(player.seat),
                                      name: player.name,
                                      isHost: player.seat == 0,
                                      isMe: player.seat == snapshot?.viewerSeat,
                                      // Absent rather than false when the
                                      // transport is not reporting: "we do not
                                      // know" and "they have gone" are
                                      // different, and only one of them
                                      // belongs on a tile.
                                      connected: snapshot
                                          ?.connectedSeats[player.seat],
                                    );
                                  },
                                ),
                        ),
                        SizedBox(height: spacing.md),
                        Text(
                          key: LobbyScreen.headphonesWarning,
                          l10n.onlineHeadphonesWarning,
                          style: type.caption.copyWith(color: colors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: spacing.md),
                        if (snapshot?.canAdvance ?? false)
                          FilledButton(
                            key: LobbyScreen.startButton,
                            onPressed: session.busy || !canStart ? null : _start,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.accentGold,
                              foregroundColor: colors.surfaceBase,
                              padding:
                                  EdgeInsets.symmetric(vertical: spacing.md),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(radii.button),
                              ),
                            ),
                            child: Text(
                              canStart
                                  ? l10n.onlineStartMatch
                                  : l10n.onlineNeedFivePlayers,
                              style: type.title,
                            ),
                          )
                        else
                          Text(
                            l10n.onlineWaitingForHost,
                            style: type.body
                                .copyWith(color: colors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        SizedBox(height: spacing.sm),
                        TextButton(
                          key: LobbyScreen.leaveButton,
                          onPressed: () async {
                            await ref
                                .read(onlineSessionProvider.notifier)
                                .leave();
                            if (context.mounted) widget.onLeave();
                          },
                          child: Text(
                            l10n.onlineLeave,
                            style:
                                type.body.copyWith(color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  final String name;
  final bool isHost;
  final bool isMe;

  /// Null when the transport does not report presence at all — offline, and
  /// during the night, where a live indicator would be a tell (doc 10 §6.3).
  final bool? connected;

  const _SeatTile({
    super.key,
    required this.name,
    required this.isHost,
    required this.isMe,
    this.connected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radii.card),
        border: Border.all(
          color: isMe ? colors.accentGold : colors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: type.body.copyWith(color: colors.textPrimary),
            ),
          ),
          if (connected == false) ...[
            Text(
              context.l10n.onlineNotConnected,
              style: type.caption.copyWith(color: colors.textMuted),
            ),
            SizedBox(width: spacing.sm),
          ],
          if (isHost)
            Text(
              context.l10n.onlineHostBadge,
              style: type.caption.copyWith(color: colors.accentGold),
            ),
        ],
      ),
    );
  }
}
