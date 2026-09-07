import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../transport/game_snapshot.dart';

/// One thing this player did, in public, on one day.
@immutable
class RecordEntry {
  final int day;

  /// The seat they named in the «اسم واحد» round, or null if they did not.
  final int? accused;

  /// The seat they whispered to, or null.
  final int? whisperedTo;

  const RecordEntry({required this.day, this.accused, this.whisperedTo});

  bool get isEmpty => accused == null && whisperedTo == null;

  RecordEntry merge(RecordEntry other) => RecordEntry(
    day: day,
    accused: other.accused ?? accused,
    whisperedTo: other.whisperedTo ?? whisperedTo,
  );

  @override
  bool operator ==(Object other) =>
      other is RecordEntry &&
      other.day == day &&
      other.accused == accused &&
      other.whisperedTo == whisperedTo;

  @override
  int get hashCode => Object.hash(day, accused, whisperedTo);
}

/// What this player did while they were alive (doc 12 §4.1).
///
/// ## Why it is accumulated on the client rather than read from the server
///
/// Because it is not a new fact. Every entry below was public at the moment it
/// happened — an accusation is said out loud in the opening round, and a
/// whisper's *existence* is drawn on the table for the whole room. This is only
/// a record of what this device already watched go past, kept so that an
/// eliminated player can look back at their own reasoning instead of at a blank
/// panel.
///
/// Storing it server-side would turn a memory into a document, and a document
/// is a thing the next feature can accidentally show to somebody else.
///
/// ## And why there is no correctness marking
///
/// Doc 12 §4.1 is explicit — *"without correctness marking (see doc 09 leakage
/// note)"* — and the reason is worth restating where somebody might add it. A
/// dead player whose record showed a green tick beside «شكّيت في سارة» would
/// know Sarah's alignment, and a dead player is in a text conversation with
/// every other dead player. Correctness marking in witness mode is a channel
/// from the graveyard to itself that reveals living roles, which is the one
/// thing doc 12 §4.1's "what they must never see" list names first.
///
/// So: what you did, in the order you did it, and never whether it was right.
class OwnRecord extends Notifier<List<RecordEntry>> {
  @override
  List<RecordEntry> build() => const [];

  /// Folds one snapshot in. Idempotent: the same snapshot applied twice
  /// changes nothing, which matters because the transport republishes on every
  /// heartbeat and on every reconnection.
  void observe(GameSnapshot snapshot) {
    final seat = snapshot.viewerSeat;
    if (seat == null) return;

    final day = snapshot.dayNumber;
    final entry = RecordEntry(
      day: day,
      accused: snapshot.openingAccusations[seat],
      whisperedTo: snapshot.whisperGraph
          .where((w) => w.fromSeat == seat && !w.voided)
          .map((w) => w.toSeat)
          .firstOrNull,
    );
    if (entry.isEmpty) return;

    final existing = state.where((e) => e.day == day).firstOrNull;
    final merged = existing == null ? entry : existing.merge(entry);
    if (merged == existing) return;

    state = [
      for (final e in state)
        if (e.day != day) e,
      merged,
    ]..sort((a, b) => a.day.compareTo(b.day));
  }

  /// Forgets everything. Called when a match ends, so the next one starts
  /// blank rather than inheriting somebody's last evening.
  void clear() => state = const [];
}

final ownRecordProvider = NotifierProvider<OwnRecord, List<RecordEntry>>(
  OwnRecord.new,
);
