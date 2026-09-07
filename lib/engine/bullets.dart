import 'models/enums.dart';
import 'models/match.dart';
import 'models/match_settings.dart';
import 'models/player.dart';
import 'models/timeline_event.dart';

/// «الطلقة الواحدة» — doc 13 §2, as rules rather than as screens.
///
/// ## Everything here is derived from the event log
///
/// There is no `bulletSpent` boolean on [Player] and there is not going to be
/// one. The log is what persists and what a resumed match is rebuilt from, so a
/// flag beside it is a second source of truth that a force-quit at the wrong
/// moment can put out of step with the first — and the failure mode of *that*
/// is a player getting their one irreversible move back, which is the one
/// property the whole mechanic rests on.
///
/// ## The Mafia's is the team's
///
/// [BulletKind.quietNight] cancels the team's single kill, so it is spent by
/// the team: the first Mafioso to arm it spends it for all of them, and no
/// second Mafioso may arm it that night or any night after. Every other bullet
/// belongs to the seat that holds it.
abstract final class Bullets {
  /// Whether this match offers [kind] at all.
  ///
  /// Two gates, both from doc 13 §7: the master switch, and the per-bullet one
  /// underneath it. Off means the control is not built — not that it is built
  /// and refused, which would be a control that differs between matches and
  /// therefore a thing to read.
  static bool enabled(MatchSettings settings, BulletKind kind) {
    if (kind == BulletKind.selfProtect) return true;
    if (!settings.bulletsEnabled) return false;
    return switch (kind) {
      BulletKind.quietNight => settings.quietNightEnabled,
      BulletKind.selfProtect => settings.selfProtectEnabled,
    };
  }

  /// Every bullet spent in this match so far, oldest first.
  static Iterable<BulletSpent> spent(Match match) =>
      match.eventLog.whereType<BulletSpent>();

  /// Whether [seat]'s own bullet is gone.
  ///
  /// For a Mafioso this is the *team's* answer, because the quiet night is the
  /// team's: a second Mafioso must not be able to spend a night the first one
  /// already spent.
  static bool isSpentFor(Match match, int seat) {
    final role = match.players[seat].role;
    if (role == Role.mafia) return isSpentByTeam(match, BulletKind.quietNight);
    return spent(match).any((e) => e.actorSeat == seat);
  }

  /// Whether anybody has spent [kind] yet.
  static bool isSpentByTeam(Match match, BulletKind kind) =>
      spent(match).any((e) => e.kind == kind);

  /// Whether [seat] may arm their bullet right now.
  ///
  /// Deliberately does not ask whose turn it is: that is the engine's job and
  /// it already checks. This answers only "is there still a bullet, and does
  /// this match have one at all".
  static bool canArm(Match match, int seat) {
    final kind = match.players[seat].role.bullet;
    if (kind == null) return false;
    if (!enabled(match.settings, kind)) return false;
    if (match.players[seat].status != PlayerStatus.alive) return false;
    return !isSpentFor(match, seat);
  }

  /// Whether the Mafia went quiet on night [night] — no kill, by choice.
  static bool quietNightOn(Match match, int night) => spent(match).any(
    (e) =>
        e.kind == BulletKind.quietNight &&
        e.phaseRef.phase == GamePhase.night &&
        e.phaseRef.number == night,
  );

  /// Whether tonight is that night.
  static bool quietNightNow(Match match) =>
      quietNightOn(match, match.dayNumber);

  /// Whether [seat] armed [kind] on night [night].
  static bool armedOn(Match match, int seat, BulletKind kind, int night) =>
      spent(match).any(
        (e) =>
            e.actorSeat == seat &&
            e.kind == kind &&
            e.phaseRef.phase == GamePhase.night &&
            e.phaseRef.number == night,
      );
}
