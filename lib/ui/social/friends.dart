import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/asset_constants.dart';
import '../economy/cosmetic_paint.dart';
import '../economy/economy_capabilities.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/feathered_art.dart';
import '../screens/online/online_session.dart';

/// «أصحابك» — friends made at the table (`friends` edge function,
/// 20260928000300_friends.sql). Public facts only: names, whether someone is
/// in a lobby (with its code) or in a match. Never a role, never a seat.

enum FriendPlace { away, lobby, playing }

class FriendPresence {
  final FriendPlace place;
  final String? code;
  final int players;
  const FriendPresence(this.place, {this.code, this.players = 0});

  static FriendPresence fromJson(Object? json) {
    if (json is! Map) return const FriendPresence(FriendPlace.away);
    return switch (json['state']) {
      'lobby' when json['code'] is String => FriendPresence(
        FriendPlace.lobby,
        code: json['code'] as String,
        players: (json['players'] as num?)?.toInt() ?? 0,
      ),
      'playing' => const FriendPresence(FriendPlace.playing),
      _ => const FriendPresence(FriendPlace.away),
    };
  }
}

class FriendEntry {
  final String id;
  final String name;
  final String gender;
  final FriendPresence presence;
  final int matches;

  /// Store truth: the frame and nameplate this person equipped. Public, like
  /// the two codes every seat already shows at the table.
  final String? frame;
  final String? plate;
  const FriendEntry({
    required this.id,
    required this.name,
    this.gender = 'unspecified',
    this.presence = const FriendPresence(FriendPlace.away),
    this.matches = 0,
    this.frame,
    this.plate,
  });

  static FriendEntry? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    return FriendEntry(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '?',
      gender: (json['gender'] as String?) ?? 'unspecified',
      presence: FriendPresence.fromJson(json['presence']),
      matches: (json['matches'] as num?)?.toInt() ?? 0,
      frame: json['frame'] is String ? json['frame'] as String : null,
      plate: json['plate'] is String ? json['plate'] as String : null,
    );
  }
}

class RoomInviteEntry {
  final String code;
  final String name;
  const RoomInviteEntry({required this.code, required this.name});
}

class FriendsState {
  final List<FriendEntry> friends;
  final List<FriendEntry> incoming;
  final List<FriendEntry> outgoing;
  final List<FriendEntry> recent;
  final List<RoomInviteEntry> invites;
  const FriendsState({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.recent = const [],
    this.invites = const [],
  });

  int get inLobby =>
      friends.where((f) => f.presence.place == FriendPlace.lobby).length;

  static FriendsState fromJson(Map<String, dynamic> json) {
    List<Object?> rows(String key) {
      final raw = json[key];
      return raw is List ? raw : const [];
    }

    List<FriendEntry> list(String key) => [
      for (final row in rows(key)) ?FriendEntry.fromJson(row),
    ];
    return FriendsState(
      friends: list('friends'),
      incoming: list('incoming'),
      outgoing: list('outgoing'),
      recent: list('recent'),
      invites: [
        for (final row in rows('invites'))
          if (row is Map && row['code'] is String)
            RoomInviteEntry(
              code: row['code'] as String,
              name: (row['name'] as String?) ?? '?',
            ),
      ],
    );
  }
}

/// Null while the feature is off or the server cannot be asked.
final friendsProvider = AsyncNotifierProvider<FriendsController, FriendsState?>(
  FriendsController.new,
);

class FriendsController extends AsyncNotifier<FriendsState?> {
  @override
  Future<FriendsState?> build() async {
    final caps = await ref.watch(economyCapabilitiesProvider.future);
    if (!caps.friends) return null;
    return _call({'action': 'status'});
  }

  Future<FriendsState?> _call(Map<String, dynamic> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    final json = await backend.call('friends', body);
    if (json['enabled'] == false) return null;
    return FriendsState.fromJson(json);
  }

  Future<void> _act(Map<String, dynamic> body) async {
    try {
      final next = await _call(body);
      state = AsyncData(next);
    } catch (_) {
      // The list stays as it was; the next refresh tells the truth.
    }
  }

