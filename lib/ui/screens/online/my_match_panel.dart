import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../economy/cosmetics.dart';
import '../../economy/my_vault.dart';
import '../../economy/wallet.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';

/// «شكلي وأدواتي»: for every seat in the lobby, what they will wear in this
/// match and the tools they carry into it, without leaving the room.
///
/// A layer in the lobby's Stack, not a route (doc 12 §2.1): when the host starts
/// the match the lobby goes and this goes with it, so it can never sit over a
/// role reveal. The seat is public and the lobby is before any role exists; a
/// frame changed here reaches the other chairs through `room_players`.
class MyMatchPanel extends ConsumerStatefulWidget {
  final bool visible;
  final VoidCallback onClose;

  const MyMatchPanel({super.key, required this.visible, required this.onClose});

  static const Key panel = ValueKey('my_match_panel');
  static const Key closeKey = ValueKey('my_match_close');

  @override
  ConsumerState<MyMatchPanel> createState() => _MyMatchPanelState();
}

class _MyMatchPanelState extends ConsumerState<MyMatchPanel> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _read();
  }

  @override
  void didUpdateWidget(MyMatchPanel old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _read();
  }

  void _read() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(walletProvider).valueOrNull == null) {
        ref.read(walletProvider.notifier).refresh();
      }
    });
  }

  Future<void> _equip(CosmeticSlot slot, String? code) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(walletProvider.notifier).equip(slot, code);
    } on WalletActionFailed {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(context.l10n.storeFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final l = context.l10n;
    final colors = context.colors;
    final s = context.spacing;
    final wallet = ref.watch(walletProvider).valueOrNull;
    return Positioned.fill(
      key: MyMatchPanel.panel,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onClose();
        },
        child: Material(
          color: colors.surfaceBase,
          child: SafeArea(
            child: DefaultTabController(
              length: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.only(start: s.md, top: s.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.lobbyMyLook,
                            style: context.typography.headline.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          key: MyMatchPanel.closeKey,
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: widget.onClose,
                          icon: Icon(Icons.close, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    tabs: [
                      Tab(text: l.vaultLookTitle),
                      Tab(text: l.toolsInMatch),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        wallet == null
                            ? const Center(child: CircularProgressIndicator())
                            : VaultLookRoom(
                                wallet: wallet,
                                busy: _busy,
                                onEquip: _equip,
                              ),
                        const VaultToolBag(),
                      ],
                    ),
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
