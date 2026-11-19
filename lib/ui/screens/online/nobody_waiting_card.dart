import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/public_web_origin.dart';
import '../../../platform/invite_share.dart';
import '../../economy/council.dart' show inviteProvider;
import '../../economy/council_hub.dart' show councilInviteLink;
import '../../friendly_error.dart';
import '../../l10n_ext.dart';
import '../../social/directory.dart' show directoryApiProvider;
import '../../social/push_prompt.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_buttons.dart';
import '../../widgets/mafia_kit.dart';

/// The app invite: the player's own council code and link when the invite
/// card has one, otherwise the site. The share sheet, or a copy. Shared by
/// this card and the queue sheet's «ادعي صحابك».
Future<void> shareAppInvite(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  void say(String text) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text)));
  String? code;
  try {
    final status = await ref.read(inviteProvider.future);
    if (status.enabled) code = status.code;
  } catch (_) {
    // No personal code: the plain link below.
  }
  if (!context.mounted) return;
  final text = code == null
      ? '${l.appTitle}\n$kPublicWebOrigin'
      : '${l.inviteShareText(code)}\n${councilInviteLink(code)}';
  final outcome = await ref
      .read(inviteSharerProvider)
      .share(text: text, subject: l.appTitle);
  if (!context.mounted) return;
  switch (outcome) {
    case InviteShareOutcome.handedOver:
      break;
    case InviteShareOutcome.copied:
      say(l.shareTextCopied);
    case InviteShareOutcome.failed:
      say(l.shareUnavailable);
  }
}

/// «مفيش حد مستني دلوقتي»: the public list, read successfully, with nobody in
/// it. Two things to do instead of nothing: send the app to friends, or ask to
/// be told (once) when a public room has people waiting.
class NobodyWaitingCard extends ConsumerStatefulWidget {
  const NobodyWaitingCard({super.key});

  static const shareKey = ValueKey('nobody_waiting_share');
  static const remindKey = ValueKey('nobody_waiting_remind');
  static const remindOnKey = ValueKey('nobody_waiting_remind_on');
  static const cancelKey = ValueKey('nobody_waiting_cancel');

  @override
  ConsumerState<NobodyWaitingCard> createState() => _NobodyWaitingCardState();
}

class _NobodyWaitingCardState extends ConsumerState<NobodyWaitingCard> {
  /// The server's answer; a failed read keeps the button.
  bool _on = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _readStatus();
  }

  /// So the «هنبعتلك» row survives leaving and reopening the screen.
  Future<void> _readStatus() async {
    try {
      final on = await ref.read(directoryApiProvider).watchRoomsStatus();
      if (mounted) setState(() => _on = on);
    } catch (_) {
      // The button stays; a tap that fails says so.
    }
  }

  void _say(String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _share() => shareAppInvite(context, ref);

  Future<void> _set(bool on) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (on) {
        // The app's own notification question, only when it is still open.
        final push = ref.read(pushPromptProvider);
        if (!await push.isOn() && !await push.setOn(true)) return;
      }
      final now = await ref.read(directoryApiProvider).watchRooms(on);
      if (mounted) setState(() => _on = now);
    } catch (error) {
      if (mounted) _say(friendlyError(context.l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final c = context.colors;
    final type = context.typography;
    return MafiaPanel(
      margin: EdgeInsets.only(top: s.md),
      padding: EdgeInsets.all(s.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.onlineNobodyWaiting,
            style: type.headline,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: s.sm),
          RimButton(
            key: NobodyWaitingCard.shareKey,
            label: l.onlineShareWithFriends,
            onPressed: _share,
          ),
          SizedBox(height: s.sm),
          if (_on)
            Container(
              key: NobodyWaitingCard.remindOnKey,
              padding: EdgeInsets.symmetric(
                horizontal: s.md,
                vertical: s.xs,
              ),
              decoration: BoxDecoration(
                color: c.surfaceOverlay,
                border: Border.all(color: c.borderSubtle),
                borderRadius: BorderRadius.circular(context.radii.card),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l.onlineRemindOn, style: type.bodySmall),
                  ),
                  TextButton(
                    key: NobodyWaitingCard.cancelKey,
                    onPressed: _busy ? null : () => _set(false),
                    child: Text(
                      l.cancel,
                      style: type.bodySmall.copyWith(color: c.textMuted),
                    ),
                  ),
                ],
              ),
            )
          else
            RimButton(
              key: NobodyWaitingCard.remindKey,
              label: l.onlineRemindMe,
              onPressed: _busy ? null : () => _set(true),
            ),
        ],
      ),
    );
  }
}
