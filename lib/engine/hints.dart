/// The hint system — doc 13 §4, as rules. The words live in the l10n layer.
///
/// ## The one constraint everything here is shaped by
///
/// Doc 13 §4.1: *"A hint whose text depends on the player's role is a leak in
/// offline mode."* Not because of what it says — because of how long it takes
/// to read. Different text is different reading time is different dwell, and
/// dwell is the tell doc 05 §L-08 spends most of its length on. Different text
/// is also a different number of lines, and a screen that is taller for one
/// role is the same tell with a ruler on it.
///
/// So role-conditioned hints are legal online, where each player has a screen
/// nobody else is waiting for, and illegal offline. Doc 13 §9 asks for that to
/// be *"enforced by type, not by convention"*, and it is: see [HintAudience].
library engine.hints;

import 'models/enums.dart';
import 'seed.dart';

/// Who is about to read a hint.
///
/// ## Why this is a sealed pair and not a `mode` flag plus a nullable role
///
/// A flag can be got wrong at one call site and nothing catches it. This
/// cannot: [TheTable] has no [Role] field at all, so a hint chosen for it
/// cannot be conditioned on one — there is nothing to condition on. Choosing
/// the offline pool is not a rule the code follows, it is the only thing the
/// type permits.
///
/// [OneSeat]'s constructor is private to this library and reachable only
/// through [HintAudience.of], which requires a viewer seat. That is the same
/// discriminator the online table already turns on: `GameSnapshot.viewerSeat`
/// is null exactly when the phone belongs to the table rather than to one
/// player, so an offline caller physically cannot produce an [OneSeat].
sealed class HintAudience {
  const HintAudience();

  /// The audience for a device holding [viewerSeat]'s own private screen.
  ///
  /// Null seat — the shared phone, passed around a table — always yields
  /// [TheTable], whatever role is passed alongside it.
  factory HintAudience.of({required int? viewerSeat, required Role? role}) {
    if (viewerSeat == null || role == null) return const TheTable();
    return OneSeat._(role);
  }
}

/// Everybody at once, on a phone that is about to be handed on.
final class TheTable extends HintAudience {
  const TheTable();
}

/// One player, on a screen only they can see.
final class OneSeat extends HintAudience {
  final Role role;
  const OneSeat._(this.role);
}

// ---------------------------------------------------------------------------
// Tier 1 — interface hints (doc 13 §4.2). Deleted, not dormant.
// ---------------------------------------------------------------------------
//
// `InterfaceHint` taught the *control*: one line, once ever, next to the pass
// pad and the night grid. Doc 14 Part 6 bans a hint on any screen inside a
// live match, and every trigger this tier had was inside one — so what was
// left was an enum, a copy table and a seen-set that nothing could ever
// reach. A tier with no call sites is not a feature held in reserve; it is
// four files the next reader has to understand before finding out that none
// of them run.
//
// The *reservation* survives it, in `TurnShell`: the slot is still measured
// and still empty, because equal height across four roles is doc 05 s
// business and never was this tier s.
//
// `MatchRecord.seenHints` also survives, unread. Dropping a persisted field
// costs a schema migration to reclaim bytes nobody is paying for; it stays,
// and says so.

// ---------------------------------------------------------------------------
// Tier 2 — play hints (doc 13 §4.3). Teach the game, in dead time only.
// ---------------------------------------------------------------------------

/// A hint's stable code. The sentence is looked up in the l10n layer, the same
/// way every other engine-issued code is.
class PlayHint {
  final String code;
  const PlayHint(this.code);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayHint && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'PlayHint($code)';
}

/// The pools, and the one function that picks from them.
abstract final class PlayHints {
  /// Doc 13 §4.3's offline pool. Generic by requirement: identical text for
  /// every player, so identical reading time for every player.
  static const List<PlayHint> table = [
    PlayHint('hint_talkers'),
    PlayHint('hint_quick_agreement'),
    PlayHint('hint_silence'),
    PlayHint('hint_changes_mind'),
    PlayHint('hint_early_accuser'),
    PlayHint('hint_majority_comfort'),
    PlayHint('hint_who_benefited'),
  ];

  /// Doc 13 §4.3's online pools. Unreachable without an [OneSeat], which is
  /// unreachable without a viewer seat.
  static const Map<Role, List<PlayHint>> private = {
    Role.mafia: [
      PlayHint('hint_mafia_suspicion_spreads'),
      PlayHint('hint_mafia_quiet_night'),
      PlayHint('hint_mafia_speak'),
    ],
    Role.doctor: [
      PlayHint('hint_doctor_no_repeat'),
      PlayHint('hint_doctor_self'),
      PlayHint('hint_doctor_save_reveals'),
    ],
    // One each, because doc 14 §4.1 removed the file and §4.2 deferred the
    // testimony, and the hints that taught them taught something the game no
    // longer does.
    Role.detective: [
      PlayHint('hint_detective_investigate_loud'),
    ],
    Role.citizen: [
      PlayHint('hint_citizen_suspicion_counts'),
    ],
  };

  /// The hint for this moment, or null when hints are off.
  ///
  /// ## Seeded, never random
  ///
  /// Doc 13 §4.3: *"Selected by `deriveSeed(matchSeed, 'hint', phaseIndex)` —
  /// not by role, not by `Random()`."* Both halves matter. Not by role, because
  /// offline that is the leak. Not by `Random()`, because offline every phone
  /// must land on the same sentence at the same moment: two players comparing
  /// notes and finding they were shown different hints would be reading a
  /// difference the app did not intend them to have.
  ///
  /// Online, where each player's pool differs anyway, the same seed keeps the
  /// choice stable across a reconnect — a hint that changed when the socket
  /// dropped would look like the app reacting to something.
  static PlayHint? forPhase({
    required HintAudience audience,
    required int matchSeed,
    required int phaseIndex,
    bool enabled = true,
  }) {
    if (!enabled) return null;
    final pool = switch (audience) {
      TheTable() => table,
      OneSeat(role: final role) => private[role] ?? table,
    };
    if (pool.isEmpty) return null;
    final seed = deriveSeed(matchSeed, SeedSalt.hint, phaseIndex);
    return pool[seed.abs() % pool.length];
  }

  /// Every code this module can ever emit. Used by the l10n coverage test, so
  /// a pool that grows a hint without a sentence fails at build time rather
  /// than showing a player a raw code.
  static List<PlayHint> get all => [
        ...table,
        for (final pool in private.values) ...pool,
      ];
}
