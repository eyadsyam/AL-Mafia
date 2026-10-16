/// Which of a fixed set of players each cue plays on (the web backend).
///
/// A cue keeps the player it last used, so a retrigger restarts the same
/// clip already loaded there (the timer tick ten times in ten seconds is one
/// player). A new cue takes an empty player, else the one idle longest, else
/// — every player sounding — the one started longest ago. Pure: the browser
/// side asks it and does what it says.
class CueSlots {
  CueSlots(this.size)
    : assert(size > 0),
      _keys = List<String?>.filled(size, null),
      _used = List<int>.filled(size, 0);

  final int size;
  final List<String?> _keys;
  final List<int> _used;
  int _clock = 0;

  /// The cue loaded in [slot], if any.
  String? keyAt(int slot) => _keys[slot];

  /// Puts [key] on a player for playing now. [sounding] says whether a
  /// player is mid-clip. [load] is true when the player must open [key]
  /// (it held another cue, or none).
  ({int slot, bool load}) take(
    String key, {
    required bool Function(int slot) sounding,
  }) {
    final held = _keys.indexOf(key);
    if (held >= 0) {
      _used[held] = ++_clock;
      return (slot: held, load: false);
    }
    var pick = _keys.indexOf(null);
    if (pick < 0) pick = _oldest((i) => !sounding(i));
    if (pick < 0) pick = _oldest((_) => true);
    _keys[pick] = key;
    _used[pick] = ++_clock;
    return (slot: pick, load: true);
  }

  /// Loads [key] ahead into an empty player, if one is left; the slot, or
  /// null when every player already holds a cue.
  int? preload(String key) {
    if (_keys.contains(key)) return null;
    final empty = _keys.indexOf(null);
    if (empty < 0) return null;
    _keys[empty] = key;
    return empty;
  }

  int _oldest(bool Function(int slot) allowed) {
    var best = -1;
    for (var i = 0; i < size; i++) {
      if (!allowed(i)) continue;
      if (best < 0 || _used[i] < _used[best]) best = i;
    }
    return best;
  }
}
