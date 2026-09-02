/// The Information Engine's two catalogues, as enums with their weights.
///
/// They live under `models/` rather than beside the generators because
/// `timeline_event.dart` records which trace was published and which
/// confrontation was issued. Putting them in `information/` would make the
/// model layer depend on the generator layer, and the generators already
/// depend on the model layer — a cycle for no gain.
///
/// Reference: `09-information-engine.md` §1.4, §1.5, §2.3, §2.4.
library engine.models.information_enums;

/// The eight forensic observations, plus the fallback.
///
/// Every one is a **true statement about something a player actually did**
/// (doc 09 §0: *"The app never invents a fact"*). [t0] is the only one that
/// asserts nothing, and it exists precisely so that "nothing happened worth
/// reporting" has a way to be said without reaching for fiction.
enum TraceType {
  /// Fallback. Not a candidate — it is what you get when there are none.
  t0(0.0),

  /// آخر شك للضحية — the dead player's last recorded suspicion.
  t1(10.0),

  /// نجاة — a kill was blocked. Never names anyone.
  t2(4.0),

  /// تطابق — two or more living players suspected the same person.
  t3(5.0),

  /// تحوّل — someone changed their suspicion since last night.
  t4(3.0),

  /// الظل — a living player nobody has ever suspected.
  t5(3.5),

  /// الصمت — somebody declined to record a suspicion.
  t6(2.5),

  /// الدائرة — two living players suspected each other.
  t7(4.5),

  /// الإجماع — 60% or more of the living table suspected one person.
  t8(6.0);

  const TraceType(this.dramaWeight);

  /// Doc 09 §1.5. Tuned from playtests, not from taste.
  final double dramaWeight;

  /// Every type that can be a candidate. [t0] is excluded by construction.
  static List<TraceType> get candidates =>
      TraceType.values.where((t) => t != TraceType.t0).toList();
}

/// The eleven confrontations.
///
/// Ordered by [severity] — *how damning the observation is*, which is the term
/// doc 09 §2.4 multiplies by recency and fairness. The spec names the factor
/// but does not table the numbers, so these are chosen here on one principle:
/// **a confrontation is more severe the more directly the player's own two
/// actions contradict each other.** [c1] and [c2] are a player caught arguing
/// with themselves; [c4] and [c6] are observations about an absence, which is
/// suggestive and nothing more.
enum ConfrontationType {
  /// تناقض التصويت — accused X in the open, then voted for Y.
  c1(10.0),

  /// الانقلاب — defended X yesterday, voted for X today.
  c2(9.0),

  /// الثبات — same night-suspicion three nights running.
  c3(6.0),

  /// الظل — never suspected by anyone, three days in.
  c4(4.0),

  /// التوأم — voted identically with the same player three times.
  c5(7.0),

  /// الصامت — least cumulative speaking time.
  c6(3.5),

  /// الميت يتكلم — the last victim's suspicion named this player.
  c7(8.5),

  /// الهمّاس — whispered to the same player on consecutive days.
  c8(5.0),

  /// التقلّب — changed suspicion three times in four nights.
  c9(5.5),

  /// الامتناع — declined to record a suspicion twice.
  c10(4.5),

  /// الناجي — survived a night attempt.
  ///
  /// **Off by default and it must stay that way** (doc 09 §2.3): it says out
  /// loud that a save occurred *and* names who was saved, which is most of the
  /// Doctor's aim in one sentence. Gated behind
  /// `MatchSettings.survivorConfrontationEnabled`.
  c11(3.0);

  const ConfrontationType(this.severity);

  final double severity;

  /// Whether this type needs the whisper layer to be running.
  bool get requiresWhispers => this == ConfrontationType.c8;

  /// Whether this type is gated behind an opt-in setting.
  bool get isGated => this == ConfrontationType.c11;
}
