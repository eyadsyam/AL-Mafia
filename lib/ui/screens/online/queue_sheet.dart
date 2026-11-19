import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../friendly_error.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../western_digits.dart';
import '../../widgets/deck/deck_buttons.dart';
import '../../widgets/deck/deck_public.dart' show showDeckSheet;
import 'match_queue.dart';
import 'nobody_waiting_card.dart' show shareAppInvite;

/// O1 «استناني» (design-system/screens/online-plan.html §O1).
///
/// Two faces of one sheet: «بندوّرلك على ناس» while the queue fills, and
/// «الأوضة كملت» once a round of five is open, with 60 seconds to say «أنا
/// جاهز». Closing the sheet keeps the player queued: the server sends the
/// push. Resolves with the room the server seated him in, or null.
Future<QueueRoom?> showQueueSheet(BuildContext context) =>
    showDeckSheet<QueueRoom>(
      context: context,
      title: context.l10n.queueTitle,
      body: (_) => const QueueSheetBody(),
    );

class QueueSheetBody extends ConsumerStatefulWidget {
  const QueueSheetBody({super.key});

  static const leaveKey = ValueKey('queue_leave');
  static const inviteKey = ValueKey('queue_invite');
  static const readyKey = ValueKey('queue_ready_yes');
  static const notNowKey = ValueKey('queue_ready_no');

  @override
  ConsumerState<QueueSheetBody> createState() => _QueueSheetBodyState();
}

class _QueueSheetBodyState extends ConsumerState<QueueSheetBody> {
  QueueStatus? _status;
  Timer? _poll;
  Timer? _tick;
  bool _busy = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _read();
    // The countdown redraws every second; the server is asked less often.
    _tick = Timer.periodic(QueueTokens.countdownTick, (_) {
      if (mounted && _status?.round != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _schedule() {
    _poll?.cancel();
    if (_closed) return;
    final open = _status?.round != null;
    _poll = Timer(
      open ? QueueTokens.roundPoll : QueueTokens.statusPoll,
      _read,
    );
  }

  Future<void> _read() async {
    try {
      final status = await ref.read(matchQueueApiProvider).status();
      if (!mounted || _closed) return;
      if (status.room != null) {
        _close(status.room);
        return;
      }
      if (!status.queued) {
        // Removed by the server (a second missed round, or two hours with
        // nobody): the sheet has nothing left to show.
        _close(null);
        return;
      }
      setState(() => _status = status);
    } catch (_) {
      // A failed read keeps the last face; the next one may answer.
    }
    if (mounted) _schedule();
  }

  void _close(QueueRoom? room) {
    if (_closed) return;
    _closed = true;
    _poll?.cancel();
    Navigator.of(context).maybePop(room);
  }

  Future<void> _leave() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(matchQueueApiProvider).leave();
      if (mounted) _close(null);
    } catch (error) {
      if (mounted) _say(friendlyError(context.l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answer(bool yes) async {
    final round = _status?.round;
    if (_busy || round == null) return;
    setState(() => _busy = true);
    try {
      // Counted server-side (queue/ready_yes, queue/ready_no).
      await ref.read(matchQueueApiProvider).ready(round.id, yes: yes);
      if (!mounted) return;
      if (!yes) {
        _close(null);
        return;
      }
      await _read();
    } catch (error) {
      if (mounted) _say(friendlyError(context.l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final c = context.colors;
    final type = context.typography;
    final status = _status;
    final round = status?.round;
    if (status == null) {
      return Padding(
        padding: EdgeInsets.all(s.xl),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (round != null) {
      final left = round.deadline.difference(DateTime.now());
      final seconds = left.isNegative ? 0 : left.inSeconds;
      final clock =
          '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.queueReadyTitle,
            style: type.headline,
            textAlign: TextAlign.center,
          ),
          _QueueRing(
            value: round.confirmed,
            caption: l.queueReadyCount,
          ),
          Text(
            westernDigits(l.queueTimeLeft(clock)),
            style: type.body.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: s.lg),
          if (status.meConfirmed)
            Text(
              l.queueWaitingOthers,
              style: type.body.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            )
          else ...[
            BoneButton(
              key: QueueSheetBody.readyKey,
              label: l.queueReadyYes,
              onPressed: _busy ? null : () => _answer(true),
            ),
            SizedBox(height: s.sm),
            TextButton(
              key: QueueSheetBody.notNowKey,
              onPressed: _busy ? null : () => _answer(false),
              child: Text(
                l.queueReadyNo,
                style: type.body.copyWith(color: c.textMuted),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QueueRing(
          value: status.count,
          caption: westernDigits(l.queueOf(QueueTokens.matchSize)),
        ),
        Text(
          l.queueCanClose,
          style: type.body.copyWith(color: c.textSecondary),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: s.lg),
        RimButton(
          key: QueueSheetBody.inviteKey,
          label: l.queueInvite,
          onPressed: () => shareAppInvite(context, ref),
        ),
        SizedBox(height: s.sm),
        TextButton(
          key: QueueSheetBody.leaveKey,
          onPressed: _busy ? null : _leave,
          child: Text(
            l.queueLeave,
            style: type.body.copyWith(color: c.textMuted),
          ),
        ),
      ],
    );
  }
}

/// The count in a bone ring: «3 · من 5», «4 · جاهزين».
class _QueueRing extends StatelessWidget {
  final int value;
  final String caption;
  const _QueueRing({required this.value, required this.caption});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final c = context.colors;
    final type = context.typography;
    final number = westernDigits('$value');
    return Semantics(
      label: '$number $caption',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: s.md),
        child: Center(
          child: Container(
            width: QueueTokens.ring,
            height: QueueTokens.ring,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: DeckTokens.bone,
                width: QueueTokens.ringStroke,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(number, style: DeckTokens.title(type)),
                Text(
                  caption,
                  style: type.bodySmall.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
