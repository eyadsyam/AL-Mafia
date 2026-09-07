import 'package:flutter/material.dart';
import '../../../engine/models/player.dart';
import '../../widgets/gender_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transport/game_snapshot.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/textured_surface.dart';
import 'online_session.dart';

/// S-20 — host a room, or join one with six characters.
///
/// ## One question at a time
///
/// This screen used to ask everything at once: a name, a code, and two buttons
/// underneath, so a player arriving with nothing to type stared at a field they
/// had no business filling in, on a screen that had already decided they were
/// joining. The code field was the largest thing on it and it is the thing
/// three players out of five never touch.
///
/// So the screen asks in order. Your name, because both paths need it. Then
/// **which of the two you are** — and only the answer "I have a code" produces
/// a field to type it into. The host never sees an empty code box; the joiner
/// never reaches a button that would refuse them. Nothing about the second step
/// exists until the first is answered.
///
/// A code that arrived from a deep link answers the question by itself: the
/// screen opens on the second step with the field filled, because somebody who
/// tapped an invite has already said which of the two they are.
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

  /// A room code that arrived from outside the app — a deep link a friend
  /// sent (doc 12 §3.1). Opens on the code step with the field filled; it never
  /// joins on its own, because a link that put somebody into a room without
  /// their name and without a tap would be a link that could be sent to them by
  /// anybody.
  final String? initialCode;

  const OnlineEntryScreen({
    super.key,
    required this.onJoined,
    required this.onPlayOffline,
    this.initialCode,
  });

  static const Key nameField = ValueKey('online_name');

  /// Only in the tree once the player has said they are joining.
  static const Key codeField = ValueKey('online_code');

  /// Step one: start a room. Hosts on the spot — there is nothing else to ask.
  static const Key hostButton = ValueKey('online_host');

  /// Step one: "I have a code". Opens the second step; joins nothing.
  static const Key haveCodeButton = ValueKey('online_have_code');
  static const Key browseButton = ValueKey('online_browse');
  static const Key browseList = ValueKey('online_browse_list');

  /// Step two: the join itself.
  static const Key joinButton = ValueKey('online_join');

  static const Key errorText = ValueKey('online_error');
  static const Key offlineButton = ValueKey('online_play_offline');

  @override
  ConsumerState<OnlineEntryScreen> createState() => _OnlineEntryScreenState();
}

/// Which of the two questions the screen is on.
enum _Step { choose, join, browse }

