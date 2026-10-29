import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/asset_constants.dart';
import '../../../app/l10n/app_localizations.dart';
import '../../../platform/audio_director.dart';
import '../../economy/account_protection.dart';
import '../../economy/cosmetic_preview.dart';
import '../../economy/cosmetics.dart';
import '../../economy/economy_capabilities.dart';
import '../../economy/mafia_coin.dart';
import '../../economy/store_art.dart';
import '../../economy/table_tool_names.g.dart';
import '../../economy/table_tools.dart';
import '../../economy/wallet.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';
import '../../widgets/mafia_public.dart';
import 'optional_roles.dart';

/// «السوق السودة»: the shop as drawers (docs/design/DECK-SYSTEM.md §10). The
/// categories come from ONE list ([storeCategories]); a new category is one
/// more entry there. This file only draws what the server's catalog and the
/// wallet already say: every price, charge and purchase goes through the same
/// controllers as before.

enum StoreKind { tool, role, narrator, room, look, bundle }

/// One thing on sale, from whichever list it came: cosmetics and roles from
/// the wallet's catalog, tools from the tools state.
class StoreEntry {
  final String code;
  final StoreKind kind;
  final String name;
  final String description;

  /// What the shelf shows: the player's current charge, or a tool's cheapest
  /// pack.
  final int price;
  final bool owned;
  final bool equipped;
  final CosmeticSlot? slot;
  final TableTool? tool;
  final WalletItem? item;

  const StoreEntry({
    required this.code,
    required this.kind,
    required this.name,
    required this.description,
    required this.price,
    required this.owned,
    required this.equipped,
    required this.slot,
    this.tool,
    this.item,
  });

  /// A tool is spent; everything else is bought once and kept.
  bool get consumable => kind == StoreKind.tool;
  int get charges => tool?.charges ?? 0;
}

/// A drawer. [holds] says which entries live in it.
class StoreCategory {
  final String id;
  final String Function(AppLocalizations) name;
  final String Function(AppLocalizations) sub;
  final bool Function(StoreEntry) holds;
  final bool isNew;
  const StoreCategory({
    required this.id,
    required this.name,
    required this.sub,
    required this.holds,
    this.isNew = false,
  });
}

/// THE list of drawers, in shelf order. Add a category here and nowhere else.
final List<StoreCategory> storeCategories = [
  StoreCategory(
    id: 'tools',
    name: (l) => l.storeCatTools,
    sub: (l) => l.storeCatToolsSub,
    holds: (e) => e.kind == StoreKind.tool || e.kind == StoreKind.role,
  ),
  StoreCategory(
    id: 'narrator',
    name: (l) => l.storeCatNarrator,
    sub: (l) => l.storeCatNarratorSub,
    holds: (e) => e.kind == StoreKind.narrator,
  ),
  StoreCategory(
    id: 'rooms',
    name: (l) => l.storeCatRooms,
    sub: (l) => l.storeCatRoomsSub,
    holds: (e) => e.kind == StoreKind.room,
    isNew: true,
  ),
  StoreCategory(
    id: 'look',
    name: (l) => l.storeCatLook,
    sub: (l) => l.storeCatLookSub,
    holds: (e) => e.kind == StoreKind.look,
  ),
  StoreCategory(
    id: 'bundles',
    name: (l) => l.storeCatBundles,
    sub: (l) => l.storeCatBundlesSub,
    holds: (e) => e.kind == StoreKind.bundle,
  ),
];

/// Roughly how many online matches an amount takes, from the current reward
/// contract (sync_player_rewards): a win's extra is not counted. [v3] is the
/// server's `economy.version=3` rule (25 a match instead of 100).
int matchesFor(int coins, {bool v3 = false}) =>
    (coins / (v3 ? coinsPerFinishedMatchV3 : coinsPerFinishedMatch)).ceil();

String storeKindLabel(AppLocalizations l, StoreKind kind) => switch (kind) {
  StoreKind.tool => l.storeKindTool,
  StoreKind.role => l.storeKindRole,
  StoreKind.narrator => l.storeKindNarrator,
  StoreKind.room => l.storeKindRoom,
  StoreKind.look => l.storeKindLook,
  StoreKind.bundle => l.storeKindBundle,
};

// The three bought roles come from one table, [OptionalRole]. A code that is
// not in it has no name, no text and no art here: it shows its bare code and
// no picture, rather than being dressed as the silencer.
String storeRoleName(AppLocalizations l, String code) =>
    switch (OptionalRole.byCode(code)) {
      OptionalRole.silencer => l.roleSilencer,
      OptionalRole.elder => l.roleElder,
      OptionalRole.sniper => l.roleSniper,
      null => code,
    };

String _roleDesc(AppLocalizations l, String code) =>
    switch (OptionalRole.byCode(code)) {
      OptionalRole.silencer => l.roleSilencerDescription,
      OptionalRole.elder => l.roleElderDescription,
      OptionalRole.sniper => l.roleSniperDescription,
      null => '',
    };

