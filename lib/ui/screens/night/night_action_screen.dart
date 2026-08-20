import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/models/enums.dart'
    show Role, NightActionKind, PlayerStatus;
import '../../l10n_ext.dart';
import '../../widgets/turn_shell.dart';
import '../match_controller.dart';

/// The night prompts and role names now live in the localisation layer
/// (`app_ar.arb` / `app_en.arb`) and are read through [EngineCopy]. Keeping a
/// second copy here would let the two drift, and the luminance budget below is
/// only meaningful if the strings under test are the strings that ship.
///
/// ## Why all four prompts are exactly the same length
///
/// Lit pixels are light, and a phone held at a table throws that light onto the
/// holder's face. A longer question is a brighter screen, and a brighter screen
/// seen four nights running is a tell. All four prompts therefore carry the
/// same number of inked glyphs ([nightPromptInkLength]), and none of them names
/// a role — a screen reader would say it out loud (L-05, Constitution VII).
///
/// `night_prompt_balance_test` states both rules; `luminance_budget_test`
/// measures the rendered result.
/// The inked-glyph budget every night prompt must hit.
///
/// Whitespace is excluded: a space advances the layout but emits no light, so
/// it cannot contribute to the brightness a bystander sees.
const int nightPromptInkLength = 19;

/// The night action a role submits. One-to-one with [Role]; no branching beyond
/// this mapping exists anywhere in the night UI.
NightActionKind nightActionFor(Role role) {
  switch (role) {
    case Role.mafia:
      return NightActionKind.mafiaVote;
    case Role.doctor:
      return NightActionKind.protect;
    case Role.detective:
      return NightActionKind.investigate;
    case Role.citizen:
      return NightActionKind.suspect;
  }
}

/// The in-hand night turn.
///
/// This screen owns no layout of its own: it binds engine data to [TurnShell]
/// and nothing else. That is deliberate — "the night screen is a single widget
/// tree shared by all roles" (Constitution II, L-01) is only credible if there
/// is literally one tree to share, so every night turn goes through the shell.
class NightActionScreen extends ConsumerWidget {
  /// Called once the last actor has passed and the night can be resolved.
  final VoidCallback onNightComplete;

  /// Called when the holder says "this is not me" — routes back to the pass
  /// screen without exposing any game content (L-12).
  final VoidCallback? onWrongPerson;

  const NightActionScreen({
    super.key,
    required this.onNightComplete,
    this.onWrongPerson,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchControllerProvider);
    final controller = ref.read(matchControllerProvider.notifier);
    final turn = state?.actorTurn;

    if (state == null || turn == null) {
      // No actor holds the phone: the night is over (or has not opened yet).
      return const SizedBox.shrink();
    }

    final players = state.public.players;
    final actorSeat = turn.actorSeat;

    // Teammate votes are data for the reserved indicator slot. For every role
    // other than Mafia the engine returns an empty list, so every tile renders
    // an empty — but identically sized — slot.
    final teammateVotes = <int, int>{};
    for (final seat in turn.teammateVotes) {
      teammateVotes[seat] = (teammateVotes[seat] ?? 0) + 1;
    }

    final targets = [
      for (final seat in turn.targets)
        TurnTarget(
          seat: seat,
          name: players[seat].name,
          indicatorCount: teammateVotes[seat] ?? 0,
          selectable: players[seat].status == PlayerStatus.alive,
        ),
    ];

    final investigate = state.investigateResult;

    return TurnShell(
      labels: TurnShellLabels.of(context.l10n),
      // Rebuilding for a new seat must start a fresh turn clock, never inherit
      // the previous player's elapsed dwell.
      turnId: 'night-${state.dayNumber}-$actorSeat',
      playerName: players[actorSeat].name,
      role: turn.actorRole,
      promptText: EngineCopy.nightPrompt(context.l10n, turn.actorRole),
      targets: targets,
      // Only the detective overrides this. Every other role falls back to the
      // name they picked, which [TurnShell] supplies itself — see `_detailSlot`.
      confirmationDetail: investigate == null
          ? null
          : EngineCopy.roleName(context.l10n, investigate.revealedRole),
      onNotYou: onWrongPerson,
      onConfirmed: (targetSeat) => controller.submitNightAction(
        kind: nightActionFor(turn.actorRole),
        targetSeat: targetSeat,
      ),
      onPass: () {
        // Drops the Detective result and every other secret before the phone
        // changes hands (FR-028, L-14).
        controller.passTurn();
        if (controller.engine.match.currentActorSeat == null) {
          onNightComplete();
        } else {
          controller.openActorTurn();
        }
      },
    );
  }
}
