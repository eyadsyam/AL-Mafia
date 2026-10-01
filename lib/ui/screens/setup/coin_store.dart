import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/payment_capabilities.dart';
import '../../economy/account_protection.dart';
import '../../economy/coin_packs.dart';
import '../../economy/cosmetic_preview.dart';
import '../../economy/cosmetics.dart';
import '../../economy/council.dart' show councilAttentionProvider;
import '../../economy/council_hub.dart';
import '../../economy/daily_rewards.dart';
import '../../economy/economy_capabilities.dart';
import '../../economy/play_offers.dart';
import '../../economy/purchase_reveal.dart';
import '../../../platform/monetization/play_billing.dart';
import '../../economy/store_art.dart';
import '../../widgets/textured_surface.dart';
import '../../economy/mafia_coin.dart';
import '../../economy/vault_kit.dart';
import '../../economy/wallet.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/settings_kit.dart';
import '../../economy/waiting_banner.dart';
import '../../widgets/feathered_art.dart';
import '../../../app/asset_constants.dart';
import '../../widgets/motion_sprite.dart';

/// Opens the store over the current screen. Reachable from Home, Settings and
/// an out-of-match lobby only: never from inside a match.
class CoinStoreButton extends StatefulWidget {
  final bool compact;

  /// Drawn as a settings row (the general settings' «أكتر» panel).
  final bool tile;
  const CoinStoreButton({super.key, this.compact = false, this.tile = false});

  static const Key buttonKey = ValueKey('coin_store_open');

  @override
  State<CoinStoreButton> createState() => _CoinStoreButtonState();
}

class _CoinStoreButtonState extends State<CoinStoreButton> {
  final _overlay = OverlayPortalController();

  void _show() => _overlay.show();
  void _hide() {
    _overlay.hide();
    // Whatever was collected inside, the dot is asked again.
    _container?.invalidate(councilAttentionProvider);
  }

  ProviderContainer? _container;

  ProviderSubscription<String?>? _invite;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final container = ProviderScope.containerOf(context, listen: false);
    if (!identical(container, _container)) {
      _invite?.close();
      // An invite link opens the vault by itself, on the Council tab.
      _invite = container.listen<String?>(pendingInviteCodeProvider, (_, next) {
        if (next != null && !_overlay.isShowing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _show();
          });
        }
      }, fireImmediately: true);
    }
    _container = container;
  }

  @override
  void dispose() {
    _invite?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _overlay,
    // System back closes the store, not the screen under it.
    overlayChildBuilder: (_) => Positioned.fill(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _hide();
        },
        child: CoinStore(onClose: _hide),
      ),
    ),
    child: widget.tile
        ? SettingsLinkRow(
            key: CoinStoreButton.buttonKey,
            leading: const SettingsBadgeFrame(
              child: MafiaCoin(size: CosmeticTokens.coinInline),
            ),
            label: context.l10n.storeTitle,
            onTap: _show,
          )
        : widget.compact
        ? IconButton(
            key: CoinStoreButton.buttonKey,
            tooltip: context.l10n.storeTitle,
            icon: const CouncilAttentionBadge(
              child: MafiaCoin(size: CosmeticTokens.coinInline),
            ),
            onPressed: _show,
          )
        : TextButton.icon(
            key: CoinStoreButton.buttonKey,
            icon: const MafiaCoin(size: CosmeticTokens.coinInline),
            label: Text(context.l10n.storeTitle),
            onPressed: _show,
          ),
  );
}

