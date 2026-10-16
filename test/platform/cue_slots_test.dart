import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_backend.dart';
import 'package:mafia_master/platform/cue_slots.dart';

/// The web's few cue players, taken in turn: what used to be one player (and
/// one Web Audio context) per clip.
void main() {
  test('a retriggered cue restarts on its own player', () {
    final slots = CueSlots(3);
    final first = slots.take('tick', sounding: (_) => false);
    expect(first.load, isTrue);
    for (var i = 0; i < 10; i++) {
      final again = slots.take('tick', sounding: (_) => true);
      expect(again, (slot: first.slot, load: false));
    }
  });

  test('overlapping cues sound on different players', () {
    final slots = CueSlots(3);
    final sounding = <int>{};
    for (final key in ['drum', 'bed', 'tick']) {
      final t = slots.take(key, sounding: sounding.contains);
      expect(sounding, isNot(contains(t.slot)));
      sounding.add(t.slot);
    }
    expect(sounding, hasLength(3));
  });

  test('a new cue takes the player idle longest, never one mid-clip', () {
    final slots = CueSlots(3);
    final a = slots.take('a', sounding: (_) => false).slot;
    final b = slots.take('b', sounding: (_) => false).slot;
    final c = slots.take('c', sounding: (_) => false).slot;
    slots.take('a', sounding: (_) => false); // a is the most recent now
    // b is mid-clip, so the idle one used longest ago is c.
    final d = slots.take('d', sounding: (i) => i == b);
    expect(d, (slot: c, load: true));
    expect(slots.keyAt(a), 'a');
    expect(slots.keyAt(b), 'b');
  });

  test('every player sounding: the one started longest ago is cut', () {
    final slots = CueSlots(2);
    final a = slots.take('a', sounding: (_) => false).slot;
    slots.take('b', sounding: (_) => false);
    expect(slots.take('c', sounding: (_) => true), (slot: a, load: true));
  });

  test('preloading fills empty players only, once per cue', () {
    final slots = CueSlots(2);
    expect(slots.preload('a'), 0);
    expect(slots.preload('a'), isNull);
    expect(slots.preload('b'), 1);
    expect(slots.preload('c'), isNull, reason: 'no player left');
    expect(slots.take('a', sounding: (_) => false), (slot: 0, load: false));
  });

  test('off the web the audio package stays the backend', () {
    expect(platformAudioBackend(web: false), isA<PluginAudioBackend>());
  });
}
