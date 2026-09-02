import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/textured_surface.dart';
import 'online_session.dart';

/// S-20 — host a room, or join one with six characters.
///
/// ## Two fields and two buttons
///
/// Everything about an online match that a player has to decide before they are
/// in it fits here: what to call themselves, and whether they are starting a
/// room or joining one. There is no account, no password and no email — the
/// session is anonymous by design (doc 10 §10), so a name is the entire
/// identity a table needs.
///
/// ## The failure copy is the feature
///
/// Doc 11 gives four distinct ways this screen can fail — no room (O14), a full
/// room (O15), a finished match, and a server that is not there at all (O9,
/// O11) — and asks for a distinct, actionable message for each rather than a
/// spinner that never resolves. They are the same size as the success path
/// here, and the unreachable case ends with the one offer that is always
/// available: play offline, which needs nothing from anybody.
class OnlineEntryScreen extends ConsumerStatefulWidget {
  /// Where the lobby lives once a room has been joined.
  final VoidCallback onJoined;

  /// The way back to a game that needs no server.
  final VoidCallback onPlayOffline;

  const OnlineEntryScreen({
    super.key,
    required this.onJoined,
    required this.onPlayOffline,
  });

  static const Key nameField = ValueKey('online_name');
  static const Key codeField = ValueKey('online_code');
  static const Key hostButton = ValueKey('online_host');
  static const Key joinButton = ValueKey('online_join');
  static const Key errorText = ValueKey('online_error');
  static const Key offlineButton = ValueKey('online_play_offline');

  @override
  ConsumerState<OnlineEntryScreen> createState() => _OnlineEntryScreenState();
}

class _OnlineEntryScreenState extends ConsumerState<OnlineEntryScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _hasName => _name.text.trim().isNotEmpty;
  bool get _hasCode => _code.text.trim().length == 6;

  Future<void> _host() async {
    await ref.read(onlineSessionProvider.notifier).host(_name.text);
    _maybeLeave();
  }

  Future<void> _join() async {
    await ref
        .read(onlineSessionProvider.notifier)
        .join(code: _code.text, name: _name.text);
    _maybeLeave();
  }

  void _maybeLeave() {
    if (!mounted) return;
    if (ref.read(onlineSessionProvider).isInRoom) widget.onJoined();
  }

  /// The refusal, in words. The code comes from the server and the sentence
  /// comes from here, which is why nothing in `lib/transport` holds copy.
  String? _message(OnlineSessionState session) {
    final l10n = context.l10n;
    return switch (session.errorCode) {
      null => null,
      'ROOM_NOT_FOUND' => l10n.onlineRoomNotFound,
      'ROOM_FULL' => l10n.onlineRoomFull,
      'ROOM_FINISHED' => l10n.onlineRoomFinished,
      'PHASE_CLOSED' => l10n.onlineRoomFinished,
      'UNREACHABLE' =>
        session.projectPaused ? l10n.onlineProjectPaused : l10n.onlineUnreachable,
      _ => l10n.onlineUnreachable,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;
    final l10n = context.l10n;
    final session = ref.watch(onlineSessionProvider);
    final message = _message(session);

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(spacing.screenMargin),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BackAction(onPressed: widget.onPlayOffline),
                  ),
                  SizedBox(height: spacing.lg),
                  Text(
                    l10n.onlineMatch,
                    style: type.headline.copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: spacing.xl),
                  _field(
                    key: OnlineEntryScreen.nameField,
                    controller: _name,
                    label: l10n.onlineYourName,
                    maxLength: 20,
                  ),
                  SizedBox(height: spacing.lg),
                  _field(
                    key: OnlineEntryScreen.codeField,
                    controller: _code,
                    label: l10n.onlineRoomCode,
                    hint: l10n.onlineRoomCodeHint,
                    maxLength: 6,
                    uppercase: true,
                  ),
                  if (message != null) ...[
                    SizedBox(height: spacing.md),
                    Text(
                      key: OnlineEntryScreen.errorText,
                      message,
                      style: type.body.copyWith(color: colors.accentCrimson),
                    ),
                  ],
                  const Spacer(),
                  FilledButton(
                    key: OnlineEntryScreen.joinButton,
                    onPressed:
                        session.busy || !_hasName || !_hasCode ? null : _join,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accentGold,
                      foregroundColor: colors.surfaceBase,
                      padding: EdgeInsets.symmetric(vertical: spacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radii.button),
                      ),
                    ),
                    child: Text(l10n.onlineJoinRoom, style: type.title),
                  ),
                  SizedBox(height: spacing.md),
                  OutlinedButton(
                    key: OnlineEntryScreen.hostButton,
                    onPressed: session.busy || !_hasName ? null : _host,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.borderSubtle),
                      padding: EdgeInsets.symmetric(vertical: spacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radii.button),
                      ),
                    ),
                    child: Text(l10n.onlineCreateRoom, style: type.body),
                  ),
                  if (session.unreachable) ...[
                    SizedBox(height: spacing.md),
                    TextButton(
                      key: OnlineEntryScreen.offlineButton,
                      onPressed: widget.onPlayOffline,
                      child: Text(
                        l10n.onlinePlayOffline,
                        style: type.body.copyWith(color: colors.accentSage),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? hint,
    int? maxLength,
    bool uppercase = false,
  }) {
    final colors = context.colors;
    final type = context.typography;
    final radii = context.radii;

    return TextField(
      key: key,
      controller: controller,
      maxLength: maxLength,
      textCapitalization:
          uppercase ? TextCapitalization.characters : TextCapitalization.words,
      style: type.body.copyWith(color: colors.textPrimary),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        labelStyle: type.caption.copyWith(color: colors.textMuted),
        hintStyle: type.caption.copyWith(color: colors.textMuted),
        filled: true,
        fillColor: colors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.button),
          borderSide: BorderSide(color: colors.borderSubtle),
        ),
      ),
    );
  }
}
