import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/models/player.dart' show PlayerGender;
import '../../economy/cosmetic_paint.dart';
import '../../economy/vault_kit.dart';
import '../../l10n_ext.dart';
import '../../social/directory.dart';
import '../../social/friends.dart';
import '../../social/push_prompt.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/player_avatar.dart';

/// «ادعي صحابك» — invite anyone into this lobby, inside the scene (doc 12
/// §2.1: a layer in the lobby's Stack, never a route or a dialog).
///
/// Three tabs: الأصحاب (friends, by id as before), دوّر بالاسم (search by
/// name or handle) and ناس قريبة (discover, ranked without any location
/// permission, with four filter chips). Each row is the person's public
/// identity — frame, plate, level, state — and one «ادعي» that becomes
/// «اتبعتت ✓». Opening it is the in-context moment to ask for notification
/// permission (never on first launch).
class InviteSheet extends ConsumerStatefulWidget {
  final bool visible;
  final String roomId;
  final VoidCallback onDismiss;

  /// The lobby's own share (room link + the sharer's referral code, with its
  /// copied/failed feedback), offered at the top of the sheet. Null hides it.
  final void Function(BuildContext button)? onShare;

  /// The referral offer line under the share button, when referrals are on.
  final bool referralOffer;
  const InviteSheet({
    super.key,
    required this.visible,
    required this.roomId,
    required this.onDismiss,
    this.onShare,
    this.referralOffer = false,
  });

  static const Key sheetKey = ValueKey('invite_sheet');
  static const Key scrimKey = ValueKey('invite_sheet_scrim');
  static const Key searchField = ValueKey('invite_search_field');
  static const Key shareKey = ValueKey('invite_room_share');
  static const Key offerKey = ValueKey('invite_referral_offer');
  static Key tabKey(int i) => ValueKey('invite_tab_$i');
  static Key filterKey(DiscoverFilter f) => ValueKey('invite_filter_${f.name}');
  static Key rowKey(String id) => ValueKey('invite_row_$id');
  static Key buttonKey(String id) => ValueKey('invite_button_$id');

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

enum _Send { sending, sent, failed }

class _InviteSheetState extends ConsumerState<InviteSheet> {
  int _tab = 0;
  final _query = TextEditingController();
  Timer? _debounce;
  DirectoryPage? _found;
  bool _searching = false;
  DiscoverFilter? _filter;
  DirectoryPage? _near;
  int _nearPage = 0;
  bool _loadingNear = false;
  final Map<String, _Send> _sent = {};
  @override
  void initState() {
    super.initState();
    if (widget.visible) _opened();
  }

