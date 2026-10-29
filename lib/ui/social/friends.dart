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
import '../screens/online/online_session.dart';
import 'directory.dart';
import 'directory_settings.dart';

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

  /// This player's directory entry (handle and the two switches).
  final DirectoryMe me;
  const FriendsState({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.recent = const [],
    this.invites = const [],
    this.me = const DirectoryMe(),
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
      me: DirectoryMe.fromJson(json['me']),
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
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(friendsProvider.notifier).refresh());
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
        style: DeckTokens.meta(type).copyWith(
          color: colors.textMuted,
          fontWeight: FontWeight.w700,
        ),
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
                ),
            ],
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
              ...children,
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
  const _Row({
    required this.name,
    required this.gender,
    required this.line,
    this.chips = const [],
    this.menu,
    this.lit = false,
    this.frame,
    this.plate,
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
