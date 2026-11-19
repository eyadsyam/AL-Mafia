import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/online_backend.dart' show BackendException;
import '../l10n_ext.dart';
import '../screens/online/online_session.dart'
    show onlineBackendFactoryProvider;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../western_digits.dart';
import '../widgets/deck/deck_buttons.dart';
import '../widgets/deck/deck_public.dart' show showDeckSheet;
import 'friends.dart' show FriendEntry;

/// Friends v2, the parts beyond the list (owner 2026-11-19): suggestions
/// (improvement 2), «الشلة» groups (improvement 1) and the news tab with the
/// week (S5, improvement 3). Everything comes from finished online matches
/// or from things players did on purpose; never a role in a running match.

@immutable
class FriendSuggestion {
  final String userId;
  final String name;
  final String gender;
  final int? matchesTogether;
  final int? mutualFriends;
  const FriendSuggestion({
    required this.userId,
    required this.name,
    this.gender = 'unspecified',
    this.matchesTogether,
    this.mutualFriends,
  });

  static FriendSuggestion? fromJson(Object? json) {
    if (json is! Map || json['userId'] is! String) return null;
    return FriendSuggestion(
      userId: json['userId'] as String,
      name: (json['name'] as String?) ?? '?',
      gender: (json['gender'] as String?) ?? 'unspecified',
      matchesTogether: (json['matchesTogether'] as num?)?.toInt(),
      mutualFriends: (json['mutualFriends'] as num?)?.toInt(),
    );
  }
}

@immutable
class FriendGroup {
  final String id;
  final String name;
  final List<({String userId, String name})> members;
  const FriendGroup({
    required this.id,
    required this.name,
    this.members = const [],
  });

  static FriendGroup? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    return FriendGroup(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      members: [
        for (final m in (json['members'] as List? ?? const []))
          if (m is Map && m['userId'] is String)
            (
              userId: m['userId'] as String,
              name: (m['name'] as String?) ?? '?',
            ),
      ],
    );
  }

  static List<FriendGroup> listFrom(Object? raw) => [
    for (final row in (raw is List ? raw : const []))
      ?FriendGroup.fromJson(row),
  ];
}

/// The wire codes (the server keeps the same three). The app draws them as
/// icons: no bundled font carries emoji.
const kFriendReactions = ['\u{1F44F}', '\u{1F525}', '\u{1F602}'];
const _reactionIcons = {
  '\u{1F44F}': Icons.celebration_outlined,
  '\u{1F525}': Icons.local_fire_department_outlined,
  '\u{1F602}': Icons.sentiment_very_satisfied_outlined,
};

@immutable
class FeedItem {
  final int id;
  final String name;
  final String kind;
  final Map<String, dynamic> data;
  final DateTime? at;
  final Map<String, int> reactions;
  final String? mine;
  const FeedItem({
    required this.id,
    required this.name,
    required this.kind,
    this.data = const {},
    this.at,
    this.reactions = const {},
    this.mine,
  });

  static FeedItem? fromJson(Object? json) {
    if (json is! Map || json['id'] is! num) return null;
    final reactions = <String, int>{};
    final raw = json['reactions'];
    if (raw is Map) {
      for (final e in kFriendReactions) {
        reactions[e] = (raw[e] as num?)?.toInt() ?? 0;
      }
    }
    return FeedItem(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '?',
      kind: (json['kind'] as String?) ?? '',
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      at: DateTime.tryParse('${json['at']}'),
      reactions: reactions,
      mine: kFriendReactions.contains(json['mine'])
          ? json['mine'] as String
          : null,
    );
  }
}

@immutable
class FriendsFeed {
  final List<FeedItem> items;
  final int matches;
  final int wins;
  final int mafia;
  final ({String name, int count})? topFriend;
  final List<({String name, int wins, bool me})> board;
  const FriendsFeed({
    this.items = const [],
    this.matches = 0,
    this.wins = 0,
    this.mafia = 0,
    this.topFriend,
    this.board = const [],
  });

  factory FriendsFeed.fromJson(Map<String, dynamic> json) {
    final weekly = json['weekly'] is Map
        ? json['weekly'] as Map
        : const <String, dynamic>{};
    final top = weekly['topFriend'];
    return FriendsFeed(
      items: [
        for (final row in (json['items'] as List? ?? const []))
          ?FeedItem.fromJson(row),
      ],
      matches: (weekly['matches'] as num?)?.toInt() ?? 0,
      wins: (weekly['wins'] as num?)?.toInt() ?? 0,
      mafia: (weekly['mafia'] as num?)?.toInt() ?? 0,
      topFriend: top is Map && top['name'] is String
          ? (
              name: top['name'] as String,
              count: (top['count'] as num?)?.toInt() ?? 0,
            )
          : null,
      board: [
        for (final row in (json['board'] as List? ?? const []))
          if (row is Map)
            (
              name: (row['name'] as String?) ?? '?',
              wins: (row['wins'] as num?)?.toInt() ?? 0,
              me: row['me'] == true,
            ),
      ],
    );
  }
}

