import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/asset_constants.dart';
import '../economy/cosmetic_paint.dart';
import '../economy/economy_capabilities.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/deck/deck_form_sheet.dart';
import '../widgets/feathered_art.dart';
import '../../transport/online_backend.dart' show BackendException;
import '../screens/online/online_session.dart';
import 'directory.dart';
import 'directory_settings.dart';
import 'friend_profile_sheet.dart';
import 'friends_extras.dart';

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

  /// S3: my unexpired incoming «يلا نلعب؟» and answers, newest first. The
  /// `friends` status answer carries them.
  final List<FriendPing> pings;

  /// Improvement 2 and 1: people I may know, and my «الشلة» groups. The
  /// status answer carries both.
  final List<FriendSuggestion> suggestions;
  final List<FriendGroup> groups;

  /// This player's directory entry (handle and the two switches).
  final DirectoryMe me;
  const FriendsState({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.recent = const [],
    this.invites = const [],
    this.pings = const [],
    this.suggestions = const [],
    this.groups = const [],
    this.me = const DirectoryMe(),
  });

  FriendsState withGroups(List<FriendGroup> next) => FriendsState(
    friends: friends,
    incoming: incoming,
    outgoing: outgoing,
    recent: recent,
    invites: invites,
    pings: pings,
    suggestions: suggestions,
    groups: next,
    me: me,
  );

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
      pings: _pingsFrom(json['pings']),
      suggestions: [
        for (final row in rows('suggestions')) ?FriendSuggestion.fromJson(row),
      ],
      groups: FriendGroup.listFrom(json['groups']),
      me: DirectoryMe.fromJson(json['me']),
    );
  }
}

enum HandleRequest { sent, refused, limited, failed }

/// S3: the four preset lines between friends; never free text.
enum FriendPingKind {
  letsPlay('lets_play'),
  coming('coming'),
  fiveMin('five_min'),
  notNow('not_now');

  final String wire;
  const FriendPingKind(this.wire);

  static FriendPingKind? fromWire(Object? raw) {
    for (final k in values) {
      if (k.wire == raw) return k;
    }
    return null;
  }
}

class FriendPing {
  final String fromId;
  final String name;
  final FriendPingKind kind;
  const FriendPing({
    required this.fromId,
    required this.name,
    required this.kind,
  });
}

List<FriendPing> _pingsFrom(Object? raw) => [
  for (final row in (raw is List ? raw : const []))
    if (row is Map && row['from'] is String)
      if (FriendPingKind.fromWire(row['kind']) case final kind?)
        FriendPing(
          fromId: row['from'] as String,
          name: (row['name'] as String?) ?? '?',
          kind: kind,
        ),
];

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

  /// S2: a request by exact @handle. The answer is one of three: sent (or
  /// accepted, when he had asked first), refused (unknown handle, his
  /// privacy, a block: the server will not say which), or failed.
  Future<HandleRequest> requestByHandle(String handle) async {
    try {
      final next = await _call({'action': 'requestByHandle', 'handle': handle});
      state = AsyncData(next);
      return HandleRequest.sent;
    } on BackendException catch (e) {
      return e.code == 'RATE_LIMITED'
          ? HandleRequest.limited
          : HandleRequest.refused;
    } catch (_) {
      return HandleRequest.failed;
    }
  }

  /// S3: «يلا نلعب؟» or an answer to one. Null when it went; otherwise the
  /// refusal code (RATE_LIMITED after three a day).
  Future<String?> ping(String id, FriendPingKind kind) async {
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      await backend.call('friends', {
        'action': 'ping',
        'userId': id,
        'kind': kind.wire,
      });
      unawaited(refresh());
      return null;
    } on BackendException catch (e) {
      return e.code;
    } catch (_) {
      return 'UNREACHABLE';
    }
  }

  /// «الشلة» changed: the list the server answered replaces ours.
  void setGroups(List<FriendGroup> groups) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.withGroups(groups));
  }

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
    if (friends == null || friends.invites.isEmpty) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.only(bottom: s.sm),
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
        ],
      ),
    );
  }
}

