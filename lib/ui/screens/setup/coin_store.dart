import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../online/online_session.dart';

class CoinStoreButton extends StatefulWidget {
  const CoinStoreButton({super.key});

  @override
  State<CoinStoreButton> createState() => _CoinStoreButtonState();
}

class _CoinStoreButtonState extends State<CoinStoreButton> {
  final _overlay = OverlayPortalController();

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _overlay,
    overlayChildBuilder: (_) =>
        Positioned.fill(child: CoinStore(onClose: _overlay.hide)),
    child: TextButton.icon(
      icon: const Icon(Icons.toll_outlined),
      label: Text(context.l10n.coinsTitle),
      onPressed: _overlay.show,
    ),
  );
}

class CoinStore extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  const CoinStore({super.key, this.onClose});

  static const closeKey = ValueKey('coins_close');
  static const buyGuideKey = ValueKey('coins_buy_mastermind_guide');

  @override
  ConsumerState<CoinStore> createState() => _CoinStoreState();
}

class _CoinStoreState extends ConsumerState<CoinStore> {
  Map<String, dynamic>? _summary;
  bool _busy = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      final answer = await backend.call('economy', {'action': 'sync'});
      if (mounted) setState(() => _summary = answer);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buy(String item) async {
    final l = context.l10n;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.coinsBuyGuide),
        content: Text(l.coinsBuyConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.coinsUnlock),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      final answer = await backend.call('economy', {
        'action': 'buy',
        'item': item,
      });
      if (mounted) setState(() => _summary = answer);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final spacing = context.spacing;
    final balance = (_summary?['balance'] as num?)?.toInt() ?? 0;
    final owned = ((_summary?['owned'] as List?) ?? const [])
        .whereType<String>()
        .toSet();
    final catalog = ((_summary?['catalog'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final guide = catalog
        .where((item) => item['code'] == 'mastermind_guide')
        .firstOrNull;
    final price = (guide?['price'] as num?)?.toInt() ?? 400;
    final hasGuide = owned.contains('mastermind_guide');

    return Scaffold(
      appBar: AppBar(
        title: Text(l.coinsTitle),
        leading: widget.onClose == null
            ? null
            : IconButton(
                key: CoinStore.closeKey,
                onPressed: widget.onClose,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
              ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
          child: ListView(
            padding: EdgeInsets.all(spacing.screenMargin),
            children: [
              Text(l.coinsBalance(balance), style: context.typography.display),
              SizedBox(height: spacing.sm),
              Text(l.coinsEarnHint, style: context.typography.body),
              SizedBox(height: spacing.lg),
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (_failed) ...[
                Text(l.coinsLoadFailed, style: context.typography.body),
                TextButton(onPressed: _load, child: Text(l.videoRetry)),
              ],
              if (!_busy && guide != null)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l.coinsGuideTitle,
                          style: context.typography.title,
                        ),
                        SizedBox(height: spacing.xs),
                        Text(l.coinsGuideHint, style: context.typography.body),
                        SizedBox(height: spacing.md),
                        if (hasGuide)
                          ExpansionTile(
                            title: Text(l.coinsGuideOpen),
                            children: [
                              Padding(
                                padding: EdgeInsets.all(spacing.md),
                                child: Text(
                                  l.coinsGuideContent,
                                  style: context.typography.body,
                                ),
                              ),
                            ],
                          )
                        else
                          FilledButton.icon(
                            key: CoinStore.buyGuideKey,
                            onPressed: balance >= price && !_busy
                                ? () => _buy('mastermind_guide')
                                : null,
                            icon: const Icon(Icons.lock_open_outlined),
                            label: Text(l.coinsGuidePrice(price)),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
