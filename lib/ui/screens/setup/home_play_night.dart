import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n_ext.dart';
import '../../social/push_prompt.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../western_digits.dart';
import '../online/match_queue.dart';
import 'home_online_rooms.dart';

/// O2 «ليلة اللعب» (online-plan.html §O2): from two hours before 21:00 Cairo
/// Home shows «ليلة اللعب الساعة 9» with a countdown and «فكّرني»; from 21:00
/// to 22:00 «ليلة اللعب شغالة» with the queue count and «ادخل». Outside that
/// window, and on any failure, the ordinary online line (B2) is drawn instead.
final homePlayNightProvider = FutureProvider.autoDispose<PlayNight?>(
  (ref) => ref.read(matchQueueApiProvider).playNight(),
);

class HomeTonightLine extends ConsumerStatefulWidget {
  final VoidCallback onOpenOnline;
  const HomeTonightLine({super.key, required this.onOpenOnline});

  static const Key cardKey = ValueKey('home_play_night');
  static const Key remindKey = ValueKey('home_play_night_remind');

  @override
  ConsumerState<HomeTonightLine> createState() => _HomeTonightLineState();
}

class _HomeTonightLineState extends ConsumerState<HomeTonightLine> {
  Timer? _timer;
  bool? _reminded;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(QueueTokens.playNightRefresh, (_) {
      if (!mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      ref.invalidate(homePlayNightProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _remind(PlayNight night) async {
    if (_busy) return;
    final on = !(_reminded ?? night.reminded);
    setState(() => _busy = true);
    try {
      if (on) {
        final push = ref.read(pushPromptProvider);
        if (!await push.isOn() && !await push.setOn(true)) return;
      }
      final now = await ref.read(matchQueueApiProvider).remindPlayNight(on);
      if (mounted) setState(() => _reminded = now);
    } catch (_) {
      // The chip keeps its last answer; Home never says «error».
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = HomeOnlineRoomsLine(onTap: widget.onOpenOnline);
    final night = ref.watch(homePlayNightProvider).valueOrNull;
    if (night == null) return fallback;
    final now = DateTime.now();
    final live = !now.isBefore(night.startsAt) && now.isBefore(night.endsAt);
    final soon =
        !live &&
        now.isBefore(night.startsAt) &&
        night.startsAt.difference(now) <= QueueTokens.playNightLead;
    if (!live && !soon) return fallback;

    final l = context.l10n;
    final s = context.spacing;
    final c = context.colors;
    final type = context.typography;
    final reminded = _reminded ?? night.reminded;

    final String title;
    final String sub;
    final String chip;
    final VoidCallback? onChip;
    if (live) {
      title = l.playNightLive;
      sub = l.playNightQueue(night.queueCount);
      chip = l.playNightEnter;
      onChip = widget.onOpenOnline;
    } else {
      final left = night.startsAt.difference(now);
      final clock =
          '${left.inHours}:${(left.inMinutes % 60).toString().padLeft(2, '0')}';
      final coming = night.remindedCount;
      sub = [
        l.playNightLeft(clock),
        if (coming != null) l.playNightComing(coming),
      ].join(' · ');
      title = l.playNightAt;
      chip = reminded ? l.playNightReminded : l.playNightRemind;
      onChip = _busy ? null : () => _remind(night);
    }

    return Padding(
      padding: EdgeInsets.only(top: s.sm),
      child: Material(
        key: HomeTonightLine.cardKey,
        color: live ? c.surfaceOverlay : Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: DeckTokens.bone),
          borderRadius: BorderRadius.circular(context.radii.card),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(context.radii.card),
          onTap: widget.onOpenOnline,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        westernDigits(title),
                        style: type.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        westernDigits(sub),
                        style: type.bodySmall.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: s.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: IdentityTokens.target,
                  ),
                  child: OutlinedButton(
                    key: HomeTonightLine.remindKey,
                    onPressed: onChip,
                    child: Text(chip),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
