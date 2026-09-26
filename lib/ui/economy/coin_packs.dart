import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/links/external_link.dart';
import '../../transport/online_backend.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/mafia_theme.dart';
import 'account_protection.dart';
import 'mafia_coin.dart';
import 'wallet.dart';
import 'store_art.dart';
import '../theme/design_tokens.dart';

/// One pack as the server prices it. Amounts are piastres (1/100 EGP).
class CoinPack {
  final String code;
  final int coins;
  final int pricePiastres;

  /// Set for the Quiet Pass: it grants this instead of coins, and the web
  /// buyer's Android app carries it on the same linked account.
  final String? entitlement;
  const CoinPack(this.code, this.coins, this.pricePiastres, [this.entitlement]);

  bool get pass => entitlement != null;
}

class PayMethod {
  final String code;
  final bool available;
  final String? url;
  const PayMethod(this.code, this.available, this.url);
}

class CoinOrder {
  final String id;
  final String reference;
  final int coins;
  final int amountPiastres;
  final String method;
  final String status;
  final String? note;
  const CoinOrder({
    required this.id,
    required this.reference,
    required this.coins,
    required this.amountPiastres,
    required this.method,
    required this.status,
    this.note,
  });

  factory CoinOrder.fromJson(Map<String, dynamic> j) => CoinOrder(
    id: j['id'] as String,
    reference: j['reference'] as String? ?? '',
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    amountPiastres: (j['amountPiastres'] as num?)?.toInt() ?? 0,
    method: j['method'] as String? ?? '',
    status: j['status'] as String? ?? '',
    note: j['playerNote'] as String?,
  );

  bool get open =>
      const {'awaiting_transfer', 'claimed', 'needs_info'}.contains(status);
}

class CoinShop {
  final bool enabled;
  final bool recoverable;
  final List<CoinPack> packs;
  final List<PayMethod> methods;
  final List<CoinOrder> orders;

  /// This account already has the Quiet Pass (from Play or the web).
  final bool adFree;
  const CoinShop({
    required this.enabled,
    required this.recoverable,
    required this.packs,
    required this.methods,
    required this.orders,
    this.adFree = false,
  });

  factory CoinShop.fromJson(Map<String, dynamic> j) => CoinShop(
    enabled: j['enabled'] as bool? ?? false,
    recoverable: j['recoverable'] as bool? ?? false,
    adFree: j['adFree'] == true,
    packs: [
      for (final p in (j['packs'] as List? ?? const []).whereType<Map>())
        if (p['pricePiastres'] is num &&
            ((p['coins'] as num?) ?? 0) >= 0 &&
            (p['entitlement'] == null || p['entitlement'] == 'remove_interruptions'))
          CoinPack(
            p['code'] as String,
            ((p['coins'] as num?) ?? 0).toInt(),
            (p['pricePiastres'] as num).toInt(),
            p['entitlement'] as String?,
          ),
    ],
    methods: [
      for (final m in (j['methods'] as List? ?? const []).whereType<Map>())
        PayMethod(
          m['code'] as String,
          m['available'] == true,
          m['available'] == true ? m['url'] as String? : null,
        ),
    ],
    orders: [
      for (final o in (j['orders'] as List? ?? const []).whereType<Map>())
        CoinOrder.fromJson(Map<String, dynamic>.from(o)),
    ],
  );

  /// The one order this player may still act on (server allows one open).
  CoinOrder? get current =>
      orders.where((o) => o.open).firstOrNull ??
      orders.where((o) => o.status == 'expired').firstOrNull;
}

String egp(int piastres) => piastres % 100 == 0
    ? '${piastres ~/ 100}'
    : (piastres / 100).toStringAsFixed(2);

final coinShopProvider = AsyncNotifierProvider<CoinShopController, CoinShop>(
  CoinShopController.new,
);