/// «أصحابك» as one small icon beside the player's own chip: a count of what
/// waits for them (room invites and friend requests), a dot when a friend
/// is at a table. Opens the full sheet. Draws nothing while the feature is
/// off.
class FriendsButton extends ConsumerWidget {
  final ValueChanged<String> onJoin;
  const FriendsButton({super.key, required this.onJoin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider).valueOrNull;
    if (friends == null) return const SizedBox.shrink();
    final l = context.l10n;
    final c = context.colors;
    final waiting = friends.invites.length + friends.incoming.length;
    final label = friends.inLobby > 0
        ? l.friendsTitleWithOnline(friends.inLobby)
        : l.friendsTitle;
    return IconButton(
      key: FriendsStrip.openKey,
      tooltip: label,
      onPressed: () => showFriendsSheet(context, onJoin: onJoin),
      icon: Badge(
        isLabelVisible: waiting > 0 || friends.inLobby > 0,
        label: waiting > 0 ? Text('$waiting') : null,
        backgroundColor: waiting > 0 ? c.accentCrimson : c.accentGold,
        smallSize: FriendsTokens.presenceDot,
        child: Icon(
          Icons.people_alt_rounded,
          color: c.accentGold,
          semanticLabel: label,
        ),
      ),
    );
  }
}

Future<void> showFriendsSheet(
  BuildContext context, {
  required ValueChanged<String> onJoin,
  String? inviteRoomId,
}) => showDeckFormSheet<void>(
  context: context,
  builder: (_) => FriendsSheet(onJoin: onJoin, inviteRoomId: inviteRoomId),
);

/// «الأصحاب»: a search field, then invites, friend requests, friends with
/// where they are, and the people you sat with lately. With [inviteRoomId]
/// (from the lobby) each friend carries «اعزم» instead of «ادخل».
///
/// Names stay on one line (ellipsized); what a row can do sits in chips under
/// the name, so a long name is never squeezed by its own buttons. The search
/// looks through every list by name, and by room code for people at a table.
class FriendsSheet extends ConsumerStatefulWidget {
  final ValueChanged<String> onJoin;
  final String? inviteRoomId;
  const FriendsSheet({super.key, required this.onJoin, this.inviteRoomId});

