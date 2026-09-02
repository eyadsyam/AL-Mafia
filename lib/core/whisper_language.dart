/// The client-side language check on outgoing whispers (doc 09 §3.5).
///
/// ## A warning, never a block
///
/// The spec is explicit: *"Profanity filter — client-side Arabic + English word
/// list, applied on send **with a warning, not a hard block**."* That is the
/// right call and it is worth writing down why, because the temptation to
/// harden it will come back.
///
/// A word list cannot tell an insult from a quotation, and this is a game whose
/// entire content is accusing your friends of murder. A list that blocks will
/// block real play — someone repeating what another player just said out loud,
/// someone swearing in delight — and the player has no way to argue with it.
/// A list that warns costs a wrong guess one extra tap and costs a right guess
/// nothing.
///
/// The real abuse controls are elsewhere and they are structural: one whisper
/// per player per day, 120 characters, private rooms only, and a block list
/// that silently drops a blocked sender's whispers without telling them
/// (H-E9 — never build a harassment feedback loop).
/// ## Why this is not in `lib/ui/`
///
/// The word list below is Arabic and English text in source, and the l10n
/// coverage test — correctly — refuses literal Arabic anywhere under
/// `lib/ui/screens` or `lib/ui/widgets`. It is right to refuse it and this file
/// is right to contain it, because these words are never *displayed*. They are
/// matched against. Routing them through the ARB files would be worse than
/// pointless: the list would then show one language at a time and stop matching
/// the other, which is exactly the bug a bilingual filter must not have.
///
/// The one string a player actually reads — the warning — is in the ARB files
/// like every other piece of copy.
library core.whisper_language;

/// Matches on word boundaries against a small, deliberately conservative list.
///
/// Substring matching is wrong here and the classic example is why: a filter
/// that matches inside words flags perfectly ordinary text and teaches players
/// that the warning means nothing.
class WhisperLanguage {
  const WhisperLanguage._();

  /// Deliberately short. This is a nudge, not a moderation system, and a long
  /// list is a long list of false positives.
  static const List<String> _flagged = [
    // English
    'fuck', 'shit', 'bitch', 'bastard', 'idiot', 'retard',
    // Arabic
    'كلب', 'حمار', 'غبي', 'خرا', 'زبالة', 'حقير',
  ];

  /// Whether [text] contains a flagged word as a whole word.
  static bool looksAbusive(String text) {
    final lower = text.toLowerCase();
    for (final word in _flagged) {
      final pattern = RegExp(
        '(^|[^\\p{L}])${RegExp.escape(word)}([^\\p{L}]|\$)',
        unicode: true,
        caseSensitive: false,
      );
      if (pattern.hasMatch(lower)) return true;
    }
    return false;
  }
}

/// Whispers the reader has chosen never to see again (doc 09 §3.5).
///
/// Offline this is a local list on the device. **The sender is never told.**
/// Telling them turns a block into a message — "you have been blocked" is
/// itself contact, and it invites the escalation the block exists to end.
/// H-E9: *"Whisper silently dropped for the recipient. Sender is **not** told."*
///
/// Offline the list is per-seat within a match and is not persisted: seats are
/// people at one table on one evening, and carrying "seat 3 is blocked" into
/// tomorrow's game would block a different person. Online the same idea keys on
/// the account instead, which is what makes it worth persisting there.
class WhisperBlockList {
  final Set<int> _blocked = <int>{};

  bool isBlocked(int seat) => _blocked.contains(seat);

  void block(int seat) => _blocked.add(seat);

  void unblock(int seat) => _blocked.remove(seat);

  Set<int> get blocked => Set.unmodifiable(_blocked);
}
