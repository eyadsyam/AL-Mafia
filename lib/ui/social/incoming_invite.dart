import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/asset_constants.dart';
import '../../data/player_profile.dart';
import '../../engine/models/player.dart' show PlayerGender;
import '../../platform/audio_director.dart';
import '../../platform/device/time_zone.dart';
import '../../platform/haptics.dart';
import '../economy/cosmetic_paint.dart';
import '../economy/economy_capabilities.dart';
import '../economy/vault_kit.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/player_avatar.dart';
import 'directory.dart';
import 'invite_privacy.dart';
import '../../platform/push/push_service.dart';
import 'push_prompt.dart';

/// The invite's knock: our sound and the long vibration. Overridden in tests.
class InviteAlert {
  final Ref _ref;
  InviteAlert(this._ref);

  static const sound = AppAudio.inviteKnock;

  Future<void> ring() async {
    // The director refuses while a phone is in a hand; the popup never shows
    // then anyway.
    _ref.read(audioDirectorProvider).playAccent(sound);
    await Haptics.pattern(InviteTokens.longVibration);
  }
}

final inviteAlertProvider = Provider<InviteAlert>(InviteAlert.new);

/// Invites that arrived while the app is open, anywhere in it.
///
/// Polls the inbox every [InviteTokens.inboxPoll] while the app is in front
/// (the codebase's short poll, as «أصحابك» does), and only once the server's
/// capabilities were read by something else and «أصحابك» is on: it never
/// starts a sign-in on its own (M1). An invite is shown once; «بعدين» keeps
/// it on the server but it does not pop again. While [privateMomentProvider]
/// is true the popup is not drawn — the invite waits and appears at the next
/// public moment, with its knock then.
class IncomingInviteHost extends ConsumerStatefulWidget {
  final Widget child;

  /// Opens the join flow for a room code (the router's `/join/<code>`).
  final ValueChanged<String> onJoin;
  const IncomingInviteHost({
    super.key,
    required this.child,
    required this.onJoin,
  });

  @override
  ConsumerState<IncomingInviteHost> createState() => IncomingInviteHostState();
}

