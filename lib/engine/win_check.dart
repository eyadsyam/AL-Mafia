import 'models/enums.dart';
import 'models/match.dart';
import 'models/player.dart';

/// Determines whether the match is over, and who won.
///
/// # One rule, evaluated on living players only
///
/// ```
/// mafiaAlive == 0             -> the town wins
/// mafiaAlive >= nonMafiaAlive -> the mafia wins
/// otherwise                   -> still playing
/// ```
///
/// **Parity, not majority.** At equal numbers the mafia can force or block any
/// vote, so the match is already decided and playing on only spends the table's
/// evening. This is the standard competitive ruling.
///
/// **The doctor and the detective are irrelevant here.** They change who is
/// alive; they never change the condition. Nothing in this file may special-case
/// them, and [outcomeIsRoleBlind] is the test that says so.
///
/// # Pure, and deliberately ignorant
///
/// It takes the alive set and nothing else — not the phase, not the night
/// number, not the action log. That is what makes it exhaustively testable and
/// impossible to desync from the UI. If a future rule needs history, it belongs
/// in another function, not in this one.
///
/// # One source of truth
///
/// No caller may re-implement the parity check inline. `win_condition_test.dart`
/// greps for that.
class WinChecker {
  const WinChecker._();

  /// The winner, or null while the match is still live.
  static Alignment? checkWin(Match match) => outcomeFor(match.players);

  /// The winner for an arbitrary roster. The whole rule lives here.
  static Alignment? outcomeFor(List<Player> players) {
    final alive = players.where((p) => p.status == PlayerStatus.alive);
    final aliveCount = alive.length;
    final mafiaCount = alive.where((p) => p.role == Role.mafia).length;
    final nonMafiaCount = aliveCount - mafiaCount;

    // Nobody left at all. Unreachable in the MVP — the balance guard keeps
    // mafia below half, and phases kill at most one player each — so this is a
    // guard rather than a rule.
    //
    // It returns the town rather than throwing, and rather than modelling a
    // draw. A crash on the result screen at the end of somebody's game night is
    // far worse than an odd outcome, and a genuine draw would mean widening
    // `Alignment` — which is a *player's* alignment, not a result — through the
    // codec, the result screen and analytics for a state that cannot happen.
    // If a future role can kill several players at once, model the draw
    // properly at that point; do not let it arrive by accident here.
    if (aliveCount == 0) return Alignment.town;

    if (mafiaCount == 0) return Alignment.town;
    if (mafiaCount >= nonMafiaCount) return Alignment.mafia;
    return null;
  }

  /// Marker used by the test that asserts non-mafia roles cannot affect the
  /// result. Kept here so the claim sits next to the code that has to honour it.
  static const String outcomeIsRoleBlind =
      'only Role.mafia is counted; every other role is just a body';
}