  @override
  ConsumerState<FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends ConsumerState<FriendsSheet> {
  final Set<String> _invited = {};
  final Set<String> _pinged = {};
  final Set<String> _answered = {};
  final TextEditingController _search = TextEditingController();
  bool _handleBusy = false;
  String? _handleNote;
  bool _news = false;
  final Set<String> _groupsInvited = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(friendsProvider.notifier).refresh());
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text)));

  /// S2: «ضيف @handle» — by the exact username typed.
  Future<void> _requestHandle(String handle) async {
    if (_handleBusy) return;
    final l = context.l10n;
    setState(() {
      _handleBusy = true;
      _handleNote = null;
    });
    final result = await ref
        .read(friendsProvider.notifier)
        .requestByHandle(handle);
    if (!mounted) return;
    setState(() {
      _handleBusy = false;
      _handleNote = switch (result) {
        HandleRequest.sent => l.friendHandleSent,
        HandleRequest.refused => l.friendHandleRefused,
        HandleRequest.limited => l.friendLimitReached,
        HandleRequest.failed => l.inviteFailed,
      };
    });
  }

  Future<void> _ping(String id, String name, FriendPingKind kind) async {
    final l = context.l10n;
    final refusal = await ref.read(friendsProvider.notifier).ping(id, kind);
    if (!mounted) return;
    if (refusal == null) {
      setState(() {
        if (kind == FriendPingKind.letsPlay) {
          _pinged.add(id);
        } else {
          _answered.add(id);
        }
      });
      if (kind == FriendPingKind.letsPlay) _say(l.friendPingSent(name));
    } else {
      _say(refusal == 'RATE_LIMITED' ? l.friendPingLimit : l.inviteFailed);
    }
  }

  String _pingLine(FriendPing ping) {
    final l = context.l10n;
    return switch (ping.kind) {
      FriendPingKind.letsPlay => l.friendPingAsks(ping.name),
      FriendPingKind.coming => l.friendPingReply(ping.name, l.friendPingComing),
      FriendPingKind.fiveMin => l.friendPingReply(
        ping.name,
        l.friendPingFiveMin,
      ),
      FriendPingKind.notNow => l.friendPingReply(ping.name, l.friendPingNotNow),
    };
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _needle =>
      _search.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();

  /// Whether a row matches what was typed: by name, or by room code.
  bool _hit(String name, [String? code]) {
    final q = _needle;
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        (code?.toLowerCase().contains(q) ?? false);
  }

  /// «شيل من أصحابك», asked once more before it happens.
  Future<void> _confirmRemove(String id, String name) async {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radii.dialog),
        ),
        content: Text(
          l.friendRemoveConfirm(name),
          style: type.body.copyWith(color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            key: FriendsSheetKeys.removeCancel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            key: FriendsSheetKeys.removeYes,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.friendRemoveYes),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final friends = ref.read(friendsProvider.notifier);
    await friends.remove(id);
    // The list as the server now has it.
    await friends.refresh();
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
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final inviting = widget.inviteRoomId != null;

    Widget heading(String text) => Padding(
      padding: EdgeInsets.only(top: s.md, bottom: s.xs),
      child: Text(
        text,
        style: DeckTokens.meta(
          type,
        ).copyWith(color: colors.textMuted, fontWeight: FontWeight.w700),
      ),
    );

    final children = <Widget>[];
    if (friends != null) {
      final invites = inviting
          ? const <RoomInviteEntry>[]
          : [
              for (final i in friends.invites)
                if (_hit(i.name, i.code)) i,
            ];
      final requests = [
        for (final f in friends.incoming)
          if (_hit(f.name)) f,
      ];
      final mine = [
        for (final f in friends.friends)
          if (_hit(f.name, f.presence.code)) f,
      ];
      final recent = [
        for (final f in friends.recent)
          if (_hit(f.name)) f,
      ];

      final pings = friends.pings;
      if (!inviting && _needle.isEmpty && pings.isNotEmpty) {
        children.add(heading(l.friendPingsTitle));
        for (final ping in pings) {
          final asks = ping.kind == FriendPingKind.letsPlay;
          children.add(
            _Row(
              name: ping.name,
              gender: 'unspecified',
              line: _pingLine(ping),
              lit: asks,
              chips: [
                if (asks && !_answered.contains(ping.fromId))
                  for (final (kind, label) in [
                    (FriendPingKind.coming, l.friendPingComing),
                    (FriendPingKind.fiveMin, l.friendPingFiveMin),
                    (FriendPingKind.notNow, l.friendPingNotNow),
                  ])
                    _Chip(
                      key: FriendsSheetKeys.answer(ping.fromId, kind.wire),
                      label: label,
                      quiet: kind != FriendPingKind.coming,
                      onPressed: () => _ping(ping.fromId, ping.name, kind),
                    ),
              ],
            ),
          );
        }
      }
      // S2: a username typed with @ can be asked directly, whoever it is.
      final typed = _search.text.trim().replaceFirst(RegExp(r'^@'), '');
      if (!inviting &&
          _search.text.trim().startsWith('@') &&
          RegExp(r'^[A-Za-z0-9_\u0621-\u064A\u0660-\u0669]{3,20}$').hasMatch(typed)) {
        children.add(
          _Row(
            name: '@$typed',
            gender: 'unspecified',
            line: _handleNote ?? l.friendHandleLine,
            chips: [
              _Chip(
                key: FriendsSheetKeys.addHandle,
                label: l.friendsAdd,
                onPressed: _handleBusy ? () {} : () => _requestHandle(typed),
              ),
            ],
          ),
        );
      }
      if (invites.isNotEmpty) {
        children.add(heading(l.friendsInvites));
        for (final invite in invites) {
          children.add(
            _Row(
              name: invite.name,
              gender: 'unspecified',
              line: l.friendsInvitedYou(invite.name),
              chips: [
                _Chip(
                  label: l.friendsJoin,
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onJoin(invite.code);
                  },
                ),
              ],
            ),
          );
        }
      }
      if (requests.isNotEmpty) {
        children.add(heading(l.friendsRequestsCount(requests.length)));
        for (final f in requests) {
          children.add(
            _Row(
              name: f.name,
              gender: f.gender,
              frame: f.frame,
              plate: f.plate,
              line: l.friendsWantsYou,
              chips: [
                _Chip(
                  key: FriendsSheetKeys.accept(f.id),
                  label: l.friendsAccept,
                  onPressed: () => controller.respond(f.id, true),
                ),
                _Chip(
                  key: FriendsSheetKeys.decline(f.id),
                  label: l.friendsDecline,
                  quiet: true,
                  onPressed: () => controller.respond(f.id, false),
                ),
              ],
            ),
          );
        }
      }
      children.add(heading(l.friendsYoursCount(mine.length)));
      if (mine.isEmpty) {
        children.add(
          Text(
            _needle.isEmpty ? l.friendsEmpty : l.inviteSearchEmpty,
            key: FriendsSheetKeys.empty,
            style: type.body.copyWith(color: colors.textMuted),
          ),
        );
      }
      for (final f in mine) {
        final joinable = f.presence.place == FriendPlace.lobby;
        children.add(
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
            lit: joinable,
            menu: IconButton(
              key: FriendsSheetKeys.remove(f.id),
              tooltip: l.friendRemove,
              onPressed: () => _confirmRemove(f.id, f.name),
              icon: const Icon(Icons.more_vert_rounded),
            ),
            chips: [
              if (inviting)
                if (_invited.contains(f.id))
                  Text(
                    l.friendsInvited,
                    style: type.caption.copyWith(color: colors.accentGold),
                  )
                else
                  _Chip(
                    label: l.friendsInvite,
                    quiet: true,
                    onPressed: () async {
                      final sent = await controller.invite(
                        f.id,
                        widget.inviteRoomId!,
                      );
                      if (sent && mounted) {
                        setState(() => _invited.add(f.id));
                      }
                    },
                  )
              else if (joinable)
                _Chip(
                  label: l.friendsJoin,
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onJoin(f.presence.code!);
                  },
                )
              else if (f.presence.place == FriendPlace.away)
                if (_pinged.contains(f.id))
                  Text(
                    l.friendPingDelivered,
                    style: type.caption.copyWith(color: colors.accentGold),
                  )
                else
                  _Chip(
                    key: FriendsSheetKeys.ping(f.id),
                    label: l.friendPingAction,
                    quiet: true,
                    onPressed: () =>
                        _ping(f.id, f.name, FriendPingKind.letsPlay),
                  ),
            ],
            // S4: the row itself opens «تاريخكم».
            onTap: inviting
                ? null
                : () => showFriendProfileSheet(
                    context,
                    friend: f,
                    onPing: () => _ping(f.id, f.name, FriendPingKind.letsPlay),
                    onRemove: () => _confirmRemove(f.id, f.name),
                  ),
            tapKey: FriendsSheetKeys.profile(f.id),
          ),
        );
      }
      if (recent.isNotEmpty) {
        children.add(heading(l.friendsRecent));
        for (final f in recent) {
          children.add(
            _Row(
              name: f.name,
              gender: f.gender,
              frame: f.frame,
              plate: f.plate,
              line: l.friendsMatchesTogether(f.matches),
              chips: [
                if (friends.outgoing.any((o) => o.id == f.id))
                  Text(
                    l.friendsPending,
                    style: type.caption.copyWith(color: colors.textMuted),
                  )
                else
                  _Chip(
                    label: l.friendsAdd,
                    quiet: true,
                    onPressed: () => controller.request(f.id),
                  ),
              ],
            ),
          );
        }
      }
      // Improvement 2: people I may know.
      final suggestions = [
        for (final p in friends.suggestions)
          if (_hit(p.name) &&
              !friends.friends.any((f) => f.id == p.userId) &&
              !friends.recent.any((f) => f.id == p.userId))
            p,
      ];
      if (!inviting && suggestions.isNotEmpty) {
        children.add(heading(l.friendSuggestions));
        for (final p in suggestions) {
          children.add(
            _Row(
              name: p.name,
              gender: p.gender,
              line: p.matchesTogether != null
                  ? l.friendsMatchesTogether(p.matchesTogether!)
                  : l.friendMutual(p.mutualFriends ?? 0),
              chips: [
                if (friends.outgoing.any((o) => o.id == p.userId))
                  Text(
                    l.friendsPending,
                    style: type.caption.copyWith(color: colors.textMuted),
                  )
                else
                  _Chip(
                    key: FriendsSheetKeys.suggest(p.userId),
                    label: l.friendsAdd,
                    quiet: true,
                    onPressed: () => controller.request(p.userId),
                  ),
              ],
            ),
          );
        }
      }
      // Improvement 1: «الشلة». From the lobby a whole group is invited at once.
      if (_needle.isEmpty && (friends.groups.isNotEmpty || !inviting)) {
        children.add(heading(l.crewTitle));
        for (final g in friends.groups) {
          children.add(
            _Row(
              name: g.name,
              gender: 'unspecified',
              line: g.members.map((m) => m.name).join(l.listSeparator),
              chips: [
                if (inviting)
                  if (_groupsInvited.contains(g.id))
                    Text(
                      l.friendsInvited,
                      style: type.caption.copyWith(color: colors.accentGold),
                    )
                  else
                    _Chip(
                      key: FriendsSheetKeys.inviteGroup(g.id),
                      label: l.groupInvite,
                      onPressed: () async {
                        final sent = await ref
                            .read(friendsExtrasApiProvider)
                            .inviteGroup(g.id, widget.inviteRoomId!);
                        if (!mounted) return;
                        if (sent != null) {
                          setState(() => _groupsInvited.add(g.id));
                        } else {
                          _say(l.inviteFailed);
                        }
                      },
                    )
                else
                  _Chip(
                    label: l.groupEdit,
                    quiet: true,
                    onPressed: () => showGroupEditor(
                      context,
                      friends: friends.friends,
                      group: g,
                      onSaved: controller.setGroups,
                    ),
                  ),
              ],
            ),
          );
        }
        if (!inviting && friends.friends.isNotEmpty) {
          children.add(
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: FriendsSheetKeys.newGroup,
                onPressed: () => showGroupEditor(
                  context,
                  friends: friends.friends,
                  onSaved: controller.setGroups,
                ),
                icon: const Icon(Icons.group_add_outlined),
                label: Text(l.groupNew),
              ),
            ),
          );
        }
      }
      // How others find this player: the handle and the two switches.
      if (!inviting && _needle.isEmpty) {
        children.add(SizedBox(height: s.md));
        children.add(const DirectorySettings());
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(s.md, s.sm, s.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!keyboardOpen) ...[
                Text(
                  l.friendsSheetTitle,
                  style: type.headline.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: s.sm),
                // S5: «أصحابك» and «الأخبار», a small tab, not a social page.
                if (!inviting && friends != null) ...[
                  SegmentedButton<bool>(
                    key: FriendsSheetKeys.tabs,
                    segments: [
                      ButtonSegment(value: false, label: Text(l.friendsTabList)),
                      ButtonSegment(value: true, label: Text(l.friendsTabNews)),
                    ],
                    selected: {_news},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() => _news = v.first),
                  ),
                  SizedBox(height: s.sm),
                ],
              ],
              TextField(
                key: FriendsSheetKeys.search,
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.friendsSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          key: FriendsSheetKeys.clear,
                          tooltip: l.sheetClose,
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: FriendsSheetKeys.list,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(s.md, 0, s.md, s.md),
            children: [
              if (friends == null && async.isLoading)
                Padding(
                  padding: EdgeInsets.all(s.xl),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              if (_news && !inviting) const FriendsFeedView() else ...children,
            ],
          ),
        ),
      ],
    );
  }
}

