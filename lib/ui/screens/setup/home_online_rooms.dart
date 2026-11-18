import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transport/game_snapshot.dart' show PublicRoom;
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../western_digits.dart';
import '../online/online_session.dart' show onlineBackendFactoryProvider;

/// How many public rooms are still in the lobby with a free seat: the same
/// `browse_rooms` call the online entry screen makes. Any failure is an
/// error value, and the line hides on it: Home never says «error».
final homeOnlineRoomsProvider = FutureProvider.autoDispose<int>((ref) async {
  final backend = await ref.read(onlineBackendFactoryProvider)();
  await backend.ensureSession();
  final result = await backend.call('browse_rooms', const {});
  final rooms = PublicRoom.ordered([
    for (final row in (result['rooms'] as List? ?? const []))
      PublicRoom.fromJson(Map<String, dynamic>.from(row as Map)),
  ]);
  // A room somebody is waiting in: an empty server-owned waiting room is
  // not «مستنية ناس», it is nobody.
  return rooms
      .where((room) => !room.waiting && room.players > 0 && !room.isFull)
      .length;
});

/// «N أوض أونلاين مستنية ناس»: a dot and one line under the start button.
/// Tapping it goes to the online entry. Nothing is drawn for no rooms, while
/// the first answer is loading, or after any error.
///
/// Read when Home opens and then every [HomeTokens.onlineLineRefresh] while
/// Home is the page on screen and the app is in the foreground: no asking in
/// the background.
class HomeOnlineRoomsLine extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  const HomeOnlineRoomsLine({super.key, required this.onTap});

  static const Key lineKey = ValueKey('home_online_rooms');

  @override
  ConsumerState<HomeOnlineRoomsLine> createState() =>
      _HomeOnlineRoomsLineState();
}

class _HomeOnlineRoomsLineState extends ConsumerState<HomeOnlineRoomsLine>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = _inForeground(WidgetsBinding.instance.lifecycleState);
    _startTimer();
  }

  static bool _inForeground(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(HomeTokens.onlineLineRefresh, (_) {
      // Home under another page, or the app away: no question to the server.
      if (!mounted || !_foreground) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      ref.invalidate(homeOnlineRoomsProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = _inForeground(state);
    if (now == _foreground) return;
    _foreground = now;
    if (now) {
      ref.invalidate(homeOnlineRoomsProvider);
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(homeOnlineRoomsProvider);
    final count = rooms.hasError ? 0 : (rooms.valueOrNull ?? 0);
    if (count <= 0) return const SizedBox.shrink();
    final colors = context.colors;
    final text = westernDigits(context.l10n.homeOnlineRooms(count));
    final style = DeckTokens.meta(
      context.typography,
    ).copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700);
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: InkWell(
        key: HomeOnlineRoomsLine.lineKey,
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: IdentityTokens.target),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: HomeTokens.onlineDot,
                  height: HomeTokens.onlineDot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DeckTokens.bone,
                    boxShadow: [
                      BoxShadow(
                        color: DeckTokens.bone.withValues(
                          alpha: HomeTokens.onlineDotHaloAlpha,
                        ),
                        spreadRadius: HomeTokens.onlineDotHalo,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: HomeTokens.onlineGap),
                Flexible(child: Text(text, style: style)),
                const SizedBox(width: HomeTokens.onlineGap),
                Icon(
                  Icons.arrow_forward,
                  size: HomeTokens.onlineArrow,
                  color: colors.textMuted,
                  textDirection: Directionality.of(context),
                  applyTextScaling: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
