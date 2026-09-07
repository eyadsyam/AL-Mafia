import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/models/enums.dart'
    show Role, NightActionKind, PlayerStatus;
import '../../l10n_ext.dart';
import '../../widgets/night_grid.dart';
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
///
/// ## The special tile (doc 14 §1.3)
///
/// Every role's grid is *N* tiles: the other living players, then one tile of
/// its own. For the Mafia that tile is «مفيش قتل الليلة»; for the Detective and
/// the Citizen it is "I am not choosing anybody"; for the Doctor it is the
/// self-protection, which sits in the row of names because protecting yourself
/// is a choice among the choices and not a power with a control of its own.
///
/// The Doctor's tile carries the same words on every night of the match. It
/// used to read their own name until the ability was spent and then change —
/// which made the label itself the announcement that the ability was gone. The
/// dimming and the lock say that already, and they say it without putting a
/// player's name where a screen reader will read it out.
///
/// Two of those four spend something. The Mafia's quiet night and the Doctor's
/// self-protection are once per match, so once used the tile stays where it is,
/// dimmed and inert — a tile that vanished would change the shape of the grid,
/// and the shape of the grid is readable from across a table.
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

    final l10n = context.l10n;
    final players = state.public.players;
    final actorSeat = turn.actorSeat;
    final role = turn.actorRole;

    // Teammate votes are data for the reserved indicator slot. For every role
    // other than Mafia the engine returns an empty list, so every tile renders
    // an empty — but identically sized — slot.
    final teammateVotes = <int, int>{};
    for (final seat in turn.teammateVotes) {
      teammateVotes[seat] = (teammateVotes[seat] ?? 0) + 1;
    }

    // Whether this match hands this role its once-per-match tile at all. A
    // property of the match, not of the turn: it is the same answer on night 1
    // and night 5, and the same on every phone.
    // Asks the room, not just the master switch: a table that turned
    // «الحماية الذاتية» off on its own should not be shown the Doctor's own
    // name as a choice the engine would then refuse. The grid keeps its N
    // tiles either way — what changes is the word on the last one.
    final hasAbility = controller.bulletExistsFor(role);
    final spent = hasAbility && controller.currentBulletSpent;

    final choices = <NightChoice>[
      for (final seat in turn.targets)
        NightChoice(
          seat: seat,
          label: players[seat].name,
          indicatorCount: teammateVotes[seat] ?? 0,
          selectable: players[seat].status == PlayerStatus.alive,
        ),
      // The last tile, always, for every role.
      if (role == Role.doctor)
        NightChoice(
          // Their own seat, among the names. The engine reads a Doctor
          // targeting their own seat as the self-protection and refuses it
          // when they have already used it, which is the same rule this tile
          // draws.
          //
          // The word on it never changes. Naming the Doctor before use and
          // «احمي نفسك حالا» after would make the tile's own label the tell
          // that the ability had been spent; the dimming and the lock say
          // that, and they say it without printing anybody's name.
          seat: actorSeat,
          // Through the same helper as the other three, so the four labels
          // stay one set: `night_prompt_balance_test` holds them to a single
          // ink length, and a doctor label written out separately here would
          // drift out from under it.
          label: EngineCopy.nightSpecial(l10n, role),
          special: true,
          spent: spent,
        )
      else
        NightChoice(
          seat: NightChoice.skipSeat,
          label: EngineCopy.nightSpecial(l10n, role),
          special: true,
          // Only the Mafia's costs anything. The Detective's and the
          // Citizen's are ordinary skips and are available every night.
          spent: role == Role.mafia && spent,
        ),
    ];

    final investigate = state.investigateResult;

    return TurnShell(
      labels: TurnShellLabels.of(l10n),
      // Rebuilding for a new seat must start a fresh turn clock, never inherit
      // the previous player's elapsed dwell.
      turnId: 'night-${state.dayNumber}-$actorSeat',
      playerName: players[actorSeat].name,
      role: role,
      promptText: EngineCopy.nightPrompt(l10n, role),
      choices: choices,
      // Only the Detective fills this explicitly; the shell falls back to the
      // name just picked for everybody else. Both halves are load-bearing —
      // the Detective's answer is the only thing on this screen that is not
      // already known, and three dark panels beside one lit one would say
      // whose panel it was. Doc 14 §1.4, as amended 2026-09-04.
      confirmationDetail: investigate == null
          ? null
          : EngineCopy.roleName(l10n, investigate.revealedRole),
      onNotYou: onWrongPerson,
      onConfirmed: (seat) {
        if (seat == NightChoice.skipSeat) {
          controller.skipNightAction(
            // The Mafia's skip *is* «الليلة الهادية» when they still have it:
            // it is what makes the morning ambiguous. The other two roles are
            // simply declining to act.
            useBullet: role == Role.mafia && hasAbility && !spent,
          );
          return;
        }
        controller.submitNightAction(
          kind: nightActionFor(role),
          targetSeat: seat,
          useBullet: role == Role.doctor && seat == actorSeat,
        );
      },
      onPass: () {
        // Drops the Detective result and every other secret before the phone
        // changes hands (FR-028, L-14).
        controller.passTurn();
        if (controller.snapshot.currentActorSeat == null) {
          onNightComplete();
        } else {
          controller.openActorTurn();
        }
      },
    );
  }
}
