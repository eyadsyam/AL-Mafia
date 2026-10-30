import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player_profile.dart';
import '../../platform/audio_director.dart';
import '../l10n_ext.dart';
import '../screens/setup/optional_roles.dart';
import '../screens/setup/role_deal_grid.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/deck/deck_public.dart';
import 'all_access.dart';
import 'cosmetic_paint.dart';
import 'cosmetics.dart';
import 'store_art.dart';
import 'table_tool_names.g.dart';
import 'table_tools.dart';
import 'wallet.dart';

/// «خزنتي» (owner, 2026-10-29): «انا اشتريت حاجه … طريقة استخدامي ليها وحش و
/// مش ظاهر كويس». What the player owns, each kind in its own room with its own
/// art and the one choice that kind has, instead of a list of rows:
///
/// * roles: the cards themselves, and where they join a match;
/// * the narrator: who tells the story, heard before it is chosen;
/// * the room's atmosphere: the scene and its opening line;
/// * the look: the player's own seat as the table draws it;
/// * the tool bag: every tool's art, when it can be used, and how many are
///   left («من غير عدد» on an owner grant).
///
/// A store surface: nothing here is drawn during a match, and nothing names
/// a role anyone holds (Doc 05).
enum MyVaultPage { hub, roles, narrator, room, look, tools }

class MyVaultTab extends StatefulWidget {
  final WalletState wallet;
  final bool busy;
  final Future<void> Function(CosmeticSlot slot, String? code) onEquip;

  const MyVaultTab({
    super.key,
    required this.wallet,
    required this.busy,
    required this.onEquip,
  });

  static Key tile(MyVaultPage page) => ValueKey('my_vault_${page.name}');
  static const Key backKey = ValueKey('my_vault_back');
  static Key pick(String code) => ValueKey('my_vault_pick_$code');

  @override
  State<MyVaultTab> createState() => _MyVaultTabState();
}

class _MyVaultTabState extends State<MyVaultTab> {
  MyVaultPage _page = MyVaultPage.hub;

