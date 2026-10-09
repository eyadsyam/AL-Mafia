/// Name hygiene shared by every field that takes a person's name.
///
/// Zero-width and bidirectional control characters render as nothing, so a
/// name made of them passes an `isEmpty` check, draws a blank seat and can
/// collide with a real name invisibly. They are removed before any check.
final RegExp _invisible = RegExp(
  '[\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF\u00AD\u061C]',
);

/// [raw] without invisible characters, with runs of whitespace collapsed and
/// the ends trimmed.
String cleanPlayerName(String raw) =>
    raw.replaceAll(_invisible, '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Whether [a] and [b] name the same person for the purpose of seating:
/// case-insensitive on cleaned text.
bool sameNameFold(String a, String b) =>
    cleanPlayerName(a).toLowerCase() == cleanPlayerName(b).toLowerCase();