  Future<void> refresh() => _act({'action': 'status'});
  Future<void> request(String id) => _act({'action': 'request', 'userId': id});
  Future<void> respond(String id, bool accept) =>
      _act({'action': 'respond', 'userId': id, 'accept': accept});
  Future<void> remove(String id) => _act({'action': 'remove', 'userId': id});

  /// True when the invite was delivered.
  Future<bool> invite(String id, String roomId) async {
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.call('friends', {
        'action': 'invite',
        'userId': id,
        'roomId': roomId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// On the online door: invites waiting for you, and the way into the list.
/// Draws nothing while the feature is off.
///
/// D5: while the strip is on screen and the app is in the foreground, invites
/// are refreshed every [FriendsTokens.inviteRefresh] and at once on resume, so
/// «فلان عزمك» arrives without leaving and re-entering the door. The timer
/// stops in the background and when the strip leaves the tree.
class FriendsStrip extends ConsumerStatefulWidget {
  /// Joins a lobby by code (an invite, or a friend's open lobby).
  final ValueChanged<String> onJoin;
  const FriendsStrip({super.key, required this.onJoin});

  static const Key openKey = ValueKey('friends_open');
  static Key inviteKey(String code) => ValueKey('friends_invite_$code');

  @override
  ConsumerState<FriendsStrip> createState() => _FriendsStripState();
}

class _FriendsStripState extends ConsumerState<FriendsStrip>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(FriendsTokens.inviteRefresh, (_) => _refresh());
  }

  void _refresh() {
    // Only while the feature answered: a null state is "off", not "stale".
    if (ref.read(friendsProvider).valueOrNull == null) return;
    ref.read(friendsProvider.notifier).refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onJoin = widget.onJoin;
    final friends = ref.watch(friendsProvider).valueOrNull;
    if (friends == null) return const SizedBox.shrink();
    final l = context.l10n;
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.only(bottom: s.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final invite in friends.invites.take(2))
            Padding(
              padding: EdgeInsets.only(bottom: s.sm),
              child: FilledButton.icon(
                key: FriendsStrip.inviteKey(invite.code),
                onPressed: () => onJoin(invite.code),
                icon: const Icon(Icons.mail_rounded),
                label: Text(l.friendsInvitedYou(invite.name)),
              ),
            ),
          OutlinedButton.icon(
            key: FriendsStrip.openKey,
            onPressed: () => showFriendsSheet(context, onJoin: onJoin),
            icon: const Icon(Icons.people_alt_rounded),
            label: Text(
              friends.inLobby > 0
                  ? l.friendsTitleWithOnline(friends.inLobby)
                  : l.friendsTitle,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showFriendsSheet(
  BuildContext context, {
  required ValueChanged<String> onJoin,
  String? inviteRoomId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.colors.surfaceBase,
  builder: (_) => FractionallySizedBox(
    heightFactor: FriendsTokens.sheetHeight,
    child: FriendsSheet(onJoin: onJoin, inviteRoomId: inviteRoomId),
  ),
);

/// The whole list: invites, requests, friends with where they are, and the
/// people you sat with lately. With [inviteRoomId] (from the lobby) each
/// friend carries «اعزم» instead of «ادخل».
class FriendsSheet extends ConsumerStatefulWidget {
  final ValueChanged<String> onJoin;
  final String? inviteRoomId;
  const FriendsSheet({super.key, required this.onJoin, this.inviteRoomId});

  @override
  ConsumerState<FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends ConsumerState<FriendsSheet> {
  final Set<String> _invited = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(friendsProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(friendsProvider);
    final friends = async.valueOrNull;
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final controller = ref.read(friendsProvider.notifier);

    Widget heading(String text) => Padding(
      padding: EdgeInsets.only(top: s.lg, bottom: s.sm),
      child: Text(
        text,
        style: type.title.copyWith(color: colors.textSecondary),
      ),
    );

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.all(s.screenMargin),
        children: [
          // A painted table instead of a header bar: the list sits under it.
          SizedBox(
            height: FriendsTokens.heroHeight,
            child: FeatheredArt(
              feather: Feather.banner,
              child: Image.asset(
                AppCouncilArt.onlineWelcome,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Text(
            l.friendsTitle,
            textAlign: TextAlign.center,
            style: type.headline.copyWith(color: colors.textPrimary),
          ),
          if (friends == null && async.isLoading)
            Padding(
              padding: EdgeInsets.all(s.xl),
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (friends != null) ...[
            if (friends.invites.isNotEmpty && widget.inviteRoomId == null) ...[
              heading(l.friendsInvites),
              for (final invite in friends.invites)
                _Row(
                  name: invite.name,
                  gender: 'unspecified',
                  line: l.friendsInvitedYou(invite.name),
                  action: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onJoin(invite.code);
                    },
                    child: Text(l.friendsJoin),
                  ),
                ),
            ],
            if (friends.incoming.isNotEmpty) ...[
              heading(l.friendsRequests),
              for (final f in friends.incoming)
                _Row(
                  name: f.name,
                  gender: f.gender,
                  frame: f.frame,
                  plate: f.plate,
                  line: l.friendsWantsYou,
                  action: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l.friendsDecline,
                        onPressed: () => controller.respond(f.id, false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      FilledButton(
                        onPressed: () => controller.respond(f.id, true),
                        child: Text(l.friendsAccept),
                      ),
                    ],
                  ),
                ),
            ],
            heading(l.friendsYours),
            if (friends.friends.isEmpty)
              Text(
                l.friendsNone,
                style: type.body.copyWith(color: colors.textMuted),
              ),
            for (final f in friends.friends)
              _Row(
                name: f.name,
                gender: f.gender,
                frame: f.frame,
                plate: f.plate,
                line: switch (f.presence.place) {
                  FriendPlace.lobby => l.friendsInLobby(f.presence.players),
                  FriendPlace.playing => l.friendsPlaying,
                  FriendPlace.away => l.friendsAway,
                },
                lit: f.presence.place == FriendPlace.lobby,
                action: widget.inviteRoomId != null
                    ? (_invited.contains(f.id)
                          ? Text(
                              l.friendsInvited,
                              style: type.caption.copyWith(
                                color: colors.accentGold,
                              ),
                            )
                          : OutlinedButton(
                              onPressed: () async {
                                final sent = await controller.invite(
                                  f.id,
                                  widget.inviteRoomId!,
                                );
                                if (sent && mounted) {
                                  setState(() => _invited.add(f.id));
                                }
                              },
                              child: Text(l.friendsInvite),
                            ))
                    : f.presence.place == FriendPlace.lobby
                    ? FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onJoin(f.presence.code!);
                        },
                        child: Text(l.friendsJoin),
                      )
                    : null,
              ),
            if (friends.recent.isNotEmpty) ...[
              heading(l.friendsRecent),
              for (final f in friends.recent)
                _Row(
                  name: f.name,
                  gender: f.gender,
                  frame: f.frame,
                  plate: f.plate,
                  line: l.friendsMatchesTogether(f.matches),
                  action: friends.outgoing.any((o) => o.id == f.id)
                      ? Text(
                          l.friendsPending,
                          style: type.caption.copyWith(color: colors.textMuted),
                        )
                      : OutlinedButton(
                          onPressed: () => controller.request(f.id),
                          child: Text(l.friendsAdd),
                        ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String name;
  final String gender;
  final String line;
  final Widget? action;
  final bool lit;
  final String? frame;
  final String? plate;
  const _Row({
    required this.name,
    required this.gender,
    required this.line,
    this.action,
    this.lit = false,
    this.frame,
    this.plate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = context.spacing;
    final type = context.typography;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.xs),
      child: Row(
        children: [
          CosmeticFrameRing(
            frame: frame,
            diameter: FriendsTokens.avatar,
            child: _avatar(colors),
          ),
          SizedBox(width: s.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CosmeticNameplate(
                  name: name,
                  plate: plate,
                  style: type.body.emphasised.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.caption.copyWith(
                    color: lit ? colors.accentGold : colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  Widget _avatar(MafiaColors colors) => SizedBox.square(
    dimension: FriendsTokens.avatar,
    child: FeatheredArt(
      feather: Feather.portrait,
      halo: lit,
      child: Image.asset(
        gender == 'female'
            ? AppCouncilArt.avatarFemale
            : AppCouncilArt.avatarMale,
        fit: BoxFit.contain,
        color: lit ? colors.accentGold : colors.textSecondary,
        excludeFromSemantics: true,
      ),
    ),
  );
}
