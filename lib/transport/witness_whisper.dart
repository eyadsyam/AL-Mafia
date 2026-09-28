/// F21a — a whisper as the dead read it. A read-only record: nothing here
/// can address a player (the witness channel has no route to the living).
/// One whisper, as the dead see it (F21a): who to whom, on which day, and
/// what it said. [text] is null when [masked] — the viewer blocked the sender.
class WitnessWhisper {
  final String id;
  final int day;
  final int fromSeat;
  final int toSeat;
  final String? text;
  final bool masked;

  const WitnessWhisper({
    required this.id,
    required this.day,
    required this.fromSeat,
    required this.toSeat,
    required this.text,
    required this.masked,
  });

  /// Rows from `witness_view`; malformed rows are skipped, a masked row's
  /// text is dropped even if a server sent one.
  static List<WitnessWhisper> listFromJson(Object? json) {
    return [
      for (final row in (json is List ? json : const []).cast<Map>())
        if (row['id'] is String &&
            row['day'] is int &&
            row['fromSeat'] is int &&
            row['toSeat'] is int)
          WitnessWhisper(
            id: row['id'] as String,
            day: row['day'] as int,
            fromSeat: row['fromSeat'] as int,
            toSeat: row['toSeat'] as int,
            text: row['masked'] == true ? null : row['text'] as String?,
            masked: row['masked'] == true,
          ),
    ];
  }
}
