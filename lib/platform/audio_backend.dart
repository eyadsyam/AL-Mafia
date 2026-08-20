import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The only file in the app that knows which audio package is installed.
///
/// ## Why the seam is here and not inside the director
///
/// [AudioDirector] owns the rules — what may play, when, and whether the phone
/// is on the table. Those rules are the leakage-critical part and they are
/// worth keeping stable across a package swap, so they live somewhere a package
/// swap cannot reach. Everything below this line is "make a noise from a file",
/// which every audio package on pub does slightly differently and none of them
/// does interestingly.
///
/// Replacing `audioplayers` means rewriting [PluginAudioBackend] and the import
/// at the top of this file. Nothing else in `lib/` mentions the package, and a
/// test enforces that (`audio_backend_isolation_test.dart`).
abstract class AudioBackend {
  /// Configures the audio session and warms every cue in [assetKeys].
  ///
  /// Call once at app start, before anything plays. Two separate jobs, both of
  /// which have to happen before the first tap rather than during it:
  ///
  ///  * **the session** decides whether two of this app's own players may sound
  ///    at the same time. Configured wrong, the score and the card effects take
  ///    turns silencing each other;
  ///  * **the warm-up** decodes each short cue so the first tap is as loud and
  ///    as immediate as the fiftieth. A cue loaded on demand is silent for the
  ///    length of the load, which on a cold start is the whole effect.
  ///
  /// Never throws. Audio is an enhancement; a game night does not stop because
  /// a decoder did.
  Future<void> warmUp(Iterable<String> assetKeys);

  /// Starts [assetKey] and returns without waiting for it to finish.
  ///
  /// The key is a path relative to `assets/`, because that is the shape
  /// `audioplayers` wants; [AudioDirector] holds full asset paths and strips the
  /// prefix at the boundary, so its catalogue reads like every other asset
  /// constant in the app.
  ///
  /// Never throws. A cue that cannot be found is a missing recording, not a
  /// fault: the app is specified to work with sound off, so it must also work
  /// with sound merely absent.
  Future<void> play(String assetKey);

  /// Cuts every *cue* currently sounding. Used when the phone is picked up.
  ///
  /// Deliberately does not touch the loop started by [startLoop]. The loop is
  /// the room's acoustic floor and is safe precisely because it never reacts to
  /// anything; stopping it at a handoff would turn it into the loudest possible
  /// signal that a turn had begun.
  Future<void> stopAll();

  /// Starts [assetKey] looping, at [volume] (0..1), and returns.
  ///
  /// Idempotent: calling it again with the same key does not restart the loop.
  /// The whole value of the score is that it is unbroken, and a rebuild that
  /// restarted it would put an audible seam at whatever moment triggered the
  /// rebuild.
  Future<void> startLoop(String assetKey, {double volume});

  /// Stops the loop, if one is running.
  Future<void> stopLoop();

  Future<void> dispose();
}

/// Plays nothing, successfully.
///
/// The default in tests and the fallback if the platform has no audio at all.
/// Note that this is *not* how muting works — [AudioDirector.muted] stops a cue
/// before it reaches a backend, so that the emitted-cue log still records what
/// the app decided to play. Swapping in this class would make that log lie.
class SilentAudioBackend implements AudioBackend {
  const SilentAudioBackend();

  @override
  Future<void> warmUp(Iterable<String> assetKeys) async {}

  @override
  Future<void> play(String assetKey) async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> startLoop(String assetKey, {double volume = 1.0}) async {}

  @override
  Future<void> stopLoop() async {}

  @override
  Future<void> dispose() async {}
}

/// `audioplayers` behind the seam.
///
/// ## One player per cue, not one player shared
///
/// Cues overlap: the elimination drum lands while the morning bed is still
/// opening out, and the timer tick fires ten times in ten seconds. A single
/// player would cut each cue off at the start of the next one, which sounds
/// like a fault rather than like restraint. Players are created on first use and
/// reused, so the count is bounded by the size of the catalogue.
class PluginAudioBackend implements AudioBackend {
  final Map<String, AudioPlayer> _players = {};

  /// The score. Held separately from [_players] so [stopAll] cannot reach it.
  AudioPlayer? _loop;
  String? _loopKey;

  bool _sessionConfigured = false;

