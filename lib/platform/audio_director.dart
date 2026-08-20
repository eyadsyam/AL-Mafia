import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_backend.dart';

/// Where the phone is right now.
///
/// This is the single most important piece of state in the audio layer. A cue
/// that plays while one player is holding the phone tells the entire table what
/// stage that player's turn has reached — which is why the gate is a hard
/// error, not a silent no-op (FR-026, L-11).
enum PhoneLocation {
  onTable,
  inHand,
}

/// The sound catalogue from the design system, §8.
///
/// Every cue is on-table by construction: there is deliberately no in-hand cue
/// to add one to. If a future feature seems to need one, that is a signal to
/// re-read L-11 rather than to extend this enum.
enum AudioCue {
  /// "Night falls…" — deep calm narrator over a faint ambient layer.
  nightFalls(narration: true, sound: 'audio/night_falls.ogg'),

  /// "Mafia, open your eyes" — the *same* narrator, with no tension music.
  /// Scoring this differently from the other calls would hint at what is
  /// happening even to someone who cannot see the screen. It therefore has no
  /// bed of its own: until the line is recorded, this cue is silent.
  mafiaWake(narration: true),

  /// "Morning has come" — a gradual rise in the ambient layer.
  morning(narration: true, sound: 'audio/morning.ogg'),

  /// Short neutral chime marking a speaker change (< 1s).
  speakerChange(narration: false, sound: 'audio/speaker_change.ogg'),

  /// Two ascending tones when a phase timer runs out.
  timerEnd(narration: false, sound: 'audio/timer_end.ogg'),

  /// Single deep drum hit on an elimination reveal.
  eliminationReveal(narration: false, sound: 'audio/elimination_reveal.ogg'),

  /// Subtle whoosh for the card flip — plays on-table only, during the
  /// distribution phase when all players can see the flip.
  cardFlip(narration: false, sound: 'audio/card_flip.ogg'),

  /// Soft tick through the last ten seconds of a phase timer.
  timerWarning(narration: false, sound: 'audio/timer_warning.ogg'),

  /// The match result. Deliberately the *same* sting for both outcomes — two
  /// stings would tell the room who won before the screen did.
  win(narration: false, sound: 'audio/win.ogg');

  const AudioCue({required this.narration, this.sound});

  /// Whether this cue is spoken narration, which the host can switch off
  /// (`MatchSettings.narrationEnabled`). Functional cues — the chime, the
  /// timer, the drum — are not narration and stay on.
  final bool narration;

  /// The cue's own sound, relative to `assets/`, or null if it has none yet.
  ///
  /// A narration cue's [sound] is its *ambient bed*, not its voice: the spoken
  /// line is a separate, optional file in [AudioDirector.narratorLines]. That
  /// split is what lets the game ship complete before a word has been recorded
  /// — `mafiaWake` has neither and simply plays nothing.
  final String? sound;
}

/// Plays the table's audio, and refuses to play anyone's private audio.
///
/// ## Narrator slot system
///
/// Every phase transition has a `narratorLine` slot. When a cue with
/// `narration == true` fires, the director checks whether a narrator audio
/// file is registered for it. If present, it plays. If not, it falls back to
/// silence (no crash, no error). This means:
///
/// - Recording a deep Egyptian voice later requires zero code changes.
/// - The plumbing is tested and enforced from day one.
/// - Every narrator slot can be independently enabled/disabled from settings.
///
/// ## Where the sound actually comes from
///
/// Nowhere in this class. Playback is delegated to an [AudioBackend], which is
/// the only place the audio package is named. This file holds the rules — the
/// in-hand gate, the mute, the narration switch, the cue catalogue — because
/// those are the leakage-critical part and should survive a package swap
/// untouched.
class AudioDirector {
  /// Where sound comes out. Defaults to silence so a unit test, a golden test
  /// or a headless run never has to remember to stub it.
  AudioBackend backend;

  AudioDirector({this.backend = const SilentAudioBackend()});

  PhoneLocation _location = PhoneLocation.onTable;

  /// Whether spoken narration is switched on for this match.
  bool narrationEnabled = true;

  /// Master mute — when true, no audio plays at all.
  bool muted = false;

  /// Cues emitted so far, in order. Exposed for tests and for debugging a
  /// mis-sequenced phase; not read by the app.
  final List<AudioCue> emitted = [];

  /// Registered narrator audio file paths, keyed by [AudioCue].
  ///
  /// If a narrator recording exists for a cue, register it here. The director
  /// will play the file when the cue fires. If no file is registered, the cue
  /// fires silently (for narration cues) or plays its functional sound.
  ///
  /// Designed so that dropping audio files into `assets/audio/narrator/` and
  /// registering them here is the only step needed to add voice narration.
  final Map<AudioCue, String> narratorLines = {};

  /// Whether the continuous score is switched on for this match.
  bool scoreEnabled = true;

  bool _scoreRunning = false;