class FriendsExtrasApi {
  final Ref _ref;
  FriendsExtrasApi(this._ref);

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final backend = await _ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('friends', body);
  }

  Future<FriendsFeed> feed() async =>
      FriendsFeed.fromJson(await _call({'action': 'feed'}));

  Future<void> react(int activityId, String? emoji) =>
      _call({'action': 'react', 'activityId': activityId, 'emoji': emoji});

  Future<List<FriendGroup>> saveGroup({
    String? id,
    required String name,
    required List<String> members,
  }) async => FriendGroup.listFrom(
    (await _call({
      'action': 'groupSave',
      'id': ?id,
      'name': name,
      'members': members,
    }))['groups'],
  );

  Future<List<FriendGroup>> deleteGroup(String id) async =>
      FriendGroup.listFrom(
        (await _call({'action': 'groupDelete', 'id': id}))['groups'],
      );

  /// How many invites went out; null on a refusal.
  Future<int?> inviteGroup(String groupId, String roomId) async {
    try {
      final json = await _call({
        'action': 'inviteGroup',
        'groupId': groupId,
        'roomId': roomId,
      });
      return (json['invited'] as num?)?.toInt() ?? 0;
    } on BackendException {
      return null;
    }
  }
}

final friendsExtrasApiProvider = Provider<FriendsExtrasApi>(
  FriendsExtrasApi.new,
);

/// Read only when the news tab is opened.
final friendsFeedProvider = FutureProvider.autoDispose<FriendsFeed>(
  (ref) => ref.read(friendsExtrasApiProvider).feed(),
);

/// S5 «الأخبار»: what friends did (wins in a row, a new rank), reactions,
/// my week and the friends' board for the week.
class FriendsFeedView extends ConsumerStatefulWidget {
  const FriendsFeedView({super.key});

  static Key reactKey(int id, String emoji) =>
      ValueKey('feed_react_${id}_$emoji');

  @override
  ConsumerState<FriendsFeedView> createState() => _FriendsFeedViewState();
}

class _FriendsFeedViewState extends ConsumerState<FriendsFeedView> {
  final Map<int, String?> _mine = {};
  final Map<int, Map<String, int>> _counts = {};

  Future<void> _react(FeedItem item, String emoji) async {
    final before = _mine.containsKey(item.id) ? _mine[item.id] : item.mine;
    final next = before == emoji ? null : emoji;
    final counts = Map<String, int>.from(_counts[item.id] ?? item.reactions);
    if (before != null) counts[before] = (counts[before] ?? 1) - 1;
    if (next != null) counts[next] = (counts[next] ?? 0) + 1;
    setState(() {
      _mine[item.id] = next;
      _counts[item.id] = counts;
    });
    try {
      await ref.read(friendsExtrasApiProvider).react(item.id, next);
    } catch (_) {
      if (mounted) {
        setState(() {
          _mine.remove(item.id);
          _counts.remove(item.id);
        });
      }
    }
  }