  /// Makes this app's own players willing to sound at the same time.
  ///
  /// # The bug this fixes
  ///
  /// Android arbitrates playback with *audio focus*, and the default request
  /// `audioplayers` makes is `gain` — exclusive. That is the correct thing to
  /// ask for when an app wants the speaker to itself, and the wrong thing when
  /// one app holds two players: the second request evicts the first. The
  /// observable result was that the score and the card effects were mutually
  /// exclusive — the loop held focus so a tap was silent, and once the loop
  /// stopped the taps started working.
  ///
  /// Requesting **no** focus is what actually fixes it. `gainTransientMayDuck`
  /// is the usual answer for "please let others through", but it does not help
  /// here, because the two players fighting belong to the same app and both
  /// would be asking for the same transient focus. With `none` neither player
  /// arbitrates at all and the mixer simply sums them, which is the behaviour
  /// this app wants: the score is an unbroken bed and an effect lands on top of
  /// it.
  ///
  /// The cost is that the app no longer ducks other apps' audio. For a
  /// pass-the-phone party game whose score is deliberately quiet and notch-cut
  /// for speech, that is the right trade — a host with music already playing
  /// keeps it.
  ///
  /// Set globally and once. `audioplayers` applies the context to every player
  /// created afterwards, which is why this must run before the first one.
  Future<void> _configureSession() async {
    if (_sessionConfigured) return;
    _sessionConfigured = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (error) {
      debugPrint('audio: could not configure the session — $error');
    }
  }

  @override
  Future<void> warmUp(Iterable<String> assetKeys) async {
    await _configureSession();
    for (final key in assetKeys) {
      try {
        final player = _players.putIfAbsent(key, AudioPlayer.new);
        // `lowLatency` is SoundPool on Android: the clip is decoded once and
        // held resident, and playing it afterwards is a single call with no
        // preparation step. It is the right mode for a handful of short cues
        // and the wrong one for the score, which is why the loop below does not
        // use it.
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(key));
      } catch (error) {
        // A cue that will not preload is a cue that will not play. Both are
        // survivable; neither may take the launch with it.
        debugPrint('audio: could not preload $key — $error');
      }
    }
  }

  @override
  Future<void> startLoop(String assetKey, {double volume = 1.0}) async {
    if (_loopKey == assetKey && _loop != null) {
      await _loop!.setVolume(volume);
      return;
    }
    try {
      await _configureSession();
      await stopLoop();
      final player = AudioPlayer()
        ..setReleaseMode(ReleaseMode.loop)
        ..setPlayerMode(PlayerMode.mediaPlayer);
      await player.setVolume(volume);
      await player.play(AssetSource(assetKey));
      _loop = player;
      _loopKey = assetKey;
    } catch (error) {
      debugPrint('audio: could not start loop $assetKey — $error');
    }
  }

  @override
  Future<void> stopLoop() async {
    final player = _loop;
    _loop = null;
    _loopKey = null;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {
      // Already trying to make it quiet; nothing useful to do.
    }
  }

  @override
  Future<void> play(String assetKey) async {
    try {
      final warmed = _players[assetKey];
      if (warmed != null) {
        // Already decoded and resident. Retrigger rather than re-open: a rapid
        // series of taps has to replay the same clip, and re-setting the source
        // each time is what made the first tap silent.
        //
        // `stop()` then `resume()` and *not* a seek. These players are in
        // `PlayerMode.lowLatency`, which is SoundPool on Android, and SoundPool
        // has no seek: the call never completes and `audioplayers` gives up on
        // it after a 30-second timeout. Every tap took thirty seconds to fail
        // and the queue backed up behind it. `stop()` already rewinds a
        // SoundPool stream to the start, so the seek bought nothing even in
        // principle.
        await warmed.stop();
        await warmed.resume();
        return;
      }
      // Not in the warm set — a narrator line registered after start-up, or a
      // cue whose preload failed. Open it the slow way rather than not at all.
      await _configureSession();
      final player = _players.putIfAbsent(assetKey, AudioPlayer.new);
      await player.stop();
      await player.play(AssetSource(assetKey));
    } catch (error, stack) {
      // A missing or unplayable cue must not take a phase transition with it.
      // The game is played face to face; silence is a degraded experience and a
      // thrown exception mid-handoff is a ruined evening.
      debugPrint('audio: could not play $assetKey — $error');
      assert(() {
        debugPrintStack(stackTrace: stack, label: 'audio');
        return true;
      }());
    }
  }

  @override
  Future<void> stopAll() async {
    for (final player in _players.values) {
      try {
        await player.stop();
      } catch (_) {
        // Nothing useful to do: we are already trying to make it quiet.
      }
    }
  }

  @override
  Future<void> dispose() async {
    await stopLoop();
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}