/// «خزنة المجلس»: wallet, catalog, collection, history and (on the web
/// store only) coin packs.
class CoinStore extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  const CoinStore({super.key, this.onClose});

  static const closeKey = ValueKey('coins_close');
  static const balanceKey = ValueKey('coins_balance');
  static Key item(String code) => ValueKey('store_item_$code');
  static Key buy(String code) => ValueKey('store_buy_$code');
  static Key equip(String code) => ValueKey('store_equip_$code');
  static Key tryOn(String code) => ValueKey('store_try_on_$code');
  static Key rail(String section) => PageStorageKey('store_rail_$section');
  static Key railNext(String section) => ValueKey('store_rail_next_$section');
  static const Key confirmBuy = ValueKey('store_confirm_buy');
  static const Key shopList = ValueKey('store_shop_list');
  static const Key sheetList = ValueKey('store_item_sheet');
  static const Key earnInfo = ValueKey('store_earn_info');

  @override
  ConsumerState<CoinStore> createState() => _CoinStoreState();
}

class _CoinStoreState extends ConsumerState<CoinStore> {
  /// One wallet action at a time, shared with an open item sheet so its
  /// button disables too.
  final _busy = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      retryCapabilitiesIfFailed(ref);
      ref.read(walletProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  void _say(String message) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));

  Future<void> _buy(WalletItem item) async {
    if (_busy.value) return;
    final l = context.l10n;
    final name = Cosmetics.items[item.code]!.name(l);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.storeBuyConfirmTitle(name)),
        content: Text(l.storeBuyConfirmBody(item.charge)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: CoinStore.confirmBuy,
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.storeBuyFor(item.charge)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || _busy.value) return;
    _busy.value = true;
    try {
      await ref.read(walletProvider.notifier).buy(item.code);
      if (mounted) {
        _busy.value = false;
        // Store truth: the item doing its job on the buyer, with one tap to
        // wear it (a bundle lists its parts, all now owned).
        final slot = Cosmetics.items[item.code]?.slot;
        await showPurchaseReveal(
          context,
          code: item.code,
          onEquip: slot == null ? null : (slot, code) => _equip(slot, code),
        );
      }
    } on WalletActionFailed catch (error) {
      if (!mounted) return;
      final balance = ref.read(walletProvider).valueOrNull?.balance ?? 0;
      _say(
        error.code == 'INSUFFICIENT_COINS'
            ? l.storeNotEnough(item.charge - balance)
            : l.storeFailed,
      );
    } finally {
      if (mounted) _busy.value = false;
    }
  }

  Future<void> _equip(CosmeticSlot slot, String? code) async {
    if (_busy.value) return;
    _busy.value = true;
    try {
      await ref.read(walletProvider.notifier).equip(slot, code);
    } on WalletActionFailed {
      if (mounted) _say(context.l10n.storeFailed);
    } finally {
      if (mounted) _busy.value = false;
    }
  }

  Future<void> _open(String code) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => _ItemSheet(
        code: code,
        busy: _busy,
        // The sheet stays open: once bought, the same sheet offers «use».
        onBuy: _buy,
        onEquip: _equip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final wallet = ref.watch(walletProvider);
    final value = wallet.valueOrNull;
    // InstaPay / Vodafone Cash (Payments v2): always a tab on the web; on
    // Android only while the server has transfers on for Android (kill
    // switch) or the player still has orders to follow.
    final pay = ref.watch(paymentCapabilitiesProvider);
    final transferShop = pay.transfer && pay.platform == 'android'
        ? ref.watch(coinShopProvider).valueOrNull
        : null;
    final coins =
        pay.transfer &&
        (pay.platform != 'android' ||
            (transferShop != null &&
                (transferShop.enabled || transferShop.orders.isNotEmpty)));
    // New vault features appear only when the server negotiated them; an
    // older server leaves this exactly the 1.0.0 store.
    final caps =
        ref.watch(economyCapabilitiesProvider).valueOrNull ??
        EconomyCapabilities.none;
    final play =
        !kIsWeb &&
        caps.products.isNotEmpty &&
        ref.watch(playBillingProvider).supported;
    final tabs = <(String, IconData, Widget)>[
      if (caps.daily)
        (l.storeTabRewards, Icons.redeem_rounded, const DailyRewardsTab()),
      if (caps.council.hub)
        (l.storeTabCouncil, Icons.groups_rounded, const CouncilHubTab()),
      (
        l.storeTabShop,
        Icons.storefront_rounded,
        value == null
            ? const SizedBox.shrink()
            : _ShopTab(wallet: value, onOpen: _open),
      ),
      (
        l.storeTabCollection,
        Icons.checkroom_rounded,
        value == null
            ? const SizedBox.shrink()
            : ValueListenableBuilder<bool>(
                valueListenable: _busy,
                builder: (context, busy, _) => _CollectionTab(
                  wallet: value,
                  busy: busy,
                  onOpen: _open,
                  onEquip: _equip,
                ),
              ),
      ),
      (
        l.storeTabHistory,
        Icons.receipt_long_rounded,
        value == null
            ? const SizedBox.shrink()
            : _HistoryTab(history: value.history),
      ),
      if (play)
        (l.storeTabPlay, Icons.shop_rounded, const PlayOffersTab()),
      if (coins)
        (
          pay.platform == 'android' ? l.pay2TabTransfer : l.storeTabCoins,
          Icons.add_card_rounded,
          const CoinPacksTab(),
        ),
    ];
    final council = tabs.indexWhere((t) => t.$1 == l.storeTabCouncil);
    return DefaultTabController(
      length: tabs.length,
      initialIndex: ref.read(pendingInviteCodeProvider) != null && council >= 0
          ? council
          : 0,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The vault's own room behind it: on a wide window the column no
        // longer floats in a black void, and on a phone it reads as a place.
        body: AppBackdrop(
          image: StoreArt.hero,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surfaceBase.withValues(
                alpha: StoreTokens.backdropShade,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _VaultHeader(
                    balance: value?.balance,
                    loading: wallet.isLoading,
                    onClose: widget.onClose,
                    tabs: [for (final tab in tabs) (tab.$1, tab.$2)],
                  ),
                  if (wallet.hasError && value == null)
                    Padding(
                      padding: EdgeInsets.all(context.spacing.md),
                      child: Column(
                        children: [
                          Text(
                            l.coinsLoadFailed,
                            style: context.typography.body,
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.read(walletProvider.notifier).refresh(),
                            child: Text(l.videoRetry),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [for (final tab in tabs) tab.$3],
                    ),
                  ),
                  // Phase 108: vault browse is a waiting surface; zero size
                  // unless switched on and filled.
                  const SafeArea(top: false, child: WaitingBanner()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The vault's head, in the same reading column as its contents: close,
/// title and the balance on one line, the rooms (tabs) under it with a mark
/// each. On a wide window the tabs sit centred under the title instead of
/// running off to one edge.
class _VaultHeader extends StatelessWidget {
  final int? balance;
  final bool loading;
  final VoidCallback? onClose;
  final List<(String, IconData)> tabs;
  const _VaultHeader({
    required this.balance,
    required this.loading,
    required this.onClose,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final close = onClose;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: StoreTokens.maxContentWidth,
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= StoreTokens.headerWideAt;
              final inline = box.maxWidth >= StoreTokens.headerInlineAt;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: s.xs,
                      end: s.sm,
                      top: s.xs,
                    ),
                    child: Row(
                      children: [
                        if (close != null)
                          IconButton(
                            key: CoinStore.closeKey,
                            onPressed: close,
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            icon: const Icon(Icons.close),
                          )
                        else
                          SizedBox(width: s.sm),
                        Expanded(
                          child: Text(
                            l.vaultTitle,
                            style: context.typography.headline.copyWith(
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Beside the title when there is room for both.
                        if (inline)
                          _WalletStrip(balance: balance, loading: loading),
                      ],
                    ),
                  ),
                  // A phone: the balance on its own line under the title.
                  if (!inline)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: s.md,
                        end: s.sm,
                        top: s.xs,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _WalletStrip(
                          balance: balance,
                          loading: loading,
                        ),
                      ),
                    ),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: wide
                        ? TabAlignment.center
                        : TabAlignment.start,
                    dividerColor: Colors.transparent,
                    indicatorColor: colors.accentGold,
                    labelColor: colors.accentGold,
                    unselectedLabelColor: colors.textSecondary,
                    tabs: [
                      for (final (label, icon) in tabs)
                        Tab(
                          height: StoreTokens.tabHeight,
                          icon: Icon(icon),
                          iconMargin: EdgeInsets.only(bottom: s.xs),
                          text: label,
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The balance as a pill in the vault's header, on every tab. How coins are
/// earned is one tap away rather than three lines above the catalog.
class _WalletStrip extends StatelessWidget {
  final int? balance;
  final bool loading;
  const _WalletStrip({required this.balance, required this.loading});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(context.radii.button),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: s.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MafiaCoin(
              size: CosmeticTokens.coinHeader / StoreTokens.walletCoinScale,
              shine: true,
            ),
            SizedBox(width: s.xs),
            Semantics(
              label: balance == null ? null : l.storeBalance(balance!),
              excludeSemantics: balance != null,
              child: Text(
                balance == null ? '…' : '$balance',
                key: CoinStore.balanceKey,
                style: context.typography.title.copyWith(
                  color: colors.accentGold,
                ),
              ),
            ),
            SizedBox(width: s.xs),
            Flexible(
              child: Text(
                l.coinsName,
                style: context.typography.caption.copyWith(
                  color: colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (loading)
              SizedBox.square(
                dimension: s.md,
                child: const CircularProgressIndicator(
                  strokeWidth: StoreTokens.progressStroke,
                ),
              ),
            IconButton(
              key: CoinStore.earnInfo,
              tooltip: l.storeAboutCoins,
              icon: const Icon(Icons.info_outline),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l.storeAboutCoins),
                  content: const _EarnHint(),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        MaterialLocalizations.of(context).okButtonLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Roughly how many online matches an amount takes, from the current reward
/// contract (sync_player_rewards): a win's extra is not counted. [v3] is the
/// server's `economy.version=3` rule (25 a match instead of 100).
int matchesFor(int coins, {bool v3 = false}) =>
    (coins / (v3 ? coinsPerFinishedMatchV3 : coinsPerFinishedMatch)).ceil();

/// What the server pays per finished match, in words; follows the contract
/// the capabilities negotiated.
class _EarnHint extends ConsumerWidget {
  final TextStyle? style;
  const _EarnHint({this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v3 =
        ref.watch(economyCapabilitiesProvider).valueOrNull?.economyV3 ?? false;
    return Text(v3 ? l.coinsEarnHintV3 : l.coinsEarnHint, style: style);
  }
}

class _ShopTab extends StatelessWidget {
  final WalletState wallet;
  final ValueChanged<String> onOpen;
  const _ShopTab({required this.wallet, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    List<WalletItem> of(CosmeticKind kind) => [
      for (final item in wallet.catalog)
        if (Cosmetics.items[item.code]!.kind == kind) item,
    ];
    final sections = <(String, String, List<WalletItem>)>[
      ('frames', l.storeFrames, of(CosmeticKind.frame)),
      ('plates', l.storeNameplates, of(CosmeticKind.nameplate)),
      ('rooms', l.storeSectionPacks, of(CosmeticKind.presentationPack)),
      ('narration', l.storeSectionNarrator, of(CosmeticKind.narratorPack)),
      ('bundles', l.storeSectionBundles, of(CosmeticKind.bundle)),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        // A readable column on a wide window; edge to edge on a phone.
        final side = math.max(
          s.md,
          (box.maxWidth - StoreTokens.maxContentWidth) / 2,
        );
        return ListView(
          key: CoinStore.shopList,
          padding: EdgeInsets.symmetric(horizontal: side, vertical: s.md),
          children: [
            const _VaultHero(),
            for (final (id, title, items) in sections)
              if (items.isNotEmpty) ...[
                SizedBox(height: s.lg),
                _ProductRail(
                  id: id,
                  title: title,
                  wallet: wallet,
                  items: items,
                  onOpen: onOpen,
                ),
              ],
            SizedBox(height: s.lg),
            SettingsPanel(
              icon: Icons.info_outline,
              title: l.storeAboutCoins,
              divided: false,
              children: [
                _EarnHint(
                  style: context.typography.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
            const AccountProtectionCard(),
          ],
        );
      },
    );
  }
}

/// The vault's cabinet on one side, its promise on the other. The art is
/// mirrored for left-to-right text so the words always sit on its dark half.
class _VaultHero extends StatelessWidget {
  const _VaultHero();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ltr = Directionality.of(context) == TextDirection.ltr;
    // No box: the cabinet dissolves into the vault around it.
    return Padding(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: StoreTokens.heroHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Opacity(
                opacity: MotionTokens.vaultEmberOpacity,
                child: MotionSprite(
                  AppMotion.emberDrift,
                  width: MotionTokens.emberWidth,
                  height: MotionTokens.emberHeight,
                ),
              ),
            ),
            FeatheredArt(
              feather: Feather.banner,
              halo: false,
              child: Transform.flip(
                flipX: ltr,
                child: Image.asset(
                  StoreArt.heroCover,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: colors.surfaceRaised),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [
                    colors.surfaceBase.withValues(alpha: StoreTokens.heroShade),
                    colors.surfaceBase.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacing.md,
                vertical: context.spacing.sm,
              ),
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: StoreTokens.heroTextWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.vaultSubtitle,
                      style: context.typography.body.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      context.l10n.storePresentationNote,
                      style: context.typography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One category: a heading, arrows for a mouse or a keyboard, and a
/// horizontal rail that starts at the reading side and shows the next card's
/// edge. No auto-scroll.
class _ProductRail extends StatefulWidget {
  final String id;
  final String title;
  final WalletState wallet;
  final List<WalletItem> items;
  final ValueChanged<String> onOpen;
  const _ProductRail({
    required this.id,
    required this.title,
    required this.wallet,
    required this.items,
    required this.onOpen,
  });

  @override
  State<_ProductRail> createState() => _ProductRailState();
}

class _ProductRailState extends State<_ProductRail> {
  final _scroll = ScrollController();
  bool _back = false;
  bool _forward = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _measure() {
    if (!mounted || !_scroll.hasClients) return false;
    final p = _scroll.position;
    if (!p.hasContentDimensions) return false;
    final back = p.pixels > p.minScrollExtent + StoreTokens.hairlineOverlap;
    final forward = p.pixels < p.maxScrollExtent - StoreTokens.hairlineOverlap;
    if (back != _back || forward != _forward) {
      setState(() {
        _back = back;
        _forward = forward;
      });
    }
    return false;
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    // A page is what is on screen, less one card so the context carries over.
    final page = math.max(
      StoreTokens.cardWidth,
      p.viewportDimension - StoreTokens.cardWidth / 2,
    );
    final target = (p.pixels + direction * page).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
      return;
    }
    _scroll.animateTo(
      target,
      duration: context.motion.standard,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: context.typography.title.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ),
            // Chevrons follow the reading direction: «next» points the way
            // the rail continues, left in Arabic and right in English.
            if (_back || _forward) ...[
              IconButton(
                tooltip: l.storeBrowsePrevious,
                onPressed: _back ? () => _move(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                key: CoinStore.railNext(widget.id),
                tooltip: l.storeBrowseNext,
                onPressed: _forward ? () => _move(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ] else
              const SizedBox(height: StoreTokens.touchTarget),
          ],
        ),
        SizedBox(height: s.xs),
        SizedBox(
          height: StoreTokens.railHeight,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) => _measure(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) => _measure(),
              child: ListView.separated(
                key: CoinStore.rail(widget.id),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                itemCount: widget.items.length,
                separatorBuilder: (_, _) => SizedBox(width: s.sm),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final slot = Cosmetics.items[item.code]!.slot;
                  return _ProductCard(
                    item: item,
                    owned: widget.wallet.owned.contains(item.code),
                    equipped:
                        slot != null &&
                        widget.wallet.equipped[slot.wire] == item.code,
                    onTap: () => widget.onOpen(item.code),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Art, name, what it does, and the server's price — or that it is yours.
class _ProductCard extends StatelessWidget {
  final WalletItem item;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;
  const _ProductCard({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final cosmetic = Cosmetics.items[item.code]!;
    final radius = BorderRadius.circular(context.radii.card);
    return SizedBox(
      width: StoreTokens.cardWidth,
      child: VaultPress(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              ...context.elevation.level1,
              if (equipped)
                BoxShadow(
                  color: VaultTokens.gold.withValues(
                    alpha: VaultTokens.litGlowAlpha,
                  ),
                  blurRadius: VaultTokens.litGlowBlur,
                ),
            ],
          ),
          child: Material(
            color: equipped
                ? Color.alphaBlend(
                    VaultTokens.gold.withValues(alpha: VaultTokens.lampWash),
                    colors.surfaceRaised,
                  )
                : colors.surfaceRaised,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: equipped
                  ? const BorderSide(
                      color: VaultTokens.gold,
                      width: StoreTokens.selectedBorder,
                    )
                  : BorderSide(color: colors.borderSubtle),
            ),
            child: InkWell(
              key: CoinStore.item(item.code),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(s.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: StoreTokens.artHeight,
                      width: double.infinity,
                      child: DecoratedBox(
                        // The art sits in a lit well: lamp-light from above on
                        // the dark ground.
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.35),
                            radius: 0.9,
                            colors: [
                              Color.alphaBlend(
                                VaultTokens.gold.withValues(
                                  alpha: VaultTokens.lampAlpha / 2,
                                ),
                                colors.surfaceBase,
                              ),
                              colors.surfaceBase,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            context.radii.button,
                          ),
                          border: Border.all(
                            color: VaultTokens.gold.withValues(
                              alpha: VaultTokens.engraveAlpha,
                            ),
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            StoreProductArt(code: item.code),
                            if (owned || equipped)
                              PositionedDirectional(
                                top: s.xs,
                                start: s.xs,
                                child: SettingsPill(
                                  text: equipped
                                      ? l.storeEquipped
                                      : l.storeOwned,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: s.sm),
                    Text(
                      cosmetic.name(l),
                      style: context.typography.body.emphasised.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      cosmetic.description(l),
                      style: context.typography.caption.copyWith(
                        color: colors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (owned || equipped)
                      Row(
                        children: [
                          Icon(
                            equipped
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline,
                            size: CosmeticTokens.coinInline,
                            color: VaultTokens.gold,
                          ),
                          SizedBox(width: s.xs),
                          Text(
                            equipped ? l.storeEquipped : l.storeOwned,
                            style: context.typography.bodySmall.copyWith(
                              color: equipped
                                  ? VaultTokens.gold
                                  : colors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    else
                      CoinAmount(
                        item.charge,
                        style: context.typography.title.copyWith(
                          color: VaultTokens.goldLight,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Details, the real preview, and the one action that fits — pinned under
/// the preview so it is reachable without scrolling on any phone.
class _ItemSheet extends ConsumerWidget {
  final String code;
  final ValueListenable<bool> busy;
  final Future<void> Function(WalletItem) onBuy;
  final Future<void> Function(CosmeticSlot, String?) onEquip;
  const _ItemSheet({
    required this.code,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = context.spacing;
    final wallet = ref.watch(walletProvider).valueOrNull;
    final cosmetic = Cosmetics.items[code]!;
    final item = wallet?.item(code);
    final owned = wallet?.owned.contains(code) ?? false;
    final slot = cosmetic.slot;
    final equipped = slot != null && wallet?.equipped[slot.wire] == code;
    final balance = wallet?.balance ?? 0;
    final bundleContents = Cosmetics.bundles[code] ?? const <String>[];
    final ownsAllContents =
        bundleContents.isNotEmpty &&
        bundleContents.every((c) => wallet?.owned.contains(c) ?? false);
    final room = cosmetic.kind == CosmeticKind.presentationPack;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: SheetTokens.previewInitialFraction,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              key: CoinStore.sheetList,
              controller: controller,
              padding: EdgeInsets.fromLTRB(
                s.screenMargin,
                0,
                s.screenMargin,
                s.md,
              ),
              children: [
                Text(cosmetic.name(l), style: context.typography.headline),
                SizedBox(height: s.xs),
                Wrap(
                  spacing: s.sm,
                  runSpacing: s.xs,
                  children: [
                    SettingsPill(text: l.storePermanent),
                    if (owned) SettingsPill(text: l.storeOwned),
                    if (equipped) SettingsPill(text: l.storeEquipped),
                  ],
                ),
                SizedBox(height: s.md),
                CosmeticPreview(
                  code: code,
                  equipped: wallet?.equipped ?? const {},
                ),
                SizedBox(height: s.md),
                Text(cosmetic.description(l), style: context.typography.body),
                if (room || cosmetic.kind == CosmeticKind.narratorPack)
                  Padding(
                    padding: EdgeInsets.only(top: s.xs),
                    child: Text(
                      l.storeHostPackNote,
                      style: context.typography.bodySmall,
                    ),
                  ),
                if (room)
                  Padding(
                    padding: EdgeInsets.only(top: s.xs),
                    child: Text(
                      l.storeRoomArtNote,
                      style: context.typography.bodySmall,
                    ),
                  ),
                if (item != null &&
                    cosmetic.kind == CosmeticKind.bundle &&
                    (ownsAllContents ||
                        _sum(wallet!, bundleContents) > item.charge))
                  Padding(
                    padding: EdgeInsets.only(top: s.sm),
                    child: Text(
                      ownsAllContents
                          ? l.storeBundleOwnedAll
                          : l.storeBundleSaves(
                              _sum(wallet!, bundleContents) - item.charge,
                            ),
                      style: context.typography.bodySmall.copyWith(
                        color: context.colors.accentGold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.colors.borderSubtle),
              ),
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
                  valueListenable: busy,
                  builder: (context, working, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (owned && slot != null)
                        FilledButton(
                          key: CoinStore.equip(code),
                          onPressed: working
                              ? null
                              : () => onEquip(slot, equipped ? null : code),
                          child: Text(equipped ? l.storeUnequip : l.storeEquip),
                        )
                      else if (!owned && item != null && !ownsAllContents)
                        FilledButton(
                          key: CoinStore.buy(code),
                          onPressed: balance >= item.charge && !working
                              ? () => onBuy(item)
                              : null,
                          child: Text(
                            balance >= item.charge
                                ? l.storeBuyFor(item.charge)
                                : l.storeNotEnough(item.charge - balance),
                          ),
                        ),
                      if (!owned && item != null && balance < item.charge)
                        Padding(
                          padding: EdgeInsets.only(top: s.xs),
                          child: Text(
                            l.storeEarnTime(
                              item.charge - balance,
                              matchesFor(
                                item.charge - balance,
                                v3:
                                    ref
                                        .watch(economyCapabilitiesProvider)
                                        .valueOrNull
                                        ?.economyV3 ??
                                    false,
                              ),
                            ),
                            style: context.typography.bodySmall,
                            textAlign: TextAlign.center,
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

  static int _sum(WalletState wallet, List<String> codes) => [
    for (final c in codes)
      if (!wallet.owned.contains(c)) wallet.item(c)?.price ?? 0,
  ].fold(0, (a, b) => a + b);
}

class _CollectionTab extends StatelessWidget {
  final WalletState wallet;
  final bool busy;
  final ValueChanged<String> onOpen;
  final Future<void> Function(CosmeticSlot, String?) onEquip;
  const _CollectionTab({
    required this.wallet,
    required this.busy,
    required this.onOpen,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Worn first, then by kind (frames, plates, packs, narrators), then name.
    final owned =
        [
          for (final code in wallet.owned)
            if (Cosmetics.items[code]?.slot != null) code,
        ]..sort((a, b) {
          final wa = wallet.equipped.values.contains(a) ? 0 : 1;
          final wb = wallet.equipped.values.contains(b) ? 0 : 1;
          if (wa != wb) return wa - wb;
          final ka = Cosmetics.items[a]!.kind.index;
          final kb = Cosmetics.items[b]!.kind.index;
          return ka != kb ? ka - kb : a.compareTo(b);
        });
    if (owned.isEmpty) {
      return Center(
        child: Text(l.storeEmptyCollection, style: context.typography.body),
      );
    }
    return ListView(
      padding: EdgeInsets.all(context.spacing.md),
      children: [
        for (final code in owned)
          Builder(
            builder: (context) {
              final cosmetic = Cosmetics.items[code]!;
              final slot = cosmetic.slot!;
              final equipped = wallet.equipped[slot.wire] == code;
              return Material(
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox.square(
                    dimension: StoreTokens.thumbnail,
                    child: StoreProductArt(code: code),
                  ),
                  title: Text(cosmetic.name(l)),
                  // Store truth: where it shows, and whether it is worn.
                  subtitle: Text(
                    equipped
                        ? '${l.storeWearing} · ${storeWhatItChanges(l, cosmetic.kind)}'
                        : storeWhatItChanges(l, cosmetic.kind),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: equipped
                        ? context.typography.caption.copyWith(
                            color: VaultTokens.gold,
                          )
                        : context.typography.caption,
                  ),
                  onTap: () => onOpen(code),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: CoinStore.tryOn(code),
                        tooltip: l.storeTryOn,
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: () => showTryOn(context, code),
                      ),
                      TextButton(
                        key: CoinStore.equip(code),
                        onPressed: busy
                            ? null
                            : () => onEquip(slot, equipped ? null : code),
                        child: Text(equipped ? l.storeUnequip : l.storeEquip),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final List<LedgerEntry> history;
  const _HistoryTab({required this.history});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (history.isEmpty) {
      return Center(
        child: Text(l.storeEmptyHistory, style: context.typography.body),
      );
    }
    final dates = MaterialLocalizations.of(context);
    String name(String? code) =>
        code == null ? '' : Cosmetics.items[code]?.name(l) ?? l.coinsGuideTitle;
    String label(LedgerEntry entry) => switch (entry.kind) {
      'match_completion' => l.historyMatchCompletion,
      'match_win' => l.historyMatchWin,
      'catalog_spend' => l.historyCatalogSpend(name(entry.item)),
      'catalog_refund' => l.historyCatalogRefund(name(entry.item)),
      'ad_reward' => l.historyAdReward,
      'ad_step_1' || 'ad_step_2' => l.historyAdStep,
      'daily_coffer' => l.historyDailyCoffer,
      'daily_wheel' => l.historyDailyWheel,
      'daily_week_bonus' => l.historyDailyWeek,
      'daily_ad' => l.historyDailyAd,
      'play_coin_purchase' => l.historyPlayCoins,
      'play_coin_reversal' => l.historyPlayReversal,
      'coin_purchase' => l.historyCoinPurchase,
      'coin_purchase_reversal' => l.historyCoinPurchaseReversal,
      _ => l.historyAdjustment,
    };
    return ListView(
      padding: EdgeInsets.all(context.spacing.md),
      children: [
        for (final entry in history)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(label(entry)),
            subtitle: entry.at == null
                ? null
                : Text(dates.formatShortDate(entry.at!.toLocal())),
            trailing: Text(
              entry.amount > 0 ? '+${entry.amount}' : '${entry.amount}',
              style: context.typography.title.copyWith(
                color: entry.amount > 0
                    ? context.colors.accentGold
                    : context.colors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