class IncomingInviteHostState extends ConsumerState<IncomingInviteHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _polling = false;
  final Set<String> _seen = {};
  final List<IncomingInvite> _queue = [];
  String? _rungFor;
  DateTime? _helloAt;
  bool _roomGone = false;
  final List<StreamSubscription<Object?>> _subs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arm();
    final push = ref.read(pushServiceProvider);
    _subs
      ..add(push.opened.listen(openFromPush))
      ..add(push.foreground.listen((_) => poll()));
    unawaited(
      push.initialOpen().then((open) {
        if (open != null && mounted) openFromPush(open);
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  /// A tapped notification (cold start, background or foreground): straight
  /// into the join flow for its room, or «الأوضة بدأت أو اتقفلت» when the
  /// room already started or closed.
  Future<void> openFromPush(PushOpen open) async {
    String? code = open.code;
    final id = open.inviteId;
    if (id != null) {
      _seen.add(id);
      setState(() => _queue.removeWhere((q) => q.id == id));
      try {
        code = await ref.read(directoryApiProvider).respond(id, accept: true);
      } catch (_) {
        // Cannot ask: the join flow says what it finds.
      }
    }
    if (!mounted) return;
    if (code == null) {
      setState(() => _roomGone = true);
    } else {
      widget.onJoin(code);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _arm();
      unawaited(poll());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer.periodic(InviteTokens.inboxPoll, (_) => poll());
  }

  EconomyCapabilities? get _caps => ref.exists(economyCapabilitiesProvider)
      ? ref.read(economyCapabilitiesProvider).valueOrNull
      : null;

  /// One look at the inbox. Public for tests.
  Future<void> poll() async {
    final caps = _caps;
    if (_polling || caps == null || !caps.friends || !mounted) return;
    _polling = true;
    try {
      final api = ref.read(directoryApiProvider);
      if (caps.directory) await _hello(api);
      final invites = await api.inbox();
      if (!mounted) return;
      final here = ref.read(onlineSessionProvider).room?.code;
      final fresh = [
        for (final i in invites)
          if (!_seen.contains(i.id) &&
              !_queue.any((q) => q.id == i.id) &&
              i.code != here)
            i,
      ];
      if (fresh.isNotEmpty) {
        setState(() => _queue.addAll(fresh.reversed));
        unawaited(ref.read(pushPromptProvider).askInContext());
      }
    } catch (_) {
      // The next tick tries again.
    } finally {
      _polling = false;
    }
  }

  /// Registers this player in the directory (name, coarse country, last
  /// seen) at most every [InviteTokens.presenceBeat].
  Future<void> _hello(DirectoryApi api) async {
    final now = DateTime.now();
    if (_helloAt != null &&
        now.difference(_helloAt!) < InviteTokens.presenceBeat) {
      return;
    }
    final profile = ref.read(playerProfileProvider).valueOrNull;
    final name = profile?.name.trim() ?? '';
    if (name.isEmpty) return;
    _helloAt = now;
    try {
      await api.hello(
        name: name,
        gender: profile!.gender.name,
        tz: await deviceTimeZone(),
        locale: deviceLocaleTag(),
      );
      unawaited(ref.read(pushPromptProvider).refreshIfAsked());
    } catch (_) {
      _helloAt = null;
    }
  }

  /// Test hook: puts an invite straight in the queue.
  void enqueue(IncomingInvite invite) =>
      setState(() => _queue.add(invite));

  void _close(IncomingInvite invite) {
    setState(() {
      _seen.add(invite.id);
      _queue.removeWhere((q) => q.id == invite.id);
    });
  }

  Future<String?> _accept(IncomingInvite invite) async {
    try {
      return await ref
          .read(directoryApiProvider)
          .respond(invite.id, accept: true);
    } catch (_) {
      // Unreachable: try the join flow; it says what it finds.
      return invite.code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final private = ref.watch(privateMomentProvider);
    final invite = _queue.isEmpty ? null : _queue.first;
    final showing = invite != null && !private;
    if (showing && _rungFor != invite.id) {
      _rungFor = invite.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(ref.read(inviteAlertProvider).ring());
      });
    }
    return Stack(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.rtl,
      children: [
        widget.child,
        if (_roomGone)
          Positioned.fill(
            child: RoomGoneNotice(
              onClose: () => setState(() => _roomGone = false),
            ),
          ),
        if (showing && !_roomGone)
          Positioned.fill(
            child: IncomingInvitePopup(
              key: ValueKey('incoming_${invite.id}'),
              invite: invite,
              onLater: () => _close(invite),
              onEnter: () async {
                final code = await _accept(invite);
                if (!mounted) return null;
                if (code != null) {
                  _close(invite);
                  widget.onJoin(code);
                }
                return code;
              },
            ),
          ),
      ],
    );
  }
}

/// «إياد بيدعوك تلعبوا مع بعض»: the sender's framed face, the room code,
/// «ادخل» / «بعدين». Rises once; reduced motion shows it at rest.
class IncomingInvitePopup extends StatefulWidget {
  final IncomingInvite invite;

  /// Returns the room code joined, or null when the room is gone.
  final Future<String?> Function() onEnter;
  final VoidCallback onLater;
  const IncomingInvitePopup({
    super.key,
    required this.invite,
    required this.onEnter,
    required this.onLater,
  });

  static const Key popupKey = ValueKey('incoming_invite_popup');
  static const Key enterKey = ValueKey('incoming_invite_enter');
  static const Key laterKey = ValueKey('incoming_invite_later');
  static const Key goneKey = ValueKey('incoming_invite_gone');

  @override
  State<IncomingInvitePopup> createState() => _IncomingInvitePopupState();
}

class _IncomingInvitePopupState extends State<IncomingInvitePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: InviteTokens.popupRise,
  );
  bool _working = false;
  bool _gone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rise.value = 1;
    } else if (!_rise.isAnimating && _rise.value == 0) {
      _rise.forward();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    if (_working) return;
    setState(() => _working = true);
    final code = await widget.onEnter();
    if (!mounted) return;
    setState(() {
      _working = false;
      _gone = code == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final invite = widget.invite;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onLater,
              child: ColoredBox(
                color: colors.surfaceBase.withValues(
                  alpha: InviteTokens.scrimAlpha,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(s.md),
                child: AnimatedBuilder(
                  animation: _rise,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_rise.value);
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * InviteTokens.popupLift),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: IncomingInvitePopup.popupKey,
                    child: VaultCard(
                      lit: true,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          l.inviteIncomingTitle,
                          style: context.typography.bodySmall.copyWith(
                            color: VaultTokens.gold,
                          ),
                        ),
                        SizedBox(height: s.sm),
                        CosmeticFrameRing(
                          frame: invite.frame,
                          diameter: InviteTokens.popupAvatar,
                          child: PlayerAvatar(
                            name: invite.name,
                            gender: PlayerGender.values.firstWhere(
                              (g) => g.name == invite.gender,
                              orElse: () => PlayerGender.unspecified,
                            ),
                            diameter: InviteTokens.popupAvatar,
                          ),
                        ),
                        SizedBox(height: s.sm),
                        CosmeticNameplate(
                          name: invite.name,
                          plate: invite.plate,
                          textAlign: TextAlign.center,
                          style: context.typography.title.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: s.xs),
                        Text(
                          l.inviteIncomingBody(invite.name),
                          textAlign: TextAlign.center,
                          style: context.typography.body.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          l.inviteIncomingCode(invite.code),
                          style: context.typography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        if (_gone) ...[
                          SizedBox(height: s.sm),
                          Text(
                            l.inviteRoomGone,
                            key: IncomingInvitePopup.goneKey,
                            textAlign: TextAlign.center,
                            style: context.typography.body.copyWith(
                              color: colors.accentCrimson,
                            ),
                          ),
                        ],
                        SizedBox(height: s.md),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                key: IncomingInvitePopup.laterKey,
                                style: vaultOutlineStyle(context),
                                onPressed: widget.onLater,
                                child: Text(l.inviteLater),
                              ),
                            ),
                            SizedBox(width: s.sm),
                            if (!_gone)
                              Expanded(
                                child: FilledButton(
                                  key: IncomingInvitePopup.enterKey,
                                  style: vaultGoldStyle(context),
                                  onPressed: _working ? null : _enter,
                                  child: Text(l.inviteEnter),
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
          ),
        ],
      ),
    );
  }
}

/// «الأوضة بدأت أو اتقفلت» after a notification for a room that is gone.
class RoomGoneNotice extends StatelessWidget {
  final VoidCallback onClose;
  const RoomGoneNotice({super.key, required this.onClose});

  static const Key noticeKey = ValueKey('invite_room_gone');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: ColoredBox(
                color: colors.surfaceBase.withValues(
                  alpha: InviteTokens.scrimAlpha,
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.all(s.md),
              child: VaultCard(
                key: noticeKey,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.door_front_door_outlined, color: VaultTokens.gold),
                  SizedBox(height: s.sm),
                  Text(
                    l.inviteRoomGone,
                    textAlign: TextAlign.center,
                    style: context.typography.body.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: s.md),
                  FilledButton(
                    style: vaultGoldStyle(context),
                    onPressed: onClose,
                    child: Text(MaterialLocalizations.of(context).okButtonLabel),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
