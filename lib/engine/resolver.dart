import 'dart:math';
import 'models/enums.dart';
import 'models/match.dart';
import 'models/timeline_event.dart';
import 'views.dart';

/// Resolves a night phase:
/// - Gathers mafia votes
/// - Determines target via seeded tie-break
/// - Applies doctor protect
/// - Returns MorningReport
class NightResolver {
  /// Resolve the night: tally mafia votes, apply protect, return report.
  static MorningReport resolveNight({
    required Match match,
    required DateTime now,
  }) {
    // Only *tonight's* actions count.
    //
    // The event log is the whole match, and both scans below used to read all
    // of it. The effect was that night one's votes were still on the table on
    // night two: the same player was reported dead every morning, because their
    // vote from the first night either won outright again or forced a tie the
    // seed broke the same way. Protection was worse — every seat ever protected
    // stayed protected for the rest of the game, so after a few nights nobody
    // could die at all.
    bool tonight(TimelineEvent e) =>
        e.phaseRef.phase == GamePhase.night &&
        e.phaseRef.number == match.dayNumber;

    // Gather mafia votes from tonight's event log
    final mafiaVotes = <int, int>{}; // targetSeat -> count
    for (final event in match.eventLog) {
      if (event is MafiaVoteCast && tonight(event)) {
        mafiaVotes[event.targetSeat] = (mafiaVotes[event.targetSeat] ?? 0) + 1;
      }
    }

    int? victimSeat;
    if (mafiaVotes.isNotEmpty) {
      // Find max votes
      final maxVotes = mafiaVotes.values.reduce((a, b) => a > b ? a : b);
      final tiedTargets = mafiaVotes.entries
          .where((e) => e.value == maxVotes)
          .map((e) => e.key)
          .toList();

      if (tiedTargets.length == 1) {
        victimSeat = tiedTargets.first;
      } else {
        // Tie-break using seed + dayNumber
        final rng = Random(match.seed + match.dayNumber);
        victimSeat = tiedTargets[rng.nextInt(tiedTargets.length)];
      }
    }

    // Gather tonight's doctor protections
    final protectedSeats = <int>{};
    for (final event in match.eventLog) {
      if (event is ProtectCast && tonight(event)) {
        protectedSeats.add(event.targetSeat);
      }
    }

    // Check if victim was protected
    bool saved = false;
    if (victimSeat != null && protectedSeats.contains(victimSeat)) {
      saved = true;
      victimSeat = null; // Nobody dies
    }

    bool allSurvived = victimSeat == null;

    return MorningReport(
      victimSeat: victimSeat,
      someoneSavedUnnamed: saved,
      allSurvived: allSurvived,
    );
  }

  /// Check if doctor protected the same target on the immediately previous night.
  static bool wouldViolateDoctorNoRepeat({
    required Match match,
    required int doctorSeat,
    required int targetSeat,
  }) {
    // Look for protect actions by this doctor in the event log
    // Find the most recent night (dayNumber - 1)
    final previousNight = match.dayNumber - 1;

    ProtectCast? lastProtect;
    for (int i = match.eventLog.length - 1; i >= 0; i--) {
      if (match.eventLog[i] is ProtectCast) {
        final protect = match.eventLog[i] as ProtectCast;
        if (protect.actorSeat == doctorSeat && protect.phaseRef.number == previousNight) {
          lastProtect = protect;
          break;
        }
      }
    }

    if (lastProtect != null && lastProtect.targetSeat == targetSeat) {
      return true; // Violation
    }

    return false;
  }
}