/// Everything goes through `coin_orders`; nothing here changes a balance.
/// Coins appear only when the wallet is re-read after an admin approval.
class CoinShopController extends AsyncNotifier<CoinShop> {
  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('coin_orders', body);
  }

  @override
  Future<CoinShop> build() async =>
      CoinShop.fromJson(await _call({'action': 'shop'}));

  Future<void> reload() async {
    state = await AsyncValue.guard(build);
    // An approval may have landed; the wallet is the server's to say.
    await ref.read(walletProvider.notifier).refresh();
  }

  Future<void> create(String pack, String method) async {
    await _call({'action': 'create', 'pack': pack, 'method': method});
    state = await AsyncValue.guard(build);
  }

  Future<void> claim(String order, String reference, String? payer) async {
    await _call({
      'action': 'claim',
      'order': order,
      'reference': reference,
      if (payer != null && payer.trim().isNotEmpty) 'payerHint': payer,
    });
    state = await AsyncValue.guard(build);
  }

  Future<void> cancel(String order) async {
    await _call({'action': 'cancel', 'order': order});
    state = await AsyncValue.guard(build);
  }
}

String methodName(BuildContext context, String code) => code == 'instapay'
    ? context.l10n.coinPayInstapay
    : context.l10n.coinPayVodafone;

/// The web store's coin packs: manual transfer review, never automatic.
class CoinPacksTab extends ConsumerStatefulWidget {
  const CoinPacksTab({super.key});

  static Key pack(String code) => ValueKey('coin_pack_$code');
  static Key method(String code) => ValueKey('coin_method_$code');
  static const createButton = ValueKey('coin_create_order');
  static const openButton = ValueKey('coin_open_payment');
  static const referenceField = ValueKey('coin_reference');
  static const claimButton = ValueKey('coin_claim');
  static const cancelButton = ValueKey('coin_cancel');
  static const notice = ValueKey('coin_manual_notice');
  static const passNote = ValueKey('coin_pass_note');

  @override
  ConsumerState<CoinPacksTab> createState() => _CoinPacksTabState();
}

class _CoinPacksTabState extends ConsumerState<CoinPacksTab> {
  String? _pack;
  bool _busy = false;

  /// A late (expired) order stays claimable; this sets it aside to start a
  /// new one without losing it (it remains in the list and on the server).
  bool _newOrder = false;
  final _reference = TextEditingController();
  final _payer = TextEditingController();
  final _packScroll = ScrollController();

