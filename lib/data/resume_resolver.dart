import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match.dart';

import 'repository_types.dart';

/// Maps a persisted [Match] to the screen it must re-enter on.
///
/// ## The rule
///
/// Every phase where the phone is (or was) in one person's hand resolves to
/// [ResumeScreen.pass] for `currentActorSeat` — distribution, night, and the day
/// ballot alike. The app can therefore never restore a role card, a target list,
/// a ballot or an investigation result straight onto the screen: whoever picks
/// the phone up after a crash has to pass the identity gate first, exactly as
/// they would mid-match (L-13, repository contract inv. 2).
///
/// The transient `*Resolving` phases resolve backwards to the pass screen too.
/// An interruption during resolution means the last actor's confirm may or may
/// not have been committed; re-entering on a neutral surface is correct either
/// way, and cannot expose anything.
class ResumeResolver {
  const ResumeResolver._();

  static ResumeTarget resolve(Match? match) {
    if (match == null) return const ResumeTarget(screen: ResumeScreen.home);

    ResumeTarget pass() {
      final seat = match.currentActorSeat ?? _firstAliveSeat(match);
      if (seat == null) {
        // No living actor to hand to; the lobby is the safe neutral surface.
        return ResumeTarget(
          screen: ResumeScreen.preNightLobby,
          dayNumber: match.dayNumber,
        );
      }
      return ResumeTarget(
        screen: ResumeScreen.pass,
        seat: seat,
        playerName: match.players[seat].name,
        dayNumber: match.dayNumber,
      );
    }

    return switch (match.phase) {
      // Nothing has been dealt yet.
      GamePhase.setup || GamePhase.rolesConfigured =>
        const ResumeTarget(screen: ResumeScreen.home),

      // In-hand phases — always the pass screen, never the content.
      GamePhase.distributing ||
      GamePhase.night ||
      GamePhase.nightResolving ||
      GamePhase.voting ||
      GamePhase.voteResolving =>
        pass(),

      // On-table phases can be restored directly: they show only what the whole
      // table has already seen.
      GamePhase.preNightLobby => ResumeTarget(
          screen: ResumeScreen.preNightLobby,
          dayNumber: match.dayNumber,
        ),
      GamePhase.morning =>
        ResumeTarget(screen: ResumeScreen.morning, dayNumber: match.dayNumber),
      GamePhase.discussion => ResumeTarget(
          screen: ResumeScreen.discussion,
          dayNumber: match.dayNumber,
        ),
      GamePhase.reveal || GamePhase.winCheck => ResumeTarget(
          screen: ResumeScreen.voteReveal,
          dayNumber: match.dayNumber,
        ),
      GamePhase.result || GamePhase.analytics =>
        ResumeTarget(screen: ResumeScreen.result, dayNumber: match.dayNumber),
    };
  }

  /// Whether a match still counts as "in progress" for the Resume prompt.
  /// A finished match belongs in History, not on the resume path (inv. 3).
  static bool isActive(Match match) =>
      match.phase != GamePhase.result &&
      match.phase != GamePhase.analytics &&
      match.outcome == null;

  static int? _firstAliveSeat(Match match) {
    for (final p in match.players) {
      if (p.status == PlayerStatus.alive) return p.seat;
    }
    return null;
  }
}
