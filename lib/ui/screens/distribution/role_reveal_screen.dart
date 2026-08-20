import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/mafia_theme.dart';
import '../../widgets/role_card.dart';
import '../match_controller.dart';

/// Distribution: each player in seating order takes the phone and walks the
/// three-step reveal (screen S-06).
///
/// 1. **Identity gate** — the player's name, large, and a pad held for
///    `MatchSettings.identityHoldSeconds`.
/// 2. **Swipe to flip** — card back to card face, 3D Y-axis rotation.
/// 3. **Auto-conceal** — 5s, progress line, unlimited re-reveals, then pass.
///
/// ## There is deliberately no separate pass screen here
///
/// There used to be: `PassScreen` gated identity with a hold, and then
/// `RoleCard`'s own identity gate asked for a second hold immediately after.
/// Two visually identical hold pads back to back, on a screen that shows the
/// same name both times. On a real table that reads as a loop — you hold, the
/// screen appears to reset, you hold again — and it was reported as the app
/// hanging.
///
/// The two gates were also answering the same question. Step 1 already shows
/// the recipient's name larger than the pass screen did, and already holds long
/// enough to be deliberate, so it *is* the handoff gate. One gate, one hold.
///
/// [PassScreen] is still the gate for the night and the ballot, where the phone
/// is being handed into a phase rather than to a card, and where the shell it
/// guards has no identity step of its own.
class RoleRevealScreen extends ConsumerWidget {
  /// Called once every seat has seen their card.
  final VoidCallback onDistributionComplete;

  const RoleRevealScreen({super.key, required this.onDistributionComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchControllerProvider);
    final controller = ref.read(matchControllerProvider.notifier);

    if (state == null) return const SizedBox.shrink();

    final seat = state.currentActorSeat;
    if (seat == null) return const SizedBox.shrink();

    final name = state.public.players[seat].name;
    final reveal = state.reveal;

    if (reveal == null || reveal.seat != seat) {
      // The role has not been drawn from the engine yet. Draw it now, in a
      // post-frame callback so `build` stays free of side effects, and show the
      // dark ground for the one frame in between. `RoleCard` then opens on its
      // identity gate, which is the only gate this phase has.
      return _DrawOnFirstFrame(
        onReady: controller.revealCurrentRole,
        playerName: name,
      );
    }

    return RoleCard(
      // A new seat must always get a fresh, face-down card.
      key: ValueKey('role-card-$seat'),
      playerName: reveal.name,
      role: reveal.role,
      teammateNames: reveal.teammateNames,
      identityHold: Duration(
        seconds: controller.engine.match.settings.identityHoldSeconds,
      ),
      onDismissed: () {
        controller.confirmRevealed();
        if (controller.engine.match.currentActorSeat == null) {
          onDistributionComplete();
        }
      },
    );
  }
}

/// Draws the next seat's role after the current frame, showing bare ground.
///
/// One frame, identically for every seat, and it carries no information: the
/// name is passed only so the semantics layer has something to announce, and it
/// is not painted. Doing the engine call in a post-frame callback keeps `build`
/// side-effect free, which matters because Riverpod may rebuild it more than
/// once per seat.
class _DrawOnFirstFrame extends StatefulWidget {
  final VoidCallback onReady;
  final String playerName;

  const _DrawOnFirstFrame({required this.onReady, required this.playerName});

  @override
  State<_DrawOnFirstFrame> createState() => _DrawOnFirstFrameState();
}

class _DrawOnFirstFrameState extends State<_DrawOnFirstFrame> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady();
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.colors.surfaceBase,
        child: const SizedBox.expand(),
      );
}
