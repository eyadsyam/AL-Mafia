import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_backend.dart';
import 'package:mafia_master/platform/audio_director.dart';

/// The audio package is allowed to exist in exactly one file.
///
/// ## Why this is a test and not a comment
///
/// "Swapping the package should touch one file" is a claim that decays the
/// first time somebody reaches for `AudioPlayer` directly because it was closer
/// to hand than the backend. Nothing about that mistake is visible in review —
/// the app still plays sound, the tests still pass — and the cost only lands
/// years later, on whoever is doing the swap.
///
/// So the boundary is measured. If a second file imports `audioplayers`, this
/// fails and names it.
void main() {
  /// The one file allowed to know the package exists.
  const seam = 'lib/platform/audio_backend.dart';

  List<File> libSources() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String rel(File f) => f.path.replaceAll(r'\', '/');

  group('the audio package is confined to one file', () {
    test('only $seam imports audioplayers', () {
      final offenders = <String>[];
      for (final file in libSources()) {
        final path = rel(file);
        if (path == seam) continue;
        if (file.readAsStringSync().contains('audioplayers')) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty,
          reason: 'these files reference the audio package directly, so '
              'swapping it would no longer be a one-file change: $offenders. '
              'Route the call through AudioBackend instead.');
    });

    test('the scan is not vacuous', () {
      // If the seam were renamed or emptied, the check above would pass by
      // finding nothing anywhere.
      expect(File(seam).readAsStringSync(), contains('audioplayers'),
          reason: '$seam no longer imports the audio package; either the seam '
              'moved or playback was removed, and this test is now checking '
              'nothing');
    });
  });

  group('the director degrades rather than fails', () {
    test('a cue with no sound and no narrator line is still emitted', () {
      // mafiaWake has neither a bed nor a recording. It must still count as
      // having happened: the emitted log is what the leakage tests read to
      // prove the *sequence* of cues is role-independent, and a cue that
      // vanished from the log because it had no file would make that sequence
      // depend on which recordings happen to exist.
      final director = AudioDirector();
      expect(AudioCue.mafiaWake.sound, isNull);

      director.play(AudioCue.mafiaWake);
      expect(director.emitted, equals([AudioCue.mafiaWake]));
    });

    test('everything works with sound off', () {
      final director = AudioDirector(backend: _RecordingBackend())
        ..muted = true;

      for (final cue in AudioCue.values) {
        director.play(cue);
      }

      expect(director.emitted, isEmpty,
          reason: 'muting must stop the cue before it is recorded as played');
      expect((director.backend as _RecordingBackend).played, isEmpty,
          reason: 'a muted director reached the speaker');
    });

    test('narration off silences the voice and the bed, not the chime', () {
      final director = AudioDirector(backend: _RecordingBackend())
        ..narrationEnabled = false
        ..registerNarratorLine(
            AudioCue.nightFalls, 'assets/audio/narrator/night_falls.ogg');

      director.play(AudioCue.nightFalls);
      director.play(AudioCue.speakerChange);

      final played = (director.backend as _RecordingBackend).played;
      expect(played, equals(['audio/speaker_change.ogg']),
          reason: 'switching narration off must take its ambient bed with it — '
              'a bed playing under a line nobody can hear is just an unexplained '
              'noise');
    });

    test('a narrator line plays over its bed, not instead of it', () {
      final director = AudioDirector(backend: _RecordingBackend())
        ..registerNarratorLine(
            AudioCue.nightFalls, 'assets/audio/narrator/night_falls.ogg');

      director.play(AudioCue.nightFalls);

      expect(
        (director.backend as _RecordingBackend).played,
        equals(['audio/night_falls.ogg', 'audio/narrator/night_falls.ogg']),
      );
    });

    test('picking the phone up cuts whatever is still sounding', () {
      final director = AudioDirector(backend: _RecordingBackend());
      director.play(AudioCue.nightFalls);
      director.setLocation(PhoneLocation.inHand);

      expect((director.backend as _RecordingBackend).stops, 1,
          reason: 'a bed carrying on under a handoff marks the moment the turn '
              'started as clearly as a cue during one would');
    });
  });

  group('the score never reacts to the game', () {
    // The whole safety argument for a bed that plays while the phone is in
    // someone's hand is that it is *constant*. A loop that started, stopped,
    // swelled or ducked at a game event would mark that event as loudly as a
    // cue would, and it would do it on the one channel nothing else watches.
    //
    // These assertions are the argument, written down.

    test('starts once and is not restarted by anything', () {
      final director = AudioDirector(backend: _RecordingBackend())
        ..syncScore();
      final backend = director.backend as _RecordingBackend;
      expect(backend.loopStarts, hasLength(1));

      // Everything a match does to the director, twice over.
      for (var round = 0; round < 2; round++) {
        for (final cue in AudioCue.values) {
          director.setLocation(PhoneLocation.onTable);
          director.play(cue);
        }
        director.setLocation(PhoneLocation.inHand);
        director.setLocation(PhoneLocation.onTable);
        director.syncScore();
      }

      expect(backend.loopStarts, hasLength(1),
          reason: 'the score was restarted mid-match. Every restart is an '
              'audible seam at the exact moment of whatever caused it.');
      expect(backend.loopStops, isZero,
          reason: 'something stopped the score during play');
    });

    test('picking the phone up silences cues but not the score', () {
      final director = AudioDirector(backend: _RecordingBackend())..syncScore();
      final backend = director.backend as _RecordingBackend;

      director.setLocation(PhoneLocation.inHand);

      expect(backend.stops, 1, reason: 'cues must be cut at a handoff');
      expect(backend.loopStops, isZero,
          reason: 'the score stopped when the phone was picked up, which turns '
              'it into the loudest possible announcement that a turn has '
              'started — the exact failure it is meant to avoid');
    });

    test('a master mute takes the score with it', () {
      final director = AudioDirector(backend: _RecordingBackend())..syncScore();
      final backend = director.backend as _RecordingBackend;

      director
        ..muted = true
        ..syncScore();
      expect(backend.loopStops, 1);

      director
        ..muted = false
        ..syncScore();
      expect(backend.loopStarts, hasLength(2));
    });

    test('the score has no phase-, role- or turn-shaped API', () {
      // Structural, not behavioural: if there is no way to make the bed react
      // to the game, nobody can accidentally make it react to the game. This
      // reads the source because that is where the absence lives.
      final source =
          File('lib/platform/audio_director.dart').readAsStringSync();
      for (final forbidden in const [
        'duckScore',
        'setScoreVolume',
        'scoreForPhase',
        'fadeScore',
      ]) {
        expect(source.contains(forbidden), isFalse,
            reason: 'AudioDirector gained `$forbidden`. A score that can be '
                'varied is a channel that reports on the game.');
      }
    });
  });

  group('every shipped cue names a file that exists', () {
    test('and every file is registered as an asset', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/audio/'));

      for (final cue in AudioCue.values) {
        final sound = cue.sound;
        if (sound == null) continue;
        expect(File('assets/$sound').existsSync(), isTrue,
            reason: '${cue.name} points at assets/$sound, which is not on '
                'disk. Run `python tool/generate_audio.py`.');
      }
    });
  });
}

class _RecordingBackend implements AudioBackend {
  final List<String> played = [];
  final List<String> loopStarts = [];

  /// Keys handed to [warmUp], so a test can assert that a cue was preloaded
  /// rather than opened on first use — which is the difference between the
  /// first tap being audible and being silent.
  final List<String> warmed = [];

  int stops = 0;
  int loopStops = 0;

  @override
  Future<void> warmUp(Iterable<String> assetKeys) async =>
      warmed.addAll(assetKeys);

  @override
  Future<void> play(String assetKey) async => played.add(assetKey);

  @override
  Future<void> stopAll() async => stops++;

  @override
  Future<void> startLoop(String assetKey, {double volume = 1.0}) async =>
      loopStarts.add(assetKey);

  @override
  Future<void> stopLoop() async => loopStops++;

  @override
  Future<void> dispose() async {}
}