String? _roleArt(String code) => switch (OptionalRole.byCode(code)) {
  OptionalRole.silencer => AppImages.cardFaceSilencer,
  OptionalRole.elder => AppImages.cardFaceElder,
  OptionalRole.sniper => AppImages.cardFaceSniper,
  null => null,
};

/// [text] folded for searching Arabic: diacritics and tatweel dropped, the
/// alef forms joined, ة read as ه and ى as ي, case folded.
String normalizeStoreSearch(String text) {
  final out = StringBuffer();
  for (final r in text.runes) {
    if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640) continue;
    if (r == 0x0623 || r == 0x0625 || r == 0x0622 || r == 0x0671) {
      out.writeCharCode(0x0627);
    } else if (r == 0x0629) {
      out.writeCharCode(0x0647);
    } else if (r == 0x0649) {
      out.writeCharCode(0x064A);
    } else {
      out.writeCharCode(r);
    }
  }
  return out.toString().toLowerCase().trim();
}

/// The one «وصل جديد» card: the newest thing on the shelf that can still be
/// sold. The last active catalog row of a cosmetic kind, preferring one the
/// player does not own yet; null when there is none. Never a fixed code, which
/// goes stale the day that item is switched off.
StoreEntry? featuredEntry(List<StoreEntry> entries) {
  final live = [
    for (final e in entries)
      if (e.item != null &&
          (e.kind == StoreKind.room ||
              e.kind == StoreKind.narrator ||
              e.kind == StoreKind.look ||
              e.kind == StoreKind.bundle))
        e,
  ];
  if (live.isEmpty) return null;
  return live.where((e) => !e.owned).lastOrNull ?? live.last;
}

/// Everything for sale, in shelf order. Tools only when the tools state has
/// loaded; roles and cosmetics only when the server lists them.
List<StoreEntry> buildStoreEntries(
  AppLocalizations l,
  WalletState wallet,
  TableToolsState? tools,
) {
  final out = <StoreEntry>[];
  for (final tier in ToolTier.values) {
    final all = tools?.tools ?? const <TableTool>[];
    for (final tool in all.where((t) => t.tier == tier)) {
      final copy = tableToolCopy(l, tool.code);
      if (copy == null || tool.packs.isEmpty) continue;
      final cheapest = tool.packs.values.reduce((a, b) => a < b ? a : b);
      out.add(
        StoreEntry(
          code: tool.code,
          kind: StoreKind.tool,
          name: copy.$1,
          description: copy.$2,
          price: cheapest,
          owned: tool.charges > 0,
          equipped: false,
          slot: null,
          tool: tool,
        ),
      );
    }
  }
  for (final code in Cosmetics.roleCodes) {
    final item = wallet.item(code);
    // A role the server no longer lists is still the player's if they own it.
    if (item == null && !wallet.owned.contains(code)) continue;
    out.add(
      StoreEntry(
        code: code,
        kind: StoreKind.role,
        name: storeRoleName(l, code),
        description: _roleDesc(l, code),
        price: item?.charge ?? 0,
        owned: wallet.owned.contains(code),
        equipped: false,
        slot: null,
        item: item,
      ),
    );
  }
  // The catalog's rows, then anything owned that the catalog no longer lists
  // (an item switched off for sale): owning it does not depend on the shelf.
  final listed = {for (final item in wallet.catalog) item.code};
  final rows = <(String, WalletItem?)>[
    for (final item in wallet.catalog) (item.code, item),
    for (final code in wallet.owned.toList()..sort())
      if (!listed.contains(code) && Cosmetics.items[code] != null) (code, null),
  ];
  for (final (code, item) in rows) {
    final cosmetic = Cosmetics.items[code];
    if (cosmetic == null) continue;
    final slot = cosmetic.slot;
    out.add(
      StoreEntry(
        code: code,
        kind: switch (cosmetic.kind) {
          CosmeticKind.frame || CosmeticKind.nameplate => StoreKind.look,
          CosmeticKind.presentationPack => StoreKind.room,
          CosmeticKind.narratorPack => StoreKind.narrator,
          CosmeticKind.bundle => StoreKind.bundle,
        },
        name: cosmetic.name(l),
        description: cosmetic.description(l),
        price: item?.charge ?? 0,
        owned: wallet.owned.contains(code),
        equipped: slot != null && wallet.equipped[slot.wire] == code,
        slot: slot,
        item: item,
      ),
    );
  }
  return out;
}

/// Keys the shop and its sheet expose (the old shop's names are kept).
abstract final class StoreShopKeys {
  static Key item(String code) => ValueKey('store_item_$code');
  static Key buy(String code) => ValueKey('store_buy_$code');
  static Key equip(String code) => ValueKey('store_equip_$code');
  static const shopList = ValueKey('store_shop_list');
  static const sheetList = ValueKey('store_item_sheet');
  static const search = ValueKey('store_search');
  static const ownedFilter = ValueKey('store_owned_filter');
  static const featured = ValueKey('store_featured');
  static const drawerList = ValueKey('store_drawer_list');
  static const back = ValueKey('store_drawer_back');
  static const sold = ValueKey('store_sold_stamp');
  static const noMatches = ValueKey('store_no_matches');
  static Key drawer(String id) => ValueKey('store_drawer_$id');
  static Key chip(String id) => ValueKey('store_chip_$id');
  static Key listen(String code) => ValueKey('store_listen_$code');
  static Key pack(String code, int pack) =>
      ValueKey('store_pack_${code}_$pack');
}