/// Keys for the friends sheet's controls.
abstract final class FriendsSheetKeys {
  static Key remove(String id) => ValueKey('friend_remove_$id');
  static Key accept(String id) => ValueKey('friend_accept_$id');
  static Key decline(String id) => ValueKey('friend_decline_$id');
  static Key ping(String id) => ValueKey('friend_ping_$id');
  static Key profile(String id) => ValueKey('friend_profile_$id');
  static Key answer(String id, String kind) =>
      ValueKey('friend_answer_${id}_$kind');
  static const addHandle = ValueKey('friend_add_handle');
  static const tabs = ValueKey('friends_tabs');
  static const newGroup = ValueKey('friends_new_group');
  static Key suggest(String id) => ValueKey('friend_suggest_$id');
  static Key inviteGroup(String id) => ValueKey('friend_invite_group_$id');
  static const removeYes = ValueKey('friend_remove_yes');
  static const removeCancel = ValueKey('friend_remove_cancel');
  static const search = ValueKey('friends_search');
  static const clear = ValueKey('friends_search_clear');
  static const list = ValueKey('friends_list');
  static const empty = ValueKey('friends_empty');
}

/// A small action under a name: bone-filled, or a quiet outline.
class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool quiet;
  const _Chip({
    super.key,
    required this.label,
    required this.onPressed,
    this.quiet = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    const size = Size(0, FriendsTokens.chipHeight);
    final padding = EdgeInsets.symmetric(horizontal: s.md);
    return quiet
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              padding: padding,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(label),
          )
        : FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: size,
              padding: padding,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(label),
          );
  }
}

