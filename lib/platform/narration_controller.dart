import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_director.dart' show webAudioAssetKey;

/// Where a narration is. [ended] is its own state: the bar offers «اسمعها
/// تاني» and never loops or restarts by itself.
enum NarrationState { idle, loading, playing, paused, ended, error }

/// The seam between the controller and a real player, so tests drive it.
abstract class NarrationPlayer {
  Stream<Duration> get positions;
  Stream<Duration> get durations;
  Stream<void> get completions;

  Future<void> start(String assetKey);
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration to);
  Future<void> stop();
  Future<void> dispose();
}

/// The audioplayers-backed player: its own instance, separate from the cue
/// pool and the score loop, in media mode because it seeks.
class PluginNarrationPlayer implements NarrationPlayer {
  final AudioPlayer _player = AudioPlayer()
    ..setPlayerMode(PlayerMode.mediaPlayer)
    ..setReleaseMode(ReleaseMode.stop);

  @override
  Stream<Duration> get positions => _player.onPositionChanged;

  @override
  Stream<Duration> get durations => _player.onDurationChanged;

  @override
  Stream<void> get completions => _player.onPlayerComplete;

  @override
  Future<void> start(String assetKey) => _player.play(AssetSource(assetKey));

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> seek(Duration to) => _player.seek(to);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

/// One story narration with real position and duration: play, pause, seek
/// anywhere, ±5 s, restart, stop. A failure is quiet: the story plays on
/// without its narrator.
class NarrationController extends ChangeNotifier {
  NarrationController(this._player, {bool web = kIsWeb}) : _web = web {
    _subs = [
      _player.positions.listen((p) {
        if (state == NarrationState.ended) return;
        position = p;
        notifyListeners();
      }),
      _player.durations.listen((d) {
        duration = d;
        notifyListeners();
      }),
      _player.completions.listen((_) {
        state = NarrationState.ended;
        position = duration;
        notifyListeners();
      }),
    ];
  }

  static const skipStep = Duration(seconds: 5);

  final NarrationPlayer _player;
  final bool _web;
  late final List<StreamSubscription<Object?>> _subs;

  NarrationState state = NarrationState.idle;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  String? _asset;

  /// The asset this controller holds, as the story names it (`assets/…`).
  String? get asset => _asset;

  bool get isPlaying => state == NarrationState.playing;

  /// Starts [assetPath] from the beginning.
  Future<void> play(String assetPath) async {
    _asset = assetPath;
    state = NarrationState.loading;
    position = Duration.zero;
    notifyListeners();
    try {
      await _player.start(_key(assetPath));
      state = NarrationState.playing;
    } catch (error) {
      debugPrint('narration: could not play $assetPath — $error');
      state = NarrationState.error;
    }
    notifyListeners();
  }

  /// The big button: play, pause, resume, or play again after the end.
  Future<void> toggle(String assetPath) async {
    switch (state) {
      case NarrationState.playing:
        await pause();
      case NarrationState.paused when _asset == assetPath:
        await _guard(() => _player.resume(), NarrationState.playing);
      default:
        await play(assetPath);
    }
  }

  Future<void> pause() async {
    if (state != NarrationState.playing) return;
    await _guard(() => _player.pause(), NarrationState.paused);
  }

  /// Seeks to [to], clamped to the track. Seeking after the end resumes play
  /// from there, which is what a tap on the bar of a finished track means.
  Future<void> seek(Duration to) async {
    final asset = _asset;
    if (asset == null) return;
    final target = _clamp(to);
    if (state == NarrationState.ended || state == NarrationState.idle) {
      await play(asset);
    }
    position = target;
    notifyListeners();
    await _guard(() => _player.seek(target), state);
  }

  Future<void> skip(Duration delta) => seek(position + delta);

  Future<void> restart() async {
    final asset = _asset;
    if (asset != null) await play(asset);
  }

  Future<void> stop() async {
    if (state == NarrationState.idle) return;
    await _guard(() => _player.stop(), NarrationState.idle);
    position = Duration.zero;
    notifyListeners();
  }

  Duration _clamp(Duration to) {
    if (to < Duration.zero) return Duration.zero;
    if (duration > Duration.zero && to > duration) return duration;
    return to;
  }

  Future<void> _guard(
    Future<void> Function() action,
    NarrationState next,
  ) async {
    try {
      await action();
      state = next;
    } catch (error) {
      debugPrint('narration: $error');
      state = NarrationState.error;
    }
    notifyListeners();
  }

  String _key(String assetPath) {
    const prefix = 'assets/';
    final key = assetPath.startsWith(prefix)
        ? assetPath.substring(prefix.length)
        : assetPath;
    return webAudioAssetKey(key, web: _web);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_player.stop().then((_) => _player.dispose()).catchError((_) {}));
    super.dispose();
  }
}