/// Buys [entry] through the same controllers the store always used. Null on
/// success, otherwise the words to show under the button. [alive] says whether
/// the owner of [busy] is still on screen.
Future<String?> storeBuy({
  required WidgetRef ref,
  required AppLocalizations l,
  required ValueNotifier<bool> busy,
  required bool Function() alive,
  required StoreEntry entry,
  required int pack,
}) async {
  if (busy.value) return l.storeBusy;
  busy.value = true;
  try {
    if (entry.tool != null) {
      await ref.read(tableToolsProvider.notifier).buy(entry.code, pack);
    } else {
      await ref.read(walletProvider.notifier).buy(entry.code);
    }
    return null;
  } on ToolActionFailed catch (e) {
    return e.code == 'INSUFFICIENT_COINS' ? l.toolNotEnough : l.toolBuyFailed;
  } on WalletActionFailed catch (e) {
    final balance = ref.read(walletProvider).valueOrNull?.balance ?? 0;
    return e.code == 'INSUFFICIENT_COINS'
        ? l.storeNotEnough(entry.price - balance)
        : l.storeFailed;
  } catch (_) {
    // Anything else (a dropped connection, a parse error): the controllers
    // have already re-read the server's truth; say so without claiming what
    // did or did not happen.
    return l.storeFailed;
  } finally {
    if (alive()) busy.value = false;
  }
}

/// Opens the buy sheet for [code].
Future<void> showStoreItemSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String code,
  required ValueNotifier<bool> busy,
  required bool Function() alive,
  required Future<void> Function(CosmeticSlot, String?) onEquip,
}) {
  final l = context.l10n;
  return showMafiaSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => StoreItemSheet(
      code: code,
      busy: busy,
      onBuy: (entry, pack) => storeBuy(
        ref: ref,
        l: l,
        busy: busy,
        alive: alive,
        entry: entry,
        pack: pack,
      ),
      onEquip: onEquip,
    ),
  );
}

class StoreShop extends ConsumerStatefulWidget {
  final WalletState wallet;

  /// One wallet action at a time, owned by the store so a sheet opened from
  /// the collection shares it.
  final ValueNotifier<bool> busy;
  final bool Function() alive;
  final Future<void> Function(CosmeticSlot, String?) onEquip;
  const StoreShop({
    super.key,
    required this.wallet,
    required this.busy,
    required this.alive,
    required this.onEquip,
  });

  @override
  ConsumerState<StoreShop> createState() => _StoreShopState();
}

class _StoreShopState extends ConsumerState<StoreShop> {
  final _query = TextEditingController();
  String? _cat;
  bool _ownedOnly = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<StoreEntry> _entries(AppLocalizations l) => buildStoreEntries(
    l,
    widget.wallet,
    ref.watch(tableToolsProvider).valueOrNull,
  );

  Future<void> _open(String code) => showStoreItemSheet(
    context: context,
    ref: ref,
    code: code,
    busy: widget.busy,
    alive: widget.alive,
    onEquip: widget.onEquip,
  );

  void _listen(String code) =>
      ref.read(audioDirectorProvider).previewNarrator(code);

  bool _matches(StoreEntry e) {
    if (_ownedOnly && !e.owned) return false;
    final q = normalizeStoreSearch(_query.text);
    return q.isEmpty || normalizeStoreSearch(e.name).contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final entries = _entries(l);
    final cats = [
      for (final c in storeCategories)
        if (entries.any(c.holds)) c,
    ];
    final cat = cats.where((c) => c.id == _cat).firstOrNull;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : StoreShopTokens.slide,
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: Offset(
              child.key == const ValueKey('index')
                  ? -StoreShopTokens.slideShift
                  : StoreShopTokens.slideShift,
              0,
            ),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: cat == null
          ? _Index(
              key: const ValueKey('index'),
              entries: entries,
              cats: cats,
              query: _query,
              ownedOnly: _ownedOnly,
              matches: _matches,
              onQuery: () => setState(() {}),
              onToggleOwned: () => setState(() => _ownedOnly = !_ownedOnly),
              onOpenCat: (id) => setState(() => _cat = id),
              onOpen: _open,
              onListen: _listen,
            )
          : _DrawerView(
              key: ValueKey('cat_${cat.id}'),
              entries: entries,
              cats: cats,
              cat: cat,
              ownedOnly: _ownedOnly,
              onBack: () => setState(() => _cat = null),
              onOpenCat: (id) => setState(() => _cat = id),
              onToggleOwned: () => setState(() => _ownedOnly = !_ownedOnly),
              onOpen: _open,
              onListen: _listen,
            ),
    );
  }
}

/// A paper panel: the dark case-file card the shop is made of.
class _Paper extends StatelessWidget {
  final Widget child;
  const _Paper({required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [DeckTokens.raised, DeckTokens.panel],
      ),
      borderRadius: BorderRadius.circular(context.radii.card),
      border: Border.all(color: DeckTokens.line),
    ),
    child: child,
  );
}

