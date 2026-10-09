import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/payment_capabilities.dart';
import '../../economy/coin_packs.dart';
import '../../economy/cosmetics.dart';
import '../../economy/council.dart' show councilAttentionProvider;
import '../../economy/council_hub.dart';
import '../../economy/daily_rewards.dart';
import '../../economy/economy_capabilities.dart';
import '../../economy/play_offers.dart';
import '../../economy/purchase_reveal.dart';
import '../../../platform/monetization/play_billing.dart';
import '../../economy/store_art.dart';
import '../../economy/table_tool_names.g.dart' show tableToolCopy;
import '../../economy/table_tools.dart' show tableToolsProvider;
import 'store_shop.dart';
import '../../widgets/textured_surface.dart';
import '../../economy/mafia_coin.dart';
import '../../economy/vault_kit.dart';
import '../../economy/wallet.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/settings_kit.dart';
import '../../widgets/deck/deck_public.dart' show CoinPill;
import '../../account/profile_panels.dart' show profileStatsProvider;
import '../../economy/waiting_banner.dart';

/// Opens the store over the current screen. Reachable from Home, Settings and
/// an out-of-match lobby only: never from inside a match.
class CoinStoreButton extends StatefulWidget {
  final bool compact;

  /// Drawn as a settings row (the general settings' «أكتر» panel).
  final bool tile;

  /// Home's store control in the deck: the balance as a gold pill, once the
  /// player has finished a match (before that, the plain coin). Compact only.
  final bool pill;
  const CoinStoreButton({
    super.key,
    this.compact = false,
    this.tile = false,
    this.pill = false,
  });

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
        : widget.compact && widget.pill
        ? Consumer(
            builder: (context, ref, _) {
              final wallet = ref.watch(walletProvider).valueOrNull;
              final played = ref.watch(profileStatsProvider).valueOrNull;
              final hasPlayed = played != null && played.$1 + played.$2 > 0;
              if (wallet == null || !hasPlayed) {
                return IconButton(
                  key: CoinStoreButton.buttonKey,
                  tooltip: context.l10n.storeTitle,
                  icon: const CouncilAttentionBadge(
                    child: MafiaCoin(size: CosmeticTokens.coinInline),
                  ),
                  onPressed: _show,
                );
              }
              return Semantics(
                button: true,
                label: context.l10n.storeTitle,
                child: CoinPill(
                  key: CoinStoreButton.buttonKey,
                  balance: wallet.balance,
                  onTap: _show,
                ),
              );
            },
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

enum CoinStoreStart { defaultTab, orders }

/// «خزنة المجلس»: wallet, catalog, collection, history and (on the web
/// store only) coin packs.

class CoinStore extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final CoinStoreStart start;
  const CoinStore({
    super.key,
    this.onClose,
    this.start = CoinStoreStart.defaultTab,
  });

  static const closeKey = ValueKey('coins_close');
  static const balanceKey = ValueKey('coins_balance');
  static Key item(String code) => StoreShopKeys.item(code);
  static Key buy(String code) => StoreShopKeys.buy(code);
  static Key equip(String code) => StoreShopKeys.equip(code);
  static Key tryOn(String code) => ValueKey('store_try_on_$code');
  static const Key shopList = StoreShopKeys.shopList;
  static const Key sheetList = StoreShopKeys.sheetList;
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
      // A shelf that failed to load stays failed until it is asked again.
      if (ref.read(tableToolsProvider).hasError) {
        ref.invalidate(tableToolsProvider);
      }
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

  Future<void> _open(String code) => showStoreItemSheet(
    context: context,
    ref: ref,
    code: code,
    busy: _busy,
    alive: () => mounted,
    onEquip: _equip,
  );

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
            : StoreShop(
                wallet: value,
                busy: _busy,
                alive: () => mounted,
                onEquip: _equip,
              ),
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
    final requested = switch (widget.start) {
      CoinStoreStart.orders => tabs.indexWhere(
          (t) => t.$1 == (pay.platform == 'android' ? l.pay2TabTransfer : l.storeTabCoins),
        ),
      CoinStoreStart.defaultTab => -1,
    };
    return DefaultTabController(
      key: ValueKey((widget.start, requested, tabs.length)),
      length: tabs.length,
      initialIndex: requested >= 0
          ? requested
          : ref.read(pendingInviteCodeProvider) != null && council >= 0
          ? council
          : 0,
      child: MafiaScaffold(
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
                  const SafeArea(top: false, child: WaitingBanner(placement: BannerPlacement.vault)),
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
                          // The title shrinks before it is cut: it is the
                          // shop's name.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              l.vaultTitle,
                              style: StoryTokens.ruqaa(
                                context.typography.headline,
                              ).copyWith(color: colors.textPrimary),
                              maxLines: 1,
                            ),
                          ),
                        ),
                        // Exactly as wide as the number; the title yields.
                        _WalletStrip(balance: balance, loading: loading),
                      ],
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

/// The balance as a pill in the vault's header, on every tab: the coin and
/// the number only, so the pill is exactly as wide as the digits. How coins
/// are earned is one tap away rather than three lines above the catalog.
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
              child: balance == null
                  ? Text(
                      '…',
                      key: CoinStore.balanceKey,
                      style: context.typography.title.copyWith(
                        color: colors.accentGold,
                      ),
                    )
                  // Counts to a new balance (a grant, a purchase) instead
                  // of jumping, so the player sees the coins arrive.
                  : TweenAnimationBuilder<double>(
                      tween: Tween(end: balance!.toDouble()),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : WinTokens.balanceCount,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        '${value.round()}',
                        key: CoinStore.balanceKey,
                        style: context.typography.title.copyWith(
                          color: colors.accentGold,
                        ),
                      ),
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

/// What the server pays per finished match, in words; follows the contract
/// the capabilities negotiated.
class _EarnHint extends ConsumerWidget {
  const _EarnHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v3 =
        ref.watch(economyCapabilitiesProvider).valueOrNull?.economyV3 ?? false;
    return Text(v3 ? l.coinsEarnHintV3 : l.coinsEarnHint);
  }
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
    String name(String? code) => code == null
        ? ''
        : Cosmetics.isRole(code)
        ? storeRoleName(l, code)
        : Cosmetics.items[code]?.name(l) ??
              tableToolCopy(l, code)?.$1 ??
              l.coinsGuideTitle;
    String label(LedgerEntry entry) => switch (entry.kind) {
      'match_completion' => l.historyMatchCompletion,
      'match_win' => l.historyMatchWin,
      'catalog_spend' => l.historyCatalogSpend(name(entry.item)),
      'catalog_refund' => l.historyCatalogRefund(name(entry.item)),
      'tool_spend' => l.historyToolSpend(name(entry.item)),
      'bot_win' => l.historyBotWin,
      'story_first_solve' => l.historyStoryFirstSolve,
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
