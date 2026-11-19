import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n_ext.dart';
import '../screens/online/online_session.dart' show onlineBackendFactoryProvider;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../western_digits.dart';
import '../widgets/deck/deck_buttons.dart';
import '../widgets/deck/deck_public.dart' show showDeckSheet;
import 'friends.dart' show FriendEntry;

/// S4 «بروفايل صاحبك»: our history together, from finished online matches
/// only (the server reads council_match_records, written when a match ends),
/// so nothing here can tell anyone a role in a match still being played.
@immutable
class FriendProfile {
  final String? handle;
  final String name;
  final int level;
  final int matchesTogether;
  final int wonTogether;
  final int fooledMe;

  /// Percent of his finished matches as Mafia; null under five matches.
  final int? mafiaShare;
  const FriendProfile({
    required this.handle,
    required this.name,
    required this.level,
    required this.matchesTogether,
    required this.wonTogether,
    required this.fooledMe,
    required this.mafiaShare,
  });

  factory FriendProfile.fromJson(Map<String, dynamic> json) => FriendProfile(
    handle: json['handle'] as String?,
    name: (json['name'] as String?) ?? '?',
    level: (json['level'] as num?)?.toInt() ?? 1,
    matchesTogether: (json['matchesTogether'] as num?)?.toInt() ?? 0,
    wonTogether: (json['wonTogether'] as num?)?.toInt() ?? 0,
    fooledMe: (json['fooledMe'] as num?)?.toInt() ?? 0,
    mafiaShare: (json['mafiaShare'] as num?)?.toInt(),
  );
}

final friendProfileProvider = FutureProvider.autoDispose
    .family<FriendProfile, String>((ref, id) async {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      return FriendProfile.fromJson(
        await backend.call('friends', {'action': 'profile', 'userId': id}),
      );
    });

Future<void> showFriendProfileSheet(
  BuildContext context, {
  required FriendEntry friend,
  required VoidCallback onPing,
  required VoidCallback onRemove,
}) => showDeckSheet<void>(
  context: context,
  title: friend.name,
  body: (_) =>
      FriendProfileBody(friend: friend, onPing: onPing, onRemove: onRemove),
);

class FriendProfileBody extends ConsumerWidget {
  final FriendEntry friend;
  final VoidCallback onPing;
  final VoidCallback onRemove;
  const FriendProfileBody({
    super.key,
    required this.friend,
    required this.onPing,
    required this.onRemove,
  });

  static const pingKey = ValueKey('friend_profile_ping');
  static const removeKey = ValueKey('friend_profile_remove');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = context.spacing;
    final c = context.colors;
    final type = context.typography;
    final profile = ref.watch(friendProfileProvider(friend.id));

    Widget stat(int value, String label) => Expanded(
      child: Column(
        children: [
          Text(westernDigits('$value'), style: DeckTokens.title(type)),
          Text(
            label,
            style: type.caption.copyWith(color: c.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    final body = profile.when(
      loading: () => Padding(
        padding: EdgeInsets.all(s.lg),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Text(
        l.inviteFailed,
        style: type.body.copyWith(color: c.textMuted),
        textAlign: TextAlign.center,
      ),
      data: (p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.handle != null)
            Text(
              '@${p.handle}',
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: c.textSecondary),
            ),
          Text(
            westernDigits(l.councilLevel(p.level)),
            textAlign: TextAlign.center,
            style: type.caption.copyWith(color: c.textMuted),
          ),
          SizedBox(height: s.md),
          Text(
            l.friendTogetherTitle,
            style: DeckTokens.meta(
              type,
            ).copyWith(color: c.textMuted, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: s.xs),
          Row(
            children: [
              stat(p.matchesTogether, l.friendStatTogether),
              stat(p.wonTogether, l.friendStatWonTogether),
              stat(p.fooledMe, l.friendStatFooledMe),
            ],
          ),
          if (p.mafiaShare != null) ...[
            SizedBox(height: s.md),
            Text(
              westernDigits(l.friendMafiaShare(p.mafiaShare!)),
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: c.textSecondary),
            ),
          ],
          SizedBox(height: s.xs),
          Text(
            l.friendStatsNote,
            textAlign: TextAlign.center,
            style: type.caption.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        SizedBox(height: s.lg),
        BoneButton(
          key: pingKey,
          label: l.friendPingAction,
          onPressed: () {
            Navigator.of(context).maybePop();
            onPing();
          },
        ),
        SizedBox(height: s.sm),
        TextButton(
          key: removeKey,
          onPressed: () {
            Navigator.of(context).maybePop();
            onRemove();
          },
          child: Text(
            l.friendRemove,
            style: type.body.copyWith(color: c.textMuted),
          ),
        ),
      ],
    );
  }
}