class _Price extends StatelessWidget {
  final int amount;
  const _Price(this.amount);

  @override
  Widget build(BuildContext context) => CoinAmount(
    amount,
    size: DeckTokens.coinGlyphSmall,
    style: DeckTokens.meta(
      context.typography,
    ).copyWith(color: DeckTokens.gold, fontWeight: FontWeight.w700),
  );
}

/// A crimson seal standing straight: «عندك» on a shelf item, «وصل جديد» on
/// the card. The tilted rubber stamp belongs to «قصص وتحقيقات».
class _Stamp extends StatelessWidget {
  final String text;
  const _Stamp(this.text);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: StoreShopTokens.stampWash,
      borderRadius: BorderRadius.circular(context.radii.button / 3),
      border: Border.all(
        color: StoreShopTokens.stamp,
        width: StoreShopTokens.stampBorder,
      ),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      child: Text(
        text,
        style: DeckTokens.meta(
          context.typography,
        ).copyWith(color: StoreShopTokens.stamp, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// The item's picture, drawn at the size it is given.
class StoreEntryArt extends StatelessWidget {
  final StoreEntry entry;
  final bool cover;
  const StoreEntryArt(this.entry, {super.key, this.cover = false});

  @override
  Widget build(BuildContext context) {
    final fit = cover ? BoxFit.cover : BoxFit.contain;
    return switch (entry.kind) {
      StoreKind.tool => RepaintBoundary(
        child: Image.asset(
          'assets/images/tools/tool_${entry.code}.webp',
          fit: fit,
          cacheWidth: StoreTokens.decodeWidth,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => Icon(
            Icons.construction_rounded,
            color: context.colors.accentGold,
          ),
        ),
      ),
      StoreKind.role =>
        _roleArt(entry.code) == null
            ? const SizedBox.shrink()
            : RepaintBoundary(
                child: Image.asset(
                  _roleArt(entry.code)!,
                  fit: fit,
                  cacheWidth: StoreTokens.decodeWidth,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
      _ =>
        cover && StoreArt.forCode(entry.code) != null
            ? RepaintBoundary(
                child: Image.asset(
                  StoreArt.forCode(entry.code)!,
                  fit: BoxFit.cover,
                  cacheWidth: StoreTokens.decodeWidth,
                  excludeFromSemantics: true,
                ),
              )
            : StoreProductArt(code: entry.code),
    };
  }
}

class _SearchRow extends StatelessWidget {
  final TextEditingController query;
  final bool ownedOnly;
  final VoidCallback onQuery;
  final VoidCallback onToggleOwned;
  const _SearchRow({
    required this.query,
    required this.ownedOnly,
    required this.onQuery,
    required this.onToggleOwned,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = DeckTokens.meta(context.typography);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: StoreShopTokens.searchHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DeckTokens.ground,
                borderRadius: BorderRadius.circular(context.radii.button),
                border: Border.all(color: DeckTokens.line),
              ),
              child: Row(
                children: [
                  SizedBox(width: s.sm),
                  const Icon(
                    Icons.search_rounded,
                    size: DeckTokens.icon,
                    color: DeckTokens.muted,
                  ),
                  SizedBox(width: s.xs),
                  Expanded(
                    child: TextField(
                      key: StoreShopKeys.search,
                      controller: query,
                      expands: true,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.center,
                      onChanged: (_) => onQuery(),
                      style: type.copyWith(color: DeckTokens.text),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: l.storeSearchHint,
                        hintStyle: type.copyWith(color: DeckTokens.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: s.sm),
        Semantics(
          button: true,
          selected: ownedOnly,
          child: Material(
            color: ownedOnly ? DeckTokens.raised : DeckTokens.ground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.radii.button),
              side: BorderSide(
                color: ownedOnly ? DeckTokens.bone : DeckTokens.line,
                width: ownedOnly ? DeckTokens.rimBorder : 1,
              ),
            ),
            child: InkWell(
              key: StoreShopKeys.ownedFilter,
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.radii.button),
              ),
              onTap: onToggleOwned,
              child: SizedBox(
                height: StoreShopTokens.searchHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: s.md),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      l.storeOwnedFilter,
                      style: type.copyWith(
                        color: ownedOnly ? DeckTokens.text : DeckTokens.text2,
                      ),
                    ),
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

class _Index extends StatelessWidget {
  final List<StoreEntry> entries;
  final List<StoreCategory> cats;
  final TextEditingController query;
  final bool ownedOnly;
  final bool Function(StoreEntry) matches;
  final VoidCallback onQuery;
  final VoidCallback onToggleOwned;
  final ValueChanged<String> onOpenCat;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onListen;
  const _Index({
    super.key,
    required this.entries,
    required this.cats,
    required this.query,
    required this.ownedOnly,
    required this.matches,
    required this.onQuery,
    required this.onToggleOwned,
    required this.onOpenCat,
    required this.onOpen,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final filtering = ownedOnly || query.text.trim().isNotEmpty;
    final found = [
      for (final e in entries)
        if (matches(e)) e,
    ];
    final featured = featuredEntry(entries);
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth > StoreTokens.maxContentWidth
            ? (box.maxWidth - StoreTokens.maxContentWidth) / 2
            : s.md;
        return ListView(
          key: StoreShopKeys.shopList,
          padding: EdgeInsets.fromLTRB(side, s.sm, side, s.lg),
          children: [
            _SearchRow(
              query: query,
              ownedOnly: ownedOnly,
              onQuery: onQuery,
              onToggleOwned: onToggleOwned,
            ),
            SizedBox(height: s.md),
            if (filtering)
              if (found.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: s.xl),
                  child: Center(
                    child: Text(
                      ownedOnly && query.text.trim().isEmpty
                          ? l.storeEmptyCollection
                          : l.storeNoMatches,
                      key: StoreShopKeys.noMatches,
                      style: DeckTokens.body(
                        context.typography,
                      ).copyWith(color: DeckTokens.text2),
                    ),
                  ),
                )
              else
                _Grid(entries: found, onOpen: onOpen, onListen: onListen)
            else ...[
              if (featured != null) ...[
                _FeaturedCard(
                  entry: featured,
                  onTap: () => onOpen(featured.code),
                ),
                SizedBox(height: s.md),
              ],
              Image.asset(
                AppOffline.dividerGold,
                height: StoreShopTokens.dividerHeight,
                fit: BoxFit.fitWidth,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) =>
                    const SizedBox(height: StoreShopTokens.dividerHeight),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: s.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l.storeDrawersLabel,
                        style: DeckTokens.meta(
                          context.typography,
                        ).copyWith(color: DeckTokens.muted),
                      ),
                    ),
                    Text(
                      l.storeDrawersCount(cats.length),
                      style: DeckTokens.meta(
                        context.typography,
                      ).copyWith(color: DeckTokens.muted),
                    ),
                  ],
                ),
              ),
              for (final (i, c) in cats.indexed) ...[
                DeckRise(
                  index: i,
                  child: _DrawerTile(
                    cat: c,
                    items: [
                      for (final e in entries)
                        if (c.holds(e)) e,
                    ],
                    onTap: () => onOpenCat(c.id),
                  ),
                ),
                SizedBox(height: s.sm),
              ],
              const AccountProtectionCard(),
            ],
          ],
        );
      },
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final StoreEntry entry;
  final VoidCallback onTap;
  const _FeaturedCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final radius = BorderRadius.circular(context.radii.card);
    return DeckPress(
      child: Material(
        color: DeckTokens.panel,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: DeckTokens.line),
        ),
        child: InkWell(
          key: StoreShopKeys.featured,
          onTap: onTap,
          child: SizedBox(
            height: StoreShopTokens.featHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                StoreEntryArt(entry, cover: true),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerEnd,
                      end: AlignmentDirectional.centerStart,
                      stops: StoreShopTokens.featStops,
                      colors: [
                        DeckTokens.ground.withValues(
                          alpha: StoreShopTokens.featShade,
                        ),
                        DeckTokens.ground.withValues(
                          alpha: StoreShopTokens.featFadeAlpha,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Image.asset(
                    AppOffline.frameCorner,
                    width: StoreShopTokens.featCorner,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(s.md),
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: StoreShopTokens.featTextWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Stamp(l.storeNewReceipt),
                        SizedBox(height: s.xs),
                        Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DeckTokens.card(type).copyWith(
                            color: DeckTokens.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          entry.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DeckTokens.meta(
                            type,
                          ).copyWith(color: DeckTokens.text2),
                        ),
                        const Spacer(),
                        if (entry.owned)
                          Text(
                            l.storeOwned,
                            style: DeckTokens.meta(
                              type,
                            ).copyWith(color: DeckTokens.text2),
                          )
                        else
                          _Price(entry.price),
                      ],
                    ),
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

/// A drawer on the shelf: three items peeking, the name, how many it holds
/// and how many are yours.
class _DrawerTile extends StatelessWidget {
  final StoreCategory cat;
  final List<StoreEntry> items;
  final VoidCallback onTap;
  const _DrawerTile({
    required this.cat,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final owned = items.where((e) => e.owned).length;
    return DeckPress(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _Paper(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: StoreShopKeys.drawer(cat.id),
                borderRadius: BorderRadius.circular(context.radii.card),
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: s.md,
                    vertical: s.sm,
                  ),
                  child: Row(
                    children: [
                      _Peek(items: items),
                      SizedBox(width: s.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.name(l),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DeckTokens.card(type).copyWith(
                                color: DeckTokens.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              cat.sub(l),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: DeckTokens.meta(
                                type,
                              ).copyWith(color: DeckTokens.muted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${items.length}',
                            style: DeckTokens.body(
                              type,
                            ).copyWith(color: DeckTokens.text2),
                          ),
                          Text(
                            owned > 0
                                ? l.storeDrawerOwned(owned)
                                : l.storeDrawerThings,
                            style: DeckTokens.meta(
                              type,
                            ).copyWith(color: DeckTokens.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (cat.isNew)
            PositionedDirectional(
              top: -s.xs,
              end: s.md,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: StoreShopTokens.stamp,
                    borderRadius: BorderRadius.circular(
                      context.radii.button / 3,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: s.sm),
                    child: Text(
                      l.storeDrawerNew,
                      style: DeckTokens.meta(type).copyWith(
                        color: DeckTokens.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Up to three items fanned out of the drawer.
class _Peek extends StatelessWidget {
  final List<StoreEntry> items;
  const _Peek({required this.items});

  @override
  Widget build(BuildContext context) {
    final shown = items.take(StoreShopTokens.peekCount).toList();
    return ExcludeSemantics(
      child: SizedBox(
        width: StoreShopTokens.peekWidth,
        height: StoreShopTokens.peekTile.height,
        child: Stack(
          children: [
            for (final (i, e) in shown.indexed.toList().reversed)
              PositionedDirectional(
                end: i * StoreShopTokens.peekStep,
                top: 0,
                child: Transform.rotate(
                  angle: StoreShopTokens.peekTurns[i],
                  child: SizedBox.fromSize(
                    size: StoreShopTokens.peekTile,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: DeckTokens.ground,
                        borderRadius: BorderRadius.circular(
                          context.radii.button / 3,
                        ),
                        border: Border.all(color: DeckTokens.line),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          context.radii.button / 3,
                        ),
                        child: StoreEntryArt(e),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerView extends StatelessWidget {
  final List<StoreEntry> entries;
  final List<StoreCategory> cats;
  final StoreCategory cat;
  final bool ownedOnly;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenCat;
  final VoidCallback onToggleOwned;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onListen;
  const _DrawerView({
    super.key,
    required this.entries,
    required this.cats,
    required this.cat,
    required this.ownedOnly,
    required this.onBack,
    required this.onOpenCat,
    required this.onToggleOwned,
    required this.onOpen,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final items = [
      for (final e in entries)
        if (cat.holds(e) && (!ownedOnly || e.owned)) e,
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth > StoreTokens.maxContentWidth
            ? (box.maxWidth - StoreTokens.maxContentWidth) / 2
            : s.md;
        return ListView(
          key: StoreShopKeys.drawerList,
          padding: EdgeInsets.fromLTRB(side, s.xs, side, s.lg),
          children: [
            Row(
              children: [
                IconButton(
                  key: StoreShopKeys.back,
                  tooltip: l.storeDrawersLabel,
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  color: DeckTokens.silverLight,
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      cat.name(l),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.headline.copyWith(color: DeckTokens.text),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: DeckTokens.chip,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cats.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: StoreShopTokens.chipsGap),
                itemBuilder: (context, i) {
                  if (i == cats.length) {
                    return DeckChip(
                      key: StoreShopKeys.ownedFilter,
                      label: l.storeOwnedFilter,
                      selected: ownedOnly,
                      onSelected: (_) => onToggleOwned(),
                    );
                  }
                  final c = cats[i];
                  return DeckChip(
                    key: StoreShopKeys.chip(c.id),
                    label: c.name(l),
                    selected: c.id == cat.id,
                    onSelected: (_) => onOpenCat(c.id),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: s.sm),
              child: Text(
                cat.sub(l),
                style: DeckTokens.meta(type).copyWith(color: DeckTokens.muted),
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: s.xl),
                child: Center(
                  child: Text(
                    l.storeEmptyCollection,
                    style: DeckTokens.body(
                      type,
                    ).copyWith(color: DeckTokens.text2),
                  ),
                ),
              )
            else
              _Grid(entries: items, onOpen: onOpen, onListen: onListen),
          ],
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  final List<StoreEntry> entries;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onListen;
  const _Grid({
    required this.entries,
    required this.onOpen,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: entries.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: StoreShopTokens.gridGap,
      mainAxisSpacing: StoreShopTokens.gridGap,
      mainAxisExtent: StoreShopTokens.bagHeight,
    ),
    itemBuilder: (context, i) {
      final e = entries[i];
      return DeckRise(
        index: i,
        child: _Bag(
          entry: e,
          onTap: () => onOpen(e.code),
          onListen: e.kind == StoreKind.narrator
              ? () => onListen(e.code)
              : null,
        ),
      );
    },
  );
}

/// One item on the shelf: art, name, what it does, its coin tag or «عندك».
class _Bag extends StatelessWidget {
  final StoreEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onListen;
  const _Bag({required this.entry, required this.onTap, this.onListen});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final cover = entry.kind == StoreKind.room;
    return DeckPress(
      child: _Paper(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: StoreShopKeys.item(entry.code),
            borderRadius: BorderRadius.circular(context.radii.card),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(s.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: StoreShopTokens.bagArt,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(context.radii.button),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: StoreShopTokens.wellCenter,
                            radius: StoreShopTokens.wellRadius,
                            colors: [DeckTokens.raised, DeckTokens.ground],
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Padding(
                              padding: cover
                                  ? EdgeInsets.zero
                                  : EdgeInsets.all(s.xs),
                              child: StoreEntryArt(entry, cover: cover),
                            ),
                            if (entry.owned)
                              PositionedDirectional(
                                end: s.xs,
                                bottom: s.xs,
                                child: _Stamp(l.storeOwned),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: s.xs),
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DeckTokens.meta(type).copyWith(
                      color: DeckTokens.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.caption.copyWith(
                        color: DeckTokens.muted,
                        height: StoreShopTokens.lineHeight,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (entry.owned && !entry.consumable)
                        Text(
                          entry.equipped ? l.storeEquipped : l.storeOwned,
                          style: DeckTokens.meta(type).copyWith(
                            color: entry.equipped
                                ? DeckTokens.gold
                                : DeckTokens.text2,
                          ),
                        )
                      else
                        _Price(entry.price),
                      if (onListen != null)
                        SizedBox.square(
                          dimension: StoreShopTokens.previewButton,
                          child: IconButton(
                            key: StoreShopKeys.listen(entry.code),
                            tooltip: l.storeListen,
                            padding: EdgeInsets.zero,
                            onPressed: onListen,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: DeckTokens.icon,
                            ),
                            color: DeckTokens.text,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The buy sheet: the item big, what it is, then one button that fits: gold
/// with the cost (and what stays after), a disabled gold with what is
/// missing, or «استخدم» once it is yours. A crimson «اتباع» lands on success.
class StoreItemSheet extends ConsumerStatefulWidget {
  final String code;
  final ValueListenable<bool> busy;
  final Future<String?> Function(StoreEntry entry, int pack) onBuy;
  final Future<void> Function(CosmeticSlot, String?) onEquip;
  const StoreItemSheet({
    super.key,
    required this.code,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  ConsumerState<StoreItemSheet> createState() => _StoreItemSheetState();
}

class _StoreItemSheetState extends ConsumerState<StoreItemSheet> {
  /// Something was bought here: the stamp and the hint show. Only a
  /// non-consumable then leaves the sale; a tool stays buyable (more charges
  /// are one tap away), so the pack chips and the buy button stay.
  bool _sold = false;
  bool _inFlight = false;
  int? _pack;
  String? _error;

  Future<void> _buy(StoreEntry entry, int pack) async {
    // Set before the first await: a second tap in the same frame must find it.
    // A one-off item already bought here is not bought again by a tap that
    // landed on the frame before the sheet re-drew.
    if (_inFlight || (_sold && !entry.consumable)) return;
    _inFlight = true;
    setState(() => _error = null);
    try {
      final error = await widget.onBuy(entry, pack);
      if (!mounted) return;
      setState(() {
        if (error == null) {
          _error = null;
          _sold = true;
        } else {
          _error = error;
        }
      });
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final wallet = ref.watch(walletProvider).valueOrNull;
    final tools = ref.watch(tableToolsProvider).valueOrNull;
    if (wallet == null) return const SizedBox.shrink();
    final entry = buildStoreEntries(
      l,
      wallet,
      tools,
    ).where((e) => e.code == widget.code).firstOrNull;
    if (entry == null) return const SizedBox.shrink();
    final balance = wallet.balance;
    final packs = entry.tool == null
        ? const <int>[]
        : (entry.tool!.packs.keys.toList()..sort());
    final pack = packs.isEmpty
        ? 0
        : (packs.contains(_pack) ? _pack! : packs.first);
    final cost = entry.tool != null ? entry.tool!.packs[pack]! : entry.price;
    final contents = Cosmetics.bundles[entry.code] ?? const <String>[];
    final ownsAllContents =
        contents.isNotEmpty && contents.every(wallet.owned.contains);
    final cosmetic = Cosmetics.items[entry.code];
    final room = entry.kind == StoreKind.room;
    final ownedMode = !entry.consumable && (_sold || entry.owned);
    final enough = balance >= cost;
    final v3 =
        ref.watch(economyCapabilitiesProvider).valueOrNull?.economyV3 ?? false;
    final slot = entry.slot;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: SheetTokens.previewInitialFraction,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              key: StoreShopKeys.sheetList,
              controller: controller,
              padding: EdgeInsets.fromLTRB(
                s.screenMargin,
                0,
                s.screenMargin,
                s.md,
              ),
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    cosmetic != null
                        ? CosmeticPreview(
                            code: entry.code,
                            equipped: wallet.equipped,
                          )
                        : SizedBox(
                            height: StoreShopTokens.sheetArt,
                            child: StoreEntryArt(entry),
                          ),
                    if (_sold)
                      const IgnorePointer(
                        child: _SoldStamp(key: StoreShopKeys.sold),
                      ),
                  ],
                ),
                SizedBox(height: s.sm),
                Wrap(
                  spacing: s.sm,
                  runSpacing: s.xs,
                  children: [
                    DeckPill(storeKindLabel(l, entry.kind)),
                    DeckPill(entry.consumable ? l.storeOnce : l.storePermanent),
                    if (entry.owned && !entry.consumable)
                      DeckPill(l.storeOwned),
                    if (entry.equipped) DeckPill(l.storeEquipped),
                    if (entry.consumable && entry.charges > 0)
                      DeckPill(l.toolCharges(entry.charges)),
                  ],
                ),
                SizedBox(height: s.xs),
                Text(
                  entry.name,
                  style: type.headline.copyWith(color: DeckTokens.text),
                ),
                Text(
                  entry.description,
                  style: DeckTokens.meta(
                    type,
                  ).copyWith(color: DeckTokens.text2),
                ),
                if (room || entry.kind == StoreKind.narrator)
                  Padding(
                    padding: EdgeInsets.only(top: s.xs),
                    child: Text(
                      l.storeHostPackNote,
                      style: type.bodySmall.copyWith(color: DeckTokens.muted),
                    ),
                  ),
                if (room)
                  Padding(
                    padding: EdgeInsets.only(top: s.xs),
                    child: Text(
                      l.storeRoomArtNote,
                      style: type.bodySmall.copyWith(color: DeckTokens.muted),
                    ),
                  ),
                if (entry.kind == StoreKind.bundle &&
                    entry.item != null &&
                    (ownsAllContents ||
                        _missing(wallet, contents) > entry.item!.charge))
                  Padding(
                    padding: EdgeInsets.only(top: s.sm),
                    child: Text(
                      ownsAllContents
                          ? l.storeBundleOwnedAll
                          : l.storeBundleSaves(
                              _missing(wallet, contents) - entry.item!.charge,
                            ),
                      style: type.bodySmall.copyWith(color: DeckTokens.gold),
                    ),
                  ),
                if (packs.length > 1 && !ownedMode)
                  Padding(
                    padding: EdgeInsets.only(top: s.sm),
                    child: Wrap(
                      spacing: s.sm,
                      runSpacing: s.sm,
                      children: [
                        for (final p in packs)
                          DeckChip(
                            key: StoreShopKeys.pack(entry.code, p),
                            label: l.toolPack(p, entry.tool!.packs[p]!),
                            selected: p == pack,
                            onSelected: (_) => setState(() => _pack = p),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DeckTokens.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  s.screenMargin,
                  s.sm,
                  s.screenMargin,
                  s.sm,
                ),
                child: ValueListenableBuilder<bool>(
                  valueListenable: widget.busy,
                  builder: (context, working, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ownedMode && slot != null)
                        BoneButton(
                          key: StoreShopKeys.equip(entry.code),
                          label: entry.equipped && !_sold
                              ? l.storeUnequip
                              : l.storeEquip,
                          onPressed: working
                              ? null
                              : () async {
                                  final nav = Navigator.of(context);
                                  await widget.onEquip(
                                    slot,
                                    entry.equipped && !_sold
                                        ? null
                                        : entry.code,
                                  );
                                  if (nav.mounted) nav.maybePop();
                                },
                        )
                      else if (ownedMode || ownsAllContents)
                        BoneButton(
                          label: l.storeRevealDone,
                          onPressed: () => Navigator.of(context).maybePop(),
                        )
                      else
                        GoldButton(
                          key: StoreShopKeys.buy(entry.code),
                          label: enough
                              ? l.storeBuyFor(cost)
                              : l.storeNotEnough(cost - balance),
                          onPressed: enough && !working
                              ? () => _buy(entry, pack)
                              : null,
                        ),
                      SizedBox(height: s.xs),
                      Text(
                        _after(l, entry, ownedMode, enough, balance, cost, v3),
                        textAlign: TextAlign.center,
                        style: DeckTokens.meta(type).copyWith(
                          color: _error != null
                              ? StoreShopTokens.stamp
                              : DeckTokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _after(
    AppLocalizations l,
    StoreEntry entry,
    bool ownedMode,
    bool enough,
    int balance,
    int cost,
    bool v3,
  ) {
    if (_error != null) return _error!;
    if (_sold) {
      return switch (entry.kind) {
        StoreKind.tool => l.storeToolHint,
        StoreKind.role => l.storeRoleHint,
        _ => '',
      };
    }
    if (ownedMode) return '';
    if (enough) return l.storeLeftAfter(balance - cost);
    return l.storeEarnTime(cost - balance, matchesFor(cost - balance, v3: v3));
  }

  static int _missing(WalletState wallet, List<String> codes) => [
    for (final c in codes)
      if (!wallet.owned.contains(c)) wallet.item(c)?.price ?? 0,
  ].fold(0, (a, b) => a + b);
}

/// «اتباع», stamped on the picture: it lands big and settles, once.
class _SoldStamp extends StatelessWidget {
  const _SoldStamp({super.key});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: reduce ? Duration.zero : StoreShopTokens.stampIn,
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(
            scale:
                StoreShopTokens.stampBigFrom +
                (1 - StoreShopTokens.stampBigFrom) * t,
            child: child,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: StoreShopTokens.stampWash,
            borderRadius: BorderRadius.circular(context.radii.button / 2),
            border: Border.all(
              color: StoreShopTokens.stamp,
              width: StoreShopTokens.stampBigBorder,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
            child: Text(
              context.l10n.storeSold,
              style: context.typography.headline.copyWith(
                color: StoreShopTokens.stamp,
                fontSize: StoreShopTokens.stampBigSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