class _OnlineEntryScreenState extends ConsumerState<OnlineEntryScreen> {
  final TextEditingController _name = TextEditingController();
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode?.toUpperCase() ?? '',
  );

  /// A deep link has answered the question, so the screen does not ask it.
  late _Step _step = (widget.initialCode?.isNotEmpty ?? false)
      ? _Step.join
      : _Step.choose;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  PlayerGender _gender = PlayerGender.unspecified;

  /// The browse list, and whether it is being fetched. Null means "not asked
  /// yet", which is the only state that triggers the first load — every state
  /// after that is the host's own pull.
  List<PublicRoom>? _rooms;
  bool _browsing = false;

  bool get _hasName => _name.text.trim().isNotEmpty;
  bool get _hasCode => _code.text.trim().length == 6;

  Future<void> _host() async {
    await ref
        .read(onlineSessionProvider.notifier)
        .host(_name.text, gender: _gender.name);
    _maybeLeave();
  }

  Future<void> _join() async {
    await ref
        .read(onlineSessionProvider.notifier)
        .join(code: _code.text, name: _name.text, gender: _gender.name);
    _maybeLeave();
  }

  void _maybeLeave() {
    if (!mounted) return;
    if (ref.read(onlineSessionProvider).isInRoom) widget.onJoined();
  }

  /// Move between the two steps, and take any standing refusal with you.
  ///
  /// A "no room with that code" left over the two buttons would be a sentence
  /// about a field that is no longer on the screen.
  void _goTo(_Step step) {
    ref.read(onlineSessionProvider.notifier).clearError();
    setState(() => _step = step);
    if (step == _Step.browse && _rooms == null) _refreshRooms();
  }

  /// Task 10: pull-to-refresh only. Nothing here runs on a timer.
  Future<void> _refreshRooms() async {
    setState(() => _browsing = true);
    final rooms = await ref.read(onlineSessionProvider.notifier).browse();
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _browsing = false;
    });
  }

  /// Tapping a public room is the same act as typing its code, so it goes
  /// through the same call and meets the same ban list.
  Future<void> _joinPublic(String code) async {
    _code.text = code;
    await _join();
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
        session.projectPaused
            ? l10n.onlineProjectPaused
            : l10n.onlineUnreachable,
      _ => l10n.onlineUnreachable,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
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
              // Tall enough to fill the screen, and able to scroll when the
              // screen is shorter than it. The form grew — a name, an explicit
              // male/female choice, a room code, and sometimes a refusal to
              // explain — and on a short window or with a large system font
              // the fixed column simply cut the buttons off the bottom. The
              // `Spacer` below still does its job: `IntrinsicHeight` under a
              // minimum of the viewport keeps the actions at the foot of the
              // screen whenever there is room for them.
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: viewport.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: BackAction(
                              onPressed: _step == _Step.choose
                                  ? widget.onPlayOffline
                                  : () => _goTo(_Step.choose),
                            ),
                          ),
                          SizedBox(height: spacing.lg),
                          Text(
                            l10n.onlineMatch,
                            style: type.headline.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          SizedBox(height: spacing.xl),
                          _field(
                            key: OnlineEntryScreen.nameField,
                            controller: _name,
                            label: l10n.onlineYourName,
                            maxLength: 20,
                            // Task 8 — the same control, in the same place, as
                            // the offline roster's. Two marks at the trailing
                            // edge of the name, not a row of its own.
                            suffix: GenderPicker(
                              value: _gender,
                              onChanged: (v) => setState(() => _gender = v),
                            ),
                          ),
                          if (_step == _Step.browse) ...[
                            SizedBox(height: spacing.lg),
                            _browseList(),
                          ],
                          if (_step == _Step.join) ...[
                            SizedBox(height: spacing.lg),
                            _field(
                              key: OnlineEntryScreen.codeField,
                              controller: _code,
                              label: l10n.onlineRoomCode,
                              hint: l10n.onlineRoomCodeHint,
                              maxLength: 6,
                              code: true,
                            ),
                          ],
                          if (message != null) ...[
                            SizedBox(height: spacing.md),
                            Text(
                              key: OnlineEntryScreen.errorText,
                              message,
                              style: type.body.copyWith(
                                color: colors.accentCrimson,
                              ),
                            ),
                          ],
                          const Spacer(),
                          ..._actions(session),
                          if (session.unreachable) ...[
                            SizedBox(height: spacing.md),
                            TextButton(
                              key: OnlineEntryScreen.offlineButton,
                              onPressed: widget.onPlayOffline,
                              child: Text(
                                l10n.onlinePlayOffline,
                                style: type.body.copyWith(
                                  color: colors.accentSage,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The bottom of the screen, which is the whole of the difference between the
  /// two steps.
  ///
  /// Both steps put one gold button in the same place, so the thing a player is
  /// reaching for does not move when the screen changes underneath them.
  List<Widget> _actions(OnlineSessionState session) {
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;

    if (_step == _Step.choose) {
      return [
        _primary(
          key: OnlineEntryScreen.hostButton,
          label: l10n.onlineCreateRoom,
          caption: l10n.onlineCreateRoomHint,
          onPressed: session.busy || !_hasName ? null : _host,
        ),
        SizedBox(height: spacing.md),
        _secondary(
          key: OnlineEntryScreen.haveCodeButton,
          label: l10n.onlineJoinRoom,
          caption: l10n.onlineJoinRoomHint,
          onPressed: !_hasName ? null : () => _goTo(_Step.join),
        ),
        SizedBox(height: spacing.md),
        // Task 10 — a room somebody did not have to be told about.
        _secondary(
          key: OnlineEntryScreen.browseButton,
          label: l10n.onlinePublicRooms,
          caption: l10n.onlinePublicRoomsHint,
          onPressed: !_hasName ? null : () => _goTo(_Step.browse),
        ),
      ];
    }

    if (_step == _Step.browse) {
      return [
        TextButton(
          onPressed: session.busy ? null : () => _goTo(_Step.choose),
          child: Text(
            l10n.back,
            style: type.body.copyWith(color: context.colors.textMuted),
          ),
        ),
      ];
    }

    return [
      _primary(
        key: OnlineEntryScreen.joinButton,
        label: l10n.onlineJoinRoom,
        onPressed: session.busy || !_hasName || !_hasCode ? null : _join,
      ),
      SizedBox(height: spacing.md),
      TextButton(
        onPressed: session.busy ? null : () => _goTo(_Step.choose),
        child: Text(
          l10n.back,
          style: type.body.copyWith(color: context.colors.textMuted),
        ),
      ),
    ];
  }

  /// The «أوض عامة» list.
  ///
  /// A room disappears from it the moment its match starts — the server's
  /// `public_rooms()` only ever returns rooms still in the lobby — so a tap on
  /// a stale row gets `PHASE_CLOSED` and the refusal above the list says so.
  /// Refreshing is a pull and nothing else; see `OnlineSession.browse`.
  Widget _browseList() {
    final l10n = context.l10n;
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final rooms = _rooms;

    if (rooms == null || _browsing) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.lg),
        child: Center(
          child: CircularProgressIndicator(color: colors.accentGold),
        ),
      );
    }

    if (rooms.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshRooms,
        child: ListView(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: spacing.xl),
            Text(
              l10n.onlineNoPublicRooms,
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.textMuted),
            ),
            SizedBox(height: spacing.xl),
          ],
        ),
      );
    }

    return RefreshIndicator(
      key: OnlineEntryScreen.browseList,
      onRefresh: _refreshRooms,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rooms.length,
        itemBuilder: (_, index) {
          final room = rooms[index];
          return ListTile(
            key: ValueKey('public_room_${room.code}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              (room.title ?? '').trim().isEmpty
                  ? l10n.onlineUntitledRoom
                  : room.title!.trim(),
              style: type.body.copyWith(color: colors.textPrimary),
            ),
            subtitle: Text(
              l10n.onlinePublicRoomPlayers(room.players),
              style: type.caption.copyWith(color: colors.textMuted),
            ),
            // Task 12 — voice is a microphone, not the word "voice".
            trailing: Icon(
              room.voice ? Icons.mic_none : Icons.mic_off,
              color: room.voice ? colors.accentSage : colors.textMuted,
            ),
            onTap: () => _joinPublic(room.code),
          );
        },
      ),
    );
  }

  Widget _primary({
    required Key key,
    required String label,
    String? caption,
    required VoidCallback? onPressed,
  }) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;

    return FilledButton(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.accentGold,
        foregroundColor: colors.surfaceBase,
        padding: EdgeInsets.symmetric(vertical: spacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.button),
        ),
      ),
      child: _label(
        label,
        caption,
        type.title,
        captionColor: colors.surfaceBase.withValues(alpha: 0.72),
      ),
    );
  }

  Widget _secondary({
    required Key key,
    required String label,
    String? caption,
    required VoidCallback? onPressed,
  }) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;

    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.borderSubtle),
        padding: EdgeInsets.symmetric(vertical: spacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.button),
        ),
      ),
      child: _label(label, caption, type.title, captionColor: colors.textMuted),
    );
  }

  /// A button's name, and under it the sentence that says what pressing it does.
  ///
  /// Doc 14 Part 5's rule for settings — *"a setting nobody understands is a
  /// setting nobody uses"* — applied to the one screen where two buttons are
  /// two different evenings.
  Widget _label(
    String label,
    String? caption,
    TextStyle style, {
    required Color captionColor,
  }) {
    if (caption == null) return Text(label, style: style);
    final type = context.typography;
    final spacing = context.spacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: style),
        SizedBox(height: spacing.xs),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: type.caption.copyWith(color: captionColor),
        ),
      ],
    );
  }

  /// Upper case, letters and digits, as it is typed.
  ///
  /// `TextCapitalization.characters` is a hint to the soft keyboard and nothing
  /// more: it does not touch a paste, and a hardware keyboard ignores it. Every
  /// code the server mints is upper case out of a 32-glyph alphabet, so a code
  /// pasted in lower case out of a chat app would be refused for a reason the
  /// player cannot see.
  ///
  /// Done here in `onChanged` rather than with a `TextInputFormatter` because a
  /// formatter lives in `package:flutter/services.dart`, and no file under
  /// `lib/ui` may import that — it is the only door onto `HapticFeedback`, and
  /// `haptics_call_site_test` keeps the door shut for L-10's sake. A screen that
  /// wanted to tidy six characters is not a good enough reason to open it.
  void _tidy(TextEditingController controller, String value) {
    final cleaned = value.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned == value) return;
    controller.value = TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? hint,
    int? maxLength,
    bool code = false,
    Widget? suffix,
  }) {
    final colors = context.colors;
    final type = context.typography;
    final radii = context.radii;

    return TextField(
      key: key,
      controller: controller,
      maxLength: maxLength,
      textCapitalization: code
          ? TextCapitalization.characters
          : TextCapitalization.words,
      // A room code is Latin, six characters, and typed back in from something
      // read aloud. Left to right wherever it is shown, for the same reason
      // `_StaggeredCode` pins its own direction.
      textDirection: code ? TextDirection.ltr : null,
      textAlign: code ? TextAlign.center : TextAlign.start,
      style: type.body.copyWith(color: colors.textPrimary),
      onChanged: (value) {
        if (code) _tidy(controller, value);
        setState(() {});
      },
      decoration: InputDecoration(
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(),
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