  String _line(FeedItem item) {
    final l = context.l10n;
    return switch (item.kind) {
      'win_streak' => l.feedWinStreak(
        item.name,
        (item.data['count'] as num?)?.toInt() ?? 3,
      ),
      'rank_up' => l.feedRankUp(item.name, '${item.data['title'] ?? ''}'),
      _ => item.name,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final c = context.colors;
    final type = context.typography;
    final feed = ref.watch(friendsFeedProvider);
    return feed.when(
      loading: () => Padding(
        padding: EdgeInsets.all(s.xl),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: EdgeInsets.all(s.lg),
        child: Text(
          l.inviteFailed,
          style: type.body.copyWith(color: c.textMuted),
          textAlign: TextAlign.center,
        ),
      ),
      data: (f) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(top: s.md, bottom: s.xs),
            child: Text(
              l.feedWeekTitle,
              style: DeckTokens.meta(
                type,
              ).copyWith(color: c.textMuted, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            westernDigits(l.feedWeekLine(f.matches, f.wins, f.mafia)),
            style: type.body.copyWith(color: c.textPrimary),
          ),
          if (f.topFriend != null)
            Text(
              westernDigits(
                l.feedWeekTopFriend(f.topFriend!.name, f.topFriend!.count),
              ),
              style: type.caption.copyWith(color: c.textSecondary),
            ),
          if (f.board.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(top: s.md, bottom: s.xs),
              child: Text(
                l.feedBoardTitle,
                style: DeckTokens.meta(
                  type,
                ).copyWith(color: c.textMuted, fontWeight: FontWeight.w700),
              ),
            ),
            for (final (i, row) in f.board.indexed)
              Padding(
                padding: EdgeInsets.symmetric(vertical: s.xs),
                child: Text(
                  westernDigits(
                    '${i + 1}. ${row.me ? l.feedBoardYou : row.name} · ${l.feedBoardWins(row.wins)}',
                  ),
                  style: type.body.copyWith(
                    color: row.me ? c.accentGold : c.textPrimary,
                    fontWeight: row.me ? FontWeight.w700 : null,
                  ),
                ),
              ),
          ],
          Padding(
            padding: EdgeInsets.only(top: s.md, bottom: s.xs),
            child: Text(
              l.feedNewsTitle,
              style: DeckTokens.meta(
                type,
              ).copyWith(color: c.textMuted, fontWeight: FontWeight.w700),
            ),
          ),
          if (f.items.isEmpty)
            Text(l.feedEmpty, style: type.body.copyWith(color: c.textMuted)),
          for (final item in f.items)
            Container(
              padding: EdgeInsets.symmetric(vertical: s.sm),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.borderSubtle)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    westernDigits(_line(item)),
                    style: type.body.copyWith(color: c.textPrimary),
                  ),
                  SizedBox(height: s.xs),
                  Wrap(
                    spacing: s.sm,
                    children: [
                      for (final emoji in kFriendReactions)
                        _ReactionChip(
                          key: FriendsFeedView.reactKey(item.id, emoji),
                          emoji: emoji,
                          count:
                              (_counts[item.id] ?? item.reactions)[emoji] ?? 0,
                          selected:
                              (_mine.containsKey(item.id)
                                  ? _mine[item.id]
                                  : item.mine) ==
                              emoji,
                          onTap: () => _react(item, emoji),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _ReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
    avatar: Icon(_reactionIcons[emoji]),
    label: Text(count > 0 ? westernDigits('$count') : ''),
    selected: selected,
    onSelected: (_) => onTap(),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );
}

/// «الشلة»: create or edit a group of friends (name, up to 15 members).
Future<void> showGroupEditor(
  BuildContext context, {
  required List<FriendEntry> friends,
  FriendGroup? group,
  required ValueChanged<List<FriendGroup>> onSaved,
}) => showDeckSheet<void>(
  context: context,
  title: group == null ? context.l10n.groupNew : group.name,
  body: (_) => _GroupEditor(friends: friends, group: group, onSaved: onSaved),
);

class _GroupEditor extends ConsumerStatefulWidget {
  final List<FriendEntry> friends;
  final FriendGroup? group;
  final ValueChanged<List<FriendGroup>> onSaved;
  const _GroupEditor({
    required this.friends,
    required this.group,
    required this.onSaved,
  });

  @override
  ConsumerState<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends ConsumerState<_GroupEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.group?.name ?? '',
  );
  late final Set<String> _members = {
    for (final m in widget.group?.members ?? const []) m.userId,
  };
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 20 || _members.isEmpty) {
      setState(() => _error = l.groupInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final groups = await ref
          .read(friendsExtrasApiProvider)
          .saveGroup(id: widget.group?.id, name: name, members: [..._members]);
      if (!mounted) return;
      widget.onSaved(groups);
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) setState(() => _error = l.inviteFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final id = widget.group?.id;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final groups = await ref.read(friendsExtrasApiProvider).deleteGroup(id);
      if (!mounted) return;
      widget.onSaved(groups);
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.inviteFailed);
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          maxLength: 20,
          decoration: InputDecoration(
            labelText: l.groupName,
            errorText: _error,
            counterText: '',
          ),
        ),
        SizedBox(height: s.sm),
        Text(
          westernDigits(l.groupMembers(_members.length)),
          style: type.caption.copyWith(color: c.textMuted),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.sizeOf(context).height * FriendsTokens.groupListMax,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final f in widget.friends)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(f.name, style: type.body),
                  value: _members.contains(f.id),
                  onChanged: (on) => setState(() {
                    if (on == true &&
                        _members.length < FriendsTokens.groupMax) {
                      _members.add(f.id);
                    } else if (on != true) {
                      _members.remove(f.id);
                    }
                  }),
                ),
            ],
          ),
        ),
        SizedBox(height: s.md),
        BoneButton(label: l.groupSave, onPressed: _busy ? null : _save),
        if (widget.group != null)
          TextButton(
            onPressed: _busy ? null : _delete,
            child: Text(
              l.groupDelete,
              style: type.body.copyWith(color: c.textMuted),
            ),
          ),
      ],
    );
  }
}