  @override
  void didUpdateWidget(InviteSheet old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _opened();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _opened() {
    unawaited(ref.read(pushPromptProvider).askInContext());
    if (_tab == 2 && _near == null) _loadNear();
  }

  void _select(int tab) {
    setState(() => _tab = tab);
    if (tab == 2 && _near == null) _loadNear();
  }

  void _onQuery(String text) {
    _debounce?.cancel();
    _debounce = Timer(InviteTokens.searchDebounce, () => _search(text));
  }

  Future<void> _search(String text) async {
    final q = text.trim().replaceFirst(RegExp(r'^@'), '');
    if (q.length < 2) {
      setState(() => _found = null);
      return;
    }
    setState(() => _searching = true);
    try {
      final page = await ref.read(directoryApiProvider).search(q);
      if (mounted && _query.text == text) setState(() => _found = page);
    } catch (_) {
      if (mounted) setState(() => _found = DirectoryPage.empty);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _loadNear({bool more = false}) async {
    if (_loadingNear) return;
    final page = more ? _nearPage + 1 : 0;
    setState(() => _loadingNear = true);
    try {
      final next = await ref
          .read(directoryApiProvider)
          .discover(_filter, page: page);
      if (!mounted) return;
      setState(() {
        _nearPage = page;
        _near = more && _near != null
            ? DirectoryPage([..._near!.rows, ...next.rows], more: next.more)
            : next;
      });
    } catch (_) {
      if (mounted) setState(() => _near ??= DirectoryPage.empty);
    } finally {
      if (mounted) setState(() => _loadingNear = false);
    }
  }

  void _setFilter(DiscoverFilter? f) {
    setState(() {
      _filter = f;
      _near = null;
    });
    _loadNear();
  }

  Future<void> _invite(String key, Future<bool> Function() send) async {
    if (_sent[key] == _Send.sending || _sent[key] == _Send.sent) return;
    setState(() => _sent[key] = _Send.sending);
    final ok = await send();
    if (!mounted) return;
    setState(() => _sent[key] = ok ? _Send.sent : _Send.failed);
    if (!ok) {
      Timer(InviteTokens.failedHold, () {
        if (mounted && _sent[key] == _Send.failed) {
          setState(() => _sent.remove(key));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final height = MediaQuery.sizeOf(context).height * InviteTokens.sheetHeight;
    return Stack(
      key: InviteSheet.sheetKey,
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: InviteSheet.scrimKey,
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: ColoredBox(
              color: colors.surfaceBase.withValues(
                alpha: InviteTokens.scrimAlpha,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(s.sm),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: height),
                child: Material(
                  type: MaterialType.transparency,
                  child: VaultCard(
                    lit: true,
                    children: [
                      VaultHeading(
                        title: l.inviteSheetTitle,
                        leading: const Icon(
                          Icons.group_add_rounded,
                          color: VaultTokens.gold,
                        ),
                        trailing: IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: widget.onDismiss,
                          icon: Icon(
                            Icons.close_rounded,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      if (widget.onShare case final share?) ...[
                        SizedBox(height: s.xs),
                        Builder(
                          builder: (button) => OutlinedButton.icon(
                            key: InviteSheet.shareKey,
                            onPressed: () => share(button),
                            icon: const Icon(Icons.ios_share_rounded),
                            label: Text(l.onlineShare),
                          ),
                        ),
                        if (widget.referralOffer) ...[
                          SizedBox(height: s.xs),
                          Text(
                            l.onlineReferralOffer,
                            key: InviteSheet.offerKey,
                            textAlign: TextAlign.center,
                            style: context.typography.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                      SizedBox(height: s.sm),
                      _Tabs(
                        selected: _tab,
                        labels: [
                          l.inviteTabFriends,
                          l.inviteTabSearch,
                          l.inviteTabNearby,
                        ],
                        onSelect: _select,
                      ),
                      SizedBox(height: s.sm),
                      Expanded(
                        child: switch (_tab) {
                          0 => _friends(context),
                          1 => _searchTab(context),
                          _ => _nearTab(context),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _friends(BuildContext context) {
    final l = context.l10n;
    final friends = ref.watch(friendsProvider).valueOrNull?.friends ?? const [];
    if (friends.isEmpty) return _Empty(l.inviteFriendsEmpty);
    return ListView(
      children: [
        for (final f in friends)
          _InviteRow(
            id: f.id,
            name: f.name,
            gender: f.gender,
            frame: f.frame,
            plate: f.plate,
            presence: switch (f.presence.place) {
              FriendPlace.lobby => DirectoryPresence.lobby,
              FriendPlace.playing => DirectoryPresence.playing,
              FriendPlace.away => DirectoryPresence.away,
            },
            state: _sent['id:${f.id}'],
            onInvite: () => _invite(
              'id:${f.id}',
              () => ref
                  .read(friendsProvider.notifier)
                  .invite(f.id, widget.roomId),
            ),
          ),
      ],
    );
  }

  Widget _searchTab(BuildContext context) {
    final l = context.l10n;
    final found = _found;
    return Column(
      children: [
        TextField(
          key: InviteSheet.searchField,
          controller: _query,
          onChanged: _onQuery,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: l.inviteSearchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searching
                ? Padding(
                    padding: EdgeInsets.all(context.spacing.sm),
                    child: const SizedBox.square(
                      dimension: InviteTokens.spinner,
                      child: CircularProgressIndicator(
                        strokeWidth: InviteTokens.spinnerStroke,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        SizedBox(height: context.spacing.sm),
        Expanded(
          child: found == null
              ? _Empty(l.inviteSearchShort)
              : found.rows.isEmpty
              ? _Empty(l.inviteSearchEmpty)
              : _rows(found.rows),
        ),
      ],
    );
  }

  Widget _nearTab(BuildContext context) {
    final l = context.l10n;
    final near = _near;
    final chips = {
      DiscoverFilter.near: l.inviteFilterNear,
      DiscoverFilter.online: l.inviteFilterOnline,
      DiscoverFilter.played: l.inviteFilterPlayed,
      DiscoverFilter.level: l.inviteFilterLevel,
    };
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in chips.entries)
                Padding(
                  padding: EdgeInsetsDirectional.only(end: context.spacing.xs),
                  child: FilterChip(
                    key: InviteSheet.filterKey(e.key),
                    label: Text(e.value),
                    selected: _filter == e.key,
                    selectedColor: VaultTokens.gold.withValues(
                      alpha: InviteTokens.chipAlpha,
                    ),
                    checkmarkColor: VaultTokens.gold,
                    onSelected: (on) => _setFilter(on ? e.key : null),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: context.spacing.sm),
        Expanded(
          child: near == null
              ? const Center(child: CircularProgressIndicator())
              : near.rows.isEmpty
              ? _Empty(l.inviteNearbyEmpty)
              : _rows(
                  near.rows,
                  more: near.more
                      ? TextButton(
                          onPressed: _loadingNear
                              ? null
                              : () => _loadNear(more: true),
                          child: Text(l.inviteMore),
                        )
                      : null,
                ),
        ),
      ],
    );
  }

  Widget _rows(List<DirectoryRow> rows, {Widget? more}) => ListView(
    children: [
      for (final r in rows)
        _InviteRow(
          id: r.handle,
          name: r.name,
          handle: r.handle,
          gender: r.gender,
          level: r.level,
          frame: r.frame,
          plate: r.plate,
          presence: r.presence,
          state: _sent['h:${r.handle}'],
          onInvite: () => _invite(
            'h:${r.handle}',
            () => ref
                .read(directoryApiProvider)
                .inviteHandle(r.handle, widget.roomId),
          ),
        ),
      ?more,
    ],
  );
}

/// Three segments in the vault look: the selected one lit gold.
class _Tabs extends StatelessWidget {
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelect;
  const _Tabs({
    required this.selected,
    required this.labels,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.xs / 2),
              child: TextButton(
                key: InviteSheet.tabKey(i),
                style: selected == i
                    ? vaultGoldStyle(context)
                    : vaultOutlineStyle(context),
                onPressed: () => onSelect(i),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    style: TextStyle(
                      color: selected == i ? null : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(context.spacing.md),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.typography.body.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    ),
  );
}

class _InviteRow extends StatelessWidget {
  final String id;
  final String name;
  final String? handle;
  final String gender;
  final int? level;
  final String? frame;
  final String? plate;
  final DirectoryPresence presence;
  final _Send? state;
  final VoidCallback onInvite;
  const _InviteRow({
    required this.id,
    required this.name,
    required this.gender,
    required this.presence,
    required this.state,
    required this.onInvite,
    this.handle,
    this.level,
    this.frame,
    this.plate,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final (label, dot) = switch (presence) {
      DirectoryPresence.online => (l.inviteStateOnline, colors.accentSage),
      DirectoryPresence.lobby => (l.inviteStateLobby, VaultTokens.gold),
      DirectoryPresence.playing => (l.inviteStatePlaying, colors.accentCrimson),
      DirectoryPresence.away => (l.inviteStateAway, colors.textMuted),
    };
    final details = [
      if (handle != null) '@$handle',
      if (level != null) l.inviteLevel(level!),
    ].join(' · ');
    return Padding(
      key: InviteSheet.rowKey(id),
      padding: EdgeInsets.symmetric(vertical: s.xs),
      child: Row(
        children: [
          CosmeticFrameRing(
            frame: frame,
            diameter: InviteTokens.rowAvatar,
            child: PlayerAvatar(
              name: name,
              gender: PlayerGender.values.firstWhere(
                (g) => g.name == gender,
                orElse: () => PlayerGender.unspecified,
              ),
              diameter: InviteTokens.rowAvatar,
            ),
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CosmeticNameplate(
                  name: name,
                  plate: plate,
                  style: context.typography.body.emphasised.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: InviteTokens.stateDot,
                      height: InviteTokens.stateDot,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: s.xs),
                    Flexible(
                      child: Text(
                        details.isEmpty ? label : '$label · $details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: s.xs),
          switch (state) {
            // «اتبعتت ✓»: the tick is an icon, not a glyph the Arabic face
            // may not carry.
            _Send.sent => Row(
              key: InviteSheet.buttonKey(id),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.inviteSent,
                  style: context.typography.body.copyWith(
                    color: VaultTokens.gold,
                  ),
                ),
                SizedBox(width: s.xs),
                const Icon(Icons.check_rounded, color: VaultTokens.gold),
              ],
            ),
            _Send.failed => Tooltip(
              message: l.inviteFailed,
              child: Icon(
                Icons.error_outline_rounded,
                key: InviteSheet.buttonKey(id),
                color: colors.accentCrimson,
              ),
            ),
            _ => FilledButton(
              key: InviteSheet.buttonKey(id),
              style: vaultGoldStyle(context),
              onPressed: state == _Send.sending ? null : onInvite,
              child: Text(l.inviteSend),
            ),
          },
        ],
      ),
    );
  }
}
