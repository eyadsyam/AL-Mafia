import '../engine/information/records.dart';
import '../engine/information/trace_generator.dart';
import '../engine/models/information_enums.dart';
import '../app/l10n/app_localizations.dart';

/// Turns the Information Engine's structured output into the sentence the
/// table reads.
///
/// ## Why rendering is separate from selection
///
/// The generators decide *what is true*; this file decides *how it is said*.
/// Keeping them apart is what lets the Edge Function run the selection (doc 10
/// §5.1) and hand the client a type plus a couple of seat numbers, rather than
/// a pre-rendered Arabic string the server has no business composing. It is
/// also what makes the generators testable without a `BuildContext`.
///
/// ## Nothing here decides what may be named
///
/// Every "does this name a player" question was already answered by the
/// generator — `TraceResult.targetSeat` is null for every type but `T1`, so a
/// renderer that wanted to name somebody would have nobody to name. That is
/// deliberate: the naming rule (doc 09 §1.4) is enforced by the shape of the
/// data, not by the discipline of whoever writes the next widget.
class InformationText {
  const InformationText._();

  /// The morning's trace, or null when the layer produced nothing at all.
  ///
  /// `T0` is a sentence like any other — «الليلة دي ماسابتش أي أثر» — because a
  /// blank space where the trace usually sits reads as a bug, and because "the
  /// night left nothing" is itself true and worth saying.
  static String? trace(
    AppLocalizations l10n,
    TraceResult? trace,
    Map<int, String> names,
  ) {
    if (trace == null) return null;
    switch (trace.type) {
      case TraceType.t0:
        return l10n.traceNone;
      case TraceType.t1:
        final victim = names[trace.subjectSeat];
        final target = names[trace.targetSeat];
        if (victim == null || target == null) return l10n.traceNone;
        return l10n.traceLastSuspicion(victim, target);
      case TraceType.t2:
        return l10n.traceSomeoneSurvived;
      case TraceType.t3:
        return l10n.traceAgreement(trace.count ?? 2);
      case TraceType.t4:
        return l10n.traceShift(trace.count ?? 1);
      case TraceType.t5:
        return l10n.traceShadow;
      case TraceType.t6:
        return l10n.traceSilence;
      case TraceType.t7:
        return l10n.traceCircle;
      case TraceType.t8:
        return l10n.traceConsensus;
    }
  }

  /// The body of today's confrontation — the observation, without the name of
  /// the player it is put to. The name is the display line above it (§2.6).
  ///
  /// Returns null for the types that are not shipped; see the header of
  /// `confrontation_generator.dart`. A null here means the screen has nothing
  /// to say, and a screen with nothing to say is not shown.
  static String? confrontation(
    AppLocalizations l10n,
    Confrontation confrontation,
    Map<int, String> names,
  ) {
    String? name(int? seat) => seat == null ? null : names[seat];

    switch (confrontation.type) {
      case ConfrontationType.c1:
        final accused = name(confrontation.evidenceSeat);
        final voted = name(confrontation.evidenceSeat2);
        if (accused == null || voted == null) return null;
        return l10n.confrontationC1(accused, voted);
      case ConfrontationType.c4:
        return l10n.confrontationC4;
      case ConfrontationType.c5:
        final twin = name(confrontation.evidenceSeat);
        if (twin == null) return null;
        return l10n.confrontationC5(twin, confrontation.count ?? 3);
      case ConfrontationType.c6:
        return l10n.confrontationC6;
      case ConfrontationType.c7:
        return l10n.confrontationC7;
      case ConfrontationType.c8:
        final other = name(confrontation.evidenceSeat);
        if (other == null) return null;
        return l10n.confrontationC8(other);
      case ConfrontationType.c11:
        return l10n.confrontationC11;
      case ConfrontationType.c2:
      case ConfrontationType.c3:
      case ConfrontationType.c9:
      case ConfrontationType.c10:
        // Not generated in this build. `c2` has no evidence to read, and the
        // other three would announce that a living, named player recorded a
        // night suspicion — which is to say, that they are a Citizen.
        return null;
    }
  }
}
