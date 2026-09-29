import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/player_profile.dart';
import '../../engine/models/enums.dart' show GamePhase;
import '../widgets/textured_surface.dart';
import 'cosmetic_paint.dart';
import 'cosmetics.dart';
import 'my_cosmetics.dart';

/// «القعدة» (pass-and-play): the phases the one phone lies flat on the table
/// for everybody at once. Stricter than [cosmeticsVisibleIn]: the vote is
/// passed hand to hand here, so it is private, like the deal and the night.
/// Doc 05 rule 3: nothing purchased is drawn on a hand-off, reveal or night.
bool passCosmeticsVisibleIn(GamePhase phase) => switch (phase) {
  GamePhase.morning ||
  GamePhase.openingRound ||
  GamePhase.confrontation ||
  GamePhase.discussion ||
  GamePhase.reveal ||
  GamePhase.winCheck ||
  GamePhase.result ||
  GamePhase.analytics => true,
  _ => false,
};

/// The host phone's own identity at the pass-and-play table: the name on this
/// phone's profile and the frame and plate its account equipped. The other
/// players typed their names on this phone and have no accounts, so only the
/// host's own seat is dressed.
class HostIdentityScope extends InheritedWidget {
  final String hostName;
  final String? frame;
  final String? plate;
  const HostIdentityScope({
    super.key,
    required this.hostName,
    required this.frame,
    required this.plate,
    required super.child,
  });

  static HostIdentityScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HostIdentityScope>();

  bool _isHost(String name) {
    final host = hostName.trim().toLowerCase();
    return host.isNotEmpty && name.trim().toLowerCase() == host;
  }

  /// The host's plate when [name] is the host's seat, else null.
  static String? plateFor(BuildContext context, String name) {
    final scope = maybeOf(context);
    return scope != null && scope._isHost(name) ? scope.plate : null;
  }

  /// The host's frame when [name] is the host's seat, else null.
  static String? frameFor(BuildContext context, String name) {
    final scope = maybeOf(context);
    return scope != null && scope._isHost(name) ? scope.frame : null;
  }

  @override
  bool updateShouldNotify(HostIdentityScope old) =>
      old.hostName != hostName || old.frame != frame || old.plate != plate;
}

/// Dresses a pass-and-play screen with the host phone's equipped pack (its
/// scene behind every public backdrop, the same art the online table uses)
/// and the host's identity, only in [passCosmeticsVisibleIn] phases. Outside
/// them it returns [child] untouched.
class PassTableDress extends ConsumerWidget {
  final GamePhase phase;
  final Widget child;
  const PassTableDress({super.key, required this.phase, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!passCosmeticsVisibleIn(phase)) return child;
    final mine = ref.watch(myCosmeticsProvider);
    final hostName = ref.watch(playerProfileProvider).valueOrNull?.name ?? '';
    final pack = Cosmetics.packs[mine.pack];
    Widget dressed = HostIdentityScope(
      hostName: hostName,
      frame: mine.frame,
      plate: mine.plate,
      child: child,
    );
    if (pack != null) {
      dressed = BackdropDressing(
        dress: (background) => PackBackdrop(pack: pack, child: background),
        child: dressed,
      );
    }
    return dressed;
  }
}