  /// The score: one loop, started once, never varied.
  ///
  /// ## Why this is allowed to play in someone's hand when no cue is
  ///
  /// Article I rule 2 bans a sound from *firing* while a player holds the
  /// phone, and the reason is in the verb. A sound that arrives marks the
  /// moment it arrives; a sound that has been running since before anyone
  /// picked anything up marks nothing. It is the room's acoustic floor,
  /// identical for the mafioso and for the citizen who takes the phone from
  /// them, and it does not change when either of them does anything.
  ///
  /// That is a property this class has to defend, not just describe. There is
  /// deliberately **no** API here to swell it, duck it, layer it, or stop it at
  /// a phase boundary — every one of those would make it react to the game, and
  /// a bed that reacts to the game is a channel that reports on the game. If a
  /// future feature seems to need one, that is a reason to re-read L-11, not to
  /// extend this.
  ///
  /// It also earns its keep: a steady bed masks the small incidental sounds a
  /// private turn makes — a thumb dragging on glass, a held breath, the pause
  /// before a decision — which silence broadcasts.
  ///
  /// Muting is the one thing that may change, because the host chooses it once
  /// and it applies to the whole match rather than to a moment inside it.
  void syncScore() {
    final shouldPlay = scoreEnabled && !muted;
    if (shouldPlay == _scoreRunning) return;
    _scoreRunning = shouldPlay;
    if (shouldPlay) {
      unawaited(backend.startLoop(_assetKey(scoreLoop), volume: scoreVolume));
    } else {
      unawaited(backend.stopLoop());
    }
  }

  /// The looping score asset, relative to `assets/`.
  static const String scoreLoop = 'audio/score_loop.ogg';

  /// Quiet enough to talk over — but the volume is not what does that work.
  ///
  /// The shipped bed is empty between 1 and 4 kHz (a 13 dB notch at 2.2 kHz),
  /// which is the band that carries consonants and therefore speech
  /// intelligibility. That notch is why a table can converse over it at a
  /// normal volume without anyone raising their voice; the level below is only
  /// setting how present it feels.
  ///
  /// The file is −20 dBFS RMS, so 0.5 lands it near −26 dBFS — the value the
  /// asset's own integration note specifies. Do not raise it to compensate for
  /// a quiet phone; raise the phone.
  static const double scoreVolume = 0.5;

  /// Configures the audio session and preloads every cue the app can fire.
  ///
  /// Call once at app start. Preloading is not an optimisation here: a cue that
  /// is decoded on first use is *silent* for the length of that decode, and the
  /// first use of the card-flip cue is the first thing a player taps on the
  /// home screen. It was reliably inaudible for exactly that reason.
  ///
  /// The registered narrator lines are included, so dropping recordings in and
  /// registering them before this runs gets them warmed too.
  Future<void> warmUp() => backend.warmUp(<String>{
        for (final cue in AudioCue.values)
          if (cue.sound != null) _assetKey(cue.sound!),
        for (final line in narratorLines.values) _assetKey(line),
      });

  PhoneLocation get location => _location;

  void setLocation(PhoneLocation location) {
    _location = location;
    // Picking the phone up silences whatever is still sounding. A bed that
    // carried on under a handoff would mark the moment the turn started, which
    // is the same tell as playing a cue during one.
    if (location == PhoneLocation.inHand) {
      backend.stopAll();
    }
  }

  /// Registers a narrator audio file for the given [cue].
  ///
  /// Call this during app initialization or when loading match settings.
  /// The file should be an asset path like `assets/audio/narrator/night_falls.ogg`.
  void registerNarratorLine(AudioCue cue, String assetPath) {
    narratorLines[cue] = assetPath;
  }

  /// Plays [cue], or throws if the phone is in someone's hand.
  ///
  /// Throwing rather than returning quietly is deliberate. A swallowed call
  /// would simply never be heard in testing, and the first person to notice
  /// would be a player who had worked out the pattern.
  void play(AudioCue cue) {
    if (_location == PhoneLocation.inHand) {
      throw StateError(
        'Audio must never play while the phone is in hand '
        '(anti-leakage FR-026): $cue',
      );
    }
    if (muted) return;
    if (cue.narration && !narrationEnabled) return;

    emitted.add(cue);

    // The bed and the narrator line are additive, not alternatives. A recorded
    // "الضلمة نزلت على البلد" is meant to sit *over* the darkening ambience, and
    // a cue with only one of the two still works — which is the whole point of
    // shipping the beds before the voice exists.
    final bed = cue.sound;
    if (bed != null) _emit(bed);

    final narratorLine = narratorLines[cue];
    if (narratorLine != null) _emit(narratorLine);
  }

  /// Hands one asset to the backend. Fire-and-forget: a phase transition must
  /// not wait on a speaker.
  void _emit(String assetPath) => unawaited(backend.play(_assetKey(assetPath)));

  /// Drops the `assets/` prefix the backend does not want.
  static String _assetKey(String assetPath) {
    const prefix = 'assets/';
    return assetPath.startsWith(prefix)
        ? assetPath.substring(prefix.length)
        : assetPath;
  }
}

/// Riverpod provider for the audio director.
///
/// The real backend is installed here and only here, so a test that overrides
/// nothing gets silence and a test that wants to assert on playback overrides
/// [AudioDirector.backend] rather than the whole director.
final audioDirectorProvider = Provider<AudioDirector>((ref) {
  final director = AudioDirector(backend: PluginAudioBackend());
  ref.onDispose(director.backend.dispose);
  return director;
});