  @override
  void dispose() {
    _reference.dispose();
    _payer.dispose();
    _packScroll.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _act(Future<void> Function(CoinShopController) step) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await step(ref.read(coinShopProvider.notifier));
    } on BackendException catch (error) {
      if (mounted) {
        _say(
          error.code == 'ALREADY_OWNED'
              ? context.l10n.webPassOwned
              : context.l10n.coinOrderFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final shop = ref.watch(coinShopProvider);
    // Linking or recovering an account changes who is buying.
    ref.listen(
      accountStatusProvider,
      (_, _) => ref.invalidate(coinShopProvider),
    );
    return shop.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      // A server without the orders feature (or offline) is "not available",
      // said plainly, with a retry.
      error: (_, _) => Center(
        child: Padding(
          padding: EdgeInsets.all(s.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.coinPacksUnavailable,
                style: context.typography.body,
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => ref.invalidate(coinShopProvider),
                child: Text(l.videoRetry),
              ),
            ],
          ),
        ),
      ),
      data: (shop) {
        if (!shop.enabled) {
          return Padding(
            padding: EdgeInsets.all(s.md),
            child: Text(l.coinPacksUnavailable, style: context.typography.body),
          );
        }
        final current = shop.current;
        final order = current?.status == 'expired' && _newOrder
            ? null
            : current;
        return RefreshIndicator(
          onRefresh: () => ref.read(coinShopProvider.notifier).reload(),
          child: ListView(
            padding: EdgeInsets.all(s.md),
            children: [
              if (!shop.recoverable) ...[
                Text(l.coinPacksNeedAccount, style: context.typography.body),
                SizedBox(height: s.sm),
                const AccountProtectionCard(),
              ] else if (order != null)
                _OrderCard(
                  order: order,
                  method: shop.methods
                      .where((m) => m.code == order.method)
                      .firstOrNull,
                  reference: _reference,
                  payer: _payer,
                  busy: _busy,
                  onClaim: () => _act(
                    (c) =>
                        c.claim(order.id, _reference.text.trim(), _payer.text),
                  ),
                  onCancel: () => _act((c) => c.cancel(order.id)),
                  onOpenFailed: () => _say(l.coinOpenFailed),
                  onNewOrder: order.status == 'expired'
                      ? () => setState(() => _newOrder = true)
                      : null,
                )
              else
                ..._chooser(shop),
              SizedBox(height: s.lg),
              for (final past in shop.orders)
                if (!past.open && past.id != order?.id)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(l.coinOrderTitle(past.reference)),
                    subtitle: Text(settledStatus(context, past)),
                  ),
            ],
          ),
        );
      },
    );
  }

  /// Choose a pack, then tap a method: its payment page opens inside the tap
  /// itself (a real link, never blocked as a pop-up) and the order is made
  /// alongside, so the player comes back to an order waiting for the
  /// transfer reference.
  void _payWith(CoinPack pack, PayMethod method) {
    final opened = ref.read(externalLinkOpenerProvider)(method.url!);
    if (!opened) _say(context.l10n.coinOpenFailed);
    _act((c) => c.create(pack.code, method.code));
  }

  List<Widget> _chooser(CoinShop shop) {
    final l = context.l10n;
    final s = context.spacing;
    final pack = shop.packs.where((p) => p.code == _pack).firstOrNull;
    final passOwned = pack != null && pack.pass && shop.adFree;
    return [
      SizedBox(
        height: StoreTokens.coinRailHeight,
        child: Scrollbar(
          controller: _packScroll,
          thumbVisibility: true,
          child: ListView.separated(
            controller: _packScroll,
            scrollDirection: Axis.horizontal,
            itemCount: shop.packs.length,
            separatorBuilder: (_, _) => SizedBox(width: s.sm),
            itemBuilder: (context, index) {
              final p = shop.packs[index];
              final selected = p.code == _pack;
              return Padding(
                padding: EdgeInsets.only(bottom: s.md),
                child: SizedBox(
                  width: StoreTokens.cardWidth,
                  child: Semantics(
                    selected: selected,
                    inMutuallyExclusiveGroup: true,
                    child: Material(
                      color: context.colors.surfaceRaised,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.radii.card),
                        side: BorderSide(
                          color: selected
                              ? context.colors.accentGold
                              : context.colors.borderSubtle,
                        ),
                      ),
                      child: InkWell(
                        key: CoinPacksTab.pack(p.code),
                        onTap: _busy
                            ? null
                            : () => setState(() => _pack = p.code),
                        child: Padding(
                          padding: EdgeInsets.all(s.sm),
                          child: Column(
                            children: [
                              Expanded(
                                child: p.pass
                                    ? Image.asset(
                                        StoreArt.quietPassCover,
                                        cacheWidth: StoreTokens.frameDecodeWidth,
                                        excludeFromSemantics: true,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox.shrink(),
                                      )
                                    : StoreProductArt(code: p.code),
                              ),
                              if (p.pass)
                                Text(
                                  l.quietPassTitle,
                                  style: context.typography.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                CoinAmount(
                                  p.coins,
                                  style: context.typography.title,
                                ),
                              Text(
                                l.coinPackPrice(egp(p.pricePiastres)),
                                style: context.typography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      if (pack != null && pack.pass) ...[
        SizedBox(height: s.sm),
        Text(
          key: CoinPacksTab.passNote,
          passOwned ? l.webPassOwned : l.webPassBody,
          style: context.typography.bodySmall.copyWith(
            color: passOwned ? context.colors.accentGold : null,
          ),
        ),
      ],
      SizedBox(height: s.sm),
      Text(l.coinPayMethod, style: context.typography.title),
      Text(l.coinPayStep, style: context.typography.bodySmall),
      SizedBox(height: s.sm),
      for (final m in shop.methods) ...[
        FilledButton.icon(
          key: CoinPacksTab.method(m.code),
          icon: const Icon(Icons.open_in_new),
          onPressed: m.available && pack != null && !passOwned && !_busy
              ? () => _payWith(pack, m)
              : null,
          label: Text(
            pack == null
                ? l.coinPayWith(methodName(context, m.code))
                : '${l.coinPayWith(methodName(context, m.code))} · ${l.coinPackPrice(egp(pack.pricePiastres))}',
          ),
        ),
        if (!m.available)
          Text(l.coinPayMethodOff, style: context.typography.caption),
        SizedBox(height: s.xs),
      ],
      SizedBox(height: s.md),
      _Notice(),
    ];
  }
}

class _Notice extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    key: CoinPacksTab.notice,
    padding: EdgeInsets.all(context.spacing.md),
    decoration: BoxDecoration(
      color: context.colors.surfaceRaised,
      borderRadius: BorderRadius.circular(context.radii.card),
      border: Border.all(color: context.colors.accentGold),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.coinManualNotice, style: context.typography.title),
        SizedBox(height: context.spacing.xs),
        Text(
          context.l10n.coinManualDetail,
          style: context.typography.bodySmall,
        ),
      ],
    ),
  );
}

class _OrderCard extends ConsumerWidget {
  final CoinOrder order;
  final PayMethod? method;
  final TextEditingController reference;
  final TextEditingController payer;
  final bool busy;
  final VoidCallback onClaim;
  final VoidCallback onCancel;
  final VoidCallback onOpenFailed;
  final VoidCallback? onNewOrder;
  const _OrderCard({
    this.onNewOrder,
    required this.order,
    required this.method,
    required this.reference,
    required this.payer,
    required this.busy,
    required this.onClaim,
    required this.onCancel,
    required this.onOpenFailed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = context.spacing;
    final name = methodName(context, order.method);
    final canClaim = const {
      'awaiting_transfer',
      'needs_info',
      'expired',
    }.contains(order.status);
    final status = switch (order.status) {
      'awaiting_transfer' => l.coinStatusAwaiting,
      'claimed' => l.coinStatusClaimed,
      'needs_info' => l.coinStatusNeedsInfo(order.note ?? ''),
      'expired' => l.coinStatusExpired,
      _ => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.coinOrderTitle(order.reference),
          style: context.typography.title,
        ),
        Text(
          order.coins == 0
              ? l.coinOrderPassSummary(egp(order.amountPiastres), name)
              : l.coinOrderSummary(order.coins, egp(order.amountPiastres), name),
          style: context.typography.body,
        ),
        SizedBox(height: s.xs),
        Text(status, style: context.typography.bodySmall),
        SizedBox(height: s.md),
        _Notice(),
        if (order.status == 'awaiting_transfer' && method?.url != null) ...[
          SizedBox(height: s.md),
          FilledButton.icon(
            key: CoinPacksTab.openButton,
            icon: const Icon(Icons.open_in_new),
            label: Text(l.coinOpenPayment(name)),
            // Opened inside the tap itself; the order stays open here.
            onPressed: () {
              if (!ref.read(externalLinkOpenerProvider)(method!.url!)) {
                onOpenFailed();
              }
            },
          ),
          Text(l.coinDesktopHint, style: context.typography.bodySmall),
        ],
        if (canClaim) ...[
          SizedBox(height: s.md),
          TextField(
            key: CoinPacksTab.referenceField,
            controller: reference,
            decoration: InputDecoration(labelText: l.coinTransferReference),
          ),
          TextField(
            controller: payer,
            maxLength: 60,
            decoration: InputDecoration(labelText: l.coinPayerHint),
          ),
          Text(l.coinClaimNote, style: context.typography.bodySmall),
          SizedBox(height: s.sm),
          ListenableBuilder(
            listenable: reference,
            builder: (context, _) => FilledButton(
              key: CoinPacksTab.claimButton,
              onPressed: busy || reference.text.trim().length < 4
                  ? null
                  : onClaim,
              child: Text(l.coinSentTransfer),
            ),
          ),
        ],
        if (order.status == 'awaiting_transfer')
          TextButton(
            key: CoinPacksTab.cancelButton,
            onPressed: busy ? null : onCancel,
            child: Text(l.coinCancelOrder),
          ),
        if (onNewOrder != null)
          TextButton(
            onPressed: busy ? null : onNewOrder,
            child: Text(l.storeTabCoins),
          ),
      ],
    );
  }
}

/// What happened to a finished order, in the player's words.
String settledStatus(BuildContext context, CoinOrder order) {
  final l = context.l10n;
  return switch (order.status) {
    'paid' => l.coinStatusPaid(order.coins),
    'rejected' => l.coinStatusRejected(order.note ?? ''),
    'cancelled' => l.coinStatusCancelled,
    'refunded' => l.coinStatusRefunded(order.note ?? ''),
    'expired' => l.coinStatusExpired,
    _ => l.coinStatusClaimed,
  };
}
