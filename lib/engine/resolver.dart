import 'dart:math';
import 'models/enums.dart';
import 'models/match.dart';
import 'models/timeline_event.dart';
import 'seed.dart';
import 'views.dart';

/// Resolves a night phase:
/// - Gathers mafia votes
/// - Determines target via seeded tie-break
/// - Applies doctor protect
/// - Returns MorningReport
/// What a night resolved to, split by who is allowed to know it.
///
/// The two halves exist because a doctor save is simultaneously a *public*
/// fact and a *secret* one. The table is told that somebody was protected and
/// survived; it is never told who, because naming the saved player narrows the
/// doctor's read to whoever was near them (doc 09 SS1.4 keeps `T2` aggregate for
/// exactly this reason, and gates the naming variant `C11` off by default).
///
/// But the match *record* has to hold the seat. `T2`'s eligibility is "the
/// doctor successfully blocked a kill", and doc 09 SS5 makes `saveOccurred` a
/// field of `NightRecord` - neither is computable from a log that threw the
/// information away.
class NightResolution {
  /// The half that may be rendered. Never names the saved player.
  final MorningReport report;

  /// The seat the mafia chose that the doctor protected, or null if no save
  /// occurred. Written to the event log; never handed to a screen.
  final int? savedSeat;

  const NightResolution({required this.report, this.savedSeat});
}

class NightResolver {
  /// Resolve the night: tally mafia votes, apply protect, return the result.
  static NightResolution resolveNight({
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
        // Tie-break on the stream reserved for it.
        //
        // This was `Random(match.seed + match.dayNumber)`, which is one stream
        // shared by whoever happens to pick the same arithmetic. The moment a
        // second seeded decision lands on the same night - the trace tie-break
        // of doc 09 SS1.5 is the next one - it draws from the identical
        // sequence, and the two correlate: the same tie between mafia targets
        // and the same tie between traces would break the same way in every
        // match forever. A table would read that as the app having a favourite,
        // and it would never show up as a failing test.
        final rng = Random(
          deriveSeed(match.seed, SeedSalt.nightTieBreak, match.dayNumber),
        );
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

    // Check if victim was protected.
    //
    // `victimSeat` is cleared here because nobody dies - and that clearing is
    // what used to lose the save. `MatchEngine.resolveNight` logged
    // `savedSeat: someoneSavedUnnamed ? report.victimSeat : null`, which on the
    // only branch where the condition is true reads a field this line has
    // already set to null. So `NightResolved.savedSeat` was null after every
    // night the game has ever played, and two very different nights - the
    // doctor blocking a kill, and the mafia simply not agreeing on anyone -
    // were recorded identically.
    //
    // Nothing on screen was wrong, because the morning reads the boolean. What
    // was wrong is everything downstream of the log: the `guardian` achievement
    // tested `savedSeat == victimSeat`, which after this line is
    // `null == null`, and it is guarded by `savedSeat != null`, so it could
    // never fire. `T2` and `C11` in doc 09 read the same field and would have
    // inherited the same silence.
    int? savedSeat;
    if (victimSeat != null && protectedSeats.contains(victimSeat)) {
      savedSeat = victimSeat;
      victimSeat = null; // Nobody dies
    }

    bool allSurvived = victimSeat == null;

    return NightResolution(
      savedSeat: savedSeat,
      report: MorningReport(
        victimSeat: victimSeat,
        someoneSavedUnnamed: savedSeat != null,
        allSurvived: allSurvived,
      ),
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