  void _go(MyVaultPage page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    final body = switch (_page) {
      MyVaultPage.hub => _Hub(wallet: widget.wallet, onOpen: _go),
      MyVaultPage.roles => _RolesRoom(wallet: widget.wallet),
      MyVaultPage.narrator => _NarratorRoom(
        wallet: widget.wallet,
        busy: widget.busy,
        onEquip: widget.onEquip,
      ),
      MyVaultPage.room => _SceneRoom(
        wallet: widget.wallet,
        busy: widget.busy,
        onEquip: widget.onEquip,
      ),
      MyVaultPage.look => VaultLookRoom(
        wallet: widget.wallet,
        busy: widget.busy,
        onEquip: widget.onEquip,
      ),
      MyVaultPage.tools => const VaultToolBag(),
    };
    if (_page == MyVaultPage.hub) return body;
    // System back steps out of a room, not out of the vault.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(MyVaultPage.hub);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              key: MyVaultTab.backKey,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => _go(MyVaultPage.hub),
              icon: const BackButtonIcon(),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

List<String> _ownedOf(WalletState wallet, CosmeticKind kind) => [
  for (final e in Cosmetics.items.entries)
    if (e.value.kind == kind && wallet.owned.contains(e.key)) e.key,
];

String? _equipped(WalletState wallet, CosmeticSlot slot) =>
    wallet.equipped[slot.wire];

class _Hub extends ConsumerWidget {
  final WalletState wallet;
  final ValueChanged<MyVaultPage> onOpen;
  const _Hub({required this.wallet, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final unlimited = ref.watch(allAccessProvider) || wallet.allAccess;
    final me = ref.watch(playerProfileProvider).valueOrNull?.name;
    final roles = [
      for (final r in OptionalRole.values)
        if (wallet.owned.contains(r.code)) r,
    ];
    final narrator = _equipped(wallet, CosmeticSlot.narrator);
    final pack = _equipped(wallet, CosmeticSlot.roomPack);
    final frame = _equipped(wallet, CosmeticSlot.frame);
    final plate = _equipped(wallet, CosmeticSlot.nameplate);
    String nameOf(String? code) => code == null
        ? l.vaultLookNone
        : (Cosmetics.items[code]?.name(l) ?? l.vaultLookNone);

    Widget label(String title, String sub) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: DeckTokens.card(
            type,
          ).copyWith(color: colors.textPrimary, fontWeight: FontWeight.w800),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DeckTokens.meta(type).copyWith(color: colors.textSecondary),
        ),
      ],
    );

    Widget tile(MyVaultPage page, Widget child, {String? art}) => Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(context.radii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: MyVaultTab.tile(page),
        onTap: () => onOpen(page),
        child: art == null
            ? Padding(padding: EdgeInsets.all(s.sm), child: child)
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    art,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ColoredBox(
                      color: colors.surfaceBase.withValues(
                        alpha: MyVaultTokens.tileMarkAlpha,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.all(s.sm),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    return ListView(
      padding: EdgeInsets.all(s.md),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.vaultMineTitle,
                    style: DeckTokens.title(
                      type,
                    ).copyWith(color: colors.textPrimary),
                  ),
                  Text(
                    l.vaultMineSub,
                    style: DeckTokens.meta(
                      type,
                    ).copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (unlimited) _GoldPill(text: l.vaultAllOpen),
          ],
        ),
        SizedBox(height: s.md),
        SizedBox(
          height: MyVaultTokens.rolesTile,
          child: tile(
            MyVaultPage.roles,
            Row(
              children: [
                SizedBox(
                  width:
                      MyVaultTokens.fanCard.width + 2 * MyVaultTokens.fanSpread,
                  child: _RoleFan(roles: OptionalRole.values, owned: roles),
                ),
                SizedBox(width: s.md),
                Expanded(
                  child: label(
                    l.vaultRolesTitle,
                    l.vaultRolesActive(
                      roles.length,
                      OptionalRole.values.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: MyVaultTokens.tileGap),
        SizedBox(
          height: MyVaultTokens.tile,
          child: Row(
            children: [
              Expanded(
                child: tile(
                  MyVaultPage.narrator,
                  label(l.vaultNarratorTitle, nameOf(narrator)),
                  art: StoreArt.forCode(
                    narrator ??
                        _ownedOf(
                          wallet,
                          CosmeticKind.narratorPack,
                        ).firstOrNull ??
                        'narrator_storyteller',
                  ),
                ),
              ),
              // The room scenes are off sale (store v4): the room only shows
              // for a player who already holds one, never as an empty room.
              if (_ownedOf(wallet, CosmeticKind.presentationPack) case [
                final first,
                ...,
              ]) ...[
                const SizedBox(width: MyVaultTokens.tileGap),
                Expanded(
                  child: tile(
                    MyVaultPage.room,
                    label(l.vaultRoomTitle, nameOf(pack)),
                    art: StoreArt.forCode(pack ?? first),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: MyVaultTokens.tileGap),
        SizedBox(
          height: MyVaultTokens.tile,
          child: Row(
            children: [
              Expanded(
                child: tile(
                  MyVaultPage.look,
                  Column(
                    children: [
                      Expanded(
                        child: FittedBox(
                          child: SeatPreview(
                            name: me ?? l.vaultLookTitle,
                            frame: frame,
                            plate: plate,
                          ),
                        ),
                      ),
                      Text(
                        l.vaultLookTitle,
                        style: DeckTokens.card(type).copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: MyVaultTokens.tileGap),
              Expanded(
                child: tile(
                  MyVaultPage.tools,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: MyVaultTokens.toolColumns,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (final code in const [
                              'lock_door',
                              'sense',
                              'double_vote',
                              'vote_shield',
                              'extra_minute',
                              'impersonate',
                            ])
                              ToolIcon(code: code, size: MyVaultTokens.toolArt),
                          ],
                        ),
                      ),
                      label(
                        l.vaultToolsTitle,
                        unlimited ? l.vaultToolsUnlimited : l.vaultToolsWhere,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoldPill extends StatelessWidget {
  final String text;
  const _GoldPill({required this.text});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: VaultTokens.gold,
      borderRadius: BorderRadius.all(Radius.circular(DeckTokens.pill)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xs / 2,
      ),
      child: Text(
        text,
        style: context.typography.caption.copyWith(
          color: VaultTokens.goldInk,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// The three sold roles fanned: owned ones ringed in gold, the rest dimmed.
class _RoleFan extends StatelessWidget {
  final List<OptionalRole> roles;
  final List<OptionalRole> owned;
  const _RoleFan({required this.roles, required this.owned});

  @override
  Widget build(BuildContext context) {
    final mid = (roles.length - 1) / 2;
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < roles.length; i++)
          Transform.translate(
            offset: Offset((i - mid) * MyVaultTokens.fanSpread, 0),
            child: Transform.rotate(
              angle: (i - mid) * MyVaultTokens.fanTilt,
              child: Opacity(
                opacity: owned.contains(roles[i])
                    ? 1
                    : RolesTokens.dealLockedAlpha,
                child: Container(
                  width: MyVaultTokens.fanCard.width,
                  height: MyVaultTokens.fanCard.height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
                    border: Border.all(
                      color: VaultTokens.gold,
                      width: RolesTokens.dealOwnedRing,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    roleFace(roles[i].role),
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Where extends StatelessWidget {
  final List<String> lines;
  const _Where({required this.lines});

  @override
  Widget build(BuildContext context) {
    final type = context.typography;
    final colors = context.colors;
    final s = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          Padding(
            padding: EdgeInsets.only(bottom: s.xs),
            child: Row(
              children: [
                Container(
                  width: MyVaultTokens.dot,
                  height: MyVaultTokens.dot,
                  decoration: const BoxDecoration(
                    color: VaultTokens.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: s.sm),
                Expanded(
                  child: Text(
                    line,
                    style: DeckTokens.meta(
                      type,
                    ).copyWith(color: colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RolesRoom extends StatelessWidget {
  final WalletState wallet;
  const _RolesRoom({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    return ListView(
      padding: EdgeInsets.all(s.md),
      children: [
        Text(
          l.vaultRolesTitle,
          style: DeckTokens.title(
            context.typography,
          ).copyWith(color: context.colors.textPrimary),
        ),
        SizedBox(height: s.sm),
        _Where(lines: [l.vaultRolesWhere]),
        SizedBox(height: s.md),
        RoleDealGrid(
          cards: [
            for (final r in OptionalRole.values)
              RoleDealSpec(
                role: r.role,
                name: EngineCopy.roleName(l, r.role),
                count: wallet.owned.contains(r.code) ? 1 : 0,
                rule: l.rolesRuleFrom(r.minPlayers),
                owned: wallet.owned.contains(r.code),
                locked: !wallet.owned.contains(r.code),
                minPlayers: r.minPlayers,
                max: 1,
              ),
          ],
        ),
      ],
    );
  }
}

class _NarratorRoom extends ConsumerStatefulWidget {
  final WalletState wallet;
  final bool busy;
  final Future<void> Function(CosmeticSlot, String?) onEquip;
  const _NarratorRoom({
    required this.wallet,
    required this.busy,
    required this.onEquip,
  });

  @override
  ConsumerState<_NarratorRoom> createState() => _NarratorRoomState();
}

class _NarratorRoomState extends ConsumerState<_NarratorRoom> {
  String? _shown;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final owned = _ownedOf(widget.wallet, CosmeticKind.narratorPack);
    if (owned.isEmpty) return const _Nothing();
    final now = _equipped(widget.wallet, CosmeticSlot.narrator);
    final shown = _shown ?? now ?? owned.first;
    final item = Cosmetics.items[shown]!;
    final pack = Cosmetics.narrators[shown];
    final isNow = now == shown;
    return ListView(
      padding: EdgeInsets.all(s.md),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.card),
          child: SizedBox(
            height: MyVaultTokens.narratorHero,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (StoreArt.forCode(shown) case final art?)
                  Image.asset(
                    art,
                    fit: BoxFit.cover,
                    semanticLabel: item.name(l),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ColoredBox(
                    color: colors.surfaceBase.withValues(
                      alpha: MyVaultTokens.tileMarkAlpha,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.all(s.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.name(l),
                              style: DeckTokens.title(
                                type,
                              ).copyWith(color: colors.textPrimary),
                            ),
                            Text(
                              item.description(l),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: DeckTokens.meta(
                                type,
                              ).copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: s.md),
        if (pack != null)
          Material(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(context.radii.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(context.radii.card),
              onTap: () =>
                  ref.read(audioDirectorProvider).previewNarrator(shown),
              child: Padding(
                padding: EdgeInsets.all(s.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: DeckTokens.bone,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: colors.surfaceBase,
                        semanticLabel: l.storeListen,
                      ),
                    ),
                    SizedBox(width: s.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.vaultListenNight,
                            style: DeckTokens.meta(
                              type,
                            ).copyWith(color: colors.textSecondary),
                          ),
                          Text(
                            '«${pack.line(l, NarrationBeat.night)}»',
                            style: DeckTokens.body(type).copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(height: s.md),
        Row(
          children: [
            for (final code in owned)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: s.xs),
                  child: _PickTile(
                    selected: code == shown,
                    label: Cosmetics.items[code]!.name(l),
                    onTap: () => setState(() => _shown = code),
                    child: SizedBox(
                      height: MyVaultTokens.portrait,
                      width: double.infinity,
                      child: StoreArt.forCode(code) == null
                          ? const SizedBox.shrink()
                          : Image.asset(
                              StoreArt.forCode(code)!,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: s.md),
        _Where(lines: [l.vaultNarratorWhereLocal, l.vaultNarratorWhereRoom]),
        SizedBox(height: s.md),
        BoneButton(
          key: MyVaultTab.pick(shown),
          label: isNow ? l.vaultNarratorIsNow : l.vaultNarratorPick,
          onPressed: isNow || widget.busy
              ? null
              : () => widget.onEquip(CosmeticSlot.narrator, shown),
        ),
      ],
    );
  }
}

class _SceneRoom extends StatefulWidget {
  final WalletState wallet;
  final bool busy;
  final Future<void> Function(CosmeticSlot, String?) onEquip;
  const _SceneRoom({
    required this.wallet,
    required this.busy,
    required this.onEquip,
  });

  @override
  State<_SceneRoom> createState() => _SceneRoomState();
}

class _SceneRoomState extends State<_SceneRoom> {
  String? _shown;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final owned = _ownedOf(widget.wallet, CosmeticKind.presentationPack);
    if (owned.isEmpty) return const _Nothing();
    final now = _equipped(widget.wallet, CosmeticSlot.roomPack);
    final shown = _shown ?? now ?? owned.first;
    final item = Cosmetics.items[shown]!;
    final pack = Cosmetics.packs[shown];
    final isNow = now == shown;
    return ListView(
      padding: EdgeInsets.all(s.md),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.card),
          child: SizedBox(
            height: MyVaultTokens.sceneHero,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (StoreArt.forCode(shown) case final art?)
                  Image.asset(
                    art,
                    fit: BoxFit.cover,
                    semanticLabel: item.name(l),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ColoredBox(
                    color: colors.surfaceBase.withValues(
                      alpha: MyVaultTokens.tileMarkAlpha,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.all(s.md),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.name(l),
                              style: DeckTokens.title(
                                type,
                              ).copyWith(color: colors.textPrimary),
                            ),
                            if (pack != null)
                              Text(
                                '«${pack.intro(l)}»',
                                textAlign: TextAlign.center,
                                style: DeckTokens.body(
                                  type,
                                ).copyWith(color: colors.textPrimary),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: s.md),
        Row(
          children: [
            for (final code in owned)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: s.xs),
                  child: _PickTile(
                    selected: code == shown,
                    label: Cosmetics.items[code]!.name(l),
                    onTap: () => setState(() => _shown = code),
                    child: SizedBox(
                      height: MyVaultTokens.portrait,
                      width: double.infinity,
                      child: StoreArt.forCode(code) == null
                          ? const SizedBox.shrink()
                          : Image.asset(
                              StoreArt.forCode(code)!,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: s.md),
        _Where(lines: [l.vaultRoomWhere]),
        SizedBox(height: s.md),
        BoneButton(
          key: MyVaultTab.pick(shown),
          label: isNow ? l.vaultRoomIsNow : l.vaultRoomPick,
          onPressed: isNow || widget.busy
              ? null
              : () => widget.onEquip(CosmeticSlot.roomPack, shown),
        ),
      ],
    );
  }
}

/// The player's own seat, as the table draws it, and what they can dress it in.
class VaultLookRoom extends ConsumerWidget {
  final WalletState wallet;
  final bool busy;
  final Future<void> Function(CosmeticSlot, String?) onEquip;
  const VaultLookRoom({
    super.key,
    required this.wallet,
    required this.busy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final me = ref.watch(playerProfileProvider).valueOrNull?.name;
    final frame = _equipped(wallet, CosmeticSlot.frame);
    final plate = _equipped(wallet, CosmeticSlot.nameplate);
    final frames = _ownedOf(wallet, CosmeticKind.frame);
    final plates = _ownedOf(wallet, CosmeticKind.nameplate);

    Widget choices(
      String title,
      CosmeticSlot slot,
      List<String> codes,
      String? on,
      double height,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: DeckTokens.card(
            type,
          ).copyWith(color: colors.textPrimary, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: s.sm),
        Wrap(
          spacing: s.sm,
          runSpacing: s.sm,
          children: [
            for (final code in <String?>[null, ...codes])
              SizedBox(
                width: MyVaultTokens.frameTile,
                child: _PickTile(
                  key: code == null ? null : MyVaultTab.pick(code),
                  selected: code == on,
                  label: code == null
                      ? l.vaultLookNone
                      : Cosmetics.items[code]!.name(l),
                  onTap: busy || code == on ? null : () => onEquip(slot, code),
                  child: SizedBox(
                    height: height,
                    width: double.infinity,
                    child: code == null || StoreArt.forCode(code) == null
                        ? Icon(Icons.block, color: colors.textMuted)
                        : Image.asset(
                            StoreArt.forCode(code)!,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    return ListView(
      padding: EdgeInsets.all(s.md),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(context.radii.card),
          ),
          child: Padding(
            padding: EdgeInsets.all(s.lg),
            child: Column(
              children: [
                Text(
                  l.vaultLookSeen,
                  style: DeckTokens.meta(
                    type,
                  ).copyWith(color: colors.textSecondary),
                ),
                SizedBox(height: s.md),
                SeatPreview(
                  name: me ?? l.vaultLookTitle,
                  frame: frame,
                  plate: plate,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: s.md),
        choices(
          l.vaultLookFrame,
          CosmeticSlot.frame,
          frames,
          frame,
          MyVaultTokens.frameTile,
        ),
        // Plates are off sale (store v4): only a player who holds one sees it.
        if (plates.isNotEmpty) ...[
          SizedBox(height: s.md),
          choices(
            l.vaultLookPlate,
            CosmeticSlot.nameplate,
            plates,
            plate,
            MyVaultTokens.plateTile,
          ),
        ],
        SizedBox(height: s.md),
        _Where(lines: [l.vaultLookWhere]),
      ],
    );
  }
}

class _PickTile extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback? onTap;
  final Widget child;
  const _PickTile({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
                border: Border.all(
                  color: selected ? VaultTokens.gold : colors.borderSubtle,
                  width: selected ? RolesTokens.dealOwnedRing : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
            SizedBox(height: context.spacing.xs),
            ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.typography.caption.copyWith(
                  color: selected ? VaultTokens.gold : colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(context.spacing.lg),
      child: Text(
        context.l10n.vaultNothingHere,
        textAlign: TextAlign.center,
        style: context.typography.body,
      ),
    ),
  );
}

/// The tool bag: every tool the player holds, its art, when it works, and how
/// many are left, or «من غير عدد» on an owner grant.
class VaultToolBag extends ConsumerWidget {
  const VaultToolBag({super.key});

  static String phaseLabel(BuildContext context, String phase) {
    final l = context.l10n;
    return switch (phase) {
      'vote' => l.vaultToolPhaseVote,
      'night' => l.vaultToolPhaseNight,
      'dead' => l.vaultToolPhaseDead,
      _ => l.vaultToolPhaseDiscuss,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final unlimited = ref.watch(allAccessProvider);
    final tools =
        ref.watch(tableToolsProvider).valueOrNull?.owned() ?? const [];
    return ListView(
      padding: EdgeInsets.all(s.md),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.vaultToolsTitle,
                style: DeckTokens.title(
                  type,
                ).copyWith(color: colors.textPrimary),
              ),
            ),
            if (unlimited) _GoldPill(text: l.vaultToolsUnlimited),
          ],
        ),
        SizedBox(height: s.sm),
        _Where(lines: [l.vaultToolsWhere]),
        SizedBox(height: s.md),
        if (tools.isEmpty)
          const _Nothing()
        else
          GridView.count(
            crossAxisCount: MyVaultTokens.toolColumns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: s.sm,
            crossAxisSpacing: s.sm,
            childAspectRatio: 1 / 1.35,
            children: [
              for (final t in tools)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(RolesTokens.dealRadius),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(s.xs),
                    child: Column(
                      children: [
                        ToolIcon(code: t.code, size: MyVaultTokens.toolArt),
                        Text(
                          tableToolCopy(l, t.code)?.$1 ?? t.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.typography.caption.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          phaseLabel(context, t.phase),
                          maxLines: 1,
                          style: context.typography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          unlimited
                              ? l.vaultToolsUnlimited
                              : l.vaultToolLeft(t.charges),
                          style: context.typography.caption.copyWith(
                            color: VaultTokens.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
