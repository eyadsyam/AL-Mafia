/// One seat's condition (doc 12 §2.3, carried forward by doc 15 §1.3).
///
/// Game states, never role states. Nothing in this enum is reachable for one
/// role and not another, and nothing derived from it may be either. Doc 15
/// replaced the seat *widget* with a painter; the rule the widget carried is
/// older than either of them, so it lives here on its own, where the painter
/// and the leakage suite read the same copy.
enum SeatStatus {
  idle,

  /// Holds the floor. Breathes.
  speaking,

  /// Named in a confrontation: everything else dims around them.
  confronted,

  /// Their client has stopped saying it is there.
  ///
  /// Never red. Doc 12 §5: red is reserved for elimination, and a red badge in
  /// a noir game reads as a crash.
  disconnected,

  /// Out of the match. The ring is cracked and tilted.
  dead,
}

/// The seat's effective status once the phase's leakage rule is applied.
///
/// Pure and exposed so the leakage suite can assert the collapse without
/// rendering anything: *"at night, every seat is idle or dead and nothing
/// else."* Death is public — everybody watched it happen in the morning — so
/// it is the one status that survives a night.
SeatStatus effectiveSeatStatus(
  SeatStatus status, {
  required bool showsStatus,
}) {
  if (showsStatus || status == SeatStatus.dead) return status;
  return SeatStatus.idle;
}