class _Row extends StatelessWidget {
  final String name;
  final String gender;
  final String line;

  /// What this row can do, under the name. Empty draws nothing.
  final List<Widget> chips;

  /// A friend's secondary control (remove), at the end of the row.
  final Widget? menu;
  final bool lit;
  final String? frame;
  final String? plate;

  /// The name and avatar open something (a friend's profile), when set.
  final VoidCallback? onTap;
  final Key? tapKey;
  const _Row({
    required this.name,
    required this.gender,
    required this.line,
    this.chips = const [],
    this.menu,
    this.lit = false,
    this.frame,
    this.plate,
    this.onTap,
    this.tapKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = context.spacing;
    final type = context.typography;
    return Container(
      padding: EdgeInsets.symmetric(vertical: s.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: tapKey,
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: CosmeticFrameRing(
              frame: frame,
              diameter: FriendsTokens.avatar,
              child: _avatar(colors),
            ),
          ),
          SizedBox(width: s.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: CosmeticNameplate(
                    name: name,
                    plate: plate,
                    style: type.body.emphasised.copyWith(
                      color: colors.textPrimary,
                    ),
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
                if (chips.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: s.xs),
                    child: Wrap(
                      spacing: s.sm,
                      runSpacing: s.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: chips,
                    ),
                  ),
              ],
            ),
          ),
          ?menu,
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
