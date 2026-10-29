import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/voice/voice_controller.dart' show VoiceMode;
import '../../l10n_ext.dart';
import '../../economy/council_hub.dart' show pendingInviteCodeProvider;
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/voice_mic_button.dart';
import '../setup/coin_store.dart';
import 'safety_center.dart';
import 'voice_session.dart';

/// The lobby's header (#u6): the room's name, three icon buttons and «⋯».
///
/// The old header was a spacer and up to seven 48dp icons, which is more than
/// a 360dp phone has once the voice controls grow a text button on the web.
/// Here the room's name takes whatever width is left and ellipsises, three
/// controls stay on screen — the microphone, the room's rules (the host) or
/// the report tools (everyone else), and leaving — and the rest live behind
/// the overflow menu, so nothing can overlap whatever the name or the width.
class LobbyHeader extends ConsumerStatefulWidget {
  /// The room's own name, or «الأوضة 4821» when the host never gave it one.
  final String title;
  final bool isHost;
  final VoidCallback onSettings;
  final VoidCallback onLeave;

  /// The lobby's own keys for the two buttons its tests already find by key.
  final Key? settingsKey;
  final Key? leaveKey;

  const LobbyHeader({
    super.key,
    required this.title,
    required this.isHost,
    required this.onSettings,
    required this.onLeave,
    this.settingsKey,
    this.leaveKey,
  });

  static const Key titleKey = ValueKey('lobby_header_title');
  static const Key moreButton = ValueKey('lobby_header_more');
  static const Key moreStore = ValueKey('lobby_header_more_store');
  static const Key moreSafety = ValueKey('lobby_header_more_safety');
  static const Key moreAudio = ValueKey('lobby_header_more_audio');
  static const Key safetyIcon = ValueKey('lobby_header_safety');

  @override
  ConsumerState<LobbyHeader> createState() => _LobbyHeaderState();
}

enum _Panel { store, safety }

enum _More { store, safety, audio }

class _LobbyHeaderState extends ConsumerState<LobbyHeader> {
  final _overlay = OverlayPortalController();
  _Panel _panel = _Panel.store;

  ProviderSubscription<String?>? _invite;

  @override
  void initState() {
    super.initState();
    // An invite link opens the vault by itself, on the Council tab. The lobby
    // used to get this from the store button it mounted; the button is in the
    // «⋯» menu now, so the header keeps the listener (identical behaviour:
    // fires for a code already waiting, and for one that arrives later).
    _invite = ref.listenManual<String?>(pendingInviteCodeProvider, (_, next) {
      if (next != null && !_overlay.isShowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_overlay.isShowing) _open(_Panel.store);
        });
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _invite?.close();
    super.dispose();
  }

  void _open(_Panel panel) {
    setState(() => _panel = panel);
    _overlay.show();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final type = context.typography;
    final spacing = context.spacing;
    final voice = ref.watch(voiceStateProvider).valueOrNull;
    final controller = ref.watch(voiceControllerProvider);
    final hasAudioControl =
        controller != null && voice != null && voice.mode != VoiceMode.off;

    return OverlayPortal(
      controller: _overlay,
      // System back closes the panel, not the lobby under it.
      overlayChildBuilder: (_) => Positioned.fill(
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _overlay.hide();
          },
          child: _panel == _Panel.store
              ? CoinStore(onClose: _overlay.hide)
              : SafetyCenter(onClose: _overlay.hide),
        ),
      ),
      child: IconButtonTheme(
        // Four 48dp controls and a name must fit 320dp: the tap target stays
        // 48dp, the glyphs just draw tighter.
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            visualDensity:
                MediaQuery.sizeOf(context).width < VaultTokens.narrowHeaderWidth
                ? VisualDensity.compact
                : null,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: spacing.sm),
                child: Text(
                  widget.title,
                  key: LobbyHeader.titleKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.title.copyWith(color: colors.textPrimary),
                ),
              ),
            ),
            // Out of the match only: this is where the lobby's voice lives.
            const VoiceMicButton(compact: true),
            if (widget.isHost)
              IconButton(
                key: widget.settingsKey,
                tooltip: l10n.onlineRoomSettings,
                onPressed: widget.onSettings,
                icon: Icon(Icons.tune, color: colors.textSecondary),
              )
            else
              IconButton(
                key: LobbyHeader.safetyIcon,
                tooltip: l10n.safetyTools,
                onPressed: () => _open(_Panel.safety),
                icon: Icon(Icons.flag_outlined, color: colors.textSecondary),
              ),
            IconButton(
              key: widget.leaveKey,
              tooltip: l10n.onlineLeave,
              onPressed: widget.onLeave,
              icon: Icon(Icons.logout, color: colors.textSecondary),
            ),
            PopupMenuButton<_More>(
              key: LobbyHeader.moreButton,
              tooltip: l10n.lobbyMoreMenu,
              icon: Icon(Icons.more_horiz, color: colors.textSecondary),
              color: colors.surfaceRaised,
              onSelected: (choice) {
                switch (choice) {
                  case _More.store:
                    _open(_Panel.store);
                  case _More.safety:
                    _open(_Panel.safety);
                  case _More.audio:
                    controller?.enableAudio();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: LobbyHeader.moreStore,
                  value: _More.store,
                  child: Text(l10n.storeTitle),
                ),
                if (widget.isHost)
                  PopupMenuItem(
                    key: LobbyHeader.moreSafety,
                    value: _More.safety,
                    child: Text(l10n.safetyTools),
                  ),
                if (hasAudioControl)
                  PopupMenuItem(
                    key: LobbyHeader.moreAudio,
                    value: _More.audio,
                    child: Text(l10n.voiceEnablePlayback),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
